///|
/// Priority assigned to an operational training recommendation.
pub(all) enum RecommendationPriority {
  Immediate
  Soon
  Monitor
  Positive
} derive(Debug, Eq, ToJson)

///|
pub(all) struct Recommendation {
  id : String
  priority : RecommendationPriority
  title : String
  rationale : String
  action : String
  expected_effect : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ActionPlan {
  focus : String
  rest_days : Int
  load_change_percent : Double
  recommendations : Array[Recommendation]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ComprehensiveAssessment {
  date : String
  risk_level : RiskLevel
  risk_score : Double
  readiness_score : Double
  load : LoadSummary
  recovery : RecoverySummary
  quality : QualityReport
  signals : SignalSummary
  action_plan : ActionPlan
  summary : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct AssessmentDelta {
  risk_score_change : Double
  readiness_score_change : Double
  load_change_percent : Double
  recovery_change : Double
  direction : TrendDirection
} derive(Debug, Eq, ToJson)

///|
pub fn recommendation_priority_name(
  priority : RecommendationPriority,
) -> String {
  match priority {
    Immediate => "immediate"
    Soon => "soon"
    Monitor => "monitor"
    Positive => "positive"
  }
}

///|
fn recommendation_from_signal(
  signal : RiskSignal,
  index : Int,
) -> Recommendation {
  let priority = match signal.severity {
    High => Immediate
    Medium => Soon
    Low => Monitor
  }
  {
    id: "recommendation-" + index.to_string() + "-" + signal.id,
    priority,
    title: signal.title,
    rationale: signal.evidence,
    action: signal.action,
    expected_effect: "lower the signal value and improve training readiness",
  }
}

///|
pub fn recommendations_from_signals(
  signals : Array[RiskSignal],
) -> Array[Recommendation] {
  let recommendations = []
  for index, signal in signals {
    recommendations.push(recommendation_from_signal(signal, index))
  }
  recommendations
}

///|
pub fn plan_focus(risk : RiskLevel, readiness : Double) -> String {
  match risk {
    High => "protect athlete and resolve high-severity signals"
    Medium => "stabilize workload and restore recovery capacity"
    Low =>
      if readiness >= 80.0 {
        "maintain progressive training"
      } else {
        "monitor recovery before progression"
      }
  }
}

///|
pub fn build_action_plan(
  risk : RiskLevel,
  readiness : Double,
  signals : Array[RiskSignal],
) -> ActionPlan {
  let rest_days = match risk {
    High => 2
    Medium => 1
    Low => 0
  }
  let change = match risk {
    High => -30.0
    Medium => -15.0
    Low => if readiness >= 80.0 { 5.0 } else { 0.0 }
  }
  {
    focus: plan_focus(risk, readiness),
    rest_days,
    load_change_percent: change,
    recommendations: recommendations_from_signals(signals),
  }
}

///|
pub fn readiness_score(
  load : LoadSummary,
  recovery : RecoverySummary,
  pain : Double,
  quality : QualityReport,
) -> Double {
  let load_component = if load.acwr <= 1.0 {
    100.0
  } else if load.acwr >= 2.0 {
    0.0
  } else {
    (2.0 - load.acwr) * 100.0
  }
  let pain_component = (100.0 - pain * 10.0).max(0.0)
  let quality_component = quality.score
  (load_component * 0.30 +
  recovery.recovery_score * 0.40 +
  pain_component * 0.20 +
  quality_component * 0.10)
  .min(100.0)
  .max(0.0)
}

///|
pub fn risk_score_from_signals(summary : SignalSummary) -> Double {
  summary.weighted_score.min(100.0)
}

///|
pub fn assessment_summary(
  date : String,
  risk : RiskLevel,
  risk_score : Double,
  readiness : Double,
  load : LoadSummary,
  recovery : RecoverySummary,
  signal_count : Int,
) -> String {
  let risk_name = match risk {
    Low => "LOW"
    Medium => "MEDIUM"
    High => "HIGH"
  }
  "date=" +
  date +
  " risk=" +
  risk_name +
  " risk_score=" +
  risk_score.to_string() +
  " readiness=" +
  readiness.to_string() +
  " acwr=" +
  load.acwr.to_string() +
  " recovery=" +
  recovery.recovery_score.to_string() +
  " signals=" +
  signal_count.to_string()
}

///|
pub fn assess_comprehensive(
  records : Array[DailyRecord],
  target_date : String,
  policy : RiskPolicy,
) -> ComprehensiveAssessment? {
  let index = find_record_index(records, target_date)
  if index is None {
    return None
  }
  let end_idx = index.unwrap()
  let load = summarize_load(
    records,
    end_idx,
    policy.acute_window,
    policy.chronic_window,
    policy.baseline_window,
  )
  let recovery = recovery_summary(
    records,
    end_idx,
    policy.chronic_window.min(records.length()),
    policy.recovery_weights,
    policy.sleep_target,
  )
  let quality = validate_records(records, default_quality_policy())
  let signals = summarize_signals(build_risk_signals(records, end_idx, policy))
  let risk = highest_signal_risk(signals.signals)
  let score = risk_score_from_signals(signals)
  let readiness = readiness_score(
    load,
    recovery,
    max_pain_level(get_window_by_index(records, end_idx, 7)),
    quality,
  )
  let plan = build_action_plan(risk, readiness, signals.signals)
  Some({
    date: target_date,
    risk_level: risk,
    risk_score: score,
    readiness_score: readiness,
    load,
    recovery,
    quality,
    signals,
    action_plan: plan,
    summary: assessment_summary(
      target_date,
      risk,
      score,
      readiness,
      load,
      recovery,
      signals.signal_count,
    ),
  })
}

///|
pub fn assess_latest(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> ComprehensiveAssessment? {
  if records.length() == 0 {
    None
  } else {
    let sorted = sort_records_by_date(records)
    assess_comprehensive(sorted, sorted[sorted.length() - 1].date, policy)
  }
}

///|
pub fn assessment_delta(
  previous : ComprehensiveAssessment,
  current : ComprehensiveAssessment,
) -> AssessmentDelta {
  let load_change = percentage_change(
    previous.load.average_load,
    current.load.average_load,
  )
  let recovery_change = current.recovery.recovery_score -
    previous.recovery.recovery_score
  let direction = classify_trend(
    [previous.risk_score, current.risk_score],
    0.1,
    1,
  )
  {
    risk_score_change: current.risk_score - previous.risk_score,
    readiness_score_change: current.readiness_score - previous.readiness_score,
    load_change_percent: load_change,
    recovery_change,
    direction,
  }
}

///|
pub fn assessment_text(assessment : ComprehensiveAssessment) -> String {
  let builder = StringBuilder()
  builder.write_string(assessment.summary)
  builder.write_string("\nfocus: ")
  builder.write_string(assessment.action_plan.focus)
  builder.write_string("\nrecommendations:")
  for recommendation in assessment.action_plan.recommendations {
    builder.write_string("\n- [")
    builder.write_string(recommendation_priority_name(recommendation.priority))
    builder.write_string("] ")
    builder.write_string(recommendation.action)
  }
  builder.to_string()
}

///|
pub fn risk_level_name(level : RiskLevel) -> String {
  match level {
    Low => "low"
    Medium => "medium"
    High => "high"
  }
}

///|
pub fn assessment_is_actionable(assessment : ComprehensiveAssessment) -> Bool {
  assessment.risk_level != Low ||
  assessment.readiness_score < 70.0 ||
  assessment.quality.blocking_issue_count > 0
}
