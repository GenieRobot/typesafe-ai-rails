# frozen_string_literal: true

module Typesafe
  module Rails
    class Railtie < ::Rails::Railtie
      config.typesafe = ActiveSupport::OrderedOptions.new

      config.typesafe.api_key = nil
      config.typesafe.base_url = nil
      config.typesafe.model = "jev-latest"
      config.typesafe.timeout = 10.0
      config.typesafe.headers = nil
      config.typesafe.user_agent = nil
      config.typesafe.logger = nil
      config.typesafe.retry_policy = nil
      config.typesafe.transport = nil
      config.typesafe.strict_logging = false
      config.typesafe.pricing = Client::DEFAULT_PRICING.transform_values(&:dup)

      initializer "typesafe.configure" do |app|
        Typesafe::Rails.configuration = app.config.typesafe
      end

      generators do
        require "generators/typesafe/rails/install/install_generator"
      end
    end
  end
end
