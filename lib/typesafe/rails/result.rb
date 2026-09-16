# frozen_string_literal: true

module Typesafe
  module Rails
    class LowConfidenceError < StandardError
      attr_reader :answer_key, :confidence, :policy

      def initialize(answer_key, confidence, policy)
        @answer_key = answer_key
        @confidence = confidence
        @policy = policy
        super(
          "#{answer_key.inspect} confidence #{confidence.inspect} is below the " \
          "#{policy.confidence_threshold} threshold configured for " \
          "decision_type #{policy.decision_type.inspect}"
        )
      end
    end

    class MissingPolicyError < StandardError
      attr_reader :decision_type, :answer_key

      def initialize(decision_type, answer_key)
        @decision_type = decision_type
        @answer_key = answer_key
        super(
          "no active TypeSafe decision policy for #{decision_type.inspect} / " \
          "#{answer_key.inspect}; use Result#[] directly for intentionally ungated reads"
        )
      end
    end

    class UnsupportedConfidenceGateError < StandardError
      attr_reader :answer_key, :answer

      def initialize(answer_key, answer)
        @answer_key = answer_key
        @answer = answer
        super(
          "#{answer_key.inspect} returned #{answer.class}, which has no TypeSafe confidence value; " \
          "Noul answers expose probability as #noul and must be thresholded explicitly"
        )
      end
    end

    class MissingConfidenceError < StandardError
      attr_reader :answer_key, :answer

      def initialize(answer_key, answer)
        @answer_key = answer_key
        @answer = answer
        super("#{answer_key.inspect} returned a confidence-bearing answer with confidence=nil")
      end
    end

    class Result
      attr_reader :response, :decision_type

      def initialize(response:, decision_type:)
        @response = response
        @decision_type = decision_type.to_s
      end

      def answers = response.answers
      def nouls = response.nouls
      def choices = response.choices
      def scores = response.scores
      def usage = response.usage
      def [](key) = response[key]

      def act!(answer_key, fallback:)
        answer = response[answer_key]
        return call_fallback(fallback, :missing_answer, nil) if answer.nil?

        unless answer.respond_to?(:confidence)
          raise UnsupportedConfidenceGateError.new(answer_key, answer)
        end

        confidence = answer.confidence
        raise MissingConfidenceError.new(answer_key, answer) if confidence.nil?

        policy = DecisionPolicy.resolve(decision_type: decision_type, answer_key: answer_key)
        raise MissingPolicyError.new(decision_type, answer_key) if policy.nil?

        return yield(answer) if confidence >= policy.confidence_threshold

        case policy.fallback
        when "escalate"
          raise LowConfidenceError.new(answer_key, confidence, policy)
        else
          call_fallback(fallback, policy.fallback, answer)
        end
      end

      private

      def call_fallback(fallback, mode, answer)
        handler =
          if fallback.respond_to?(:call)
            fallback
          elsif fallback.respond_to?(:[])
            fallback[mode.to_sym] || fallback[mode.to_s]
          end

        unless handler.respond_to?(:call)
          raise ArgumentError, "fallback handler for #{mode.inspect} is required"
        end

        handler.call(answer)
      end
    end
  end
end
