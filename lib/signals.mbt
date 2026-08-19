///|
/// Signal families emitted by the assessment pipeline.
pub(all) enum SignalKind {
  Workload
  Recovery
  Sleep
  Pain
  Fatigue
  LoadSpike
  Monotony
  Trend
  DataQuality
  MissingHistory
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RiskSignal {
  id : String
  kind : SignalKind
  title : String
  value : Double
  threshold : Double
  severity : RiskLevel
  confidence : Double
  evidence : String
  action : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct SignalSummary {
  signal_count : Int
  high_count : Int
  medium_count : Int
  low_count : Int
  weighted_score : Double
  highest_risk : RiskLevel
  signals : Array[RiskSignal]
} derive(Debug, Eq, ToJson)

///|
pub fn signal_kind_name(kind : SignalKind) -> String {
  match kind {
    Workload => "workload"
    Recovery => "recovery"
    Sleep => "sleep"
    Pain => "pain"
    Fatigue => "fatigue"
    LoadSpike => "load-spike"
    Monotony => "monotony"
    Trend => "trend"
    DataQuality => "data-quality"
    MissingHistory => "missing-history"
  }
}

///|
pub fn signal_weight(signal : RiskSignal) -> Double {
  let severity = match signal.severity {
    Low => 1.0
    Medium => 2.0
    High => 3.0
  }
  severity * signal.confidence
}

///|
fn decision_signal(decision : PolicyDecision, index : Int) -> RiskSignal {
  let kind = match decision.metric {
    AcuteLoad | ChronicLoad | ACWR => Workload
    SleepHours | SleepQuality => Sleep
    PainLevel => Pain
    FatigueLevel => Fatigue
    LoadSpike => LoadSpike
  }
  {
    id: "policy-" + index.to_string() + "-" + decision.rule_id,
    kind,
    title: decision.rule_name,
    value: decision.actual_value,
    threshold: decision.threshold,
    severity: decision.severity,
    confidence: if decision.triggered {
      1.0
    } else {
      0.0
    },
    evidence: decision.message,
    action: decision.message,
  }
}

///|
pub fn signals_from_policy(
  decisions : Array[PolicyDecision],
) -> Array[RiskSignal] {
  let signals = []
  for index, decision in decisions {
    if decision.triggered {
      signals.push(decision_signal(decision, index))
    }
  }
  signals
}

///|
pub fn pain_signal(
  records : Array[DailyRecord],
  end_idx : Int,
  window_size : Int,
  threshold : Double,
) -> RiskSignal? {
  let value = max_pain_level(get_window_by_index(records, end_idx, window_size))
  if value <= threshold {
    None
  } else {
    Some({
      id: "pain-window",
      kind: Pain,
      title: "Pain escalation",
      value,
      threshold,
      severity: if value >= 7.0 {
        High
      } else {
        Medium
      },
      confidence: (value / 10.0).min(1.0),
      evidence: "maximum pain in the recent window is " + value.to_string(),
      action: "stop aggravating work and review the pain location",
    })
  }
}

///|
pub fn recovery_signal(
  records : Array[DailyRecord],
  end_idx : Int,
  window_size : Int,
  policy : RiskPolicy,
) -> RiskSignal? {
  let summary = recovery_summary(
    records,
    end_idx,
    window_size,
    policy.recovery_weights,
    policy.sleep_target,
  )
  if summary.recovery_score >= 70.0 {
    None
  } else {
    Some({
      id: "recovery-score",
      kind: Recovery,
      title: "Recovery reserve is low",
      value: summary.recovery_score,
      threshold: 70.0,
      severity: if summary.recovery_score < 50.0 {
        High
      } else {
        Medium
      },
      confidence: (70.0 - summary.recovery_score).max(0.0) / 70.0,
      evidence: "recovery score=" +
      summary.recovery_score.to_string() +
      " sleep debt=" +
      summary.sleep_debt_hours.to_string(),
      action: "reduce load until sleep and fatigue markers recover",
    })
  }
}

///|
pub fn monotony_signal(
  records : Array[DailyRecord],
  threshold : Double,
) -> RiskSignal? {
  let value = workload_monotony(training_loads(records))
  if value <= threshold {
    None
  } else {
    Some({
      id: "load-monotony",
      kind: Monotony,
      title: "Training monotony is elevated",
      value,
      threshold,
      severity: Low,
      confidence: (value / (threshold * 2.0)).min(1.0),
      evidence: "load monotony=" + value.to_string(),
      action: "vary training stimulus and schedule a lower-load day",
    })
  }
}

///|
pub fn trend_signal(
  records : Array[DailyRecord],
  window_size : Int,
) -> RiskSignal? {
  let values = rolling_metric(records, window_size, Average)
  let summary = summarize_trend(values, 0.1, 2)
  if summary.direction is Improving && summary.percent_change > 20.0 {
    Some({
      id: "load-trend",
      kind: Trend,
      title: "Workload trend is rising",
      value: summary.percent_change,
      threshold: 20.0,
      severity: if summary.percent_change >= 50.0 {
        High
      } else {
        Medium
      },
      confidence: (summary.percent_change / 100.0).min(1.0),
      evidence: trend_summary_text(summary),
      action: "hold progression and compare the next microcycle with baseline",
    })
  } else {
    None
  }
}

///|
pub fn data_quality_signal(report : QualityReport) -> RiskSignal? {
  if report.issue_count == 0 {
    None
  } else {
    Some({
      id: "data-quality",
      kind: DataQuality,
      title: "Telemetry quality needs review",
      value: report.score,
      threshold: 80.0,
      severity: if report.blocking_issue_count > 0 {
        High
      } else {
        Low
      },
      confidence: (report.issue_count.to_double() /
      (report.record_count + 1).to_double()).min(1.0),
      evidence: quality_report_text(report),
      action: "repair or annotate the affected records before interpreting risk",
    })
  }
}

///|
pub fn missing_history_signal(
  records : Array[DailyRecord],
  required_days : Int,
) -> RiskSignal? {
  if records.length() >= required_days {
    None
  } else {
    Some({
      id: "missing-history",
      kind: MissingHistory,
      title: "Insufficient history for stable baselines",
      value: records.length().to_double(),
      threshold: required_days.to_double(),
      severity: Medium,
      confidence: 1.0 - records.length().to_double() / required_days.to_double(),
      evidence: "records=" +
      records.length().to_string() +
      " required=" +
      required_days.to_string(),
      action: "collect a longer continuous baseline before increasing training volume",
    })
  }
}

///|
pub fn build_risk_signals(
  records : Array[DailyRecord],
  end_idx : Int,
  policy : RiskPolicy,
) -> Array[RiskSignal] {
  let signals = signals_from_policy(evaluate_policy(records, end_idx, policy))
  match pain_signal(records, end_idx, 3, 4.0) {
    Some(signal) => signals.push(signal)
    None => ()
  }
  match recovery_signal(records, end_idx, 7, policy) {
    Some(signal) => signals.push(signal)
    None => ()
  }
  match monotony_signal(records, 2.0) {
    Some(signal) => signals.push(signal)
    None => ()
  }
  match trend_signal(records, 7) {
    Some(signal) => signals.push(signal)
    None => ()
  }
  let report = validate_records(records, default_quality_policy())
  match data_quality_signal(report) {
    Some(signal) => signals.push(signal)
    None => ()
  }
  match missing_history_signal(records, policy.chronic_window) {
    Some(signal) => signals.push(signal)
    None => ()
  }
  signals
}

///|
pub fn summarize_signals(signals : Array[RiskSignal]) -> SignalSummary {
  let high = signals.filter(signal => signal.severity == High).length()
  let medium = signals.filter(signal => signal.severity == Medium).length()
  let low = signals.filter(signal => signal.severity == Low).length()
  let mut score = 0.0
  for signal in signals {
    score += signal_weight(signal)
  }
  let highest = if high > 0 { High } else if medium > 0 { Medium } else { Low }
  {
    signal_count: signals.length(),
    high_count: high,
    medium_count: medium,
    low_count: low,
    weighted_score: score,
    highest_risk: highest,
    signals,
  }
}

///|
pub fn highest_signal_risk(signals : ArrayView[RiskSignal]) -> RiskLevel {
  let mut highest = Low
  for signal in signals {
    highest = highest.max(signal.severity)
  }
  highest
}

///|
pub fn signal_text(signal : RiskSignal) -> String {
  "[" +
  signal_kind_name(signal.kind) +
  "] " +
  signal.title +
  " value=" +
  signal.value.to_string() +
  " confidence=" +
  signal.confidence.to_string() +
  " action=" +
  signal.action
}

///|
pub fn signal_ids(signals : Array[RiskSignal]) -> Array[String] {
  signals.map(signal => signal.id)
}
