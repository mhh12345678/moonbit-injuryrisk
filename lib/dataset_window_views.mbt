///|
/// Dataset windows expose coverage, gaps, and the evidence available to a run.
pub(all) struct DatasetWindowView {
  start_date : String
  end_date : String
  expected_days : Int
  observed_days : Int
  missing_days : Int
  duplicate_days : Int
  valid_days : Int
  coverage_percent : Double
  quality_score : Double
  status : String
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct DatasetWindowComparison {
  left_coverage : Double
  right_coverage : Double
  coverage_change : Double
  left_quality : Double
  right_quality : Double
  quality_change : Double
  missing_change : Int
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
fn dataset_window_dates(records : Array[DailyRecord]) -> Array[DateParts] {
  let values = []
  for record in sort_records_by_date(records) {
    match parse_date(record.date) {
      Some(date) => values.push(date)
      None => ()
    }
  }
  values
}

///|
pub fn build_dataset_window_view(
  records : Array[DailyRecord],
) -> DatasetWindowView {
  let sorted = sort_records_by_date(records)
  let dates = dataset_window_dates(sorted)
  let start = if dates.length() == 0 { "" } else { format_date(dates[0]) }
  let end = if dates.length() == 0 {
    ""
  } else {
    format_date(dates[dates.length() - 1])
  }
  let expected = if dates.length() == 0 {
    0
  } else {
    days_between(dates[0], dates[dates.length() - 1]) + 1
  }
  let missing = missing_dates(sorted).length()
  let duplicates = duplicate_date_indices(sorted).length()
  let quality = validate_records(sorted, default_quality_policy()).score
  let coverage = if expected == 0 {
    0.0
  } else {
    (expected - missing).max(0).to_double() / expected.to_double() * 100.0
  }
  {
    start_date: start,
    end_date: end,
    expected_days: expected,
    observed_days: sorted.length(),
    missing_days: missing,
    duplicate_days: duplicates,
    valid_days: validate_records(sorted, default_quality_policy()).valid_record_count,
    coverage_percent: coverage,
    quality_score: quality,
    status: if sorted.length() == 0 {
      "empty"
    } else if quality < 60.0 || duplicates > 0 {
      "blocked"
    } else if coverage < 80.0 || quality < 80.0 {
      "review"
    } else {
      "ready"
    },
    recommendation: if sorted.length() == 0 {
      "collect a baseline"
    } else if duplicates > 0 {
      "deduplicate dates"
    } else if missing > 0 {
      "fill the missing date range"
    } else if quality < 80.0 {
      "repair invalid fields"
    } else {
      "dataset is ready"
    },
  }
}

///|
pub fn dataset_window_empty(view : DatasetWindowView) -> Bool {
  view.expected_days == 0
}

///|
pub fn dataset_window_ready(view : DatasetWindowView) -> Bool {
  view.status == "ready"
}

///|
pub fn dataset_window_blocked(view : DatasetWindowView) -> Bool {
  view.status == "blocked"
}

///|
pub fn dataset_window_needs_review(view : DatasetWindowView) -> Bool {
  view.status == "review" || view.status == "blocked"
}

///|
pub fn dataset_window_valid(view : DatasetWindowView) -> Bool {
  view.expected_days >= 0 &&
  view.observed_days >= 0 &&
  view.missing_days >= 0 &&
  view.duplicate_days >= 0 &&
  view.valid_days >= 0 &&
  view.coverage_percent >= 0.0 &&
  view.coverage_percent <= 100.0 &&
  view.quality_score >= 0.0 &&
  view.quality_score <= 100.0
}

///|
pub fn dataset_window_range(view : DatasetWindowView) -> Array[String] {
  [view.start_date, view.end_date]
}

///|
pub fn dataset_window_length(view : DatasetWindowView) -> Int {
  view.expected_days
}

///|
pub fn dataset_window_observed(view : DatasetWindowView) -> Int {
  view.observed_days
}

///|
pub fn dataset_window_missing(view : DatasetWindowView) -> Int {
  view.missing_days
}

///|
pub fn dataset_window_duplicates(view : DatasetWindowView) -> Int {
  view.duplicate_days
}

///|
pub fn dataset_window_valid_days(view : DatasetWindowView) -> Int {
  view.valid_days
}

///|
pub fn dataset_window_coverage(view : DatasetWindowView) -> Double {
  view.coverage_percent
}

///|
pub fn dataset_window_quality(view : DatasetWindowView) -> Double {
  view.quality_score
}

///|
pub fn dataset_window_missing_percent(view : DatasetWindowView) -> Double {
  if view.expected_days == 0 {
    0.0
  } else {
    view.missing_days.to_double() / view.expected_days.to_double() * 100.0
  }
}

///|
pub fn dataset_window_duplicate_percent(view : DatasetWindowView) -> Double {
  if view.observed_days == 0 {
    0.0
  } else {
    view.duplicate_days.to_double() / view.observed_days.to_double() * 100.0
  }
}

///|
pub fn dataset_window_valid_percent(view : DatasetWindowView) -> Double {
  if view.observed_days == 0 {
    0.0
  } else {
    view.valid_days.to_double() / view.observed_days.to_double() * 100.0
  }
}

///|
pub fn dataset_window_status(view : DatasetWindowView) -> String {
  view.status
}

///|
pub fn dataset_window_recommendation(view : DatasetWindowView) -> String {
  view.recommendation
}

///|
pub fn dataset_window_status_code(view : DatasetWindowView) -> Int {
  if view.status == "ready" {
    200
  } else if view.status == "review" {
    206
  } else if view.status == "blocked" {
    422
  } else {
    204
  }
}

///|
pub fn dataset_window_metric(view : DatasetWindowView, name : String) -> Double {
  match name {
    "expected" => view.expected_days.to_double()
    "observed" => view.observed_days.to_double()
    "missing" => view.missing_days.to_double()
    "duplicates" => view.duplicate_days.to_double()
    "valid" => view.valid_days.to_double()
    "coverage" => view.coverage_percent
    "quality" => view.quality_score
    _ => 0.0
  }
}

///|
pub fn dataset_window_metric_names() -> Array[String] {
  [
    "expected", "observed", "missing", "duplicates", "valid", "coverage", "quality",
  ]
}

///|
pub fn dataset_window_summary_header() -> Array[String] {
  [
    "start_date", "end_date", "expected_days", "observed_days", "missing_days", "duplicate_days",
    "valid_days", "coverage_percent", "quality_score", "status", "recommendation",
  ]
}

///|
pub fn dataset_window_summary(view : DatasetWindowView) -> Array[String] {
  [
    view.start_date,
    view.end_date,
    view.expected_days.to_string(),
    view.observed_days.to_string(),
    view.missing_days.to_string(),
    view.duplicate_days.to_string(),
    view.valid_days.to_string(),
    view.coverage_percent.to_string(),
    view.quality_score.to_string(),
    view.status,
    view.recommendation,
  ]
}

///|
pub fn dataset_window_summary_csv(view : DatasetWindowView) -> String {
  dataset_window_summary_header().join(",") +
  "\n" +
  dataset_window_summary(view).join(",")
}

///|
pub fn dataset_window_text(view : DatasetWindowView) -> String {
  "window=" +
  view.start_date +
  ".." +
  view.end_date +
  " expected=" +
  view.expected_days.to_string() +
  " observed=" +
  view.observed_days.to_string() +
  " missing=" +
  view.missing_days.to_string() +
  " duplicates=" +
  view.duplicate_days.to_string() +
  " valid=" +
  view.valid_days.to_string() +
  " coverage=" +
  view.coverage_percent.to_string() +
  " quality=" +
  view.quality_score.to_string() +
  " status=" +
  view.status +
  " recommendation=" +
  view.recommendation
}

///|
pub fn dataset_window_compare(
  left : DatasetWindowView,
  right : DatasetWindowView,
) -> DatasetWindowComparison {
  {
    left_coverage: left.coverage_percent,
    right_coverage: right.coverage_percent,
    coverage_change: right.coverage_percent - left.coverage_percent,
    left_quality: left.quality_score,
    right_quality: right.quality_score,
    quality_change: right.quality_score - left.quality_score,
    missing_change: right.missing_days - left.missing_days,
    conclusion: if right.coverage_percent > left.coverage_percent &&
      right.quality_score >= left.quality_score {
      "dataset quality improved"
    } else if right.coverage_percent < left.coverage_percent ||
      right.quality_score < left.quality_score {
      "dataset quality worsened"
    } else {
      "dataset quality is stable"
    },
  }
}

///|
pub fn dataset_window_comparison_text(
  comparison : DatasetWindowComparison,
) -> String {
  "coverage=" +
  comparison.left_coverage.to_string() +
  " -> " +
  comparison.right_coverage.to_string() +
  " quality=" +
  comparison.left_quality.to_string() +
  " -> " +
  comparison.right_quality.to_string() +
  " missing_change=" +
  comparison.missing_change.to_string() +
  " conclusion=" +
  comparison.conclusion
}

///|
pub fn dataset_window_checksum(view : DatasetWindowView) -> String {
  let mut value = view.expected_days + view.observed_days
  for character in dataset_window_text(view) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn dataset_window_reproducible(
  left : DatasetWindowView,
  right : DatasetWindowView,
) -> Bool {
  dataset_window_checksum(left) == dataset_window_checksum(right)
}

///|
pub fn dataset_window_exportable(view : DatasetWindowView) -> Bool {
  dataset_window_valid(view) && !dataset_window_blocked(view)
}

///|
pub fn dataset_window_export_status(view : DatasetWindowView) -> String {
  if dataset_window_exportable(view) {
    "exportable"
  } else {
    "blocked"
  }
}

///|
pub fn dataset_window_contract(view : DatasetWindowView) -> Array[String] {
  [
    view.status,
    view.expected_days.to_string(),
    view.observed_days.to_string(),
    view.coverage_percent.to_string(),
    view.quality_score.to_string(),
    dataset_window_recommendation(view),
    dataset_window_export_status(view),
    dataset_window_checksum(view),
  ]
}
