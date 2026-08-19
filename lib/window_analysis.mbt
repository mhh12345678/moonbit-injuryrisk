///|
/// Comparison of two adjacent telemetry windows.
pub(all) struct WindowComparison {
  recent_days : Int
  baseline_days : Int
  recent_load : Double
  baseline_load : Double
  load_change_percent : Double
  recent_sleep : Double
  baseline_sleep : Double
  sleep_change : Double
  recent_fatigue : Double
  baseline_fatigue : Double
  fatigue_change : Double
  direction : TrendDirection
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
pub fn records_window_from_end(
  records : Array[DailyRecord],
  end_idx : Int,
  window_size : Int,
) -> Array[DailyRecord] {
  get_window_by_index(records, end_idx, window_size).to_owned()
}

///|
pub fn compare_adjacent_windows(
  records : Array[DailyRecord],
  end_idx : Int,
  recent_size : Int,
  baseline_size : Int,
) -> WindowComparison {
  let recent = records_window_from_end(records, end_idx, recent_size)
  let baseline_end = end_idx - recent_size
  let baseline = records_window_from_end(records, baseline_end, baseline_size)
  let recent_load = mean_load_values(training_loads(recent))
  let baseline_load = mean_load_values(training_loads(baseline))
  let recent_sleep = average_sleep_hours(recent)
  let baseline_sleep = average_sleep_hours(baseline)
  let recent_fatigue = average_fatigue(recent)
  let baseline_fatigue = average_fatigue(baseline)
  let load_change = percentage_change(baseline_load, recent_load)
  let direction = classify_trend([baseline_load, recent_load], 0.1, 1)
  {
    recent_days: recent.length(),
    baseline_days: baseline.length(),
    recent_load,
    baseline_load,
    load_change_percent: load_change,
    recent_sleep,
    baseline_sleep,
    sleep_change: recent_sleep - baseline_sleep,
    recent_fatigue,
    baseline_fatigue,
    fatigue_change: recent_fatigue - baseline_fatigue,
    direction,
    conclusion: if load_change > 15.0 && recent_sleep < baseline_sleep {
      "load increased while sleep fell"
    } else if load_change < -15.0 && recent_sleep > baseline_sleep {
      "load reduced while sleep improved"
    } else {
      "adjacent-window changes are mixed"
    },
  }
}

///|
pub fn window_quality_scores(
  records : Array[DailyRecord],
  window_size : Int,
  policy : QualityPolicy,
) -> Array[Double] {
  let scores = []
  for index in 0..<records.length() {
    let window = records_window_from_end(records, index, window_size)
    scores.push(validate_records(window, policy).score)
  }
  scores
}

///|
pub fn rolling_risk_scores(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  window_size : Int,
) -> Array[Double] {
  let scores = []
  for index in 0..<records.length() {
    let window = records_window_from_end(records, index, window_size)
    match assess_latest(window, policy) {
      Some(assessment) => scores.push(assessment.risk_score)
      None => scores.push(0.0)
    }
  }
  scores
}

///|
pub fn window_alert_count(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  window_size : Int,
) -> Array[Int] {
  let counts = []
  for index in 0..<records.length() {
    let window = records_window_from_end(records, index, window_size)
    match assess_latest(window, policy) {
      Some(assessment) => counts.push(assessment.signals.signal_count)
      None => counts.push(0)
    }
  }
  counts
}

///|
pub fn window_comparison_text(comparison : WindowComparison) -> String {
  "recent_days=" +
  comparison.recent_days.to_string() +
  " baseline_days=" +
  comparison.baseline_days.to_string() +
  " load_change=" +
  comparison.load_change_percent.to_string() +
  "%" +
  " sleep_change=" +
  comparison.sleep_change.to_string() +
  " fatigue_change=" +
  comparison.fatigue_change.to_string() +
  " direction=" +
  trend_direction_name(comparison.direction) +
  " conclusion=" +
  comparison.conclusion
}
