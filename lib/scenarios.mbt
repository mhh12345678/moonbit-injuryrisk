///|
/// Deterministic application scenarios used by examples and regression tests.
pub(all) enum ScenarioKind {
  Balanced
  WorkloadSpike
  SleepDeprivation
  PainEscalation
  RapidProgression
  MissingHistory
  IrregularTelemetry
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ScenarioDefinition {
  id : String
  name : String
  description : String
  expected_risk : RiskLevel
  expected_focus : String
  days : Int
} derive(Debug, Eq, ToJson)

///|
pub fn scenario_kind_name(kind : ScenarioKind) -> String {
  match kind {
    Balanced => "balanced"
    WorkloadSpike => "workload-spike"
    SleepDeprivation => "sleep-deprivation"
    PainEscalation => "pain-escalation"
    RapidProgression => "rapid-progression"
    MissingHistory => "missing-history"
    IrregularTelemetry => "irregular-telemetry"
  }
}

///|
fn scenario_date(day : Int) -> String {
  let base = parse_date("2026-08-01").unwrap()
  format_date(add_days(base, day).unwrap())
}

///|
fn scenario_record(
  day : Int,
  duration : Double,
  intensity : Double,
  pain : Double,
  site : String?,
  sleep : Double,
  quality : Double,
  fatigue : Double,
) -> DailyRecord {
  {
    date: scenario_date(day),
    training_duration: duration,
    training_intensity: intensity,
    pain_level: pain,
    pain_site: site,
    sleep_hours: sleep,
    sleep_quality: quality,
    fatigue,
  }
}

///|
pub fn generate_scenario(kind : ScenarioKind, days : Int) -> Array[DailyRecord] {
  let count = days.max(0)
  let records = []
  for day in 0..<count {
    let record = match kind {
      Balanced => scenario_record(day, 45.0, 5.0, 0.0, None, 8.0, 4.0, 3.0)
      WorkloadSpike =>
        if day < count - 7 {
          scenario_record(day, 30.0, 4.0, 0.0, None, 7.5, 4.0, 3.0)
        } else {
          scenario_record(day, 90.0, 8.0, 1.0, Some("left calf"), 7.0, 3.5, 5.0)
        }
      SleepDeprivation =>
        if day < count - 7 {
          scenario_record(day, 40.0, 5.0, 0.0, None, 8.0, 4.5, 3.0)
        } else {
          scenario_record(day, 40.0, 5.0, 0.0, None, 5.0, 2.0, 8.0)
        }
      PainEscalation => {
        let pain = if day < count / 2 {
          0.5
        } else {
          0.5 + (day - count / 2).to_double() * 0.5
        }
        scenario_record(
          day,
          45.0,
          5.0,
          pain.min(10.0),
          Some("right knee"),
          7.5,
          3.5,
          4.0,
        )
      }
      RapidProgression => {
        let factor = 1.0 + day.to_double() * 0.08
        scenario_record(day, 40.0 * factor, 5.0, 0.5, None, 7.5, 3.5, 4.0)
      }
      MissingHistory =>
        if day < count / 2 {
          scenario_record(day * 2, 50.0, 5.0, 0.0, None, 8.0, 4.0, 3.0)
        } else {
          scenario_record(day, 50.0, 5.0, 0.0, None, 8.0, 4.0, 3.0)
        }
      IrregularTelemetry =>
        if day % 3 == 0 {
          scenario_record(day, 0.0, 0.0, 0.0, None, 8.0, 4.0, 3.0)
        } else {
          scenario_record(day, 60.0, 6.0, 0.0, None, 6.0, 3.0, 6.0)
        }
    }
    records.push(record)
  }
  records
}

///|
pub fn scenario_definition(
  kind : ScenarioKind,
  days : Int,
) -> ScenarioDefinition {
  match kind {
    Balanced =>
      {
        id: "balanced",
        name: "Balanced baseline",
        description: "steady workload and recovery",
        expected_risk: Low,
        expected_focus: "progress gradually",
        days,
      }
    WorkloadSpike =>
      {
        id: "workload-spike",
        name: "Workload spike",
        description: "a sharp final-week increase",
        expected_risk: High,
        expected_focus: "reduce acute load",
        days,
      }
    SleepDeprivation =>
      {
        id: "sleep-deprivation",
        name: "Sleep deprivation",
        description: "reduced sleep and elevated fatigue",
        expected_risk: High,
        expected_focus: "restore sleep",
        days,
      }
    PainEscalation =>
      {
        id: "pain-escalation",
        name: "Pain escalation",
        description: "persistent localized pain",
        expected_risk: High,
        expected_focus: "review symptoms",
        days,
      }
    RapidProgression =>
      {
        id: "rapid-progression",
        name: "Rapid progression",
        description: "a sustained volume ramp",
        expected_risk: Medium,
        expected_focus: "slow progression",
        days,
      }
    MissingHistory =>
      {
        id: "missing-history",
        name: "Missing history",
        description: "insufficient continuous baseline",
        expected_risk: Medium,
        expected_focus: "collect baseline",
        days,
      }
    IrregularTelemetry =>
      {
        id: "irregular-telemetry",
        name: "Irregular telemetry",
        description: "intermittent and inconsistent observations",
        expected_risk: Medium,
        expected_focus: "repair data",
        days,
      }
  }
}

///|
pub fn scenario_catalog() -> Array[ScenarioDefinition] {
  [
    Balanced,
    WorkloadSpike,
    SleepDeprivation,
    PainEscalation,
    RapidProgression,
    MissingHistory,
    IrregularTelemetry,
  ].map(kind => scenario_definition(kind, 30))
}

///|
pub fn evaluate_scenario(
  kind : ScenarioKind,
  days : Int,
) -> ComprehensiveAssessment? {
  let records = generate_scenario(kind, days)
  assess_latest(records, default_risk_policy())
}

///|
pub fn scenario_matches_expectation(
  kind : ScenarioKind,
  assessment : ComprehensiveAssessment?,
) -> Bool {
  let definition = scenario_definition(kind, 30)
  match assessment {
    Some(value) =>
      value.risk_level.max(definition.expected_risk) == value.risk_level
    None => false
  }
}
