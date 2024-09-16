# CapybaraAccessibilityAudit

Extend your Capybara-powered System Tests to automatically audit the page for
[WCAG Standards-based accessibility violations](https://www.w3.org/WAI/standards-guidelines/wcag/).

## Usage

```
Failure:
Found 1 accessibility violation:

1) label: Form elements must have labels (critical)
    https://dequeuniversity.com/rules/axe/4.4/label?application=axeAPI
    The following 1 node violate this rule:

        Selector: input
        HTML: <input>
        Fix any of the following:
        - Form element does not have an implicit (wrapped) <label>
        - Form element does not have an explicit <label>
        - aria-label attribute does not exist or is empty
        - aria-labelledby attribute does not exist, references elements that do not exist or references elements that are empty
        - Element has no title attribute
        - Element has no placeholder attribute
        - Element's default semantics were not overridden with role="none" or role="presentation"

Invocation: axe.run({:exclude=>[]}, {}, callback);
```

Installing the gem will automatically configure your System Tests to audit for
accessibility violations after common actions, including:

* [`visit`](https://rubydoc.info/github/teamcapybara/capybara/master/Capybara/Session:visit)
* [`click_button`](https://rubydoc.info/github/teamcapybara/capybara/master/Capybara/Node/Actions#click_button-instance_method)
* [`click_link`](https://rubydoc.info/github/teamcapybara/capybara/master/Capybara/Node/Actions#click_link-instance_method)
* [`click_link_or_button`](https://rubydoc.info/github/teamcapybara/capybara/master/Capybara/Node/Actions#click_link_or_button-instance_method)
* [`click_on`](https://rubydoc.info/github/teamcapybara/capybara/master/Capybara/Node/Actions:click_on)

Under the hood, `capybara_accessibility_audit` relies on [axe-core-rspec][], which uses [aXe][]
to audit for accessibility violations. To configure which options are passed to
the `be_axe_clean` matcher, override the class-level
`accessibility_audit_options`. Supported keys include:

* [`according_to:`](https://github.com/dequelabs/axe-core-gems/blob/develop/packages/axe-core-rspec/README.md#according_to---accessibility-standard-tag-clause)
* [`checking_only:`](https://github.com/dequelabs/axe-core-gems/blob/develop/packages/axe-core-rspec/README.md#checking_only---exclusive-rules-clause)
* [`checking:`](https://github.com/dequelabs/axe-core-gems/blob/develop/packages/axe-core-rspec/README.md#checking---checking-rules-clause)
* [`excluding:`](https://github.com/dequelabs/axe-core-gems/blob/develop/packages/axe-core-rspec/README.md#excluding---exclusion-clause)
* [`skipping:`](https://github.com/dequelabs/axe-core-gems/blob/develop/packages/axe-core-rspec/README.md#skipping---skipping-rules-clause)
* [`within:`](https://github.com/dequelabs/axe-core-gems/blob/develop/packages/axe-core-rspec/README.md#within---inclusion-clause)

To override the class-level setting, wrap code in calls to the
`with_accessibility_audit_options` method:

```ruby
with_accessibility_audit_options according_to: :wcag21aaa do
  visit page_with_violations_path
end
```

[aXe]: https://www.deque.com/axe/
[axe-core-rspec]: https://github.com/dequelabs/axe-core-gems/blob/develop/packages/axe-core-rspec/README.md#matcher

## Frequently Asked Questions

My application already exists, automated accessibility audits are uncovering violations left and right. Do I have to fix them all at once?
---

Your suite has control over which rules are skipped and which rules are
enforced through the `accessibility_audit_options` configuration.

Configuration overrides can occur at any scope, ranging from class-wide to
block-wide.

For example, to skip a rule at the suite-level, override it in your
`ApplicationSystemTestCase`:

```ruby
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  accessibility_audit_options.skipping = %w[label button-name image-alt]
end
```

To skip a rule at the test-level, wrap the test in a
`with_accessibility_audit_options` block:

```ruby
class MySystemTest < ApplicationSystemTestCase
  test "with overridden accessibility audit options" do
    with_accessibility_audit_options skipping: %w[label button-name image-alt] do
      visit examples_path
      # ...
    end
  end
end
```

To skip a rule at the block-level, wrap the code in a
`with_accessibility_audit_options` block:

```ruby
class MySystemTest < ApplicationSystemTestCase
  test "with overridden accessibility audit options" do
    visit examples_path

    with_accessibility_audit_options skipping: %w[label button-name image-alt] do
      click_on "A link to a page with a violation"
    end

    # ...
  end
end
```

As you resolve the violations, you can remove entries from the list of skipped
rules.

I've implemented a custom Capybara action to toggle a disclosure element. How can I automatically audit for violations after it's called?
---

You can add the method to the list of methods that will initiate an automated
audit:

```ruby
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  def toggle_disclosure(locator)
    # ...
  end

  accessibility_audit_after :toggle_disclosure
end
```

How can I turn off auditing for the entire suite?
---

You can disable automated auditing within your `ApplicationSystemTestCase`:

```ruby
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  self.accessibility_audit_enabled = false
end
```

How can I make all of the failing tests just be pending instead of failures?
---

You can allow automated auditing, but mark tests that fail the auditing be marked as `pending` instead of `failed`:

```ruby
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  self.accessibility_audit_skip_on_error = true
end
```

How can I turn off auditing for a block of code?
---

You can disable automated auditing temporarily by wrapping code in a
`skip_accessibility_audits` block:

```ruby
class MySystemTest < ApplicationSystemTestCase
  test "with overridden accessibility audit options" do
    skip_accessibility_audits do
      visit a_page_with_violations_path

      click_on "A link to a page with a violation"
    end

    # ...
  end
end
```

How can I turn off auditing hooks for a method?
---

You can remove the method from the test's [Set][] of
`accessibility_audit_after_methods` configuration by calling
`skip_accessibility_audit_after`:

```ruby
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  skip_accessibility_audit_after :visit
end
```

[Set]: https://ruby-doc.org/stdlib-3.0.1/libdoc/set/rdoc/Set.html

How can I turn off auditing for a test file?
---

You can disable automated auditing at the class-level:

```ruby
class MySystemTest < ApplicationSystemTestCase
  self.accessibility_audit_enabled = false
end
```

As you gradually address violations, you can re-enable audits within
`with_accessibility_audits` blocks:

```ruby
class MySystemTest < ApplicationSystemTestCase
  self.accessibility_audit_enabled = false

  test "a test with a violation" do
    visit examples_path

    with_accessibility_audits do
      click_on "A link to a page with violations"
    end
  end
end
```

## Installation
Add this line to your application's Gemfile:

```ruby
gem "capybara_accessibility_audit"
```

And then execute:
```bash
$ bundle
```

## Contributing

Please read [CONTRIBUTING.md](./CONTRIBUTING.md).

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

<!-- START /templates/footer.md -->
## About thoughtbot

![thoughtbot](https://thoughtbot.com/thoughtbot-logo-for-readmes.svg)

This repo is maintained and funded by thoughtbot, inc.
The names and logos for thoughtbot are trademarks of thoughtbot, inc.

We love open source software!
See [our other projects][community].
We are [available for hire][hire].

[community]: https://thoughtbot.com/community?utm_source=github
[hire]: https://thoughtbot.com/hire-us?utm_source=github


<!-- END /templates/footer.md -->
