# frozen_string_literal: true

require "active_record"
require "typesafe/rails/version"
require "typesafe/rails/questions"
require "typesafe/rails/decision_policy"
require "typesafe/rails/call_log"
require "typesafe/rails/result"
require "typesafe/rails/client"
require "typesafe/rails/railtie" if defined?(::Rails::Railtie)

module Typesafe
  module Rails
    class << self
      include Questions

      attr_accessor :configuration

      def client
        @client ||= Client.from_config
      end

      def reset_client!
        @client&.close
        @client = nil
      end
    end
  end
end
