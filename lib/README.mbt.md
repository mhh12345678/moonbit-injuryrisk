# MoonBit Injury Risk Rule Engine (`moonbit-injuryrisk`)

A lightweight, high-performance rule engine for sports movement injury risk stratification, training load monitoring, and recovery compliance tracking, written in idiomatic MoonBit.

## Features

- 🏃 **Training Load Monitoring**: Automatic sliding-window calculations for Session RPE (sRPE), Acute Load (7-day), Chronic Load (28-day), and Acute:Chronic Workload Ratio (ACWR).
- 🛌 **Recovery & Compliance Tracking**: Rolling monitoring of recovery metrics including average sleep duration, sleep quality, and subjective fatigue.
- ⚠️ **Pain Level & Symptoms Tracking**: Tracking of maximum pain scores and localized pain sites.
- ⚙️ **Configurable Rule DSL**: Construct modular threshold rules targeting any window size, operator (`>`, `<`, `==`), and severity (`Low`, `Medium`, `High`).
- 📝 **Automated Risk Summaries**: Aggregates triggered alerts and generates descriptive explanation reports to guide athletic training adjustment.

---

## Quick Start Example

The following block is type-checked and executed as part of the test suite:

```mbt check
///|
test "Quickstart example" {
  // 1. Create telemetry records
  let records = [
    DailyRecord::{
      date: "2026-08-01",
      training_duration: 60.0,
      training_intensity: 6.0, // daily workload: 360.0
      pain_level: 0.0,
      pain_site: None,
      sleep_hours: 8.0,
      sleep_quality: 4.0,
      fatigue: 2.0,
    },
  ]

  // 2. Define risk rules
  let rules = [
    Rule::{
      name: "High Workload",
      metric: Metric::AcuteLoad,
      op: Operator::GreaterThan,
      threshold: 300.0,
      window_size: 1,
      severity: RiskLevel::Medium,
      description: "Workload exceeds 300.",
    },
  ]

  // 3. Assess injury risk
  let assessment = assess_injury_risk(records, "2026-08-01", rules)

  // 4. Verify assessment
  assert_true(assessment is Some(_))
  let report = assessment.unwrap()
  assert_true(report.risk_level is RiskLevel::Medium)
}
```

---

## Run and Test

Ensure you have the latest MoonBit toolchain (v0.10.3 or higher) installed:

```bash
# Type-check everything
moon check --deny-warn

# Run the test suite
moon test --deny-warn --target wasm-gc

# Run the command-line demo report
moon run --target wasm-gc cmd/main
```
