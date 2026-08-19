///|
/// Explicit progression review records for the next training decision.
pub(all) enum ProgressionDecision {
  ProgressionApprove
  ProgressionHold
  ProgressionReduce
  ProgressionPause
  ProgressionRefer
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ProgressionReview {
  date : String
  decision : ProgressionDecision
  requested_change_percent : Double
  allowed_change_percent : Double
  current_load : Double
  projected_load : Double
  current_risk : Double
  current_readiness : Double
  reasons : Array[String]
  next_review_date : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ProgressionHistory {
  reviews : Array[ProgressionReview]
  approved_count : Int
  held_count : Int
  reduced_count : Int
  paused_count : Int
  referred_count : Int
  status : String
} derive(Debug, Eq, ToJson)

///|
pub fn progression_decision_name(decision : ProgressionDecision) -> String {
  match decision {
    ProgressionApprove => "approve"
    ProgressionHold => "hold"
    ProgressionReduce => "reduce"
    ProgressionPause => "pause"
    ProgressionRefer => "refer"
  }
}

///|
fn progression_review_date(date : String, days : Int) -> String {
  match parse_date(date) {
    Some(value) =>
      match add_days(value, days) {
        Some(next) => format_date(next)
        None => date
      }
    None => date
  }
}

///|
fn progression_reasons(
  assessment : ComprehensiveAssessment,
  guardrail : ProgressionGuardrail,
  requested : Double,
) -> Array[String] {
  let reasons = []
  if !guardrail.allowed {
    reasons.push(guardrail.reason)
  }
  if assessment.risk_level == High {
    reasons.push("current risk is high")
  }
  if assessment.risk_level == Medium {
    reasons.push("current risk is medium")
  }
  if assessment.readiness_score < 70.0 {
    reasons.push("readiness is below progression floor")
  }
  if assessment.quality.blocking_issue_count > 0 {
    reasons.push("quality has blocking issues")
  }
  if requested > guardrail.maximum_increase_percent {
    reasons.push("requested change exceeds guardrail")
  }
  reasons
}

///|
pub fn review_progression(
  assessment : ComprehensiveAssessment,
  policy : RiskPolicy,
  requested_change : Double,
) -> ProgressionReview {
  let guardrail = progression_guardrail(
    [assessment_to_record(assessment)],
    policy,
    requested_change,
  )
  let reasons = progression_reasons(assessment, guardrail, requested_change)
  let decision = if assessment.quality.blocking_issue_count > 0 {
    ProgressionPause
  } else if assessment.risk_level == High {
    ProgressionRefer
  } else if assessment.risk_level == Medium || assessment.readiness_score < 70.0 {
    ProgressionReduce
  } else if !guardrail.allowed {
    ProgressionHold
  } else {
    ProgressionApprove
  }
  let allowed = match decision {
    ProgressionApprove =>
      requested_change.min(guardrail.maximum_increase_percent)
    ProgressionHold => 0.0
    ProgressionReduce => requested_change.min(0.0)
    ProgressionPause | ProgressionRefer => -30.0
  }
  let current = assessment.load.average_load
  {
    date: assessment.date,
    decision,
    requested_change_percent: requested_change,
    allowed_change_percent: allowed,
    current_load: current,
    projected_load: current * (1.0 + allowed / 100.0).max(0.0),
    current_risk: assessment.risk_score,
    current_readiness: assessment.readiness_score,
    reasons,
    next_review_date: progression_review_date(
      assessment.date,
      if decision == ProgressionApprove {
        3
      } else {
        1
      },
    ),
  }
}

///|
fn assessment_to_record(assessment : ComprehensiveAssessment) -> DailyRecord {
  {
    date: assessment.date,
    training_duration: assessment.load.average_load / 5.0,
    training_intensity: 5.0,
    pain_level: 0.0,
    pain_site: None,
    sleep_hours: assessment.recovery.average_sleep_hours,
    sleep_quality: assessment.recovery.average_sleep_quality,
    fatigue: assessment.recovery.average_fatigue,
  }
}

///|
pub fn progression_review_for_latest(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  requested_change : Double,
) -> ProgressionReview? {
  match assess_latest(records, policy) {
    Some(value) => Some(review_progression(value, policy, requested_change))
    None => None
  }
}

///|
pub fn new_progression_history() -> ProgressionHistory {
  {
    reviews: [],
    approved_count: 0,
    held_count: 0,
    reduced_count: 0,
    paused_count: 0,
    referred_count: 0,
    status: "empty",
  }
}

///|
fn history_status(history : ProgressionHistory) -> String {
  if history.referred_count > 0 {
    "refer"
  } else if history.paused_count > 0 {
    "paused"
  } else if history.reduced_count > 0 {
    "reduced"
  } else if history.held_count > 0 {
    "held"
  } else if history.approved_count > 0 {
    "approved"
  } else {
    "empty"
  }
}

///|
pub fn append_progression_review(
  history : ProgressionHistory,
  review : ProgressionReview,
) -> ProgressionHistory {
  let approved = history.approved_count +
    (if review.decision == ProgressionApprove { 1 } else { 0 })
  let held = history.held_count +
    (if review.decision == ProgressionHold { 1 } else { 0 })
  let reduced = history.reduced_count +
    (if review.decision == ProgressionReduce { 1 } else { 0 })
  let paused = history.paused_count +
    (if review.decision == ProgressionPause { 1 } else { 0 })
  let referred = history.referred_count +
    (if review.decision == ProgressionRefer { 1 } else { 0 })
  let base = {
    reviews: history.reviews + [review],
    approved_count: approved,
    held_count: held,
    reduced_count: reduced,
    paused_count: paused,
    referred_count: referred,
    status: "",
  }
  {
    reviews: base.reviews,
    approved_count: approved,
    held_count: held,
    reduced_count: reduced,
    paused_count: paused,
    referred_count: referred,
    status: history_status(base),
  }
}

///|
pub fn latest_progression_review(
  history : ProgressionHistory,
) -> ProgressionReview? {
  if history.reviews.length() == 0 {
    None
  } else {
    Some(history.reviews[history.reviews.length() - 1])
  }
}

///|
pub fn progression_reviews_by_decision(
  history : ProgressionHistory,
  decision : ProgressionDecision,
) -> Array[ProgressionReview] {
  history.reviews.filter(review => review.decision == decision)
}

///|
pub fn progression_average_allowed_change(
  history : ProgressionHistory,
) -> Double {
  mean_load_values(history.reviews.map(review => review.allowed_change_percent))
}

///|
pub fn progression_average_requested_change(
  history : ProgressionHistory,
) -> Double {
  mean_load_values(
    history.reviews.map(review => review.requested_change_percent),
  )
}

///|
pub fn progression_reason_counts(history : ProgressionHistory) -> Array[Int] {
  [
    history.reviews
    .filter(review => review.reasons.contains("current risk is high"))
    .length(),
    history.reviews
    .filter(review => review.reasons.contains("current risk is medium"))
    .length(),
    history.reviews
    .filter(review => {
      review.reasons.contains("readiness is below progression floor")
    })
    .length(),
    history.reviews
    .filter(review => review.reasons.contains("quality has blocking issues"))
    .length(),
  ]
}

///|
pub fn progression_is_conservative(history : ProgressionHistory) -> Bool {
  history.reviews.all(review => {
    review.allowed_change_percent <= review.requested_change_percent
  })
}

///|
pub fn progression_requires_followup(history : ProgressionHistory) -> Bool {
  history.status == "refer" ||
  history.status == "paused" ||
  history.status == "reduced"
}

///|
pub fn progression_recommendation(history : ProgressionHistory) -> String {
  match history.status {
    "refer" => "route the case for qualified review"
    "paused" => "pause automatic progression"
    "reduced" => "keep the reduced load cap"
    "held" => "collect another observation"
    "approved" => "continue with the approved cap"
    _ => "complete an initial assessment"
  }
}

///|
pub fn progression_review_text(review : ProgressionReview) -> String {
  "date=" +
  review.date +
  " decision=" +
  progression_decision_name(review.decision) +
  " requested=" +
  review.requested_change_percent.to_string() +
  "% allowed=" +
  review.allowed_change_percent.to_string() +
  "% current_load=" +
  review.current_load.to_string() +
  " projected=" +
  review.projected_load.to_string() +
  " risk=" +
  review.current_risk.to_string() +
  " readiness=" +
  review.current_readiness.to_string() +
  " reasons=" +
  review.reasons.join(";")
}

///|
pub fn progression_history_text(history : ProgressionHistory) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "status=" +
    history.status +
    " reviews=" +
    history.reviews.length().to_string() +
    " approved=" +
    history.approved_count.to_string() +
    " held=" +
    history.held_count.to_string() +
    " reduced=" +
    history.reduced_count.to_string() +
    " paused=" +
    history.paused_count.to_string() +
    " referred=" +
    history.referred_count.to_string(),
  )
  for review in history.reviews {
    builder.write_string("\n" + progression_review_text(review))
  }
  builder.to_string()
}

///|
pub fn progression_review_csv_header() -> String {
  "date,decision,requested_change,allowed_change,current_load,projected_load,current_risk,current_readiness,next_review"
}

///|
pub fn progression_review_csv(review : ProgressionReview) -> String {
  review.date +
  "," +
  progression_decision_name(review.decision) +
  "," +
  review.requested_change_percent.to_string() +
  "," +
  review.allowed_change_percent.to_string() +
  "," +
  review.current_load.to_string() +
  "," +
  review.projected_load.to_string() +
  "," +
  review.current_risk.to_string() +
  "," +
  review.current_readiness.to_string() +
  "," +
  review.next_review_date
}

///|
pub fn progression_history_csv(history : ProgressionHistory) -> String {
  let builder = StringBuilder::new()
  builder.write_string(progression_review_csv_header())
  for review in history.reviews {
    builder.write_string("\n")
    builder.write_string(progression_review_csv(review))
  }
  builder.to_string()
}

///|
pub fn progression_review_valid(review : ProgressionReview) -> Bool {
  review.date != "" &&
  review.requested_change_percent.is_nan() == false &&
  review.allowed_change_percent.is_nan() == false &&
  review.current_load >= 0.0 &&
  review.projected_load >= 0.0 &&
  review.current_risk >= 0.0 &&
  review.current_risk <= 100.0 &&
  review.current_readiness >= 0.0 &&
  review.current_readiness <= 100.0
}
