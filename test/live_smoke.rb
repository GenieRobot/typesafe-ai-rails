# frozen_string_literal: true

require "active_record"

api_key = ENV["TYPESAFE_API_KEY"].to_s
abort "TYPESAFE_API_KEY is not available to this workflow" if api_key.empty?

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :typesafe_decision_policies, force: true do |t|
    t.string :decision_type, null: false
    t.string :answer_key, null: false, default: "*"
    t.decimal :confidence_threshold, precision: 3, scale: 2, null: false
    t.string :fallback, null: false, default: "surface_to_user"
    t.boolean :active, null: false, default: true
    t.timestamps
  end
  add_index :typesafe_decision_policies, [:decision_type, :answer_key], unique: true

  create_table :typesafe_calls, force: true do |t|
    t.string :decision_type, null: false
    t.string :model
    t.integer :input_tokens
    t.integer :output_tokens
    t.decimal :input_rate, precision: 12, scale: 6
    t.decimal :output_rate, precision: 12, scale: 6
    t.decimal :cost_usd, precision: 12, scale: 6
    t.decimal :latency_ms, precision: 12, scale: 3
    t.string :request_id
    t.datetime :created_at, null: false
  end
end

require "typesafe/rails"

client = Typesafe::Rails::Client.new(api_key: api_key, strict_logging: true)

begin
  result = client.ask(
    decision_type: "live_smoke",
    state: "The square is blue.",
    questions: {
      mentions_color: Typesafe::Rails.noul("Does the state explicitly mention a color?"),
      color: Typesafe::Rails.choice(
        "Which color is explicitly named?",
        { blue: nil, red: nil }
      ),
      vividness: Typesafe::Rails.score(
        "How vivid is the color description?",
        ["plain", "vivid"]
      )
    }
  )

  noul = result.nouls.fetch("mentions_color")
  choice = result.choices.fetch("color")
  score = result.scores.fetch("vividness")

  raise "unexpected Noul answer type: #{noul.class}" unless noul.is_a?(Typesafe::SDK::NoulAnswer)
  raise "unexpected Choice answer type: #{choice.class}" unless choice.is_a?(Typesafe::SDK::ChoiceAnswer)
  raise "unexpected Score answer type: #{score.class}" unless score.is_a?(Typesafe::SDK::ScoreAnswer)

  raise "Noul probability out of range" unless noul.noul.between?(0.0, 1.0)
  raise "Choice confidence out of range" unless choice.confidence.between?(0.0, 1.0)
  raise "Choice returned an unknown label" unless %w[blue red].include?(choice.choice)
  raise "Score confidence out of range" unless score.confidence.between?(0.0, 1.0)
  raise "Score value out of range" unless score.score.between?(0.0, 1.0)

  Typesafe::Rails::DecisionPolicy.create!(
    decision_type: "live_smoke",
    answer_key: "color",
    confidence_threshold: 0.0,
    fallback: "escalate"
  )

  acted_choice = result.act!(:color, fallback: ->(_answer) { raise "unexpected fallback" }) do |answer|
    answer.choice
  end
  raise "confidence gate returned the wrong answer" unless acted_choice == choice.choice

  begin
    result.act!(:mentions_color, fallback: ->(_answer) {}) { raise "Noul gate unexpectedly yielded" }
    raise "Noul confidence gating should have been rejected"
  rescue Typesafe::Rails::UnsupportedConfidenceGateError
    # Expected: Noul exposes probability, not confidence.
  end

  log = Typesafe::Rails::CallLog.last
  raise "call telemetry was not persisted" if log.nil?
  raise "telemetry model missing" if log.model.to_s.empty?
  raise "telemetry latency missing" if log.latency_ms.nil?
  raise "request id missing from live response" if log.request_id.to_s.empty?
  raise "input token count is invalid" if !log.input_tokens.nil? && log.input_tokens <= 0
  raise "output token count is invalid" if !log.output_tokens.nil? && log.output_tokens.negative?

  if log.model.start_with?("jev-")
    raise "Jev family input pricing missing" unless (log.input_rate.to_f - 0.042).abs < 0.000001
    raise "Jev family output pricing missing" unless log.output_rate.to_f.zero?
    raise "Jev cost estimate missing" if log.cost_usd.nil?
  end

  puts "Live TypeSafe smoke test passed"
  puts "model=#{log.model}"
  puts "answer_types=noul,choice,score"
  puts "usage_reported=#{!log.input_tokens.nil?}"
  puts "request_id_present=true"
  puts "cost_estimated=#{!log.cost_usd.nil?}"
ensure
  client.close
end
