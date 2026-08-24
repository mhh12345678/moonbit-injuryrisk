///|
/// Reusable window operations for daily monitoring and block review.
pub(all) struct WindowSlice {
  start_date : String
  end_date : String
  records : Array[DailyRecord]
  total_load : Double
  average_load : Double
  recovery_score : Double
  readiness_score : Double
  risk_score : Double
  quality_score : Double
  complete : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct OperationalWindowComparison {
  left : WindowSlice
  right : WindowSlice
  load_change_percent : Double
  recovery_change : Double
  readiness_change : Double
  risk_change : Double
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
fn window_assessment(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> ComprehensiveAssessment? {
  assess_latest(records, policy)
}

///|
pub fn build_window_slice(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  start : String,
  end : String,
) -> WindowSlice {
  let selected = match (parse_date(start), parse_date(end)) {
    (Some(start), Some(end)) =>
      match make_date_range(start, end) {
        Some(range) => records_in_date_range(records, range)
        None => []
      }
    _ => []
  }
  let assessment = window_assessment(selected, policy)
  {
    start_date: start,
    end_date: end,
    records: selected,
    total_load: total_load_values(training_loads(selected)),
    average_load: mean_load_values(training_loads(selected)),
    recovery_score: match assessment {
      Some(value) => value.recovery.recovery_score
      None => 0.0
    },
    readiness_score: match assessment {
      Some(value) => value.readiness_score
      None => 0.0
    },
    risk_score: match assessment {
      Some(value) => value.risk_score
      None => 0.0
    },
    quality_score: validate_records(selected, default_quality_policy()).score,
    complete: missing_dates(selected).length() == 0 &&
    duplicate_date_indices(selected).length() == 0,
  }
}

///|
pub fn build_equal_windows(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  window_days : Int,
) -> Array[WindowSlice] {
  let sorted = sort_records_by_date(records)
  let output = []
  if sorted.length() == 0 || window_days <= 0 {
    return output
  }
  let mut start = 0
  while start < sorted.length() {
    let end_index = (start + window_days - 1).min(sorted.length() - 1)
    output.push(
      build_window_slice(
        sorted,
        policy,
        sorted[start].date,
        sorted[end_index].date,
      ),
    )
    start += window_days
  }
  output
}

///|
pub fn compare_operational_windows(
  left : WindowSlice,
  right : WindowSlice,
) -> OperationalWindowComparison {
  let load_change = percentage_change(left.average_load, right.average_load)
  let recovery_change = right.recovery_score - left.recovery_score
  let readiness_change = right.readiness_score - left.readiness_score
  let risk_change = right.risk_score - left.risk_score
  {
    left,
    right,
    load_change_percent: load_change,
    recovery_change,
    readiness_change,
    risk_change,
    conclusion: if load_change > 10.0 && recovery_change < -5.0 {
      "load increased while recovery declined"
    } else if load_change < -10.0 && recovery_change > 5.0 {
      "load reduced while recovery improved"
    } else {
      "window changes are mixed or small"
    },
  }
}

///|
pub fn window_slice_valid(slice : WindowSlice) -> Bool {
  slice.start_date != "" &&
  slice.end_date != "" &&
  slice.total_load >= 0.0 &&
  slice.average_load >= 0.0 &&
  slice.recovery_score >= 0.0 &&
  slice.recovery_score <= 100.0 &&
  slice.readiness_score >= 0.0 &&
  slice.readiness_score <= 100.0 &&
  slice.risk_score >= 0.0 &&
  slice.risk_score <= 100.0 &&
  slice.quality_score >= 0.0 &&
  slice.quality_score <= 100.0
}

///|
pub fn window_slice_days(slice : WindowSlice) -> Int {
  match (parse_date(slice.start_date), parse_date(slice.end_date)) {
    (Some(start), Some(end)) => (days_between(start, end) + 1).max(0)
    _ => 0
  }
}

///|
pub fn window_slice_has_action(slice : WindowSlice) -> Bool {
  slice.risk_score >= 40.0 || slice.readiness_score < 70.0 || !slice.complete
}

///|
pub fn window_slice_training_days(slice : WindowSlice) -> Int {
  training_day_count(slice.records)
}

///|
pub fn window_slice_rest_days(slice : WindowSlice) -> Int {
  rest_day_count(slice.records)
}

///|
pub fn window_slice_load_profile(slice : WindowSlice) -> Array[Double] {
  training_loads(slice.records)
}

///|
pub fn window_slice_peak_load(slice : WindowSlice) -> Double {
  maximum_load_values(window_slice_load_profile(slice))
}

///|
pub fn window_slice_monotony(slice : WindowSlice) -> Double {
  workload_monotony(window_slice_load_profile(slice))
}

///|
pub fn window_slice_summary_text(slice : WindowSlice) -> String {
  slice.start_date +
  ".." +
  slice.end_date +
  " days=" +
  window_slice_days(slice).to_string() +
  " load=" +
  slice.total_load.to_string() +
  " average=" +
  slice.average_load.to_string() +
  " risk=" +
  slice.risk_score.to_string() +
  " readiness=" +
  slice.readiness_score.to_string() +
  " complete=" +
  slice.complete.to_string()
}

///|
pub fn operational_window_comparison_text(
  comparison : OperationalWindowComparison,
) -> String {
  comparison.left.start_date +
  ".." +
  comparison.left.end_date +
  " vs " +
  comparison.right.start_date +
  ".." +
  comparison.right.end_date +
  " load_change=" +
  comparison.load_change_percent.to_string() +
  "% recovery_change=" +
  comparison.recovery_change.to_string() +
  " readiness_change=" +
  comparison.readiness_change.to_string() +
  " risk_change=" +
  comparison.risk_change.to_string() +
  " conclusion=" +
  comparison.conclusion
}

///|
pub fn window_slice_csv_header() -> String {
  "start_date,end_date,days,records,total_load,average_load,recovery_score,readiness_score,risk_score,quality_score,complete"
}

///|
pub fn window_slice_csv(slice : WindowSlice) -> String {
  slice.start_date +
  "," +
  slice.end_date +
  "," +
  window_slice_days(slice).to_string() +
  "," +
  slice.records.length().to_string() +
  "," +
  slice.total_load.to_string() +
  "," +
  slice.average_load.to_string() +
  "," +
  slice.recovery_score.to_string() +
  "," +
  slice.readiness_score.to_string() +
  "," +
  slice.risk_score.to_string() +
  "," +
  slice.quality_score.to_string() +
  "," +
  slice.complete.to_string()
}

///|
pub fn windows_csv(windows : Array[WindowSlice]) -> String {
  let builder = StringBuilder()
  builder.write_string(window_slice_csv_header())
  for window in windows {
    builder.write_string("\n")
    builder.write_string(window_slice_csv(window))
  }
  builder.to_string()
}
