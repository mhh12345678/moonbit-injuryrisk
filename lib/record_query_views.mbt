///|
/// Record queries let integrations select a defensible subset before assessment.
pub(all) struct RecordQuery {
  start_date : String?
  end_date : String?
  minimum_load : Double?
  maximum_load : Double?
  minimum_sleep : Double?
  maximum_pain : Double?
  require_training : Bool
  require_pain : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RecordQueryResult {
  query : RecordQuery
  records : Array[DailyRecord]
  input_count : Int
  matched_count : Int
  rejected_count : Int
  status : String
  explanation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RecordQueryStats {
  result : RecordQueryResult
  average_load : Double
  peak_load : Double
  average_sleep : Double
  maximum_pain : Double
  coverage_percent : Double
  quality_score : Double
} derive(Debug, Eq, ToJson)

///|
pub fn empty_record_query() -> RecordQuery {
  {
    start_date: None,
    end_date: None,
    minimum_load: None,
    maximum_load: None,
    minimum_sleep: None,
    maximum_pain: None,
    require_training: false,
    require_pain: false,
  }
}

///|
fn record_query_date_matches(record : DailyRecord, query : RecordQuery) -> Bool {
  let date_ok = match (query.start_date, query.end_date) {
    (None, None) => true
    (Some(start), None) => record.date >= start
    (None, Some(end)) => record.date <= end
    (Some(start), Some(end)) => record.date >= start && record.date <= end
  }
  date_ok
}

///|
fn record_query_value_matches(
  record : DailyRecord,
  query : RecordQuery,
) -> Bool {
  let load = daily_training_load(record)
  let load_ok = match (query.minimum_load, query.maximum_load) {
    (None, None) => true
    (Some(minimum), None) => load >= minimum
    (None, Some(maximum)) => load <= maximum
    (Some(minimum), Some(maximum)) => load >= minimum && load <= maximum
  }
  let sleep_ok = match query.minimum_sleep {
    Some(value) => record.sleep_hours >= value
    None => true
  }
  let pain_ok = match query.maximum_pain {
    Some(value) => record.pain_level <= value
    None => true
  }
  load_ok &&
  sleep_ok &&
  pain_ok &&
  (!query.require_training || load > 0.0) &&
  (!query.require_pain || record.pain_level > 0.0)
}

///|
fn record_query_matches(record : DailyRecord, query : RecordQuery) -> Bool {
  record_query_date_matches(record, query) &&
  record_query_value_matches(record, query)
}

///|
pub fn execute_record_query(
  records : Array[DailyRecord],
  query : RecordQuery,
) -> RecordQueryResult {
  let matched = records.filter(record => record_query_matches(record, query))
  {
    query,
    records: matched,
    input_count: records.length(),
    matched_count: matched.length(),
    rejected_count: records.length() - matched.length(),
    status: if records.length() == 0 {
      "empty"
    } else if matched.length() == 0 {
      "no_match"
    } else if matched.length() < records.length() {
      "filtered"
    } else {
      "all"
    },
    explanation: if matched.length() == records.length() {
      "all records matched"
    } else {
      "query conditions filtered the input"
    },
  }
}

///|
pub fn record_query_stats(result : RecordQueryResult) -> RecordQueryStats {
  {
    result,
    average_load: mean_load_values(training_loads(result.records)),
    peak_load: maximum_load_values(training_loads(result.records)),
    average_sleep: mean_load_values(
      result.records.map(record => record.sleep_hours),
    ),
    maximum_pain: maximum_load_values(
      result.records.map(record => record.pain_level),
    ),
    coverage_percent: completeness_ratio(result.records) * 100.0,
    quality_score: validate_records(result.records, default_quality_policy()).score,
  }
}

///|
pub fn record_query_accepts(result : RecordQueryResult) -> Bool {
  result.status != "empty" && result.status != "no_match"
}

///|
pub fn record_query_empty(result : RecordQueryResult) -> Bool {
  result.matched_count == 0
}

///|
pub fn record_query_filtered(result : RecordQueryResult) -> Bool {
  result.rejected_count > 0
}

///|
pub fn record_query_dates(result : RecordQueryResult) -> Array[String] {
  result.records.map(record => record.date)
}

///|
pub fn record_query_loads(result : RecordQueryResult) -> Array[Double] {
  training_loads(result.records)
}

///|
pub fn record_query_count(result : RecordQueryResult) -> Int {
  result.matched_count
}

///|
pub fn record_query_input_count(result : RecordQueryResult) -> Int {
  result.input_count
}

///|
pub fn record_query_rejected_count(result : RecordQueryResult) -> Int {
  result.rejected_count
}

///|
pub fn record_query_match_percent(result : RecordQueryResult) -> Double {
  if result.input_count == 0 {
    0.0
  } else {
    result.matched_count.to_double() / result.input_count.to_double() * 100.0
  }
}

///|
pub fn record_query_rejection_percent(result : RecordQueryResult) -> Double {
  if result.input_count == 0 {
    0.0
  } else {
    result.rejected_count.to_double() / result.input_count.to_double() * 100.0
  }
}

///|
pub fn record_query_stats_average_load(stats : RecordQueryStats) -> Double {
  stats.average_load
}

///|
pub fn record_query_stats_peak_load(stats : RecordQueryStats) -> Double {
  stats.peak_load
}

///|
pub fn record_query_stats_average_sleep(stats : RecordQueryStats) -> Double {
  stats.average_sleep
}

///|
pub fn record_query_stats_maximum_pain(stats : RecordQueryStats) -> Double {
  stats.maximum_pain
}

///|
pub fn record_query_stats_coverage(stats : RecordQueryStats) -> Double {
  stats.coverage_percent
}

///|
pub fn record_query_stats_quality(stats : RecordQueryStats) -> Double {
  stats.quality_score
}

///|
pub fn record_query_valid(result : RecordQueryResult) -> Bool {
  result.input_count >= 0 &&
  result.matched_count >= 0 &&
  result.rejected_count >= 0 &&
  result.matched_count + result.rejected_count == result.input_count &&
  result.records.length() == result.matched_count
}

///|
pub fn record_query_stats_valid(stats : RecordQueryStats) -> Bool {
  record_query_valid(stats.result) &&
  stats.average_load >= 0.0 &&
  stats.peak_load >= stats.average_load &&
  stats.average_sleep >= 0.0 &&
  stats.maximum_pain >= 0.0 &&
  stats.maximum_pain <= 10.0 &&
  stats.coverage_percent >= 0.0 &&
  stats.coverage_percent <= 100.0 &&
  stats.quality_score >= 0.0 &&
  stats.quality_score <= 100.0
}

///|
pub fn record_query_text(query : RecordQuery) -> String {
  let start = match query.start_date {
    Some(value) => value
    None => ""
  }
  let end = match query.end_date {
    Some(value) => value
    None => ""
  }
  "start=" +
  start +
  " end=" +
  end +
  " require_training=" +
  query.require_training.to_string() +
  " require_pain=" +
  query.require_pain.to_string()
}

///|
pub fn record_query_result_text(result : RecordQueryResult) -> String {
  record_query_text(result.query) +
  " input=" +
  result.input_count.to_string() +
  " matched=" +
  result.matched_count.to_string() +
  " rejected=" +
  result.rejected_count.to_string() +
  " status=" +
  result.status +
  " explanation=" +
  result.explanation
}

///|
pub fn record_query_stats_text(stats : RecordQueryStats) -> String {
  record_query_result_text(stats.result) +
  " average_load=" +
  stats.average_load.to_string() +
  " peak_load=" +
  stats.peak_load.to_string() +
  " average_sleep=" +
  stats.average_sleep.to_string() +
  " maximum_pain=" +
  stats.maximum_pain.to_string() +
  " coverage=" +
  stats.coverage_percent.to_string() +
  " quality=" +
  stats.quality_score.to_string()
}

///|
pub fn record_query_csv_header() -> String {
  "date,training_duration,training_intensity,pain_level,sleep_hours,sleep_quality,fatigue,load"
}

///|
pub fn record_query_record_csv(record : DailyRecord) -> String {
  record.date +
  "," +
  record.training_duration.to_string() +
  "," +
  record.training_intensity.to_string() +
  "," +
  record.pain_level.to_string() +
  "," +
  record.sleep_hours.to_string() +
  "," +
  record.sleep_quality.to_string() +
  "," +
  record.fatigue.to_string() +
  "," +
  daily_training_load(record).to_string()
}

///|
pub fn record_query_csv(result : RecordQueryResult) -> String {
  let builder = StringBuilder()
  builder.write_string(record_query_csv_header())
  for record in result.records {
    builder.write_string("\n" + record_query_record_csv(record))
  }
  builder.to_string()
}

///|
pub fn record_query_summary_header() -> Array[String] {
  [
    "status", "input_count", "matched_count", "rejected_count", "match_percent",
    "rejection_percent", "explanation",
  ]
}

///|
pub fn record_query_summary(result : RecordQueryResult) -> Array[String] {
  [
    result.status,
    result.input_count.to_string(),
    result.matched_count.to_string(),
    result.rejected_count.to_string(),
    record_query_match_percent(result).to_string(),
    record_query_rejection_percent(result).to_string(),
    result.explanation,
  ]
}

///|
pub fn record_query_summary_csv(result : RecordQueryResult) -> String {
  record_query_summary_header().join(",") +
  "\n" +
  record_query_summary(result).join(",")
}

///|
pub fn record_query_stats_summary_header() -> Array[String] {
  [
    "average_load", "peak_load", "average_sleep", "maximum_pain", "coverage_percent",
    "quality_score",
  ]
}

///|
pub fn record_query_stats_summary(stats : RecordQueryStats) -> Array[String] {
  [
    stats.average_load.to_string(),
    stats.peak_load.to_string(),
    stats.average_sleep.to_string(),
    stats.maximum_pain.to_string(),
    stats.coverage_percent.to_string(),
    stats.quality_score.to_string(),
  ]
}

///|
pub fn record_query_stats_summary_csv(stats : RecordQueryStats) -> String {
  record_query_stats_summary_header().join(",") +
  "\n" +
  record_query_stats_summary(stats).join(",")
}

///|
pub fn record_query_recommendation(result : RecordQueryResult) -> String {
  if result.status == "empty" {
    "provide records"
  } else if result.status == "no_match" {
    "relax query filters or collect more records"
  } else if result.rejected_count > result.matched_count {
    "review query exclusions"
  } else {
    "query result is suitable for analysis"
  }
}

///|
pub fn record_query_checksum(result : RecordQueryResult) -> String {
  let mut value = result.input_count + result.matched_count
  for character in record_query_result_text(result) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn record_query_reproducible(
  left : RecordQueryResult,
  right : RecordQueryResult,
) -> Bool {
  record_query_checksum(left) == record_query_checksum(right)
}

///|
pub fn record_query_exportable(result : RecordQueryResult) -> Bool {
  record_query_valid(result)
}

///|
pub fn record_query_export_status(result : RecordQueryResult) -> String {
  if record_query_exportable(result) {
    "exportable"
  } else {
    "blocked"
  }
}

///|
pub fn record_query_contract(result : RecordQueryResult) -> Array[String] {
  [
    result.status,
    result.input_count.to_string(),
    result.matched_count.to_string(),
    result.rejected_count.to_string(),
    record_query_match_percent(result).to_string(),
    record_query_recommendation(result),
    record_query_export_status(result),
    record_query_checksum(result),
  ]
}
