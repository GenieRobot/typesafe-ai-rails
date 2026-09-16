# frozen_string_literal: true

require_relative "../../test_helper"

class ResultTest < Minitest::Test
  include SdkFixtures

  def teardown
    Typesafe::Rails::DecisionPolicy.delete_all
  end

  def create_policy(**attrs)
    Typesafe::Rails::DecisionPolicy.create!(
      {
        decision_type: "routing",
        answer_key: "department",
        confidence_threshold: 0.5,
        fallback: "surface_to_user"
      }.merge(attrs)
    )
  end

  def build_result(answer, key: "department")
    Typesafe::Rails::Result.new(
      response: response_with(key => answer),
      decision_type: "routing"
    )
  end

  def test_missing_policy_fails_closed
    result = build_result(choice_answer(confidence: 0.99))

    assert_raises(Typesafe::Rails::MissingPolicyError) do
      result.act!(:department, fallback: ->(_answer) {}) { flunk "must not yield" }
    end
  end

  def test_yields_when_confidence_meets_specific_policy
    create_policy(confidence_threshold: 0.8)
    result = build_result(choice_answer(confidence: 0.9))
    yielded = nil

    result.act!(:department, fallback: ->(_answer) { flunk "must not fall back" }) do |answer|
      yielded = answer
    end

    assert_equal "technical", yielded.choice
  end

  def test_wildcard_policy_applies_when_no_specific_policy_exists
    create_policy(answer_key: "*", confidence_threshold: 0.8)
    result = build_result(choice_answer(confidence: 0.9))

    assert result.act!(:department, fallback: ->(_answer) { flunk }) { true }
  end

  def test_hash_fallback_dispatches_by_policy_mode
    create_policy(confidence_threshold: 0.8, fallback: "deterministic_rule")
    result = build_result(choice_answer(confidence: 0.3))
    called = nil

    result.act!(
      :department,
      fallback: {
        deterministic_rule: ->(answer) { called = [:deterministic, answer.choice] },
        surface_to_user: ->(_answer) { flunk "wrong fallback" }
      }
    ) { flunk "must not yield" }

    assert_equal [:deterministic, "technical"], called
  end

  def test_single_callable_remains_supported_for_non_escalating_modes
    create_policy(confidence_threshold: 0.8, fallback: "surface_to_user")
    result = build_result(choice_answer(confidence: 0.3))
    fallback_called = false

    result.act!(:department, fallback: ->(_answer) { fallback_called = true }) do
      flunk "must not yield"
    end

    assert fallback_called
  end

  def test_escalate_raises_below_threshold
    create_policy(confidence_threshold: 0.8, fallback: "escalate")
    result = build_result(choice_answer(confidence: 0.3))

    assert_raises(Typesafe::Rails::LowConfidenceError) do
      result.act!(:department, fallback: ->(_answer) {}) { flunk "must not yield" }
    end
  end

  def test_noul_cannot_be_confidence_gated
    create_policy
    result = build_result(noul_answer(0.8))

    assert_raises(Typesafe::Rails::UnsupportedConfidenceGateError) do
      result.act!(:department, fallback: ->(_answer) {}) { flunk "must not yield" }
    end
  end

  def test_missing_answer_uses_missing_answer_fallback
    result = Typesafe::Rails::Result.new(
      response: response_with({}),
      decision_type: "routing"
    )
    called = :not_called

    result.act!(
      :missing,
      fallback: { missing_answer: ->(answer) { called = answer } }
    ) { flunk "must not yield" }

    assert_nil called
  end
end
