# frozen_string_literal: true

require_relative "../../test_helper"

class QuestionsTest < Minitest::Test
  include Typesafe::Rails::Questions

  def test_helpers_return_sdk_accepted_plain_hashes
    questions = {
      urgent: noul("Is this urgent?"),
      team: choice("Which team?", { billing: nil, technical: "Bugs" }),
      score: score("How urgent?", ["low", "high"])
    }

    normalized = Typesafe::SDK::QuestionSet.normalize(questions)

    assert_equal "noul", normalized["urgent"]["type"]
    assert_equal "choice", normalized["team"]["type"]
    assert_equal "score", normalized["score"]["type"]
  end

  def test_unknown_fields_are_forwarded_through_the_sdk_hash_path
    normalized = Typesafe::SDK::QuestionSet.normalize(
      experimental: noul("Experimental?", weight: 2, future_flag: { enabled: true })
    )

    assert_equal 2, normalized["experimental"]["weight"]
    assert_equal({ "enabled" => true }, normalized["experimental"]["future_flag"])
  end

  def test_choice_requires_nonempty_hash_criteria
    assert_raises(ArgumentError) { choice("Which team?") }
    assert_raises(ArgumentError) { choice("Which team?", []) }
    assert_raises(ArgumentError) { choice("Which team?", {}) }
  end

  def test_score_requires_two_to_ten_ordered_levels
    assert_raises(ArgumentError) { score("Urgency?", ["only"]) }
    assert_raises(ArgumentError) { score("Urgency?", Array.new(11, "level")) }

    question = score("Urgency?", ["low", "high"])
    assert_equal ["low", "high"], question["criteria"]
  end

  def test_double_specifying_criteria_raises
    assert_raises(ArgumentError) do
      score("Urgency?", %w[low high], criteria: %w[a b])
    end
  end

  def test_double_specifying_instructions_raises
    assert_raises(ArgumentError) do
      noul("Urgent?", instructions: "Something else")
    end
  end

  def test_type_cannot_be_changed
    assert_raises(ArgumentError) { choice("Team?", { a: nil }, type: "noul") }
  end
end
