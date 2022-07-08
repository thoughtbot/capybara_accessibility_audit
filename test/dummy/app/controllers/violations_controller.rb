class ViolationsController < ApplicationController
  def index
    @violations = params.fetch(:rules, []).map(&:underscore).inquiry
  end
end
