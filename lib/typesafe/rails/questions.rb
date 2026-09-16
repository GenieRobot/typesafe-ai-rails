# frozen_string_literal: true

module Typesafe
  module Rails
    module Questions
      def noul(instructions = nil, criteria = nil, **fields)
        question_hash("noul", instructions, criteria, fields) do |value|
          next if value.nil? || value.is_a?(Hash)

          raise ArgumentError, "noul criteria must be a hash with true/false descriptions"
        end
      end

      def choice(instructions = nil, criteria = nil, **fields)
        question_hash("choice", instructions, criteria, fields) do |value|
          unless value.is_a?(Hash) && !value.empty?
            raise ArgumentError, "choice requires a non-empty criteria hash"
          end
        end
      end

      def score(instructions = nil, criteria = nil, **fields)
        question_hash("score", instructions, criteria, fields) do |value|
          unless value.is_a?(Array) && value.length.between?(2, 10)
            raise ArgumentError, "score criteria must be an array with 2 to 10 levels"
          end
        end
      end

      private

      def question_hash(type, instructions, criteria, fields)
        fields = fields.dup
        reject_type_override!(fields, type)
        instructions = merge_argument!(fields, :instructions, instructions)
        criteria = merge_argument!(fields, :criteria, criteria)
        yield(criteria) if block_given?

        question = { "type" => type }
        question["instructions"] = instructions unless instructions.nil?
        question["criteria"] = criteria unless criteria.nil?
        fields.each { |key, value| question[key.to_s] = value }
        question
      end

      def merge_argument!(fields, name, positional)
        return positional unless fields.key?(name)
        raise ArgumentError, "#{name} given both positionally and as a keyword" unless positional.nil?

        fields.delete(name)
      end

      def reject_type_override!(fields, expected)
        return unless fields.key?(:type)

        supplied = fields.delete(:type)
        return if supplied.to_s == expected

        raise ArgumentError, "#{expected} helper cannot build type #{supplied.inspect}"
      end
    end
  end
end
