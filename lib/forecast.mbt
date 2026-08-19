///|
/// Guardrail classification for a projected training change.
pub(all) enum ForecastBand {
  Safe
  Caution
  Unsafe
  Unknown
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ForecastPoint {
  day_offset : Int
  projected_load : Double
  projected_recovery : Double
  projected_acwr : Double
  band : ForecastBand
  rationale : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct TrainingForecast {
  horizon_days : Int
  baseline_load : Double
  proposed_change_percent : Double
  points : Array[ForecastPoint]
  maximum_acwr : Double
  minimum_recovery : Double
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ProgressionGuardrail {
  maximum_increase_percent : Double
  projected_acwr : Double
  allowed : Bool
  reason : String
} derive(Debug, Eq, ToJson)

///|
pub fn forecast_band_name(band : ForecastBand) -> String {
  match band {
    Safe => "safe"
    Caution => "caution"
    Unsafe => "unsafe"
    Unknown => "unknown"
  }
}

///|
fn projected_value(base : Double, slope : Double, offset : Int) -> Double {
  (base + slope * offset.to_double()).max(0.0)
}

///|
pub fn project_load(values : ArrayView[Double], day_offset : Int) -> Double {
  if values.length() == 0 {
    0.0
  } else {
    projected_value(
      values[values.length() - 1],
      linear_slope(values),
      day_offset,
    )
  }
}

///|
pub fn project_recovery(values : ArrayView[Double], day_offset : Int) -> Double {
  if values.length() == 0 {
    0.0
  } else {
    projected_value(
      values[values.length() - 1],
      linear_slope(values),
      day_offset,
    ).min(100.0)
  }
}

///|
pub fn project_acwr(
  current_acute : Double,
  current_chronic : Double,
  proposed_change_percent : Double,
) -> Double {
  let acute = current_acute * (1.0 + proposed_change_percent / 100.0)
  let chronic = current_chronic * 0.95 + acute * 0.05
  if chronic <= 0.0 {
    0.0
  } else {
    acute / chronic
  }
}

///|
pub fn classify_forecast(
  acwr : Double,
  recovery : Double,
  high_acwr : Double,
) -> ForecastBand {
  if high_acwr <= 0.0 {
    Unknown
  } else if acwr >= high_acwr || recovery < 40.0 {
    Unsafe
  } else if acwr >= high_acwr - 0.15 || recovery < 60.0 {
    Caution
  } else {
    Safe
  }
}

///|
pub fn forecast_rationale(
  band : ForecastBand,
  acwr : Double,
  recovery : Double,
) -> String {
  let prefix = match band {
    Safe => "projected load remains inside the policy guardrails"
    Caution =>
      "projected load is near a guardrail; confirm recovery before progression"
    Unsafe => "projected load or recovery crosses a high-risk guardrail"
    Unknown => "insufficient baseline data for a reliable projection"
  }
  prefix + " acwr=" + acwr.to_string() + " recovery=" + recovery.to_string()
}

///|
pub fn forecast_training(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  horizon_days : Int,
  proposed_change_percent : Double,
) -> TrainingForecast {
  let horizon = horizon_days.max(0)
  let load_values = rolling_metric(records, policy.acute_window, Average)
  let recovery_values = recovery_scores(
    records,
    policy.recovery_weights,
    policy.sleep_target,
  )
  let latest_load = if load_values.length() == 0 {
    0.0
  } else {
    load_values[load_values.length() - 1]
  }
  let latest_recovery = if recovery_values.length() == 0 {
    0.0
  } else {
    recovery_values[recovery_values.length() - 1]
  }
  let latest = if records.length() == 0 { 0 } else { records.length() - 1 }
  let current_summary = summarize_load(
    records,
    latest,
    policy.acute_window,
    policy.chronic_window,
    policy.baseline_window,
  )
  let points = []
  for offset in 1..<=horizon {
    let load = latest_load * (1.0 + proposed_change_percent / 100.0)
    let recovery = (latest_recovery - offset.to_double() * 1.5).max(0.0)
    let acwr = project_acwr(
      current_summary.acute_load,
      current_summary.chronic_load,
      proposed_change_percent,
    )
    let band = classify_forecast(acwr, recovery, policy.high_acwr)
    points.push({
      day_offset: offset,
      projected_load: load,
      projected_recovery: recovery,
      projected_acwr: acwr,
      band,
      rationale: forecast_rationale(band, acwr, recovery),
    })
  }
  let maximum = maximum_load_values(points.map(point => point.projected_acwr))
  let minimum = minimum_load_values(
    points.map(point => point.projected_recovery),
  )
  let recommendation = if maximum >= policy.high_acwr {
    "reduce the proposed increase before the next microcycle"
  } else if minimum < 60.0 {
    "hold the proposed increase until recovery is stable"
  } else {
    "proposed progression remains inside the configured guardrails"
  }
  {
    horizon_days: horizon,
    baseline_load: latest_load,
    proposed_change_percent,
    points,
    maximum_acwr: maximum,
    minimum_recovery: minimum,
    recommendation,
  }
}

///|
pub fn progression_guardrail(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  proposed_change_percent : Double,
) -> ProgressionGuardrail {
  let summary = summarize_load_window(records, policy.chronic_window)
  let projected = project_acwr(
    summary.acute_load,
    summary.chronic_load,
    proposed_change_percent,
  )
  let allowed = proposed_change_percent <= 10.0 && projected < policy.high_acwr
  {
    maximum_increase_percent: 10.0,
    projected_acwr: projected,
    allowed,
    reason: if allowed {
      "progression is within the default 10% and ACWR guardrails"
    } else {
      "progression exceeds the configured increase or ACWR guardrail"
    },
  }
}

///|
pub fn forecast_text(forecast : TrainingForecast) -> String {
  "horizon=" +
  forecast.horizon_days.to_string() +
  " baseline_load=" +
  forecast.baseline_load.to_string() +
  " change=" +
  forecast.proposed_change_percent.to_string() +
  "%" +
  " max_acwr=" +
  forecast.maximum_acwr.to_string() +
  " min_recovery=" +
  forecast.minimum_recovery.to_string() +
  " recommendation=" +
  forecast.recommendation
}
