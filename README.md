# MoonBit Injury Risk

A reusable MoonBit library and CLI for explainable sports-training risk screening. It combines training load, sleep, fatigue, pain, data quality, policy rules, recommendations, and reports in one deterministic pipeline.

## Project Positioning

The library is designed for daily training telemetry, coaching dashboards, rehabilitation workflows, and batch screening. It is a decision-support component: it surfaces measurable signals and recommended next actions, while clinical decisions remain with qualified professionals.

## Core Capabilities

- Sliding-window workload metrics: sRPE load, acute/chronic load, ACWR, EWMA, ramp rate, monotony, strain, variability, percentiles, and trends.
- Recovery analysis: sleep debt, sleep consistency, sleep quality, fatigue, pain burden, recovery score, readiness bands, and daily alerts.
- Explainable rules: configurable metrics, operators, thresholds, severity, weights, evidence, and recommendations.
- Data quality: ISO date validation, range checks, duplicate and missing-date detection, chronological normalization, gap filling, and contract checks.
- Application workflows: CSV telemetry ingestion, in-memory store, daily timeline, cohort screening, training-plan review, progression guardrails, and deterministic benchmark harness.
- Outputs: plain-text reports, CSV exports, dashboard snapshots, action plans, and machine-readable derived data.

## Quick Start

Install the current MoonBit stable toolchain, then run:

```bash
moon check --deny-warn
moon test --deny-warn
moon run --target native cmd/main
```

The library entry points are available from:

```mbt nocheck
import {
  "mhh12345678/injuryrisk/lib" @injury,
}

fn main {
  let records = @injury.generate_healthy_athlete()
  let policy = @injury.default_risk_policy()
  match @injury.assess_latest(records, policy) {
    Some(assessment) => println(@injury.assessment_text(assessment))
    None => println("no valid telemetry")
  }
}
```

## CLI

The demo CLI exercises four deterministic athlete scenarios:

```bash
moon run --target native cmd/main
moon run --target native cmd/main -- --json
moon run --target native cmd/main -- --bench
```

The benchmark command is separate and suitable for repeatable timing:

```bash
moon run --target native --release cmd/bench
```

## Architecture

```text
lib/types.mbt             public telemetry and rule types
lib/calendar.mbt          ISO dates, ordinals, ranges, ordering
lib/load_metrics.mbt      workload distribution and ACWR metrics
lib/recovery_metrics.mbt  sleep, fatigue, pain, recovery scores
lib/policy.mbt            configurable rule policy and decisions
lib/signals.mbt           evidence-bearing risk signals
lib/assessment.mbt        comprehensive assessment and action plan
lib/timeline.mbt          daily risk timeline and trends
lib/cohort.mbt            batch athlete screening
lib/telemetry_csv.mbt     CSV ingestion and parse diagnostics
lib/reports.mbt           text and CSV rendering
lib/workflow.mbt          end-to-end ingest-to-report workflow
cmd/main                  scenario CLI
cmd/bench                 deterministic native benchmark
```

All public domain types are owned by the library package. The implementation is split by responsibility so applications can depend on a focused API instead of the CLI.

## Benchmarks

The benchmark uses a deterministic 120-day progressive workload and performs 100 complete latest-assessment passes:

```bash
moon run --target native --release cmd/bench
```

Run wall-clock timing on the local machine with PowerShell:

```powershell
Measure-Command { moon run --target native --release cmd/bench }
```

Measured output and environment details are recorded in [BENCHMARKS.md](BENCHMARKS.md). The benchmark reports a checksum so an optimized or broken pipeline cannot silently produce a different result.

## Source Scale

The CI source-size check counts production `.mbt` lines, excludes files ending in `_test.mbt` or `_wbtest.mbt`, and excludes `_build`, `.mooncakes`, and `.repos`. The enforced minimum is 8,000 lines. This rule is intentionally visible and reproducible; tests and generated build output are never used to satisfy it.

## Tests

The test suite covers:

- empty and short windows, zero baselines, equal thresholds, and out-of-range indices;
- leap years, invalid dates, cross-month and cross-year arithmetic;
- duplicates, missing dates, unordered records, invalid scales, and CSV parse failures;
- policy decisions, high/medium/low risk paths, readiness, pain escalation, timelines, cohorts, stores, plans, and contracts.

Run all tests with:

```bash
moon test --deny-warn
moon test --target all --deny-warn
moon test --target native --deny-warn --enable-coverage
moon coverage report -f summary
```

## CI

GitHub Actions runs on Ubuntu, macOS, and Windows. It installs the current stable MoonBit toolchain, checks formatting and generated interfaces, runs all-target checks and tests, performs native coverage and CLI smoke tests on Linux, and enforces the production source-size rule.

## License

Apache-2.0. See [LICENSE](LICENSE).
