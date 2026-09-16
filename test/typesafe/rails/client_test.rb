# frozen_string_literal: true

require_relative "../../test_helper"

class ClientTest < Minitest::Test
  def teardown
    Typesafe::Rails::CallLog.delete_all
  end

  def response_body(model: "jev-1.12", input_tokens: 1_000_000, output_tokens: 0)
    {
      model: model,
      usage: { input_tokens: input_tokens, output_tokens: output_tokens },
      answers: {
        department: {
          type: "choice",
          choice: "technical",
          confidence: 0.9,
          probabilities: { technical: 0.9, billing: 0.1 }
        }
      }
    }
  end

  def build_client(response: response_body, pricing: nil, strict_logging: false)
    transport = RecordingTransport.new(response)
    options = { api_key: "test", transport: transport, strict_logging: strict_logging }
    options[:pricing] = pricing unless pricing.nil?
    [Typesafe::Rails::Client.new(**options), transport]
  end

  def questions
    {
      department: {
        type: "choice",
        instructions: "Which team?",
        criteria: { technical: nil, billing: nil }
      }
    }
  end

  def test_ask_uses_real_sdk_parser_and_logs_model_usage_cost_and_request_id
    pricing = { "jev-1.12" => { input_per_mtok: 0.042, output_per_mtok: 0.0 } }
    client, transport = build_client(pricing: pricing)

    result = client.ask(decision_type: "routing", state: "hello", questions: questions)

    assert_equal "technical", result[:department].choice
    assert_equal 1, transport.requests.length

    log = Typesafe::Rails::CallLog.last
    assert_equal "routing", log.decision_type
    assert_equal "jev-1.12", log.model
    assert_equal 1_000_000, log.input_tokens
    assert_in_delta 0.042, log.input_rate.to_f, 0.000001
    assert_in_delta 0.042, log.cost_usd.to_f, 0.000001
    assert_equal "req_test", log.request_id
    assert_operator log.latency_ms.to_f, :>=, 0.0
  ensure
    client&.close
  end

  def test_versioned_jev_model_uses_family_pricing
    client, = build_client(response: response_body(model: "jev-1.13.0"))

    client.ask(decision_type: "routing", state: "s", questions: questions)

    log = Typesafe::Rails::CallLog.last
    assert_equal "jev-1.13.0", log.model
    assert_in_delta 0.042, log.input_rate.to_f, 0.000001
    assert_in_delta 0.0, log.output_rate.to_f, 0.000001
    assert_in_delta 0.042, log.cost_usd.to_f, 0.000001
  ensure
    client&.close
  end

  def test_unknown_model_logs_unknown_cost_instead_of_zero
    client, = build_client(response: response_body(model: "future-model"))

    client.ask(decision_type: "routing", state: "s", questions: questions)

    log = Typesafe::Rails::CallLog.last
    assert_equal "future-model", log.model
    assert_nil log.cost_usd
    assert_nil log.input_rate
  ensure
    client&.close
  end

  def test_per_call_options_and_extra_body_reach_sdk
    client, transport = build_client

    client.ask(
      decision_type: "routing",
      state: "s",
      questions: questions,
      model: "jev-1.12",
      timeout: 2.5,
      extra_body: { beam_width: 4 }
    )

    request_body = JSON.parse(transport.requests.last.body)
    assert_equal "jev-1.12", request_body["model"]
    assert_equal 4, request_body["beam_width"]
    assert_in_delta 2.5, transport.requests.last.timeout, 0.001
  ensure
    client&.close
  end

  def test_sdk_rejects_unknown_call_option_without_wrapper_allowlist
    client, = build_client

    error = assert_raises(ArgumentError) do
      client.ask(
        decision_type: "routing",
        state: "s",
        questions: questions,
        future_option_that_sdk_does_not_have: true
      )
    end

    assert_match(/future_option_that_sdk_does_not_have/, error.message)
  ensure
    client&.close
  end

  def test_telemetry_failure_is_nonfatal_by_default
    client, = build_client
    result = nil

    Typesafe::Rails::CallLog.stub(:create!, ->(*) { raise "database unavailable" }) do
      result = client.ask(decision_type: "routing", state: "s", questions: questions)
    end

    assert_equal "technical", result[:department].choice
  ensure
    client&.close
  end

  def test_strict_logging_surfaces_telemetry_failure
    client, = build_client(strict_logging: true)

    Typesafe::Rails::CallLog.stub(:create!, ->(*) { raise "database unavailable" }) do
      assert_raises(RuntimeError) do
        client.ask(decision_type: "routing", state: "s", questions: questions)
      end
    end
  ensure
    client&.close
  end
end
