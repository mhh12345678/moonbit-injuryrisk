///|
/// Multi-source load model for reconciling daily telemetry and sessions.
pub(all) struct LoadModelConfig {
  acute_days : Int
  chronic_days : Int
  intensity_weight : Double
  duration_weight : Double
  distance_weight : Double
  recovery_discount : Double
  high_intensity_threshold : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct LoadPoint {
  date : String
  internal_load : Double
  external_load : Double
  session_count : Int
  recovery_discount : Double
  modeled_load : Double
  acute_average : Double
  chronic_average : Double
  ratio : Double
  confidence : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct LoadModelSummary {
  points : Array[LoadPoint]
  total_internal_load : Double
  total_external_load : Double
  average_modeled_load : Double
  peak_modeled_load : Double
  latest_ratio : Double
  modeled_days : Int
  confidence : Double
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct LoadScenario {
  name : String
  duration_change_percent : Double
  intensity_change : Double
  recovery_factor : Double
  projected_load : Double
  projected_ratio : Double
  guardrail_pass : Bool
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub fn default_load_model_config() -> LoadModelConfig {
  {
    acute_days: 7,
    chronic_days: 28,
    intensity_weight: 1.0,
    duration_weight: 1.0,
    distance_weight: 0.15,
    recovery_discount: 0.05,
    high_intensity_threshold: 8.0,
  }
}

///|
fn safe_nonnegative(value : Double) -> Double {
  if value.is_nan() || value < 0.0 {
    0.0
  } else {
    value
  }
}

///|
fn session_external_load(
  session : TrainingSession,
  config : LoadModelConfig,
) -> Double {
  let distance = match session.distance_km {
    Some(value) => safe_nonnegative(value)
    None => 0.0
  }
  safe_nonnegative(session.duration_minutes) * config.duration_weight +
  distance * config.distance_weight
}

///|
fn session_internal_load(
  session : TrainingSession,
  config : LoadModelConfig,
) -> Double {
  safe_nonnegative(session.duration_minutes) *
  safe_nonnegative(session.intensity) *
  config.intensity_weight
}

///|
fn date_session_load(
  sessions : Array[TrainingSession],
  date : String,
  config : LoadModelConfig,
) -> Array[Double] {
  sessions_on_date(sessions, date).map(session => {
    session_internal_load(session, config)
  })
}

///|
fn date_external_load(
  sessions : Array[TrainingSession],
  date : String,
  config : LoadModelConfig,
) -> Double {
  sessions_on_date(sessions, date).fold(init=0.0, (total, session) => {
    total + session_external_load(session, config)
  })
}

///|
fn date_internal_load(
  sessions : Array[TrainingSession],
  date : String,
  config : LoadModelConfig,
) -> Double {
  date_session_load(sessions, date, config).fold(init=0.0, (total, value) => {
    total + value
  })
}

///|
fn recovery_factor(record : DailyRecord, config : LoadModelConfig) -> Double {
  let sleep_gap = (8.0 - record.sleep_hours).max(0.0).min(8.0)
  let fatigue_gap = record.fatigue.max(0.0).min(10.0)
  (1.0 -
  sleep_gap * config.recovery_discount -
  fatigue_gap * config.recovery_discount * 0.5)
  .max(0.2)
  .min(1.0)
}

///|
fn record_load_confidence(record : DailyRecord?, session_count : Int) -> Double {
  match record {
    Some(record) =>
      if session_count > 0 {
        if record.training_duration >= 0.0 {
          1.0
        } else {
          0.0
        }
      } else {
        0.75
      }
    None => if session_count > 0 { 0.65 } else { 0.0 }
  }
}

///|
fn load_dates(
  records : Array[DailyRecord],
  sessions : Array[TrainingSession],
) -> Array[String] {
  let dates = []
  for record in sort_records_by_date(records) {
    if !dates.contains(record.date) {
      dates.push(record.date)
    }
  }
  for session in sessions {
    if !dates.contains(session.date) {
      dates.push(session.date)
    }
  }
  dates
}

///|
fn record_lookup(records : Array[DailyRecord], date : String) -> DailyRecord? {
  for record in records {
    if record.date == date {
      return Some(record)
    }
  }
  None
}

///|
fn window_sum(points : Array[Double], end : Int, window : Int) -> Double {
  if end < 0 || points.length() == 0 || window <= 0 {
    return 0.0
  }
  let start = (end - window + 1).max(0)
  let mut total = 0.0
  for index in start..<(end + 1) {
    total += points[index]
  }
  total
}

///|
fn point_averages(
  points : Array[Double],
  index : Int,
  config : LoadModelConfig,
) -> Array[Double] {
  [
    window_sum(points, index, config.acute_days) /
    config.acute_days.max(1).to_double(),
    window_sum(points, index, config.chronic_days) /
    config.chronic_days.max(1).to_double(),
  ]
}

///|
pub fn model_load_points(
  records : Array[DailyRecord],
  sessions : Array[TrainingSession],
  config : LoadModelConfig,
) -> Array[LoadPoint] {
  let dates = load_dates(records, sessions)
  let internal = dates.map(date => date_internal_load(sessions, date, config))
  let points = []
  for index, date in dates {
    let record = record_lookup(records, date)
    let raw = if internal[index] > 0.0 {
      internal[index]
    } else {
      match record {
        Some(record) => daily_training_load(record)
        None => 0.0
      }
    }
    let discount = match record {
      Some(record) => recovery_factor(record, config)
      None => 1.0
    }
    let modeled = raw * discount
    let values = internal.copy()
    values[index] = modeled
    let averages = point_averages(values, index, config)
    let point = {
      date,
      internal_load: raw,
      external_load: date_external_load(sessions, date, config),
      session_count: sessions_on_date(sessions, date).length(),
      recovery_discount: discount,
      modeled_load: modeled,
      acute_average: averages[0],
      chronic_average: averages[1],
      ratio: if averages[1] == 0.0 {
        if averages[0] == 0.0 {
          0.0
        } else {
          100.0
        }
      } else {
        averages[0] / averages[1]
      },
      confidence: record_load_confidence(
        record,
        sessions_on_date(sessions, date).length(),
      ),
    }
    points.push(point)
  }
  points
}

///|
pub fn summarize_load_model(points : Array[LoadPoint]) -> LoadModelSummary {
  let modeled = points.map(point => point.modeled_load)
  let internal = points.map(point => point.internal_load)
  let external = points.map(point => point.external_load)
  let confidence = points.map(point => point.confidence)
  let latest_ratio = if points.length() == 0 {
    0.0
  } else {
    points[points.length() - 1].ratio
  }
  let status = if points.any(point => point.ratio >= 1.5) {
    "guardrail_breach"
  } else if points.any(point => point.confidence < 0.8) {
    "data_review"
  } else {
    "stable"
  }
  {
    points,
    total_internal_load: total_load_values(internal),
    total_external_load: total_load_values(external),
    average_modeled_load: mean_load_values(modeled),
    peak_modeled_load: maximum_load_values(modeled),
    latest_ratio,
    modeled_days: points.length(),
    confidence: mean_load_values(confidence),
    status,
  }
}

///|
pub fn build_load_model(
  records : Array[DailyRecord],
  sessions : Array[TrainingSession],
  config : LoadModelConfig,
) -> LoadModelSummary {
  summarize_load_model(model_load_points(records, sessions, config))
}

///|
pub fn model_point_for_date(
  summary : LoadModelSummary,
  date : String,
) -> LoadPoint? {
  for point in summary.points {
    if point.date == date {
      return Some(point)
    }
  }
  None
}

///|
pub fn model_peak_date(summary : LoadModelSummary) -> String? {
  if summary.points.length() == 0 {
    return None
  }
  let mut peak = summary.points[0]
  for point in summary.points {
    if point.modeled_load > peak.modeled_load {
      peak = point
    }
  }
  Some(peak.date)
}

///|
pub fn model_ratio_breach_dates(
  summary : LoadModelSummary,
  threshold : Double,
) -> Array[String] {
  summary.points
  .filter(point => point.ratio > threshold)
  .map(point => point.date)
}

///|
pub fn model_low_confidence_dates(
  summary : LoadModelSummary,
  threshold : Double,
) -> Array[String] {
  summary.points
  .filter(point => point.confidence < threshold)
  .map(point => point.date)
}

///|
pub fn reconcile_model_with_records(
  summary : LoadModelSummary,
  records : Array[DailyRecord],
) -> Array[Double] {
  let gaps = []
  for point in summary.points {
    match record_lookup(records, point.date) {
      Some(record) =>
        gaps.push(point.modeled_load - daily_training_load(record))
      None => gaps.push(point.modeled_load)
    }
  }
  gaps
}

///|
pub fn model_reconciliation_error(
  summary : LoadModelSummary,
  records : Array[DailyRecord],
) -> Double {
  let gaps = reconcile_model_with_records(summary, records)
  if gaps.length() == 0 {
    0.0
  } else {
    mean_load_values(gaps.map(value => value.abs()))
  }
}

///|
fn projected_modeled_load(
  summary : LoadModelSummary,
  duration_change : Double,
  intensity_change : Double,
  recovery_factor : Double,
) -> Double {
  let base = if summary.points.length() == 0 {
    0.0
  } else {
    summary.points[summary.points.length() - 1].modeled_load
  }
  base *
  (1.0 + duration_change / 100.0).max(0.0) *
  (1.0 + intensity_change / 10.0).max(0.0) *
  recovery_factor.max(0.0).min(1.0)
}

///|
pub fn evaluate_load_scenario(
  summary : LoadModelSummary,
  name : String,
  duration_change : Double,
  intensity_change : Double,
  recovery_factor : Double,
  maximum_ratio : Double,
) -> LoadScenario {
  let projected = projected_modeled_load(
    summary, duration_change, intensity_change, recovery_factor,
  )
  let chronic = if summary.points.length() == 0 {
    0.0
  } else {
    summary.points[summary.points.length() - 1].chronic_average
  }
  let ratio = if chronic == 0.0 {
    if projected == 0.0 {
      0.0
    } else {
      100.0
    }
  } else {
    projected / chronic
  }
  let pass = ratio <= maximum_ratio
  {
    name,
    duration_change_percent: duration_change,
    intensity_change,
    recovery_factor,
    projected_load: projected,
    projected_ratio: ratio,
    guardrail_pass: pass,
    recommendation: if pass {
      "scenario is within the configured ratio guardrail"
    } else {
      "reduce duration or intensity before execution"
    },
  }
}

///|
pub fn evaluate_load_scenarios(
  summary : LoadModelSummary,
  maximum_ratio : Double,
) -> Array[LoadScenario] {
  [
    evaluate_load_scenario(summary, "hold", 0.0, 0.0, 1.0, maximum_ratio),
    evaluate_load_scenario(
      summary, "small_progression", 5.0, 0.2, 1.0, maximum_ratio,
    ),
    evaluate_load_scenario(
      summary, "large_progression", 15.0, 0.5, 1.0, maximum_ratio,
    ),
    evaluate_load_scenario(
      summary, "recovery_week", -30.0, -1.0, 1.0, maximum_ratio,
    ),
    evaluate_load_scenario(
      summary, "poor_recovery", 0.0, 0.0, 0.75, maximum_ratio,
    ),
  ]
}

///|
pub fn safe_load_scenarios(
  summary : LoadModelSummary,
  maximum_ratio : Double,
) -> Array[LoadScenario] {
  evaluate_load_scenarios(summary, maximum_ratio).filter(scenario => {
    scenario.guardrail_pass
  })
}

///|
pub fn model_session_kind_load(
  _summary : LoadModelSummary,
  sessions : Array[TrainingSession],
  kind : SessionKind,
  config : LoadModelConfig,
) -> Double {
  sessions_by_kind(sessions, kind).fold(init=0.0, (total, session) => {
    total + session_internal_load(session, config)
  })
}

///|
pub fn model_high_intensity_share(
  sessions : Array[TrainingSession],
  config : LoadModelConfig,
) -> Double {
  if sessions.length() == 0 {
    0.0
  } else {
    sessions
    .filter(session => session.intensity >= config.high_intensity_threshold)
    .length()
    .to_double() /
    sessions.length().to_double() *
    100.0
  }
}

///|
pub fn model_training_day_count(summary : LoadModelSummary) -> Int {
  summary.points.filter(point => point.modeled_load > 0.0).length()
}

///|
pub fn model_rest_day_count(summary : LoadModelSummary) -> Int {
  summary.points.filter(point => point.modeled_load == 0.0).length()
}

///|
pub fn load_model_text(summary : LoadModelSummary) -> String {
  "status=" +
  summary.status +
  " days=" +
  summary.modeled_days.to_string() +
  " internal=" +
  summary.total_internal_load.to_string() +
  " external=" +
  summary.total_external_load.to_string() +
  " average=" +
  summary.average_modeled_load.to_string() +
  " peak=" +
  summary.peak_modeled_load.to_string() +
  " latest_ratio=" +
  summary.latest_ratio.to_string() +
  " confidence=" +
  summary.confidence.to_string()
}

///|
pub fn load_point_csv_header() -> String {
  "date,internal_load,external_load,session_count,recovery_discount,modeled_load,acute_average,chronic_average,ratio,confidence"
}

///|
pub fn load_point_csv(point : LoadPoint) -> String {
  point.date +
  "," +
  point.internal_load.to_string() +
  "," +
  point.external_load.to_string() +
  "," +
  point.session_count.to_string() +
  "," +
  point.recovery_discount.to_string() +
  "," +
  point.modeled_load.to_string() +
  "," +
  point.acute_average.to_string() +
  "," +
  point.chronic_average.to_string() +
  "," +
  point.ratio.to_string() +
  "," +
  point.confidence.to_string()
}

///|
pub fn load_model_csv(summary : LoadModelSummary) -> String {
  let builder = StringBuilder()
  builder.write_string(load_point_csv_header())
  for point in summary.points {
    builder.write_string("\n")
    builder.write_string(load_point_csv(point))
  }
  builder.to_string()
}

///|
pub fn load_model_config_valid(config : LoadModelConfig) -> Bool {
  config.acute_days > 0 &&
  config.chronic_days >= config.acute_days &&
  config.intensity_weight >= 0.0 &&
  config.duration_weight >= 0.0 &&
  config.distance_weight >= 0.0 &&
  config.recovery_discount >= 0.0 &&
  config.recovery_discount <= 1.0 &&
  config.high_intensity_threshold >= 0.0 &&
  config.high_intensity_threshold <= 10.0
}

///|
pub fn load_model_point_valid(point : LoadPoint) -> Bool {
  point.date != "" &&
  point.session_count >= 0 &&
  point.recovery_discount >= 0.0 &&
  point.recovery_discount <= 1.0 &&
  !point.modeled_load.is_nan() &&
  !point.ratio.is_nan()
}
