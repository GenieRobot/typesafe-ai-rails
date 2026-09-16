# frozen_string_literal: true

require_relative "../../test_helper"
require "rails"
require "typesafe/rails/railtie"

class RailtieTest < Minitest::Test
  def test_default_pricing_includes_jev_family
    pricing = Typesafe::Rails::Railtie.config.typesafe.pricing

    assert_in_delta 0.042, pricing.fetch("jev").fetch(:input_per_mtok), 0.000001
    assert_in_delta 0.0, pricing.fetch("jev").fetch(:output_per_mtok), 0.000001
  end
end
