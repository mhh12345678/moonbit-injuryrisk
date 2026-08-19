///|
/// The operational decision produced after a risk screening.
pub(all) enum TrainingDecision {
  Progress
  Maintain
  Reduce
  Rest
  Refer
  CollectData
} derive(Debug, Eq, ToJson)

///|
pub(all) struct DecisionRecord {
  decision : TrainingDecision
  allowed_load_change : Double
  confidence : Double
  reason : String
  next_review_days : Int
} derive(Debug, Eq, ToJson)

///|
pub fn decision_name(decision : TrainingDecision) -> String {
  match decision {
    Progress => "progress"
    Maintain => "maintain"
    Reduce => "reduce"
    Rest => "rest"
    Refer => "refer"
    CollectData => "collect-data"
  }
}

///|
pub fn operational_decision(
  assessment : ComprehensiveAssessment,
) -> DecisionRecord {
  if assessment.quality.blocking_issue_count > 0 {
    {
      decision: CollectData,
      allowed_load_change: 0.0,
      confidence: 0.4,
      reason: "repair blocking telemetry quality issues",
      next_review_days: 1,
    }
  } else if assessment.recovery.maximum_pain >= 7.0 {
    {
      decision: Refer,
      allowed_load_change: -40.0,
      confidence: 0.95,
      reason: "severe pain requires review before loading",
      next_review_days: 1,
    }
  } else if assessment.risk_level == High {
    {
      decision: Rest,
      allowed_load_change: -30.0,
      confidence: 0.90,
      reason: "high-severity risk signal is active",
      next_review_days: 2,
    }
  } else if assessment.risk_level == Medium || assessment.readiness_score < 60.0 {
    {
      decision: Reduce,
      allowed_load_change: -15.0,
      confidence: 0.80,
      reason: "moderate risk or low readiness needs stabilization",
      next_review_days: 2,
    }
  } else if assessment.readiness_score >= 80.0 {
    {
      decision: Progress,
      allowed_load_change: 5.0,
      confidence: 0.75,
      reason: "signals are clear and readiness supports gradual progression",
      next_review_days: 3,
    }
  } else {
    {
      decision: Maintain,
      allowed_load_change: 0.0,
      confidence: 0.70,
      reason: "maintain current load while monitoring recovery",
      next_review_days: 2,
    }
  }
}

///|
pub fn decision_is_restrictive(record : DecisionRecord) -> Bool {
  record.allowed_load_change < 0.0 ||
  record.decision == Rest ||
  record.decision == Refer
}

///|
pub fn decision_text(record : DecisionRecord) -> String {
  decision_name(record.decision) +
  " change=" +
  record.allowed_load_change.to_string() +
  "% confidence=" +
  record.confidence.to_string() +
  " review_in=" +
  record.next_review_days.to_string() +
  "d reason=" +
  record.reason
}

///|
pub fn decision_for_records(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> DecisionRecord? {
  match assess_latest(records, policy) {
    Some(assessment) => Some(operational_decision(assessment))
    None => None
  }
}

///|
pub fn allowed_next_load(
  current_load : Double,
  decision : DecisionRecord,
) -> Double {
  (current_load * (1.0 + decision.allowed_load_change / 100.0)).max(0.0)
}

///|
pub fn decision_requires_review(
  record : DecisionRecord,
  days_since_review : Int,
) -> Bool {
  days_since_review >= record.next_review_days
}

///|
pub fn decision_catalog() -> Array[String] {
  [Progress, Maintain, Reduce, Rest, Refer, CollectData].map(decision => {
    decision_name(decision)
  })
}
