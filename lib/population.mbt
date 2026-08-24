///|
/// Metrics used for cohort-level operational comparison.
pub(all) enum PopulationMetric {
  PopulationRisk
  PopulationReadiness
  PopulationLoad
  PopulationRecovery
  PopulationPain
  PopulationSleep
  PopulationFatigue
  PopulationQuality
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PopulationRow {
  athlete_id : String
  sample_count : Int
  risk_score : Double
  readiness_score : Double
  load : Double
  recovery : Double
  pain : Double
  sleep_hours : Double
  fatigue : Double
  quality : Double
  risk_level : RiskLevel
  coverage_percent : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PopulationSummary {
  athlete_count : Int
  sample_count : Int
  high_risk_count : Int
  medium_risk_count : Int
  low_risk_count : Int
  mean_risk : Double
  median_risk : Double
  mean_readiness : Double
  mean_load : Double
  mean_recovery : Double
  mean_pain : Double
  mean_sleep : Double
  mean_fatigue : Double
  mean_quality : Double
  coverage_percent : Double
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PopulationOutlier {
  athlete_id : String
  metric : PopulationMetric
  value : Double
  population_center : Double
  deviation : Double
  direction : String
  priority : RiskEventPriority
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PopulationCoverage {
  athlete_id : String
  expected_days : Int
  observed_days : Int
  missing_days : Int
  duplicate_days : Int
  completeness_percent : Double
  usable : Bool
} derive(Debug, Eq, ToJson)

///|
pub fn population_metric_name(metric : PopulationMetric) -> String {
  match metric {
    PopulationRisk => "risk"
    PopulationReadiness => "readiness"
    PopulationLoad => "load"
    PopulationRecovery => "recovery"
    PopulationPain => "pain"
    PopulationSleep => "sleep"
    PopulationFatigue => "fatigue"
    PopulationQuality => "quality"
  }
}

///|
fn assessment_for_series(
  series : AthleteSeries,
  policy : RiskPolicy,
) -> ComprehensiveAssessment? {
  assess_latest(series.records, policy)
}

///|
fn population_row(series : AthleteSeries, policy : RiskPolicy) -> PopulationRow {
  let assessment = assessment_for_series(series, policy)
  match assessment {
    Some(assessment) =>
      {
        athlete_id: series.athlete_id,
        sample_count: series.records.length(),
        risk_score: assessment.risk_score,
        readiness_score: assessment.readiness_score,
        load: assessment.load.average_load,
        recovery: assessment.recovery.recovery_score,
        pain: max_pain_level(series.records),
        sleep_hours: mean_load_values(
          series.records.map(record => record.sleep_hours),
        ),
        fatigue: mean_load_values(series.records.map(record => record.fatigue)),
        quality: assessment.quality.score,
        risk_level: assessment.risk_level,
        coverage_percent: completeness_ratio(series.records) * 100.0,
      }
    None =>
      {
        athlete_id: series.athlete_id,
        sample_count: series.records.length(),
        risk_score: 0.0,
        readiness_score: 0.0,
        load: 0.0,
        recovery: 0.0,
        pain: max_pain_level(series.records),
        sleep_hours: mean_load_values(
          series.records.map(record => record.sleep_hours),
        ),
        fatigue: mean_load_values(series.records.map(record => record.fatigue)),
        quality: 0.0,
        risk_level: High,
        coverage_percent: completeness_ratio(series.records) * 100.0,
      }
  }
}

///|
pub fn population_rows(
  cohort : Array[AthleteSeries],
  policy : RiskPolicy,
) -> Array[PopulationRow] {
  cohort.map(series => population_row(series, policy))
}

///|
fn population_median(values : Array[Double]) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let sorted = values.copy()
  sorted.sort()
  sorted[sorted.length() / 2]
}

///|
fn population_status(rows : Array[PopulationRow]) -> String {
  if rows.length() == 0 {
    "empty"
  } else if rows.filter(row => row.risk_level == High).length().to_double() /
    rows.length().to_double() >=
    0.25 {
    "high_attention"
  } else if rows.filter(row => row.coverage_percent < 80.0).length() > 0 {
    "coverage_review"
  } else {
    "operational"
  }
}

///|
pub fn summarize_population(rows : Array[PopulationRow]) -> PopulationSummary {
  let risk = rows.map(row => row.risk_score)
  let readiness = rows.map(row => row.readiness_score)
  let load = rows.map(row => row.load)
  let recovery = rows.map(row => row.recovery)
  let pain = rows.map(row => row.pain)
  let sleep = rows.map(row => row.sleep_hours)
  let fatigue = rows.map(row => row.fatigue)
  let quality = rows.map(row => row.quality)
  let sample = rows.fold(init=0, (total, row) => total + row.sample_count)
  let coverage = rows.fold(init=0.0, (total, row) => {
    total + row.coverage_percent
  })
  {
    athlete_count: rows.length(),
    sample_count: sample,
    high_risk_count: rows.filter(row => row.risk_level == High).length(),
    medium_risk_count: rows.filter(row => row.risk_level == Medium).length(),
    low_risk_count: rows.filter(row => row.risk_level == Low).length(),
    mean_risk: mean_load_values(risk),
    median_risk: population_median(risk),
    mean_readiness: mean_load_values(readiness),
    mean_load: mean_load_values(load),
    mean_recovery: mean_load_values(recovery),
    mean_pain: mean_load_values(pain),
    mean_sleep: mean_load_values(sleep),
    mean_fatigue: mean_load_values(fatigue),
    mean_quality: mean_load_values(quality),
    coverage_percent: if rows.length() == 0 {
      0.0
    } else {
      coverage / rows.length().to_double()
    },
    status: population_status(rows),
  }
}

///|
pub fn summarize_population_series(
  cohort : Array[AthleteSeries],
  policy : RiskPolicy,
) -> PopulationSummary {
  summarize_population(population_rows(cohort, policy))
}

///|
pub fn population_metric_value(
  row : PopulationRow,
  metric : PopulationMetric,
) -> Double {
  match metric {
    PopulationRisk => row.risk_score
    PopulationReadiness => row.readiness_score
    PopulationLoad => row.load
    PopulationRecovery => row.recovery
    PopulationPain => row.pain
    PopulationSleep => row.sleep_hours
    PopulationFatigue => row.fatigue
    PopulationQuality => row.quality
  }
}

///|
fn population_metric_values(
  rows : Array[PopulationRow],
  metric : PopulationMetric,
) -> Array[Double] {
  rows.map(row => population_metric_value(row, metric))
}

///|
fn outlier_priority(
  deviation : Double,
  metric : PopulationMetric,
  value : Double,
) -> RiskEventPriority {
  if metric == PopulationPain ||
    metric == PopulationRisk ||
    metric == PopulationFatigue {
    if deviation >= 2.0 || value >= 70.0 {
      Critical
    } else if deviation >= 1.0 {
      Urgent
    } else {
      Important
    }
  } else if deviation >= 2.0 {
    Urgent
  } else {
    Important
  }
}

///|
pub fn population_outliers(
  rows : Array[PopulationRow],
  metric : PopulationMetric,
  z_threshold : Double,
) -> Array[PopulationOutlier] {
  let values = population_metric_values(rows, metric)
  let center = mean_load_values(values)
  let stddev = standard_deviation_values(values)
  let outliers = []
  if stddev == 0.0 {
    return outliers
  }
  for row in rows {
    let value = population_metric_value(row, metric)
    let deviation = (value - center) / stddev
    if deviation.abs() >= z_threshold.abs() {
      outliers.push({
        athlete_id: row.athlete_id,
        metric,
        value,
        population_center: center,
        deviation,
        direction: if deviation > 0.0 {
          "above"
        } else {
          "below"
        },
        priority: outlier_priority(deviation.abs(), metric, value),
      })
    }
  }
  outliers
}

///|
pub fn all_population_outliers(
  rows : Array[PopulationRow],
  z_threshold : Double,
) -> Array[PopulationOutlier] {
  let output = []
  for metric in population_metrics() {
    for item in population_outliers(rows, metric, z_threshold) {
      output.push(item)
    }
  }
  output
}

///|
pub fn population_metrics() -> Array[PopulationMetric] {
  [
    PopulationRisk,
    PopulationReadiness,
    PopulationLoad,
    PopulationRecovery,
    PopulationPain,
    PopulationSleep,
    PopulationFatigue,
    PopulationQuality,
  ]
}

///|
pub fn sort_population_by_metric(
  rows : Array[PopulationRow],
  metric : PopulationMetric,
) -> Array[PopulationRow] {
  let sorted = rows.copy()
  for i in 1..<sorted.length() {
    let current = sorted[i]
    let mut cursor = i
    while cursor > 0 &&
          population_metric_value(sorted[cursor - 1], metric) <
          population_metric_value(current, metric) {
      sorted[cursor] = sorted[cursor - 1]
      cursor -= 1
    }
    sorted[cursor] = current
  }
  sorted
}

///|
fn population_limit(
  rows : Array[PopulationRow],
  limit : Int,
) -> Array[PopulationRow] {
  let output = []
  let count = limit.min(rows.length()).max(0)
  for index in 0..<count {
    output.push(rows[index])
  }
  output
}

///|
fn population_reverse(rows : Array[PopulationRow]) -> Array[PopulationRow] {
  let output = []
  for index in 0..<rows.length() {
    output.push(rows[rows.length() - index - 1])
  }
  output
}

///|
pub fn highest_population_risk(
  rows : Array[PopulationRow],
  limit : Int,
) -> Array[PopulationRow] {
  population_limit(sort_population_by_metric(rows, PopulationRisk), limit)
}

///|
pub fn lowest_population_readiness(
  rows : Array[PopulationRow],
  limit : Int,
) -> Array[PopulationRow] {
  let sorted = sort_population_by_metric(rows, PopulationReadiness)
  let reversed = population_reverse(sorted)
  population_limit(reversed, limit)
}

///|
pub fn population_risk_band(
  rows : Array[PopulationRow],
  minimum : Double,
) -> Array[PopulationRow] {
  rows.filter(row => row.risk_score >= minimum)
}

///|
pub fn population_coverage(
  rows : Array[PopulationRow],
  expected_days : Int,
) -> Array[PopulationCoverage] {
  rows.map(row => {
    let observed = row.sample_count
    let missing = (expected_days - observed).max(0)
    {
      athlete_id: row.athlete_id,
      expected_days,
      observed_days: observed,
      missing_days: missing,
      duplicate_days: 0,
      completeness_percent: if expected_days <= 0 {
        0.0
      } else {
        observed.to_double() / expected_days.to_double() * 100.0
      },
      usable: observed > 0 && row.coverage_percent >= 80.0,
    }
  })
}

///|
pub fn population_coverage_with_records(
  cohort : Array[AthleteSeries],
  expected_days : Int,
) -> Array[PopulationCoverage] {
  cohort.map(series => {
    let report = validate_records(series.records, default_quality_policy())
    let missing = report.missing_date_count
    let observed = series.records.length()
    {
      athlete_id: series.athlete_id,
      expected_days,
      observed_days: observed,
      missing_days: missing,
      duplicate_days: report.duplicate_date_count,
      completeness_percent: if expected_days <= 0 {
        0.0
      } else {
        (observed - report.duplicate_date_count).max(0).to_double() /
        expected_days.to_double() *
        100.0
      },
      usable: report.blocking_issue_count == 0 && observed > 0,
    }
  })
}

///|
pub fn population_action_ids(rows : Array[PopulationRow]) -> Array[String] {
  rows
  .filter(row => {
    row.risk_level == High ||
    row.readiness_score < 60.0 ||
    row.coverage_percent < 60.0
  })
  .map(row => row.athlete_id)
}

///|
pub fn population_ready_ids(rows : Array[PopulationRow]) -> Array[String] {
  rows
  .filter(row => {
    row.risk_level == Low &&
    row.readiness_score >= 80.0 &&
    row.coverage_percent >= 80.0
  })
  .map(row => row.athlete_id)
}

///|
pub fn population_metric_percentile(
  rows : Array[PopulationRow],
  metric : PopulationMetric,
  percentile : Double,
) -> Double {
  quantile(population_metric_values(rows, metric), percentile)
}

///|
pub fn population_metric_range(
  rows : Array[PopulationRow],
  metric : PopulationMetric,
) -> Array[Double] {
  let values = population_metric_values(rows, metric)
  [minimum_load_values(values), maximum_load_values(values)]
}

///|
pub fn population_summary_text(summary : PopulationSummary) -> String {
  "status=" +
  summary.status +
  " athletes=" +
  summary.athlete_count.to_string() +
  " samples=" +
  summary.sample_count.to_string() +
  " high=" +
  summary.high_risk_count.to_string() +
  " medium=" +
  summary.medium_risk_count.to_string() +
  " low=" +
  summary.low_risk_count.to_string() +
  " mean_risk=" +
  summary.mean_risk.to_string() +
  " mean_readiness=" +
  summary.mean_readiness.to_string() +
  " coverage=" +
  summary.coverage_percent.to_string() +
  "%"
}

///|
pub fn population_row_csv_header() -> String {
  "athlete_id,sample_count,risk_score,readiness_score,load,recovery,pain,sleep_hours,fatigue,quality,risk_level,coverage_percent"
}

///|
pub fn population_row_csv(row : PopulationRow) -> String {
  row.athlete_id +
  "," +
  row.sample_count.to_string() +
  "," +
  row.risk_score.to_string() +
  "," +
  row.readiness_score.to_string() +
  "," +
  row.load.to_string() +
  "," +
  row.recovery.to_string() +
  "," +
  row.pain.to_string() +
  "," +
  row.sleep_hours.to_string() +
  "," +
  row.fatigue.to_string() +
  "," +
  row.quality.to_string() +
  "," +
  risk_level_name(row.risk_level) +
  "," +
  row.coverage_percent.to_string()
}

///|
pub fn population_rows_csv(rows : Array[PopulationRow]) -> String {
  let builder = StringBuilder()
  builder.write_string(population_row_csv_header())
  for row in rows {
    builder.write_string("\n")
    builder.write_string(population_row_csv(row))
  }
  builder.to_string()
}

///|
pub fn population_outlier_text(outlier : PopulationOutlier) -> String {
  outlier.athlete_id +
  " metric=" +
  population_metric_name(outlier.metric) +
  " value=" +
  outlier.value.to_string() +
  " center=" +
  outlier.population_center.to_string() +
  " deviation=" +
  outlier.deviation.to_string() +
  " priority=" +
  risk_event_priority_name(outlier.priority)
}

///|
pub fn population_outlier_ids(
  outliers : Array[PopulationOutlier],
  priority : RiskEventPriority,
) -> Array[String] {
  outliers
  .filter(item => item.priority == priority)
  .map(item => item.athlete_id)
}

///|
pub fn population_data_quality(rows : Array[PopulationRow]) -> String {
  if rows.length() == 0 {
    "empty"
  } else if rows.any(row => row.coverage_percent < 50.0) {
    "poor"
  } else if rows.any(row => row.coverage_percent < 80.0) {
    "review"
  } else {
    "good"
  }
}
