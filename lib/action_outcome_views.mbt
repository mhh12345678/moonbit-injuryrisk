///|
/// Action outcome views connect queue work with measured post-action effects.
pub(all) struct ActionOutcomeView {
  action_id : String
  category : String
  action : String
  status : String
  outcome_status : String
  risk_change : Double
  readiness_change : Double
  recovery_change : Double
  pain_change : Double
  confidence : Double
  effective : Bool
  note : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ActionOutcomeSummary {
  rows : Array[ActionOutcomeView]
  effective_count : Int
  ineffective_count : Int
  pending_count : Int
  average_risk_change : Double
  average_readiness_change : Double
  average_confidence : Double
  status : String
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ActionOutcomeComparison {
  left_effective : Int
  right_effective : Int
  effective_change : Int
  left_confidence : Double
  right_confidence : Double
  confidence_change : Double
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
fn action_outcome_for_effect(
  effect : OutcomeEffect,
  action : ActionQueueItem?,
) -> ActionOutcomeView {
  let category = match action {
    Some(item) => item.category
    None => "outcome"
  }
  let title = match action {
    Some(item) => item.action
    None => "review measured outcome"
  }
  let status = match action {
    Some(item) => intervention_status_name(item.status)
    None => "completed"
  }
  {
    action_id: effect.intervention_id,
    category,
    action: title,
    status,
    outcome_status: if effect.effective {
      "effective"
    } else if effect.risk_change > 10.0 {
      "ineffective"
    } else {
      "mixed"
    },
    risk_change: effect.risk_change,
    readiness_change: effect.readiness_change,
    recovery_change: effect.recovery_change,
    pain_change: effect.pain_change,
    confidence: effect.confidence,
    effective: effect.effective,
    note: effect.note,
  }
}

///|
pub fn build_action_outcome_summary(
  report : OutcomeReport,
  queue : ActionQueue,
) -> ActionOutcomeSummary {
  let rows = report.effects.map(effect => {
    action_outcome_for_effect(effect, queue_find(queue, effect.intervention_id))
  })
  let effective = rows.filter(row => row.effective).length()
  let ineffective = rows
    .filter(row => !row.effective && row.outcome_status == "ineffective")
    .length()
  let pending = queue_open(queue).length()
  {
    rows,
    effective_count: effective,
    ineffective_count: ineffective,
    pending_count: pending,
    average_risk_change: mean_load_values(
      report.effects.map(effect => effect.risk_change),
    ),
    average_readiness_change: mean_load_values(
      report.effects.map(effect => effect.readiness_change),
    ),
    average_confidence: mean_load_values(
      report.effects.map(effect => effect.confidence),
    ),
    status: if ineffective > effective {
      "review"
    } else if effective > 0 {
      "improving"
    } else {
      "pending"
    },
    recommendation: if ineffective > effective {
      "review ineffective actions and adherence"
    } else if pending > 0 {
      "complete pending actions before judging effect"
    } else if effective > 0 {
      "retain effective actions"
    } else {
      "collect more outcome observations"
    },
  }
}

///|
pub fn action_outcome_for_run(
  run : DecisionRun,
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> ActionOutcomeSummary {
  build_action_outcome_summary(
    build_outcome_report(records, policy),
    build_action_queue(run),
  )
}

///|
pub fn action_outcome_rows(
  summary : ActionOutcomeSummary,
) -> Array[ActionOutcomeView] {
  summary.rows
}

///|
pub fn action_outcome_by_id(
  summary : ActionOutcomeSummary,
  id : String,
) -> ActionOutcomeView? {
  for row in summary.rows {
    if row.action_id == id {
      return Some(row)
    }
  }
  None
}

///|
pub fn action_outcome_effective(
  summary : ActionOutcomeSummary,
) -> Array[ActionOutcomeView] {
  summary.rows.filter(row => row.effective)
}

///|
pub fn action_outcome_ineffective(
  summary : ActionOutcomeSummary,
) -> Array[ActionOutcomeView] {
  summary.rows.filter(row => {
    !row.effective && row.outcome_status == "ineffective"
  })
}

///|
pub fn action_outcome_mixed(
  summary : ActionOutcomeSummary,
) -> Array[ActionOutcomeView] {
  summary.rows.filter(row => row.outcome_status == "mixed")
}

///|
pub fn action_outcome_pending(
  summary : ActionOutcomeSummary,
) -> Array[ActionOutcomeView] {
  summary.rows.filter(row => row.outcome_status == "pending")
}

///|
pub fn action_outcome_count(summary : ActionOutcomeSummary) -> Int {
  summary.rows.length()
}

///|
pub fn action_outcome_effective_count(summary : ActionOutcomeSummary) -> Int {
  summary.effective_count
}

///|
pub fn action_outcome_ineffective_count(summary : ActionOutcomeSummary) -> Int {
  summary.ineffective_count
}

///|
pub fn action_outcome_pending_count(summary : ActionOutcomeSummary) -> Int {
  summary.pending_count
}

///|
pub fn action_outcome_effective_percent(
  summary : ActionOutcomeSummary,
) -> Double {
  if summary.rows.length() == 0 {
    0.0
  } else {
    summary.effective_count.to_double() /
    summary.rows.length().to_double() *
    100.0
  }
}

///|
pub fn action_outcome_risk_change(summary : ActionOutcomeSummary) -> Double {
  summary.average_risk_change
}

///|
pub fn action_outcome_readiness_change(
  summary : ActionOutcomeSummary,
) -> Double {
  summary.average_readiness_change
}

///|
pub fn action_outcome_confidence(summary : ActionOutcomeSummary) -> Double {
  summary.average_confidence
}

///|
pub fn action_outcome_status(summary : ActionOutcomeSummary) -> String {
  summary.status
}

///|
pub fn action_outcome_requires_review(summary : ActionOutcomeSummary) -> Bool {
  summary.status == "review" || summary.pending_count > 0
}

///|
pub fn action_outcome_recommendation(summary : ActionOutcomeSummary) -> String {
  summary.recommendation
}

///|
pub fn action_outcome_categories(
  summary : ActionOutcomeSummary,
) -> Array[String] {
  let values = []
  for row in summary.rows {
    if !values.contains(row.category) {
      values.push(row.category)
    }
  }
  values
}

///|
pub fn action_outcome_category_count(
  summary : ActionOutcomeSummary,
  category : String,
) -> Int {
  summary.rows.filter(row => row.category == category).length()
}

///|
pub fn action_outcome_category_effective_count(
  summary : ActionOutcomeSummary,
  category : String,
) -> Int {
  summary.rows.filter(row => row.category == category && row.effective).length()
}

///|
pub fn action_outcome_category_effective_percent(
  summary : ActionOutcomeSummary,
  category : String,
) -> Double {
  let count = action_outcome_category_count(summary, category)
  if count == 0 {
    0.0
  } else {
    action_outcome_category_effective_count(summary, category).to_double() /
    count.to_double() *
    100.0
  }
}

///|
pub fn action_outcome_metric(row : ActionOutcomeView, name : String) -> Double {
  match name {
    "risk_change" => row.risk_change
    "readiness_change" => row.readiness_change
    "recovery_change" => row.recovery_change
    "pain_change" => row.pain_change
    "confidence" => row.confidence
    "effective" => if row.effective { 1.0 } else { 0.0 }
    _ => 0.0
  }
}

///|
pub fn action_outcome_projection(
  summary : ActionOutcomeSummary,
  name : String,
) -> Array[Double] {
  summary.rows.map(row => action_outcome_metric(row, name))
}

///|
pub fn action_outcome_projection_average(
  summary : ActionOutcomeSummary,
  name : String,
) -> Double {
  mean_load_values(action_outcome_projection(summary, name))
}

///|
pub fn action_outcome_projection_minimum(
  summary : ActionOutcomeSummary,
  name : String,
) -> Double {
  minimum_load_values(action_outcome_projection(summary, name))
}

///|
pub fn action_outcome_projection_maximum(
  summary : ActionOutcomeSummary,
  name : String,
) -> Double {
  maximum_load_values(action_outcome_projection(summary, name))
}

///|
pub fn action_outcome_projection_deviation(
  summary : ActionOutcomeSummary,
  name : String,
) -> Double {
  standard_deviation_values(action_outcome_projection(summary, name))
}

///|
pub fn action_outcome_valid_row(row : ActionOutcomeView) -> Bool {
  row.action_id != "" &&
  row.category != "" &&
  row.action != "" &&
  row.status != "" &&
  row.outcome_status != "" &&
  row.confidence >= 0.0 &&
  row.confidence <= 1.0 &&
  row.note != ""
}

///|
pub fn action_outcome_valid(summary : ActionOutcomeSummary) -> Bool {
  summary.rows.all(row => action_outcome_valid_row(row)) &&
  summary.effective_count >= 0 &&
  summary.ineffective_count >= 0 &&
  summary.pending_count >= 0 &&
  summary.average_confidence >= 0.0 &&
  summary.average_confidence <= 1.0
}

///|
pub fn action_outcome_row_text(row : ActionOutcomeView) -> String {
  row.action_id +
  " category=" +
  row.category +
  " outcome=" +
  row.outcome_status +
  " risk_change=" +
  row.risk_change.to_string() +
  " readiness_change=" +
  row.readiness_change.to_string() +
  " recovery_change=" +
  row.recovery_change.to_string() +
  " pain_change=" +
  row.pain_change.to_string() +
  " confidence=" +
  row.confidence.to_string() +
  " note=" +
  row.note
}

///|
pub fn action_outcome_text(summary : ActionOutcomeSummary) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "status=" +
    summary.status +
    " rows=" +
    summary.rows.length().to_string() +
    " effective=" +
    summary.effective_count.to_string() +
    " ineffective=" +
    summary.ineffective_count.to_string() +
    " pending=" +
    summary.pending_count.to_string() +
    " risk_change=" +
    summary.average_risk_change.to_string() +
    " readiness_change=" +
    summary.average_readiness_change.to_string() +
    " confidence=" +
    summary.average_confidence.to_string(),
  )
  builder.write_string("\nrecommendation=" + summary.recommendation)
  for row in summary.rows {
    builder.write_string("\n" + action_outcome_row_text(row))
  }
  builder.to_string()
}

///|
pub fn action_outcome_csv_header() -> String {
  "action_id,category,action,status,outcome_status,risk_change,readiness_change,recovery_change,pain_change,confidence,effective,note"
}

///|
pub fn action_outcome_csv(row : ActionOutcomeView) -> String {
  row.action_id +
  "," +
  row.category +
  "," +
  row.action +
  "," +
  row.status +
  "," +
  row.outcome_status +
  "," +
  row.risk_change.to_string() +
  "," +
  row.readiness_change.to_string() +
  "," +
  row.recovery_change.to_string() +
  "," +
  row.pain_change.to_string() +
  "," +
  row.confidence.to_string() +
  "," +
  row.effective.to_string() +
  "," +
  row.note
}

///|
pub fn action_outcome_summary_csv(summary : ActionOutcomeSummary) -> String {
  let builder = StringBuilder::new()
  builder.write_string(action_outcome_csv_header())
  for row in summary.rows {
    builder.write_string("\n" + action_outcome_csv(row))
  }
  builder.to_string()
}

///|
pub fn action_outcome_compare(
  left : ActionOutcomeSummary,
  right : ActionOutcomeSummary,
) -> ActionOutcomeComparison {
  {
    left_effective: left.effective_count,
    right_effective: right.effective_count,
    effective_change: right.effective_count - left.effective_count,
    left_confidence: left.average_confidence,
    right_confidence: right.average_confidence,
    confidence_change: right.average_confidence - left.average_confidence,
    conclusion: if right.effective_count > left.effective_count &&
      right.average_confidence >= left.average_confidence {
      "action outcomes improved"
    } else if right.effective_count < left.effective_count {
      "action outcomes worsened"
    } else {
      "action outcomes are stable"
    },
  }
}

///|
pub fn action_outcome_comparison_text(
  comparison : ActionOutcomeComparison,
) -> String {
  "effective=" +
  comparison.left_effective.to_string() +
  " -> " +
  comparison.right_effective.to_string() +
  " change=" +
  comparison.effective_change.to_string() +
  " confidence=" +
  comparison.confidence_change.to_string() +
  " conclusion=" +
  comparison.conclusion
}

///|
pub fn action_outcome_checksum(summary : ActionOutcomeSummary) -> String {
  let mut value = summary.rows.length()
  for character in action_outcome_text(summary) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn action_outcome_reproducible(
  left : ActionOutcomeSummary,
  right : ActionOutcomeSummary,
) -> Bool {
  action_outcome_checksum(left) == action_outcome_checksum(right)
}

///|
pub fn action_outcome_exportable(summary : ActionOutcomeSummary) -> Bool {
  action_outcome_valid(summary)
}

///|
pub fn action_outcome_export_status(summary : ActionOutcomeSummary) -> String {
  if action_outcome_exportable(summary) {
    "exportable"
  } else {
    "blocked"
  }
}

///|
pub fn action_outcome_contract(summary : ActionOutcomeSummary) -> Array[String] {
  [
    summary.status,
    summary.rows.length().to_string(),
    summary.effective_count.to_string(),
    summary.ineffective_count.to_string(),
    summary.pending_count.to_string(),
    action_outcome_effective_percent(summary).to_string(),
    action_outcome_recommendation(summary),
    action_outcome_export_status(summary),
    action_outcome_checksum(summary),
  ]
}
