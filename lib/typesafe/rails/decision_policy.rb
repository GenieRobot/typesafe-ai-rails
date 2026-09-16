# frozen_string_literal: true

module Typesafe
  module Rails
    class DecisionPolicy < ActiveRecord::Base
      self.table_name = "typesafe_decision_policies"

      DEFAULT_ANSWER_KEY = "*"
      FALLBACKS = %w[deterministic_rule surface_to_user escalate].freeze

      validates :decision_type, presence: true
      validates :answer_key, presence: true,
                             uniqueness: { scope: :decision_type }
      validates :confidence_threshold,
                numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
      validates :fallback, inclusion: { in: FALLBACKS }

      scope :active, -> { where(active: true) }

      def self.resolve(decision_type:, answer_key:)
        decision_type = decision_type.to_s
        answer_key = answer_key.to_s

        active.find_by(decision_type: decision_type, answer_key: answer_key) ||
          active.find_by(decision_type: decision_type, answer_key: DEFAULT_ANSWER_KEY)
      end
    end
  end
end
