///|
/// A compact row for batch export and dashboard summaries.
pub(all) struct BatchRow {
  date : String
  risk_level : RiskLevel
  risk_score : Double
  readiness_score : Double
  load : Double
  acwr : Double
  recovery : Double
  quality : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct BatchReport {
  start_date : String
  end_date : String
  row_count : Int
  high_risk_rows : Int
  average_risk : Double
  average_readiness : Double
  average_load : Double
  average_recovery : Double
  rows : Array[BatchRow]
} derive(Debug, Eq, ToJson)

///|
pub fn batch_row(assessment : ComprehensiveAssessment) -> BatchRow {
  {
    date: assessment.date,
    risk_level: assessment.risk_level,
    risk_score: assessment.risk_score,
    readiness_score: assessment.readiness_score,
    load: assessment.load.average_load,
    acwr: assessment.load.acwr,
    recovery: assessment.recovery.recovery_score,
    quality: assessment.quality.score,
  }
}

///|
pub fn assess_dates(
  records : Array[DailyRecord],
  dates : Array[String],
  policy : RiskPolicy,
) -> Array[BatchRow] {
  let rows = []
  for date in dates {
    match assess_comprehensive(records, date, policy) {
      Some(assessment) => rows.push(batch_row(assessment))
      None => ()
    }
  }
  rows
}

///|
pub fn assess_every_record(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> Array[BatchRow] {
  let sorted = sort_records_by_date(records)
  assess_dates(sorted, sorted.map(record => record.date), policy)
}

///|
pub fn build_batch_report(rows : Array[BatchRow]) -> BatchReport {
  let sorted = rows.copy()
  let first = if sorted.length() == 0 { "" } else { sorted[0].date }
  let last = if sorted.length() == 0 {
    ""
  } else {
    sorted[sorted.length() - 1].date
  }
  let high = sorted.filter(row => row.risk_level == High).length()
  {
    start_date: first,
    end_date: last,
    row_count: sorted.length(),
    high_risk_rows: high,
    average_risk: mean_load_values(sorted.map(row => row.risk_score)),
    average_readiness: mean_load_values(sorted.map(row => row.readiness_score)),
    average_load: mean_load_values(sorted.map(row => row.load)),
    average_recovery: mean_load_values(sorted.map(row => row.recovery)),
    rows: sorted,
  }
}

///|
pub fn batch_report_for_records(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> BatchReport {
  build_batch_report(assess_every_record(records, policy))
}

///|
pub fn batch_rows_in_range(
  rows : Array[BatchRow],
  range : DateRange,
) -> Array[BatchRow] {
  rows.filter(row => {
    match parse_date(row.date) {
      Some(date) => date_is_in_range(date, range)
      None => false
    }
  })
}

///|
pub fn batch_high_risk_dates(rows : Array[BatchRow]) -> Array[String] {
  rows.filter(row => row.risk_level == High).map(row => row.date)
}

///|
pub fn batch_readiness_below(
  rows : Array[BatchRow],
  threshold : Double,
) -> Array[BatchRow] {
  rows.filter(row => row.readiness_score < threshold)
}

///|
pub fn batch_average_by_risk(
  rows : Array[BatchRow],
  level : RiskLevel,
) -> Double {
  mean_load_values(
    rows.filter(row => row.risk_level == level).map(row => row.risk_score),
  )
}

///|
pub fn batch_report_text(report : BatchReport) -> String {
  "range=" +
  report.start_date +
  ".." +
  report.end_date +
  " rows=" +
  report.row_count.to_string() +
  " high_risk=" +
  report.high_risk_rows.to_string() +
  " average_risk=" +
  report.average_risk.to_string() +
  " average_readiness=" +
  report.average_readiness.to_string() +
  " average_load=" +
  report.average_load.to_string()
}

///|
pub fn batch_row_csv(row : BatchRow) -> String {
  row.date +
  "," +
  risk_level_name(row.risk_level) +
  "," +
  row.risk_score.to_string() +
  "," +
  row.readiness_score.to_string() +
  "," +
  row.load.to_string() +
  "," +
  row.acwr.to_string() +
  "," +
  row.recovery.to_string() +
  "," +
  row.quality.to_string()
}

///|
pub fn batch_report_csv(report : BatchReport) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "date,risk_level,risk_score,readiness_score,load,acwr,recovery,quality\n",
  )
  for row in report.rows {
    builder.write_string(batch_row_csv(row))
    builder.write_string("\n")
  }
  builder.to_string()
}
