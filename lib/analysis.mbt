///|
/// Cross-domain analysis for a training block.
pub(all) struct TrainingAnalysis {
  load : LoadSummary
  recovery : RecoverySummary
  pain : PainSummary
  readiness : ReadinessSummary
  quality : QualityReport
  overtraining_index : Double
  load_recovery_ratio : Double
  risk_note : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PeriodComparison {
  first_period_load : Double
  second_period_load : Double
  load_change_percent : Double
  first_recovery : Double
  second_recovery : Double
  recovery_change : Double
  first_readiness : Double
  second_readiness : Double
  readiness_change : Double
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
pub fn load_recovery_ratio(load : Double, recovery : Double) -> Double {
  if recovery <= 0.0 {
    if load <= 0.0 {
      0.0
    } else {
      100.0
    }
  } else {
    load / recovery
  }
}

///|
pub fn overtraining_index(
  load : LoadSummary,
  recovery : RecoverySummary,
  pain : PainSummary,
  readiness : ReadinessSummary,
) -> Double {
  let load_component = ((load.acwr - 1.0) * 60.0).max(0.0).min(100.0)
  let monotony_component = (load.monotony * 20.0).min(100.0)
  let recovery_component = (100.0 - recovery.recovery_score).max(0.0)
  let pain_component = (pain.maximum_level * 10.0).min(100.0)
  let readiness_component = (100.0 - readiness.average_score).max(0.0)
  (load_component * 0.25 +
  monotony_component * 0.15 +
  recovery_component * 0.25 +
  pain_component * 0.20 +
  readiness_component * 0.15).min(100.0)
}

///|
pub fn overtraining_band(index : Double) -> String {
  if index >= 75.0 {
    "critical"
  } else if index >= 50.0 {
    "elevated"
  } else if index >= 25.0 {
    "watch"
  } else {
    "low"
  }
}

///|
pub fn analysis_note(index : Double, quality : QualityReport) -> String {
  if quality.blocking_issue_count > 0 {
    "data quality is blocking confident interpretation"
  } else if index >= 75.0 {
    "multiple load and recovery domains require immediate review"
  } else if index >= 50.0 {
    "training stress is elevated; stabilize the next microcycle"
  } else if index >= 25.0 {
    "signals are within a watch zone; continue daily monitoring"
  } else {
    "no composite overtraining pattern is detected"
  }
}

///|
pub fn analyze_training_block(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> TrainingAnalysis {
  let summary = summarize_load_window(records, policy.chronic_window)
  let recovery = recovery_summary(
    records,
    records.length() - 1,
    policy.chronic_window,
    policy.recovery_weights,
    policy.sleep_target,
  )
  let pain = summarize_pain(records, 1.0, 3)
  let readiness = summarize_readiness(
    readiness_history(records, policy.acute_window, policy.sleep_target),
  )
  let quality = validate_records(records, default_quality_policy())
  let index = overtraining_index(summary, recovery, pain, readiness)
  {
    load: summary,
    recovery,
    pain,
    readiness,
    quality,
    overtraining_index: index,
    load_recovery_ratio: load_recovery_ratio(
      summary.average_load,
      recovery.recovery_score,
    ),
    risk_note: analysis_note(index, quality),
  }
}

///|
pub fn compare_periods(
  first : Array[DailyRecord],
  second : Array[DailyRecord],
  policy : RiskPolicy,
) -> PeriodComparison {
  let first_analysis = analyze_training_block(first, policy)
  let second_analysis = analyze_training_block(second, policy)
  let load_change = percentage_change(
    first_analysis.load.average_load,
    second_analysis.load.average_load,
  )
  let recovery_change = second_analysis.recovery.recovery_score -
    first_analysis.recovery.recovery_score
  let readiness_change = second_analysis.readiness.average_score -
    first_analysis.readiness.average_score
  let conclusion = if load_change > 15.0 && recovery_change < -5.0 {
    "load increased while recovery deteriorated"
  } else if load_change < -15.0 && recovery_change > 5.0 {
    "load was reduced and recovery improved"
  } else {
    "period changes are mixed or within the normal monitoring band"
  }
  {
    first_period_load: first_analysis.load.average_load,
    second_period_load: second_analysis.load.average_load,
    load_change_percent: load_change,
    first_recovery: first_analysis.recovery.recovery_score,
    second_recovery: second_analysis.recovery.recovery_score,
    recovery_change,
    first_readiness: first_analysis.readiness.average_score,
    second_readiness: second_analysis.readiness.average_score,
    readiness_change,
    conclusion,
  }
}

///|
pub fn analysis_risk_level(analysis : TrainingAnalysis) -> RiskLevel {
  if analysis.overtraining_index >= 75.0 || analysis.pain.maximum_level >= 7.0 {
    High
  } else if analysis.overtraining_index >= 50.0 ||
    analysis.recovery.recovery_score < 50.0 {
    Medium
  } else {
    Low
  }
}

///|
pub fn analysis_text(analysis : TrainingAnalysis) -> String {
  "overtraining_index=" +
  analysis.overtraining_index.to_string() +
  " band=" +
  overtraining_band(analysis.overtraining_index) +
  " acwr=" +
  analysis.load.acwr.to_string() +
  " recovery=" +
  analysis.recovery.recovery_score.to_string() +
  " readiness=" +
  analysis.readiness.average_score.to_string() +
  " pain=" +
  analysis.pain.maximum_level.to_string() +
  " note=" +
  analysis.risk_note
}
