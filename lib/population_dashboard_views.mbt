///|
/// Population dashboard views support safe cohort-level triage.
pub(all) struct PopulationDashboardCard {
  metric : PopulationMetric
  name : String
  average : Double
  minimum : Double
  maximum : Double
  percentile25 : Double
  percentile75 : Double
  action_count : Int
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PopulationDashboard {
  rows : Array[PopulationRow]
  summary : PopulationSummary
  cards : Array[PopulationDashboardCard]
  outlier_count : Int
  action_count : Int
  ready_count : Int
  status : String
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PopulationDashboardComparison {
  left_athletes : Int
  right_athletes : Int
  athlete_change : Int
  risk_change : Double
  readiness_change : Double
  coverage_change : Double
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
fn population_dashboard_card(
  rows : Array[PopulationRow],
  metric : PopulationMetric,
) -> PopulationDashboardCard {
  let values = population_metric_values(rows, metric)
  let average = mean_load_values(values)
  let minimum = minimum_load_values(values)
  let maximum = maximum_load_values(values)
  let action = rows
    .filter(row => {
      population_metric_value(row, metric) >= quantile(values, 0.75)
    })
    .length()
  {
    metric,
    name: population_metric_name(metric),
    average,
    minimum,
    maximum,
    percentile25: quantile(values, 0.25),
    percentile75: quantile(values, 0.75),
    action_count: action,
    status: if rows.length() == 0 {
      "empty"
    } else if action > rows.length() / 2 {
      "watch"
    } else {
      "stable"
    },
  }
}

///|
pub fn build_population_dashboard(
  rows : Array[PopulationRow],
) -> PopulationDashboard {
  let cards = population_metrics().map(metric => {
    population_dashboard_card(rows, metric)
  })
  let summary = summarize_population(rows)
  let outliers = all_population_outliers(rows, 2.0)
  let actions = population_action_ids(rows)
  let ready = population_ready_ids(rows)
  {
    rows,
    summary,
    cards,
    outlier_count: outliers.length(),
    action_count: actions.length(),
    ready_count: ready.length(),
    status: if rows.length() == 0 {
      "empty"
    } else if actions.length() > 0 {
      "review"
    } else {
      "stable"
    },
    recommendation: if actions.length() > 0 {
      "triage action rows and inspect outliers"
    } else {
      "continue cohort monitoring"
    },
  }
}

///|
pub fn population_dashboard_for_cohort(
  cohort : Array[AthleteSeries],
  policy : RiskPolicy,
) -> PopulationDashboard {
  build_population_dashboard(population_rows(cohort, policy))
}

///|
pub fn population_dashboard_card_by_metric(
  dashboard : PopulationDashboard,
  metric : PopulationMetric,
) -> PopulationDashboardCard? {
  for card in dashboard.cards {
    if card.metric == metric {
      return Some(card)
    }
  }
  None
}

///|
pub fn population_dashboard_card_by_name(
  dashboard : PopulationDashboard,
  name : String,
) -> PopulationDashboardCard? {
  for card in dashboard.cards {
    if card.name == name {
      return Some(card)
    }
  }
  None
}

///|
pub fn population_dashboard_cards(
  dashboard : PopulationDashboard,
) -> Array[PopulationDashboardCard] {
  dashboard.cards
}

///|
pub fn population_dashboard_rows(
  dashboard : PopulationDashboard,
) -> Array[PopulationRow] {
  dashboard.rows
}

///|
pub fn population_dashboard_athlete_ids(
  dashboard : PopulationDashboard,
) -> Array[String] {
  dashboard.rows.map(row => row.athlete_id)
}

///|
pub fn population_dashboard_actions(
  dashboard : PopulationDashboard,
) -> Array[String] {
  population_action_ids(dashboard.rows)
}

///|
pub fn population_dashboard_ready(
  dashboard : PopulationDashboard,
) -> Array[String] {
  population_ready_ids(dashboard.rows)
}

///|
pub fn population_dashboard_outliers(
  dashboard : PopulationDashboard,
) -> Array[PopulationOutlier] {
  all_population_outliers(dashboard.rows, 2.0)
}

///|
pub fn population_dashboard_card_values(
  dashboard : PopulationDashboard,
  metric : PopulationMetric,
) -> Array[Double] {
  population_metric_values(dashboard.rows, metric)
}

///|
pub fn population_dashboard_average(
  dashboard : PopulationDashboard,
  metric : PopulationMetric,
) -> Double {
  mean_load_values(population_dashboard_card_values(dashboard, metric))
}

///|
pub fn population_dashboard_minimum(
  dashboard : PopulationDashboard,
  metric : PopulationMetric,
) -> Double {
  minimum_load_values(population_dashboard_card_values(dashboard, metric))
}

///|
pub fn population_dashboard_maximum(
  dashboard : PopulationDashboard,
  metric : PopulationMetric,
) -> Double {
  maximum_load_values(population_dashboard_card_values(dashboard, metric))
}

///|
pub fn population_dashboard_percentile(
  dashboard : PopulationDashboard,
  metric : PopulationMetric,
  percentile : Double,
) -> Double {
  quantile(population_dashboard_card_values(dashboard, metric), percentile)
}

///|
pub fn population_dashboard_range(
  dashboard : PopulationDashboard,
  metric : PopulationMetric,
) -> Double {
  population_dashboard_maximum(dashboard, metric) -
  population_dashboard_minimum(dashboard, metric)
}

///|
pub fn population_dashboard_deviation(
  dashboard : PopulationDashboard,
  metric : PopulationMetric,
) -> Double {
  standard_deviation_values(population_dashboard_card_values(dashboard, metric))
}

///|
pub fn population_dashboard_athlete_count(
  dashboard : PopulationDashboard,
) -> Int {
  dashboard.summary.athlete_count
}

///|
pub fn population_dashboard_sample_count(
  dashboard : PopulationDashboard,
) -> Int {
  dashboard.summary.sample_count
}

///|
pub fn population_dashboard_high_risk_count(
  dashboard : PopulationDashboard,
) -> Int {
  dashboard.summary.high_risk_count
}

///|
pub fn population_dashboard_medium_risk_count(
  dashboard : PopulationDashboard,
) -> Int {
  dashboard.summary.medium_risk_count
}

///|
pub fn population_dashboard_low_risk_count(
  dashboard : PopulationDashboard,
) -> Int {
  dashboard.summary.low_risk_count
}

///|
pub fn population_dashboard_mean_risk(
  dashboard : PopulationDashboard,
) -> Double {
  dashboard.summary.mean_risk
}

///|
pub fn population_dashboard_mean_readiness(
  dashboard : PopulationDashboard,
) -> Double {
  dashboard.summary.mean_readiness
}

///|
pub fn population_dashboard_mean_recovery(
  dashboard : PopulationDashboard,
) -> Double {
  dashboard.summary.mean_recovery
}

///|
pub fn population_dashboard_mean_quality(
  dashboard : PopulationDashboard,
) -> Double {
  dashboard.summary.mean_quality
}

///|
pub fn population_dashboard_coverage(dashboard : PopulationDashboard) -> Double {
  dashboard.summary.coverage_percent
}

///|
pub fn population_dashboard_status(dashboard : PopulationDashboard) -> String {
  dashboard.status
}

///|
pub fn population_dashboard_requires_review(
  dashboard : PopulationDashboard,
) -> Bool {
  dashboard.action_count > 0 || dashboard.outlier_count > 0
}

///|
pub fn population_dashboard_is_stable(dashboard : PopulationDashboard) -> Bool {
  dashboard.status == "stable"
}

///|
pub fn population_dashboard_valid_card(card : PopulationDashboardCard) -> Bool {
  card.name != "" &&
  card.average >= 0.0 &&
  card.minimum >= 0.0 &&
  card.maximum >= card.minimum &&
  card.percentile25 >= card.minimum &&
  card.percentile75 <= card.maximum &&
  card.action_count >= 0
}

///|
pub fn population_dashboard_valid(dashboard : PopulationDashboard) -> Bool {
  dashboard.rows.all(row => {
    row.athlete_id != "" &&
    row.sample_count >= 0 &&
    row.risk_score >= 0.0 &&
    row.risk_score <= 100.0 &&
    row.readiness_score >= 0.0 &&
    row.readiness_score <= 100.0
  }) &&
  dashboard.cards.all(card => population_dashboard_valid_card(card)) &&
  dashboard.action_count >= 0 &&
  dashboard.ready_count >= 0
}

///|
pub fn population_dashboard_metric_names() -> Array[String] {
  population_metrics().map(metric => population_metric_name(metric))
}

///|
pub fn population_dashboard_metric(
  metric_name : String,
  dashboard : PopulationDashboard,
) -> Double {
  match population_dashboard_card_by_name(dashboard, metric_name) {
    Some(card) => card.average
    None => 0.0
  }
}

///|
pub fn population_dashboard_action_percent(
  dashboard : PopulationDashboard,
) -> Double {
  if dashboard.rows.length() == 0 {
    0.0
  } else {
    dashboard.action_count.to_double() /
    dashboard.rows.length().to_double() *
    100.0
  }
}

///|
pub fn population_dashboard_ready_percent(
  dashboard : PopulationDashboard,
) -> Double {
  if dashboard.rows.length() == 0 {
    0.0
  } else {
    dashboard.ready_count.to_double() /
    dashboard.rows.length().to_double() *
    100.0
  }
}

///|
pub fn population_dashboard_outlier_percent(
  dashboard : PopulationDashboard,
) -> Double {
  if dashboard.rows.length() == 0 {
    0.0
  } else {
    dashboard.outlier_count.to_double() /
    dashboard.rows.length().to_double() *
    100.0
  }
}

///|
pub fn population_dashboard_risk_trend(
  left : PopulationDashboard,
  right : PopulationDashboard,
) -> TrendDirection {
  if right.summary.mean_risk < left.summary.mean_risk {
    Improving
  } else if right.summary.mean_risk > left.summary.mean_risk {
    Worsening
  } else {
    Stable
  }
}

///|
pub fn population_dashboard_compare(
  left : PopulationDashboard,
  right : PopulationDashboard,
) -> PopulationDashboardComparison {
  {
    left_athletes: left.summary.athlete_count,
    right_athletes: right.summary.athlete_count,
    athlete_change: right.summary.athlete_count - left.summary.athlete_count,
    risk_change: right.summary.mean_risk - left.summary.mean_risk,
    readiness_change: right.summary.mean_readiness - left.summary.mean_readiness,
    coverage_change: right.summary.coverage_percent -
    left.summary.coverage_percent,
    conclusion: if right.summary.mean_risk < left.summary.mean_risk &&
      right.summary.mean_readiness > left.summary.mean_readiness {
      "cohort readiness improved"
    } else if right.summary.mean_risk > left.summary.mean_risk {
      "cohort risk increased"
    } else {
      "cohort changes are mixed"
    },
  }
}

///|
pub fn population_dashboard_comparison_text(
  comparison : PopulationDashboardComparison,
) -> String {
  "athletes=" +
  comparison.left_athletes.to_string() +
  " -> " +
  comparison.right_athletes.to_string() +
  " risk_change=" +
  comparison.risk_change.to_string() +
  " readiness_change=" +
  comparison.readiness_change.to_string() +
  " coverage_change=" +
  comparison.coverage_change.to_string() +
  " conclusion=" +
  comparison.conclusion
}

///|
pub fn population_dashboard_text(dashboard : PopulationDashboard) -> String {
  "status=" +
  dashboard.status +
  " athletes=" +
  dashboard.summary.athlete_count.to_string() +
  " actions=" +
  dashboard.action_count.to_string() +
  " outliers=" +
  dashboard.outlier_count.to_string() +
  " ready=" +
  dashboard.ready_count.to_string() +
  " mean_risk=" +
  dashboard.summary.mean_risk.to_string() +
  " mean_readiness=" +
  dashboard.summary.mean_readiness.to_string() +
  " coverage=" +
  dashboard.summary.coverage_percent.to_string() +
  " recommendation=" +
  dashboard.recommendation
}

///|
pub fn population_dashboard_card_text(card : PopulationDashboardCard) -> String {
  card.name +
  " average=" +
  card.average.to_string() +
  " range=" +
  card.minimum.to_string() +
  ".." +
  card.maximum.to_string() +
  " p25=" +
  card.percentile25.to_string() +
  " p75=" +
  card.percentile75.to_string() +
  " actions=" +
  card.action_count.to_string() +
  " status=" +
  card.status
}

///|
pub fn population_dashboard_cards_text(
  dashboard : PopulationDashboard,
) -> String {
  dashboard.cards.map(card => population_dashboard_card_text(card)).join("\n")
}

///|
pub fn population_dashboard_summary_header() -> Array[String] {
  [
    "status", "athletes", "samples", "high_risk", "medium_risk", "low_risk", "mean_risk",
    "mean_readiness", "mean_recovery", "mean_quality", "coverage", "actions", "outliers",
    "ready",
  ]
}

///|
pub fn population_dashboard_summary(
  dashboard : PopulationDashboard,
) -> Array[String] {
  [
    dashboard.status,
    dashboard.summary.athlete_count.to_string(),
    dashboard.summary.sample_count.to_string(),
    dashboard.summary.high_risk_count.to_string(),
    dashboard.summary.medium_risk_count.to_string(),
    dashboard.summary.low_risk_count.to_string(),
    dashboard.summary.mean_risk.to_string(),
    dashboard.summary.mean_readiness.to_string(),
    dashboard.summary.mean_recovery.to_string(),
    dashboard.summary.mean_quality.to_string(),
    dashboard.summary.coverage_percent.to_string(),
    dashboard.action_count.to_string(),
    dashboard.outlier_count.to_string(),
    dashboard.ready_count.to_string(),
  ]
}

///|
pub fn population_dashboard_summary_csv(
  dashboard : PopulationDashboard,
) -> String {
  population_dashboard_summary_header().join(",") +
  "\n" +
  population_dashboard_summary(dashboard).join(",")
}

///|
pub fn population_dashboard_checksum(dashboard : PopulationDashboard) -> String {
  let mut value = dashboard.rows.length() + dashboard.cards.length()
  for character in population_dashboard_text(dashboard) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn population_dashboard_reproducible(
  left : PopulationDashboard,
  right : PopulationDashboard,
) -> Bool {
  population_dashboard_checksum(left) == population_dashboard_checksum(right)
}

///|
pub fn population_dashboard_recommendation(
  dashboard : PopulationDashboard,
) -> String {
  dashboard.recommendation
}

///|
pub fn population_dashboard_exportable(dashboard : PopulationDashboard) -> Bool {
  population_dashboard_valid(dashboard)
}

///|
pub fn population_dashboard_export_status(
  dashboard : PopulationDashboard,
) -> String {
  if population_dashboard_exportable(dashboard) {
    "exportable"
  } else {
    "blocked"
  }
}

///|
pub fn population_dashboard_contract(
  dashboard : PopulationDashboard,
) -> Array[String] {
  [
    dashboard.status,
    dashboard.summary.athlete_count.to_string(),
    population_dashboard_action_percent(dashboard).to_string(),
    population_dashboard_ready_percent(dashboard).to_string(),
    population_dashboard_outlier_percent(dashboard).to_string(),
    population_dashboard_recommendation(dashboard),
    population_dashboard_export_status(dashboard),
    population_dashboard_checksum(dashboard),
  ]
}
