# typesafe-ai-rails

Community Rails integration for TypeSafe AI's System One API, built on the
community [`typesafe-sdk`](https://github.com/joshmn/typesafe-sdk) Ruby gem.
This project is not an official TypeSafe package.

The SDK stays framework-neutral. `typesafe-ai-rails` adds Rails configuration,
persisted usage/cost telemetry, and an opt-in persistence-backed confidence
policy for Choice and Score answers.

## Installation

```bash
bundle add typesafe-ai-rails
bin/rails generate typesafe:rails:install
bin/rails db:migrate
```

Bundler loads the gem through `typesafe-ai-rails`. The stable Ruby API remains
under `Typesafe::Rails`; direct users may also `require "typesafe/rails"`.

Add the API key to Rails credentials:

```yaml
typesafe:
  api_key: sk-...
```

## Usage

```ruby
result = Typesafe::Rails.client.ask(
  decision_type: "support_ticket_routing",
  state: ticket.body,
  questions: {
    department: Typesafe::Rails.choice(
      "Which team should handle this",
      { billing: nil, technical: nil, sales: nil }
    ),
    is_urgent: Typesafe::Rails.noul("Is this time-sensitive?"),
    frustration: Typesafe::Rails.score(
      "How frustrated is the customer",
      ["Calm", "Frustrated but civil", "Very angry"]
    )
  }
)
```

`ask` sends all questions about the state in one System One call. That follows
TypeSafe's recommendation to batch independent questions that share state.

The returned `Result` exposes the SDK response directly:

```ruby
result[:department]
result.choices
result.scores
result.nouls
result.usage
result.response
```

## Confidence policies

TypeSafe returns `confidence` for Choice and Score answers. Noul does **not**
have a separate confidence value; its `noul` field is the probability of yes.

`Result#act!` is a fail-closed helper for Choice/Score side effects. Create
either a policy for a specific answer or a wildcard policy for the decision:

```ruby
Typesafe::Rails::DecisionPolicy.create!(
  decision_type: "support_ticket_routing",
  answer_key: "department",
  confidence_threshold: 0.7,
  fallback: "surface_to_user"
)
```

A wildcard row applies to every confidence-bearing answer that does not have a
more specific row:

```ruby
Typesafe::Rails::DecisionPolicy.create!(
  decision_type: "support_ticket_routing",
  answer_key: "*",
  confidence_threshold: 0.5,
  fallback: "surface_to_user"
)
```

Then gate the side effect:

```ruby
result.act!(
  :department,
  fallback: ->(_answer) { route_to_human(ticket) }
) do |answer|
  ticket.route_to!(answer.choice)
end
```

If no active policy exists, `act!` raises
`Typesafe::Rails::MissingPolicyError`. Intentionally ungated reads should use
`result[:department]` directly.

For distinct fallback modes, pass handlers by mode:

```ruby
result.act!(
  :department,
  fallback: {
    deterministic_rule: ->(answer) { route_with_rules(ticket, answer) },
    surface_to_user: ->(_answer) { ask_customer(ticket) },
    missing_answer: ->(_answer) { route_to_human(ticket) }
  }
) do |answer|
  ticket.route_to!(answer.choice)
end
```

`fallback: "escalate"` raises `Typesafe::Rails::LowConfidenceError`.

For Noul, threshold its probability directly:

```ruby
urgent = result[:is_urgent]
escalate(ticket) if urgent.noul >= 0.8
```

## Question helpers

`Typesafe::Rails.noul`, `.choice`, and `.score` return plain question hashes.
The Ruby SDK accepts hashes, so new API fields can pass through before the SDK
adds matching constructor keywords:

```ruby
Typesafe::Rails.noul(
  "Is this relevant?",
  weight: 2,
  future_field: { enabled: true }
)
```

Choice requires a non-empty criteria hash. Score requires the currently
documented 2–10 ordered levels.

You can always use `Typesafe::SDK::Noul`, `Choice`, `Score`, or raw hashes
directly in the same `questions:` map.

## Configuration

```ruby
Rails.application.config.typesafe.api_key =
  Rails.application.credentials.dig(:typesafe, :api_key)

Rails.application.config.typesafe.model = "jev-latest"
Rails.application.config.typesafe.timeout = 10.0
```

Client-level SDK options are available through Rails configuration:
`base_url`, `headers`, `user_agent`, `logger`, `retry_policy`, and `transport`.

SDK logging is deliberately opt-in. At debug level, the Ruby SDK logs request
and response bodies, so enabling it may place application state in logs:

```ruby
Rails.application.config.typesafe.logger = Rails.logger
```

Per-call SDK options are forwarded directly:

```ruby
Typesafe::Rails.client.ask(
  decision_type: "routing",
  state: ticket.body,
  questions: questions,
  model: "jev-1.12",
  extra_body: { beam_width: 4 }
)
```

For anything else, `Typesafe::Rails.client.sdk` exposes the underlying client.
Calls made directly on it bypass Rails telemetry.

## Telemetry and pricing

Each successful `ask` attempts to append a row to `typesafe_calls` containing:

- decision type and returned model
- input/output token counts
- the pricing rates used for the estimate
- estimated USD cost
- request ID and local latency

Pricing is keyed by the returned model. The built-in defaults include a Jev
family rate so `jev-latest` can resolve to versioned names such as `jev-1.13.0`
without losing the cost estimate. Unknown model families are recorded with
`cost_usd = NULL` rather than an invented price. Override `pricing` when
TypeSafe changes its published rates.

A telemetry database failure is non-fatal by default. Set
`Rails.application.config.typesafe.strict_logging = true` when complete
accounting is more important than availability.

## License

MIT.
