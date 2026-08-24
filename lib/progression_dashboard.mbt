///|
/// Progression dashboards expose the next-load decision and its guardrails.
pub(all) struct ProgressionDashboardItem {
  date : String
  decision : ProgressionDecision
  requested_change : Double
  allowed_change : Double
  current_load : Double
  projected_load : Double
  risk : Double
  readiness : Double
  reason_count : Int
  next_review_date : String
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ProgressionDashboard {
  items : Array[ProgressionDashboardItem]
  approved_count : Int
  hold_count : Int
  reduction_count : Int
  pause_count : Int
  referral_count : Int
  average_requested : Double
  average_allowed : Double
  average_risk : Double
  average_readiness : Double
  status : String
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ProgressionDashboardComparison {
  left : ProgressionDashboardItem
  right : ProgressionDashboardItem
  allowed_change_delta : Double
  risk_delta : Double
  readiness_delta : Double
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
fn progression_dashboard_item(
  review : ProgressionReview,
) -> ProgressionDashboardItem {
  {
    date: review.date,
    decision: review.decision,
    requested_change: review.requested_change_percent,
    allowed_change: review.allowed_change_percent,
    current_load: review.current_load,
    projected_load: review.projected_load,
    risk: review.current_risk,
    readiness: review.current_readiness,
    reason_count: review.reasons.length(),
    next_review_date: review.next_review_date,
    status: progression_decision_name(review.decision),
  }
}

///|
fn progression_dashboard_status_value(
  items : Array[ProgressionDashboardItem],
) -> String {
  if items.any(item => item.decision == ProgressionRefer) {
    "refer"
  } else if items.any(item => item.decision == ProgressionPause) {
    "paused"
  } else if items.any(item => item.decision == ProgressionReduce) {
    "reduced"
  } else if items.any(item => item.decision == ProgressionHold) {
    "held"
  } else if items.length() > 0 {
    "approved"
  } else {
    "empty"
  }
}

///|
pub fn build_progression_dashboard(
  reviews : Array[ProgressionReview],
) -> ProgressionDashboard {
  let items = reviews.map(review => progression_dashboard_item(review))
  let status = progression_dashboard_status_value(items)
  {
    items,
    approved_count: reviews
    .filter(review => review.decision == ProgressionApprove)
    .length(),
    hold_count: reviews
    .filter(review => review.decision == ProgressionHold)
    .length(),
    reduction_count: reviews
    .filter(review => review.decision == ProgressionReduce)
    .length(),
    pause_count: reviews
    .filter(review => review.decision == ProgressionPause)
    .length(),
    referral_count: reviews
    .filter(review => review.decision == ProgressionRefer)
    .length(),
    average_requested: mean_load_values(
      reviews.map(review => review.requested_change_percent),
    ),
    average_allowed: mean_load_values(
      reviews.map(review => review.allowed_change_percent),
    ),
    average_risk: mean_load_values(reviews.map(review => review.current_risk)),
    average_readiness: mean_load_values(
      reviews.map(review => review.current_readiness),
    ),
    status,
    recommendation: if status == "refer" {
      "route progression decisions for qualified review"
    } else if status == "paused" {
      "pause progression until blocking evidence is resolved"
    } else if status == "reduced" {
      "keep the reduced load cap"
    } else if status == "held" {
      "collect another observation"
    } else if status == "approved" {
      "continue with the approved cap"
    } else {
      "complete an initial review"
    },
  }
}

///|
pub fn progression_dashboard_for_records(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  requested_change : Double,
) -> ProgressionDashboard {
  let reviews = []
  for record in sort_records_by_date(records) {
    match assess_comprehensive(records, record.date, policy) {
      Some(assessment) =>
        reviews.push(review_progression(assessment, policy, requested_change))
      None => ()
    }
  }
  build_progression_dashboard(reviews)
}

///|
pub fn progression_dashboard_items(
  dashboard : ProgressionDashboard,
) -> Array[ProgressionDashboardItem] {
  dashboard.items
}

///|
pub fn progression_dashboard_latest(
  dashboard : ProgressionDashboard,
) -> ProgressionDashboardItem? {
  if dashboard.items.length() == 0 {
    None
  } else {
    Some(dashboard.items[dashboard.items.length() - 1])
  }
}

///|
pub fn progression_dashboard_first(
  dashboard : ProgressionDashboard,
) -> ProgressionDashboardItem? {
  if dashboard.items.length() == 0 {
    None
  } else {
    Some(dashboard.items[0])
  }
}

///|
pub fn progression_dashboard_count(dashboard : ProgressionDashboard) -> Int {
  dashboard.items.length()
}

///|
pub fn progression_dashboard_dates(
  dashboard : ProgressionDashboard,
) -> Array[String] {
  dashboard.items.map(item => item.date)
}

///|
pub fn progression_dashboard_decisions(
  dashboard : ProgressionDashboard,
) -> Array[String] {
  dashboard.items.map(item => item.status)
}

///|
pub fn progression_dashboard_requested_values(
  dashboard : ProgressionDashboard,
) -> Array[Double] {
  dashboard.items.map(item => item.requested_change)
}

///|
pub fn progression_dashboard_allowed_values(
  dashboard : ProgressionDashboard,
) -> Array[Double] {
  dashboard.items.map(item => item.allowed_change)
}

///|
pub fn progression_dashboard_risk_values(
  dashboard : ProgressionDashboard,
) -> Array[Double] {
  dashboard.items.map(item => item.risk)
}

///|
pub fn progression_dashboard_readiness_values(
  dashboard : ProgressionDashboard,
) -> Array[Double] {
  dashboard.items.map(item => item.readiness)
}

///|
pub fn progression_dashboard_by_decision(
  dashboard : ProgressionDashboard,
  decision : ProgressionDecision,
) -> Array[ProgressionDashboardItem] {
  dashboard.items.filter(item => item.decision == decision)
}

///|
pub fn progression_dashboard_actionable(
  dashboard : ProgressionDashboard,
) -> Array[ProgressionDashboardItem] {
  dashboard.items.filter(item => item.decision != ProgressionApprove)
}

///|
pub fn progression_dashboard_approved(
  dashboard : ProgressionDashboard,
) -> Array[ProgressionDashboardItem] {
  progression_dashboard_by_decision(dashboard, ProgressionApprove)
}

///|
pub fn progression_dashboard_referred(
  dashboard : ProgressionDashboard,
) -> Array[ProgressionDashboardItem] {
  progression_dashboard_by_decision(dashboard, ProgressionRefer)
}

///|
pub fn progression_dashboard_needs_review(
  dashboard : ProgressionDashboard,
) -> Bool {
  dashboard.referral_count > 0 ||
  dashboard.pause_count > 0 ||
  dashboard.hold_count > 0
}

///|
pub fn progression_dashboard_ready(dashboard : ProgressionDashboard) -> Bool {
  dashboard.items.length() > 0 &&
  dashboard.referral_count == 0 &&
  dashboard.pause_count == 0
}

///|
pub fn progression_dashboard_decision_count(
  dashboard : ProgressionDashboard,
  decision : ProgressionDecision,
) -> Int {
  progression_dashboard_by_decision(dashboard, decision).length()
}

///|
pub fn progression_dashboard_average_change(
  dashboard : ProgressionDashboard,
) -> Double {
  dashboard.average_allowed
}

///|
pub fn progression_dashboard_change_gap(
  dashboard : ProgressionDashboard,
) -> Double {
  dashboard.average_requested - dashboard.average_allowed
}

///|
pub fn progression_dashboard_average_risk(
  dashboard : ProgressionDashboard,
) -> Double {
  dashboard.average_risk
}

///|
pub fn progression_dashboard_average_readiness(
  dashboard : ProgressionDashboard,
) -> Double {
  dashboard.average_readiness
}

///|
pub fn progression_dashboard_risk_trend(
  dashboard : ProgressionDashboard,
) -> LoadTrend {
  load_trend(progression_dashboard_risk_values(dashboard), 0.1)
}

///|
pub fn progression_dashboard_readiness_trend(
  dashboard : ProgressionDashboard,
) -> LoadTrend {
  load_trend(progression_dashboard_readiness_values(dashboard), 0.1)
}

///|
pub fn progression_dashboard_valid_item(
  item : ProgressionDashboardItem,
) -> Bool {
  item.date != "" &&
  item.requested_change.is_nan() == false &&
  item.allowed_change.is_nan() == false &&
  item.current_load >= 0.0 &&
  item.projected_load >= 0.0 &&
  item.risk >= 0.0 &&
  item.risk <= 100.0 &&
  item.readiness >= 0.0 &&
  item.readiness <= 100.0 &&
  item.reason_count >= 0 &&
  item.next_review_date != ""
}

///|
pub fn progression_dashboard_valid(dashboard : ProgressionDashboard) -> Bool {
  dashboard.items.all(item => progression_dashboard_valid_item(item)) &&
  dashboard.approved_count >= 0 &&
  dashboard.hold_count >= 0 &&
  dashboard.reduction_count >= 0 &&
  dashboard.pause_count >= 0 &&
  dashboard.referral_count >= 0 &&
  dashboard.average_risk >= 0.0 &&
  dashboard.average_risk <= 100.0 &&
  dashboard.average_readiness >= 0.0 &&
  dashboard.average_readiness <= 100.0
}

///|
pub fn progression_dashboard_item_metric(
  item : ProgressionDashboardItem,
  name : String,
) -> Double {
  match name {
    "requested" => item.requested_change
    "allowed" => item.allowed_change
    "current_load" => item.current_load
    "projected_load" => item.projected_load
    "risk" => item.risk
    "readiness" => item.readiness
    "reasons" => item.reason_count.to_double()
    _ => 0.0
  }
}

///|
pub fn progression_dashboard_metric_names() -> Array[String] {
  [
    "requested", "allowed", "current_load", "projected_load", "risk", "readiness",
    "reasons",
  ]
}

///|
pub fn progression_dashboard_projection(
  dashboard : ProgressionDashboard,
  name : String,
) -> Array[Double] {
  dashboard.items.map(item => progression_dashboard_item_metric(item, name))
}

///|
pub fn progression_dashboard_projection_average(
  dashboard : ProgressionDashboard,
  name : String,
) -> Double {
  mean_load_values(progression_dashboard_projection(dashboard, name))
}

///|
pub fn progression_dashboard_projection_minimum(
  dashboard : ProgressionDashboard,
  name : String,
) -> Double {
  minimum_load_values(progression_dashboard_projection(dashboard, name))
}

///|
pub fn progression_dashboard_projection_maximum(
  dashboard : ProgressionDashboard,
  name : String,
) -> Double {
  maximum_load_values(progression_dashboard_projection(dashboard, name))
}

///|
pub fn progression_dashboard_projection_deviation(
  dashboard : ProgressionDashboard,
  name : String,
) -> Double {
  standard_deviation_values(progression_dashboard_projection(dashboard, name))
}

///|
pub fn progression_dashboard_threshold_count(
  dashboard : ProgressionDashboard,
  name : String,
  threshold : Double,
) -> Int {
  dashboard.items
  .filter(item => progression_dashboard_item_metric(item, name) >= threshold)
  .length()
}

///|
pub fn progression_dashboard_threshold_percent(
  dashboard : ProgressionDashboard,
  name : String,
  threshold : Double,
) -> Double {
  if dashboard.items.length() == 0 {
    0.0
  } else {
    progression_dashboard_threshold_count(dashboard, name, threshold).to_double() /
    dashboard.items.length().to_double() *
    100.0
  }
}

///|
pub fn progression_dashboard_compare(
  left : ProgressionDashboardItem,
  right : ProgressionDashboardItem,
) -> ProgressionDashboardComparison {
  {
    left,
    right,
    allowed_change_delta: right.allowed_change - left.allowed_change,
    risk_delta: right.risk - left.risk,
    readiness_delta: right.readiness - left.readiness,
    conclusion: if right.risk < left.risk && right.readiness > left.readiness {
      "progression evidence improved"
    } else if right.risk > left.risk || right.readiness < left.readiness {
      "progression evidence worsened"
    } else {
      "progression evidence is stable"
    },
  }
}

///|
pub fn progression_dashboard_compare_latest(
  dashboard : ProgressionDashboard,
) -> ProgressionDashboardComparison? {
  if dashboard.items.length() < 2 {
    None
  } else {
    Some(
      progression_dashboard_compare(
        dashboard.items[dashboard.items.length() - 2],
        dashboard.items[dashboard.items.length() - 1],
      ),
    )
  }
}

///|
pub fn progression_dashboard_comparison_text(
  comparison : ProgressionDashboardComparison,
) -> String {
  comparison.left.date +
  " -> " +
  comparison.right.date +
  " allowed_change=" +
  comparison.allowed_change_delta.to_string() +
  " risk=" +
  comparison.risk_delta.to_string() +
  " readiness=" +
  comparison.readiness_delta.to_string() +
  " conclusion=" +
  comparison.conclusion
}

///|
pub fn progression_dashboard_text(dashboard : ProgressionDashboard) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "status=" +
    dashboard.status +
    " items=" +
    dashboard.items.length().to_string() +
    " approved=" +
    dashboard.approved_count.to_string() +
    " hold=" +
    dashboard.hold_count.to_string() +
    " reduce=" +
    dashboard.reduction_count.to_string() +
    " pause=" +
    dashboard.pause_count.to_string() +
    " refer=" +
    dashboard.referral_count.to_string(),
  )
  builder.write_string(
    "\naverage_requested=" +
    dashboard.average_requested.to_string() +
    " average_allowed=" +
    dashboard.average_allowed.to_string() +
    " average_risk=" +
    dashboard.average_risk.to_string() +
    " average_readiness=" +
    dashboard.average_readiness.to_string(),
  )
  builder.write_string("\nrecommendation=" + dashboard.recommendation)
  for item in dashboard.items {
    builder.write_string(
      "\n" +
      item.date +
      " decision=" +
      item.status +
      " requested=" +
      item.requested_change.to_string() +
      " allowed=" +
      item.allowed_change.to_string() +
      " risk=" +
      item.risk.to_string() +
      " readiness=" +
      item.readiness.to_string(),
    )
  }
  builder.to_string()
}

///|
pub fn progression_dashboard_item_text(
  item : ProgressionDashboardItem,
) -> String {
  item.date +
  " decision=" +
  item.status +
  " requested=" +
  item.requested_change.to_string() +
  " allowed=" +
  item.allowed_change.to_string() +
  " current=" +
  item.current_load.to_string() +
  " projected=" +
  item.projected_load.to_string() +
  " risk=" +
  item.risk.to_string() +
  " readiness=" +
  item.readiness.to_string() +
  " reasons=" +
  item.reason_count.to_string() +
  " next_review=" +
  item.next_review_date
}

///|
pub fn progression_dashboard_csv_header() -> String {
  "date,decision,requested_change,allowed_change,current_load,projected_load,risk,readiness,reason_count,next_review_date,status"
}

///|
pub fn progression_dashboard_item_csv(
  item : ProgressionDashboardItem,
) -> String {
  item.date +
  "," +
  item.status +
  "," +
  item.requested_change.to_string() +
  "," +
  item.allowed_change.to_string() +
  "," +
  item.current_load.to_string() +
  "," +
  item.projected_load.to_string() +
  "," +
  item.risk.to_string() +
  "," +
  item.readiness.to_string() +
  "," +
  item.reason_count.to_string() +
  "," +
  item.next_review_date +
  "," +
  item.status
}

///|
pub fn progression_dashboard_csv(dashboard : ProgressionDashboard) -> String {
  let builder = StringBuilder()
  builder.write_string(progression_dashboard_csv_header())
  for item in dashboard.items {
    builder.write_string("\n" + progression_dashboard_item_csv(item))
  }
  builder.to_string()
}

///|
pub fn progression_dashboard_summary_header() -> Array[String] {
  [
    "status", "count", "approved", "hold", "reduce", "pause", "refer", "average_requested",
    "average_allowed", "average_risk", "average_readiness",
  ]
}

///|
pub fn progression_dashboard_summary(
  dashboard : ProgressionDashboard,
) -> Array[String] {
  [
    dashboard.status,
    dashboard.items.length().to_string(),
    dashboard.approved_count.to_string(),
    dashboard.hold_count.to_string(),
    dashboard.reduction_count.to_string(),
    dashboard.pause_count.to_string(),
    dashboard.referral_count.to_string(),
    dashboard.average_requested.to_string(),
    dashboard.average_allowed.to_string(),
    dashboard.average_risk.to_string(),
    dashboard.average_readiness.to_string(),
  ]
}

///|
pub fn progression_dashboard_summary_csv(
  dashboard : ProgressionDashboard,
) -> String {
  progression_dashboard_summary_header().join(",") +
  "\n" +
  progression_dashboard_summary(dashboard).join(",")
}

///|
pub fn progression_dashboard_checksum(
  dashboard : ProgressionDashboard,
) -> String {
  let mut value = dashboard.items.length()
  for character in progression_dashboard_text(dashboard) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn progression_dashboard_recommendation(
  dashboard : ProgressionDashboard,
) -> String {
  dashboard.recommendation
}

///|
pub fn progression_dashboard_status(dashboard : ProgressionDashboard) -> String {
  dashboard.status
}

///|
pub fn progression_dashboard_exportable(
  dashboard : ProgressionDashboard,
) -> Bool {
  progression_dashboard_valid(dashboard)
}

///|
pub fn progression_dashboard_export_status(
  dashboard : ProgressionDashboard,
) -> String {
  if progression_dashboard_exportable(dashboard) {
    "exportable"
  } else {
    "blocked"
  }
}

///|
pub fn progression_dashboard_contract(
  dashboard : ProgressionDashboard,
) -> Array[String] {
  [
    dashboard.status,
    dashboard.items.length().to_string(),
    progression_dashboard_needs_review(dashboard).to_string(),
    progression_dashboard_export_status(dashboard),
    progression_dashboard_checksum(dashboard),
  ]
}
