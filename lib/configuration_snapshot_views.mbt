///|
/// Configuration snapshots preserve the policy context behind each decision.
pub(all) struct ConfigurationSnapshot {
  run_id : String
  athlete_label : String
  risk_policy_name : String
  acute_window : Int
  chronic_window : Int
  baseline_window : Int
  high_acwr : Double
  medium_acwr : Double
  sleep_target : Double
  high_risk_score : Double
  medium_risk_score : Double
  minimum_readiness : Double
  quality_floor : Double
  minimum_records : Int
  minimum_coverage : Double
  include_sessions : Bool
  valid : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ConfigurationSnapshotDelta {
  left_run_id : String
  right_run_id : String
  changed_fields : Array[String]
  load_window_changed : Bool
  risk_threshold_changed : Bool
  quality_gate_changed : Bool
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
pub fn configuration_snapshot(
  config : DecisionRunConfig,
) -> ConfigurationSnapshot {
  let policy = config.risk_policy
  let monitor = config.monitor_thresholds
  let gate = config.quality_gate
  {
    run_id: config.run_id,
    athlete_label: config.athlete_label,
    risk_policy_name: policy.name,
    acute_window: policy.acute_window,
    chronic_window: policy.chronic_window,
    baseline_window: policy.baseline_window,
    high_acwr: policy.high_acwr,
    medium_acwr: policy.medium_acwr,
    sleep_target: policy.sleep_target,
    high_risk_score: monitor.high_risk_score,
    medium_risk_score: monitor.medium_risk_score,
    minimum_readiness: monitor.minimum_readiness,
    quality_floor: monitor.quality_floor,
    minimum_records: gate.minimum_records,
    minimum_coverage: gate.minimum_coverage,
    include_sessions: config.include_sessions,
    valid: decision_run_config_valid(config),
  }
}

///|
pub fn configuration_snapshot_default() -> ConfigurationSnapshot {
  configuration_snapshot(default_decision_run_config())
}

///|
pub fn configuration_snapshot_valid(snapshot : ConfigurationSnapshot) -> Bool {
  snapshot.run_id != "" &&
  snapshot.athlete_label != "" &&
  snapshot.risk_policy_name != "" &&
  snapshot.acute_window > 0 &&
  snapshot.chronic_window >= snapshot.acute_window &&
  snapshot.baseline_window > 0 &&
  snapshot.high_acwr > snapshot.medium_acwr &&
  snapshot.medium_acwr > 0.0 &&
  snapshot.sleep_target > 0.0 &&
  snapshot.sleep_target <= 24.0 &&
  snapshot.high_risk_score > snapshot.medium_risk_score &&
  snapshot.high_risk_score <= 100.0 &&
  snapshot.minimum_readiness >= 0.0 &&
  snapshot.minimum_readiness <= 100.0 &&
  snapshot.quality_floor >= 0.0 &&
  snapshot.quality_floor <= 100.0 &&
  snapshot.minimum_records >= 0 &&
  snapshot.minimum_coverage >= 0.0 &&
  snapshot.minimum_coverage <= 1.0
}

///|
pub fn configuration_snapshot_field_names() -> Array[String] {
  [
    "run_id", "athlete_label", "risk_policy_name", "acute_window", "chronic_window",
    "baseline_window", "high_acwr", "medium_acwr", "sleep_target", "high_risk_score",
    "medium_risk_score", "minimum_readiness", "quality_floor", "minimum_records",
    "minimum_coverage", "include_sessions",
  ]
}

///|
pub fn configuration_snapshot_field(
  snapshot : ConfigurationSnapshot,
  name : String,
) -> String {
  match name {
    "run_id" => snapshot.run_id
    "athlete_label" => snapshot.athlete_label
    "risk_policy_name" => snapshot.risk_policy_name
    "acute_window" => snapshot.acute_window.to_string()
    "chronic_window" => snapshot.chronic_window.to_string()
    "baseline_window" => snapshot.baseline_window.to_string()
    "high_acwr" => snapshot.high_acwr.to_string()
    "medium_acwr" => snapshot.medium_acwr.to_string()
    "sleep_target" => snapshot.sleep_target.to_string()
    "high_risk_score" => snapshot.high_risk_score.to_string()
    "medium_risk_score" => snapshot.medium_risk_score.to_string()
    "minimum_readiness" => snapshot.minimum_readiness.to_string()
    "quality_floor" => snapshot.quality_floor.to_string()
    "minimum_records" => snapshot.minimum_records.to_string()
    "minimum_coverage" => snapshot.minimum_coverage.to_string()
    "include_sessions" => snapshot.include_sessions.to_string()
    _ => ""
  }
}

///|
pub fn configuration_snapshot_values(
  snapshot : ConfigurationSnapshot,
) -> Array[String] {
  configuration_snapshot_field_names().map(name => {
    configuration_snapshot_field(snapshot, name)
  })
}

///|
pub fn configuration_snapshot_changed_fields(
  left : ConfigurationSnapshot,
  right : ConfigurationSnapshot,
) -> Array[String] {
  configuration_snapshot_field_names().filter(name => {
    configuration_snapshot_field(left, name) !=
    configuration_snapshot_field(right, name)
  })
}

///|
pub fn configuration_snapshot_compare(
  left : ConfigurationSnapshot,
  right : ConfigurationSnapshot,
) -> ConfigurationSnapshotDelta {
  let changed = configuration_snapshot_changed_fields(left, right)
  {
    left_run_id: left.run_id,
    right_run_id: right.run_id,
    changed_fields: changed,
    load_window_changed: changed.contains("acute_window") ||
    changed.contains("chronic_window") ||
    changed.contains("baseline_window"),
    risk_threshold_changed: changed.contains("high_acwr") ||
    changed.contains("medium_acwr") ||
    changed.contains("high_risk_score") ||
    changed.contains("medium_risk_score"),
    quality_gate_changed: changed.contains("quality_floor") ||
    changed.contains("minimum_records") ||
    changed.contains("minimum_coverage"),
    conclusion: if changed.length() == 0 {
      "configuration is unchanged"
    } else if changed.contains("high_acwr") ||
      changed.contains("high_risk_score") {
      "risk sensitivity changed"
    } else if changed.contains("minimum_coverage") ||
      changed.contains("quality_floor") {
      "quality acceptance changed"
    } else {
      "operational configuration changed"
    },
  }
}

///|
pub fn configuration_snapshot_delta_text(
  delta : ConfigurationSnapshotDelta,
) -> String {
  delta.left_run_id +
  " -> " +
  delta.right_run_id +
  " changed=" +
  delta.changed_fields.join(",") +
  " load_window=" +
  delta.load_window_changed.to_string() +
  " risk_threshold=" +
  delta.risk_threshold_changed.to_string() +
  " quality_gate=" +
  delta.quality_gate_changed.to_string() +
  " conclusion=" +
  delta.conclusion
}

///|
pub fn configuration_snapshot_text(snapshot : ConfigurationSnapshot) -> String {
  "run=" +
  snapshot.run_id +
  " athlete=" +
  snapshot.athlete_label +
  " policy=" +
  snapshot.risk_policy_name +
  " acute=" +
  snapshot.acute_window.to_string() +
  " chronic=" +
  snapshot.chronic_window.to_string() +
  " baseline=" +
  snapshot.baseline_window.to_string() +
  " high_acwr=" +
  snapshot.high_acwr.to_string() +
  " medium_acwr=" +
  snapshot.medium_acwr.to_string() +
  " sleep_target=" +
  snapshot.sleep_target.to_string() +
  " high_risk=" +
  snapshot.high_risk_score.to_string() +
  " medium_risk=" +
  snapshot.medium_risk_score.to_string() +
  " readiness=" +
  snapshot.minimum_readiness.to_string() +
  " quality=" +
  snapshot.quality_floor.to_string() +
  " minimum_records=" +
  snapshot.minimum_records.to_string() +
  " coverage=" +
  snapshot.minimum_coverage.to_string() +
  " include_sessions=" +
  snapshot.include_sessions.to_string() +
  " valid=" +
  snapshot.valid.to_string()
}

///|
pub fn configuration_snapshot_checksum(
  snapshot : ConfigurationSnapshot,
) -> String {
  let mut value = snapshot.run_id.length() + snapshot.acute_window
  for character in configuration_snapshot_text(snapshot) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn configuration_snapshot_reproducible(
  left : ConfigurationSnapshot,
  right : ConfigurationSnapshot,
) -> Bool {
  configuration_snapshot_checksum(left) ==
  configuration_snapshot_checksum(right)
}

///|
pub fn configuration_snapshot_policy_status(
  snapshot : ConfigurationSnapshot,
) -> String {
  if !configuration_snapshot_valid(snapshot) {
    "invalid"
  } else if snapshot.high_acwr < 1.2 || snapshot.minimum_readiness < 60.0 {
    "sensitive"
  } else {
    "stable"
  }
}

///|
pub fn configuration_snapshot_review_days(
  snapshot : ConfigurationSnapshot,
) -> Int {
  if !configuration_snapshot_valid(snapshot) {
    0
  } else if configuration_snapshot_policy_status(snapshot) == "sensitive" {
    1
  } else {
    7
  }
}

///|
pub fn configuration_snapshot_review_label(
  snapshot : ConfigurationSnapshot,
) -> String {
  "review_in_" +
  configuration_snapshot_review_days(snapshot).to_string() +
  "_days"
}

///|
pub fn configuration_snapshot_exportable(
  snapshot : ConfigurationSnapshot,
) -> Bool {
  configuration_snapshot_valid(snapshot)
}

///|
pub fn configuration_snapshot_export_status(
  snapshot : ConfigurationSnapshot,
) -> String {
  if configuration_snapshot_exportable(snapshot) {
    "exportable"
  } else {
    "blocked"
  }
}

///|
pub fn configuration_snapshot_summary_header() -> Array[String] {
  [
    "run_id", "athlete_label", "policy", "acute_window", "chronic_window", "baseline_window",
    "high_acwr", "medium_acwr", "sleep_target", "high_risk", "medium_risk", "minimum_readiness",
    "quality_floor", "minimum_records", "minimum_coverage", "include_sessions", "valid",
  ]
}

///|
pub fn configuration_snapshot_summary(
  snapshot : ConfigurationSnapshot,
) -> Array[String] {
  configuration_snapshot_values(snapshot) + [snapshot.valid.to_string()]
}

///|
pub fn configuration_snapshot_summary_csv(
  snapshot : ConfigurationSnapshot,
) -> String {
  configuration_snapshot_summary_header().join(",") +
  "\n" +
  configuration_snapshot_summary(snapshot).join(",")
}

///|
pub fn configuration_snapshot_contract(
  snapshot : ConfigurationSnapshot,
) -> Array[String] {
  [
    snapshot.run_id,
    configuration_snapshot_policy_status(snapshot),
    configuration_snapshot_review_label(snapshot),
    configuration_snapshot_export_status(snapshot),
    configuration_snapshot_checksum(snapshot),
  ]
}
