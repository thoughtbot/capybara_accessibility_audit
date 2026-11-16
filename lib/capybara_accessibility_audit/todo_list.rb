require "yaml"
require "axe/api/results"

module CapybaraAccessibilityAudit
  # Reads and writes the todo file: the accessibility violations that a suite
  # permits while it works through them. The file maps each test to the rules
  # it violates, and each rule to the selectors of the nodes that violate it:
  #
  #   ---
  #   CheckoutTest#test_submits_the_order:
  #     color-contrast:
  #     - ".total"
  #     label:
  #     - "#coupon"
  #
  # A rule without a list of selectors permits every node that violates it.
  class TodoList
    HEADER = <<~YAML
      # This file lists the accessibility violations that each system test is
      # permitted to detect. capybara_accessibility_audit generated it, and it
      # ignores the violations it lists. Fix a violation, then remove its entry.
      #
      # To regenerate this file, run the suite with CAPYBARA_ACCESSIBILITY_AUDIT_TODO=1
    YAML

    def self.identify(test)
      if defined?(::RSpec::Core::ExampleGroup) && test.is_a?(::RSpec::Core::ExampleGroup)
        ::RSpec.current_example.full_description
      else
        "#{test.class.name}##{test.name}"
      end
    end

    def self.selector(node)
      Array(node.target).join(", ")
    end

    attr_reader :path

    def initialize(path)
      @path = Pathname(path)
    end

    def entries
      @entries ||= path.exist? ? parse(path.read) : {}
    end

    def permitted?(test_id, rule_id, node)
      rules = entries.fetch(test_id, {})

      if rules.key?(rule_id.to_s)
        selectors = rules[rule_id.to_s]

        selectors.nil? || selectors.include?(self.class.selector(node))
      else
        false
      end
    end

    # Answers a copy of the results without the violations that the list
    # permits for the test.
    def reject_permitted(test_id, results)
      violations = results.violations.filter_map do |rule|
        nodes = rule.nodes.reject { |node| permitted?(test_id, rule.id, node) }

        rule.class.new(rule.attributes.merge(nodes: nodes)) if nodes.any?
      end

      results.class.new(results.attributes.merge(violations: violations))
    end

    # Writes the violations to the test's entry. Replacing the entry discards
    # what an earlier run recorded for the test. Parallel test processes share
    # the file, so the write holds an exclusive lock.
    def record(test_id, violations, replace: false)
      path.dirname.mkpath

      path.open(File::RDWR | File::CREAT) do |file|
        file.flock(File::LOCK_EX)

        entries = parse(file.read)
        rules = replace ? {} : entries.fetch(test_id, {})

        violations.each do |rule|
          next if rules.key?(rule.id.to_s) && rules[rule.id.to_s].nil?

          selectors = rules[rule.id.to_s] ||= []
          selectors.concat(rule.nodes.map { |node| self.class.selector(node) })
          selectors.uniq!
          selectors.sort!
        end

        if rules.empty?
          entries.delete(test_id)
        else
          entries[test_id] = rules.sort.to_h
        end

        file.rewind
        file.truncate(0)
        file.write(dump(entries.sort.to_h))
        file.flush

        @entries = entries
      end
    end

    private

    def parse(source)
      YAML.safe_load(source) || {}
    end

    def dump(entries)
      HEADER + YAML.dump(entries)
    end
  end
end
