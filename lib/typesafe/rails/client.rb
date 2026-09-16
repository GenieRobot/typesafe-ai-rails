# frozen_string_literal: true

require "typesafe/sdk"

module Typesafe
  module Rails
    class Client
      SDK_OPTIONS = %i[base_url headers user_agent logger retry_policy transport].freeze

      DEFAULT_PRICING = {
        "jev" => { input_per_mtok: 0.042, output_per_mtok: 0.0 },
        "jev-latest" => { input_per_mtok: 0.042, output_per_mtok: 0.0 },
        "jev-1.12" => { input_per_mtok: 0.042, output_per_mtok: 0.0 }
      }.freeze

      def self.from_config
        config = Typesafe::Rails.configuration

        new(
          api_key: config&.api_key || ::Rails.application.credentials.dig(:typesafe, :api_key),
          model: config&.model || "jev-latest",
          timeout: config&.timeout || 10.0,
          pricing: config&.pricing || DEFAULT_PRICING,
          strict_logging: config&.strict_logging || false,
          **sdk_options_from(config)
        )
      end

      def self.sdk_options_from(config)
        SDK_OPTIONS.each_with_object({}) do |key, acc|
          value = config&.public_send(key)
          acc[key] = value unless value.nil?
        end
      end
      private_class_method :sdk_options_from

      def initialize(
        api_key:,
        model: "jev-latest",
        timeout: 10.0,
        pricing: DEFAULT_PRICING,
        strict_logging: false,
        sdk_client: nil,
        **sdk_options
      )
        @pricing = pricing
        @strict_logging = strict_logging
        @sdk = sdk_client || Typesafe::SDK::Client.new(
          api_key: api_key, model: model, timeout: timeout, **sdk_options
        )
      end

      def ask(decision_type:, state:, questions:, **call_options)
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = @sdk.system_one(state: state, questions: questions, **call_options)
        latency_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000.0

        record_call(response, decision_type: decision_type, latency_ms: latency_ms)
        Result.new(response: response, decision_type: decision_type)
      end

      def models
        @sdk.models
      end

      def close
        @sdk.close if @sdk.respond_to?(:close)
        nil
      end

      attr_reader :sdk

      private

      def record_call(response, decision_type:, latency_ms:)
        rates = pricing_for(response.model)
        input_rate = rate_value(rates, :input_per_mtok)
        output_rate = rate_value(rates, :output_per_mtok)

        CallLog.create!(
          decision_type: decision_type.to_s,
          model: response.model,
          input_tokens: response.usage&.input_tokens,
          output_tokens: response.usage&.output_tokens,
          input_rate: input_rate,
          output_rate: output_rate,
          cost_usd: estimate_cost(response.usage, input_rate, output_rate),
          latency_ms: latency_ms,
          request_id: response.respond_to?(:request_id) ? response.request_id : nil
        )
      rescue StandardError => error
        raise if @strict_logging

        warn_logging_failure(error)
      end

      def pricing_for(model)
        return @pricing.call(model) if @pricing.respond_to?(:call)
        return nil unless @pricing.respond_to?(:[])
        return @pricing if rate_hash?(@pricing)

        exact = @pricing[model] ||
                (model.respond_to?(:to_sym) ? @pricing[model.to_sym] : nil)
        return exact unless exact.nil?

        if model.to_s.start_with?("jev-")
          family = @pricing["jev"] || @pricing[:jev]
          return family unless family.nil?
        end

        @pricing["default"] || @pricing[:default]
      end

      def rate_hash?(value)
        value.is_a?(Hash) &&
          (value.key?(:input_per_mtok) || value.key?("input_per_mtok"))
      end

      def rate_value(rates, key)
        return nil unless rates.respond_to?(:[])

        value = rates[key]
        value = rates[key.to_s] if value.nil?
        value&.to_f
      end

      def estimate_cost(usage, input_rate, output_rate)
        return nil if usage.nil? || input_rate.nil? || output_rate.nil?
        return nil if usage.input_tokens.nil?
        return nil if output_rate.nonzero? && usage.output_tokens.nil?

        input_cost = usage.input_tokens.to_f / 1_000_000 * input_rate
        output_tokens = usage.output_tokens || 0
        output_cost = output_tokens.to_f / 1_000_000 * output_rate
        input_cost + output_cost
      end

      def warn_logging_failure(error)
        return unless defined?(::Rails) && ::Rails.respond_to?(:logger) && ::Rails.logger

        ::Rails.logger.warn(
          "typesafe-ai-rails could not persist call telemetry: #{error.class}: #{error.message}"
        )
      end
    end
  end
end
