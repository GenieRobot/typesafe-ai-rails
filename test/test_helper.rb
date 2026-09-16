# frozen_string_literal: true

require "active_record"
require "minitest/autorun"
require "json"
require "typesafe/sdk"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.define do
  create_table :typesafe_decision_policies, force: true do |t|
    t.string  :decision_type, null: false
    t.string  :answer_key, null: false, default: "*"
    t.decimal :confidence_threshold, precision: 3, scale: 2, null: false
    t.string  :fallback, null: false, default: "surface_to_user"
    t.boolean :active, null: false, default: true
    t.timestamps
  end
  add_index :typesafe_decision_policies, [:decision_type, :answer_key], unique: true

  create_table :typesafe_calls, force: true do |t|
    t.string   :decision_type, null: false
    t.string   :model
    t.integer  :input_tokens
    t.integer  :output_tokens
    t.decimal  :input_rate, precision: 12, scale: 6
    t.decimal  :output_rate, precision: 12, scale: 6
    t.decimal  :cost_usd, precision: 12, scale: 6
    t.decimal  :latency_ms, precision: 12, scale: 3
    t.string   :request_id
    t.datetime :created_at, null: false
  end
end

require "typesafe/rails/decision_policy"
require "typesafe/rails/call_log"
require "typesafe/rails/result"
require "typesafe/rails/client"
require "typesafe/rails/questions"

class RecordingTransport
  attr_reader :requests

  def initialize(response_body)
    @response_body = response_body
    @requests = []
  end

  def call(request)
    @requests << request
    body = @response_body.respond_to?(:call) ? @response_body.call(request) : @response_body

    Typesafe::SDK::HTTPResponse.new(
      status: 200,
      headers: { "x-typesafe-request-id" => "req_test" },
      body: JSON.generate(body)
    )
  end

  def close; end
end

module SdkFixtures
  def choice_answer(choice: "technical", confidence: 0.9)
    Typesafe::SDK::ChoiceAnswer.new(
      choice: choice,
      confidence: confidence,
      probabilities: { "technical" => confidence, "billing" => 1.0 - confidence }
    )
  end

  def score_answer(score: 1.2, confidence: 0.8)
    Typesafe::SDK::ScoreAnswer.new(
      score: score,
      confidence: confidence,
      legend: { 0 => "low", 1 => "medium", 2 => "high" },
      probabilities: { 0 => 0.0, 1 => 0.8, 2 => 0.2 }
    )
  end

  def noul_answer(value = 0.8)
    Typesafe::SDK::NoulAnswer.new(noul: value)
  end

  def response_with(answers)
    Typesafe::SDK::SystemOneResponse.new(
      model: "jev-1.12",
      usage: Typesafe::SDK::Usage.new(input_tokens: 100, output_tokens: 10),
      answers: answers
    )
  end
end
