# Changelog

## 0.4.0

Initial public release under the `typesafe-ai-rails` name.

- Fail-closed Choice/Score confidence gating backed by Rails persistence.
- Answer-specific policies with wildcard defaults and distinct fallback handlers.
- Explicit Noul handling: probability is never treated as confidence.
- Forward-compatible plain-hash question helpers with documented Score validation.
- Direct per-call SDK keyword forwarding.
- Model-aware, non-fatal call/cost telemetry with pricing snapshots, latency, usage,
  and request IDs.
- Jev-family pricing handles versioned response model names such as `jev-1.13.0`.
- SDK logging is opt-in to avoid accidental request/response body logging.
- Tests use the real community `typesafe-sdk` request/response contract.
- Fresh-install and development-snapshot upgrade migrations.
