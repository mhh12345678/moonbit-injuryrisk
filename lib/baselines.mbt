///|
/// Baseline statistics for athlete-specific, explainable comparisons.
pub(all) struct BaselineProfile {
  label : String
  window_days : Int
  load_mean : Double
  load_stddev : Double
  load_median : Double
  sleep_mean : Double
  sleep_stddev : Double
  recovery_mean : Double
  readiness_mean : Double
  pain_mean : Double
  fatigue_mean : Double
  sample_count : Int
  coverage_percent : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct BaselineObservation {
  date : String
  load : Double
  load_z : Double
  sleep_hours : Double
  sleep_z : Double
  recovery_score : Double
  recovery_delta : Double
  readiness_score : Double
  readiness_delta : Double
  pain_level : Double
  pain_delta : Double
  fatigue : Double
  fatigue_delta : Double
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct BaselineDrift {
  metric : String
  baseline : Double
  current : Double
  change_percent : Double
  direction : String
  concern : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct BaselineReport {
  profile : BaselineProfile
  observations : Array[BaselineObservation]
  drifts : Array[BaselineDrift]
  stable : Bool
  note : String
} derive(Debug, Eq, ToJson)

///|
fn baseline_mean(values : Array[Double]) -> Double {
  mean_load_values(values)
}

///|
fn baseline_stddev(values : Array[Double]) -> Double {
  standard_deviation_values(values)
}

///|
fn baseline_median(values : Array[Double]) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let sorted = values.copy()
  sorted.sort()
  if sorted.length() % 2 == 1 {
    sorted[sorted.length() / 2]
  } else {
    let right = sorted.length() / 2
    (sorted[right - 1] + sorted[right]) / 2.0
  }
}

///|
fn baseline_sleep_values(records : Array[DailyRecord]) -> Array[Double] {
  records.map(record => record.sleep_hours)
}

///|
fn baseline_recovery_values(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> Array[Double] {
  let values = []
  let sorted = sort_records_by_date(records)
  for index in 0..<sorted.length() {
    values.push(
      record_recovery_score(
        sorted[index],
        policy.recovery_weights,
        policy.sleep_target,
      ),
    )
  }
  values
}

///|
fn baseline_readiness_values(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> Array[Double] {
  let values = []
  let sorted = sort_records_by_date(records)
  for index in 0..<sorted.length() {
    match assess_comprehensive(sorted, sorted[index].date, policy) {
      Some(assessment) => values.push(assessment.readiness_score)
      None => values.push(0.0)
    }
  }
  values
}

///|
fn baseline_pain_values(records : Array[DailyRecord]) -> Array[Double] {
  records.map(record => record.pain_level)
}

///|
fn baseline_fatigue_values(records : Array[DailyRecord]) -> Array[Double] {
  records.map(record => record.fatigue)
}

///|
pub fn build_baseline_profile(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  label : String,
) -> BaselineProfile {
  let normalized = normalize_records(records)
  let loads = training_loads(normalized)
  let sleep = baseline_sleep_values(normalized)
  let recovery = baseline_recovery_values(normalized, policy)
  let readiness = baseline_readiness_values(normalized, policy)
  let pain = baseline_pain_values(normalized)
  let fatigue = baseline_fatigue_values(normalized)
  {
    label,
    window_days: policy.baseline_window,
    load_mean: baseline_mean(loads),
    load_stddev: baseline_stddev(loads),
    load_median: baseline_median(loads),
    sleep_mean: baseline_mean(sleep),
    sleep_stddev: baseline_stddev(sleep),
    recovery_mean: baseline_mean(recovery),
    readiness_mean: baseline_mean(readiness),
    pain_mean: baseline_mean(pain),
    fatigue_mean: baseline_mean(fatigue),
    sample_count: normalized.length(),
    coverage_percent: completeness_ratio(normalized) * 100.0,
  }
}

///|
pub fn baseline_profile_empty(
  label : String,
  policy : RiskPolicy,
) -> BaselineProfile {
  build_baseline_profile([], policy, label)
}

///|
fn delta_from_baseline(value : Double, baseline : Double) -> Double {
  value - baseline
}

///|
fn percent_from_baseline(value : Double, baseline : Double) -> Double {
  percentage_change(baseline, value)
}

///|
fn baseline_status(
  load_z : Double,
  sleep_z : Double,
  pain_delta : Double,
  fatigue_delta : Double,
) -> String {
  if pain_delta >= 3.0 || fatigue_delta >= 3.0 || load_z >= 2.0 {
    "critical"
  } else if pain_delta >= 1.5 ||
    fatigue_delta >= 1.5 ||
    load_z >= 1.5 ||
    sleep_z <= -1.5 {
    "watch"
  } else if load_z <= -1.5 && sleep_z >= 1.0 {
    "recovery"
  } else {
    "within_baseline"
  }
}

///|
pub fn observe_against_baseline(
  profile : BaselineProfile,
  record : DailyRecord,
  recovery_score : Double,
  readiness_score : Double,
) -> BaselineObservation {
  let load = daily_training_load(record)
  let load_z = load_z_score([profile.load_mean, profile.load_stddev], load)
  let sleep_z = load_z_score(
    [profile.sleep_mean, profile.sleep_stddev],
    record.sleep_hours,
  )
  let recovery_delta = delta_from_baseline(
    recovery_score,
    profile.recovery_mean,
  )
  let readiness_delta = delta_from_baseline(
    readiness_score,
    profile.readiness_mean,
  )
  let pain_delta = delta_from_baseline(record.pain_level, profile.pain_mean)
  let fatigue_delta = delta_from_baseline(record.fatigue, profile.fatigue_mean)
  {
    date: record.date,
    load,
    load_z,
    sleep_hours: record.sleep_hours,
    sleep_z,
    recovery_score,
    recovery_delta,
    readiness_score,
    readiness_delta,
    pain_level: record.pain_level,
    pain_delta,
    fatigue: record.fatigue,
    fatigue_delta,
    status: baseline_status(load_z, sleep_z, pain_delta, fatigue_delta),
  }
}

///|
pub fn observe_records_against_baseline(
  profile : BaselineProfile,
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> Array[BaselineObservation] {
  let observations = []
  let sorted = sort_records_by_date(records)
  for index, record in sorted {
    match assess_comprehensive(sorted, record.date, policy) {
      Some(assessment) =>
        observations.push(
          observe_against_baseline(
            profile,
            record,
            assessment.recovery.recovery_score,
            assessment.readiness_score,
          ),
        )
      None =>
        observations.push(observe_against_baseline(profile, record, 0.0, 0.0))
    }
    if index < 0 {
      ()
    }
  }
  observations
}

///|
fn drift(
  metric : String,
  baseline : Double,
  current : Double,
  concern : Bool,
) -> BaselineDrift {
  let change = percent_from_baseline(current, baseline)
  {
    metric,
    baseline,
    current,
    change_percent: change,
    direction: if change > 5.0 {
      "up"
    } else if change < -5.0 {
      "down"
    } else {
      "stable"
    },
    concern,
  }
}

///|
pub fn baseline_drifts(
  profile : BaselineProfile,
  observations : Array[BaselineObservation],
) -> Array[BaselineDrift] {
  if observations.length() == 0 {
    return []
  }
  let latest = observations[observations.length() - 1]
  [
    drift("load", profile.load_mean, latest.load, latest.load_z >= 1.5),
    drift(
      "sleep",
      profile.sleep_mean,
      latest.sleep_hours,
      latest.sleep_z <= -1.5,
    ),
    drift(
      "recovery",
      profile.recovery_mean,
      latest.recovery_score,
      latest.recovery_delta <= -10.0,
    ),
    drift(
      "readiness",
      profile.readiness_mean,
      latest.readiness_score,
      latest.readiness_delta <= -10.0,
    ),
    drift(
      "pain",
      profile.pain_mean,
      latest.pain_level,
      latest.pain_delta >= 2.0,
    ),
    drift(
      "fatigue",
      profile.fatigue_mean,
      latest.fatigue,
      latest.fatigue_delta >= 2.0,
    ),
  ]
}

///|
pub fn build_baseline_report(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  label : String,
) -> BaselineReport {
  let profile = build_baseline_profile(records, policy, label)
  let observations = observe_records_against_baseline(profile, records, policy)
  let drifts = baseline_drifts(profile, observations)
  let concern_count = drifts.filter(item => item.concern).length()
  {
    profile,
    observations,
    drifts,
    stable: concern_count == 0,
    note: if concern_count == 0 {
      "latest values are within the configured baseline band"
    } else {
      "one or more latest values have drifted from baseline"
    },
  }
}

///|
pub fn baseline_concern_count(report : BaselineReport) -> Int {
  report.drifts.filter(item => item.concern).length()
}

///|
pub fn baseline_critical_dates(report : BaselineReport) -> Array[String] {
  report.observations
  .filter(item => item.status == "critical")
  .map(item => item.date)
}

///|
pub fn baseline_watch_dates(report : BaselineReport) -> Array[String] {
  report.observations
  .filter(item => item.status == "watch")
  .map(item => item.date)
}

///|
pub fn baseline_recovery_dates(report : BaselineReport) -> Array[String] {
  report.observations
  .filter(item => item.status == "recovery")
  .map(item => item.date)
}

///|
pub fn baseline_status_counts(report : BaselineReport) -> Array[Int] {
  [
    report.observations
    .filter(item => item.status == "within_baseline")
    .length(),
    report.observations.filter(item => item.status == "watch").length(),
    report.observations.filter(item => item.status == "critical").length(),
    report.observations.filter(item => item.status == "recovery").length(),
  ]
}

///|
pub fn baseline_profile_valid(profile : BaselineProfile) -> Bool {
  profile.window_days > 0 &&
  profile.sample_count >= 0 &&
  profile.coverage_percent >= 0.0 &&
  profile.coverage_percent <= 100.0 &&
  !profile.load_mean.is_nan() &&
  !profile.load_stddev.is_nan() &&
  !profile.sleep_mean.is_nan()
}

///|
pub fn baseline_observation_valid(observation : BaselineObservation) -> Bool {
  observation.date != "" &&
  !observation.load.is_nan() &&
  !observation.load_z.is_nan() &&
  observation.status != ""
}

///|
pub fn baseline_drift_text(item : BaselineDrift) -> String {
  item.metric +
  " baseline=" +
  item.baseline.to_string() +
  " current=" +
  item.current.to_string() +
  " change=" +
  item.change_percent.to_string() +
  "% direction=" +
  item.direction
}

///|
pub fn baseline_report_text(report : BaselineReport) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "label=" +
    report.profile.label +
    " samples=" +
    report.profile.sample_count.to_string() +
    " coverage=" +
    report.profile.coverage_percent.to_string() +
    "%",
  )
  builder.write_string(
    " stable=" + report.stable.to_string() + " note=" + report.note,
  )
  for item in report.drifts {
    builder.write_string("\n")
    builder.write_string(baseline_drift_text(item))
  }
  builder.to_string()
}

///|
pub fn baseline_observation_csv_header() -> String {
  "date,load,load_z,sleep_hours,sleep_z,recovery,recovery_delta,readiness,readiness_delta,pain,pain_delta,fatigue,fatigue_delta,status"
}

///|
pub fn baseline_observation_csv(item : BaselineObservation) -> String {
  item.date +
  "," +
  item.load.to_string() +
  "," +
  item.load_z.to_string() +
  "," +
  item.sleep_hours.to_string() +
  "," +
  item.sleep_z.to_string() +
  "," +
  item.recovery_score.to_string() +
  "," +
  item.recovery_delta.to_string() +
  "," +
  item.readiness_score.to_string() +
  "," +
  item.readiness_delta.to_string() +
  "," +
  item.pain_level.to_string() +
  "," +
  item.pain_delta.to_string() +
  "," +
  item.fatigue.to_string() +
  "," +
  item.fatigue_delta.to_string() +
  "," +
  item.status
}

///|
pub fn baseline_report_csv(report : BaselineReport) -> String {
  let builder = StringBuilder::new()
  builder.write_string(baseline_observation_csv_header())
  for observation in report.observations {
    builder.write_string("\n")
    builder.write_string(baseline_observation_csv(observation))
  }
  builder.to_string()
}

///|
pub fn baseline_metric_value(
  profile : BaselineProfile,
  metric : String,
) -> Double {
  match metric {
    "load" => profile.load_mean
    "sleep" => profile.sleep_mean
    "recovery" => profile.recovery_mean
    "readiness" => profile.readiness_mean
    "pain" => profile.pain_mean
    "fatigue" => profile.fatigue_mean
    _ => 0.0
  }
}

///|
pub fn baseline_metric_names() -> Array[String] {
  ["load", "sleep", "recovery", "readiness", "pain", "fatigue"]
}

///|
pub fn baseline_latest(report : BaselineReport) -> BaselineObservation? {
  if report.observations.length() == 0 {
    None
  } else {
    Some(report.observations[report.observations.length() - 1])
  }
}

///|
pub fn baseline_trend(report : BaselineReport, metric : String) -> LoadTrend {
  let values = report.observations.map(item => {
    match metric {
      "load" => item.load
      "sleep" => item.sleep_hours
      "recovery" => item.recovery_score
      "readiness" => item.readiness_score
      "pain" => item.pain_level
      "fatigue" => item.fatigue
      _ => 0.0
    }
  })
  load_trend(values, 0.1)
}

///|
pub fn baseline_safe_to_progress(report : BaselineReport) -> Bool {
  report.stable && baseline_critical_dates(report).length() == 0
}

///|
pub fn baseline_report_line_count(report : BaselineReport) -> Int {
  2 + report.drifts.length() + report.observations.length()
}
