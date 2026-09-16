# frozen_string_literal: true

require_relative "../../test_helper"

class DecisionPolicyTest < Minitest::Test
  def teardown
    Typesafe::Rails::DecisionPolicy.delete_all
  end

  def create_policy(**attrs)
    Typesafe::Rails::DecisionPolicy.create!(
      {
        decision_type: "routing",
        answer_key: "*",
        confidence_threshold: 0.5,
        fallback: "surface_to_user"
      }.merge(attrs)
    )
  end

  def test_requires_valid_fallback
    policy = Typesafe::Rails::DecisionPolicy.new(
      decision_type: "test", answer_key: "*", confidence_threshold: 0.8,
      fallback: "not_a_real_fallback"
    )
    refute policy.valid?
  end

  def test_confidence_threshold_must_be_probability
    policy = Typesafe::Rails::DecisionPolicy.new(
      decision_type: "test", answer_key: "*", confidence_threshold: 1.5,
      fallback: "surface_to_user"
    )
    refute policy.valid?
  end

  def test_uniqueness_is_per_decision_and_answer
    create_policy(answer_key: "department")
    assert create_policy(answer_key: "tone")

    duplicate = Typesafe::Rails::DecisionPolicy.new(
      decision_type: "routing", answer_key: "department", confidence_threshold: 0.7,
      fallback: "surface_to_user"
    )
    refute duplicate.valid?
  end

  def test_resolve_prefers_answer_specific_policy
    generic = create_policy(confidence_threshold: 0.4)
    specific = create_policy(answer_key: "department", confidence_threshold: 0.9)

    assert_equal specific,
                 Typesafe::Rails::DecisionPolicy.resolve(
                   decision_type: "routing", answer_key: "department"
                 )
    assert_equal generic,
                 Typesafe::Rails::DecisionPolicy.resolve(
                   decision_type: "routing", answer_key: "tone"
                 )
  end

  def test_inactive_policy_is_not_resolved
    create_policy(active: false)
    assert_nil Typesafe::Rails::DecisionPolicy.resolve(
      decision_type: "routing", answer_key: "department"
    )
  end
end
