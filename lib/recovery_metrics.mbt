///|
/// A compact view of recovery signals used by the risk pipeline.
pub(all) struct RecoverySummary {
  sample_count : Int
  average_sleep_hours : Double
  sleep_debt_hours : Double
  sleep_consistency : Double
  average_sleep_quality : Double
  average_fatigue : Double
  maximum_fatigue : Double
  average_pain : Double
  maximum_pain : Double
  recovery_score : Double
  training_readiness : Double
  depleted_days : Int
} derive(Debug, Eq, ToJson)

///|
pub(all) enum RecoveryBand {
  Restored
  Ready
  Caution
  Depleted
  Unknown
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RecoveryWeights {
  sleep_hours : Double
  sleep_quality : Double
  fatigue : Double
  pain : Double
} derive(Debug, Eq, ToJson)

///|
pub fn default_recovery_weights() -> RecoveryWeights {
  { sleep_hours: 0.35, sleep_quality: 0.20, fatigue: 0.25, pain: 0.20 }
}

///|
fn clamp_unit(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn clamp_scale(value : Double, minimum : Double, maximum : Double) -> Double {
  if value < minimum {
    minimum
  } else if value > maximum {
    maximum
  } else {
    value
  }
}

///|
pub fn sleep_score(hours : Double, target_hours : Double) -> Double {
  if target_hours <= 0.0 {
    0.0
  } else {
    clamp_unit(hours / target_hours)
  }
}

///|
pub fn quality_score(quality : Double, maximum_quality : Double) -> Double {
  if maximum_quality <= 0.0 {
    0.0
  } else {
    clamp_unit(quality / maximum_quality)
  }
}

///|
pub fn fatigue_score(fatigue : Double, maximum_fatigue : Double) -> Double {
  if maximum_fatigue <= 0.0 {
    0.0
  } else {
    1.0 - clamp_unit(fatigue / maximum_fatigue)
  }
}

///|
pub fn pain_score(pain : Double, maximum_pain : Double) -> Double {
  if maximum_pain <= 0.0 {
    0.0
  } else {
    1.0 - clamp_unit(pain / maximum_pain)
  }
}

///|
pub fn record_recovery_score(
  record : DailyRecord,
  weights : RecoveryWeights,
  target_sleep : Double,
) -> Double {
  let total = weights.sleep_hours +
    weights.sleep_quality +
    weights.fatigue +
    weights.pain
  if total <= 0.0 {
    return 0.0
  }
  let weighted = sleep_score(record.sleep_hours, target_sleep) *
    weights.sleep_hours +
    quality_score(record.sleep_quality, 5.0) * weights.sleep_quality +
    fatigue_score(record.fatigue, 10.0) * weights.fatigue +
    pain_score(record.pain_level, 10.0) * weights.pain
  clamp_unit(weighted / total) * 100.0
}

///|
pub fn recovery_scores(
  records : Array[DailyRecord],
  weights : RecoveryWeights,
  target_sleep : Double,
) -> Array[Double] {
  records.map(record => record_recovery_score(record, weights, target_sleep))
}

///|
pub fn average_recovery_score(scores : ArrayView[Double]) -> Double {
  mean_load_values(scores)
}

///|
pub fn average_recovery_score_for(
  records : Array[DailyRecord],
  end_idx : Int,
  window_size : Int,
  weights : RecoveryWeights,
  target_sleep : Double,
) -> Double {
  let window = get_window_by_index(records, end_idx, window_size)
  if window.length() == 0 {
    0.0
  } else {
    average_recovery_score(
      window.map(r => record_recovery_score(r, weights, target_sleep)),
    )
  }
}

///|
pub fn sleep_debt(
  records : Array[DailyRecord],
  target_hours : Double,
) -> Double {
  if target_hours <= 0.0 {
    return 0.0
  }
  let mut debt = 0.0
  for record in records {
    let deficit = target_hours - record.sleep_hours
    if deficit > 0.0 {
      debt += deficit
    }
  }
  debt
}

///|
pub fn sleep_surplus(
  records : Array[DailyRecord],
  target_hours : Double,
) -> Double {
  if target_hours <= 0.0 {
    return 0.0
  }
  let mut surplus = 0.0
  for record in records {
    let extra = record.sleep_hours - target_hours
    if extra > 0.0 {
      surplus += extra
    }
  }
  surplus
}

///|
pub fn sleep_consistency(records : Array[DailyRecord]) -> Double {
  if records.length() == 0 {
    0.0
  } else {
    let variation = standard_deviation_values(records.map(r => r.sleep_hours))
    1.0 / (1.0 + variation)
  }
}

///|
pub fn average_sleep_hours_for(
  records : Array[DailyRecord],
  end_idx : Int,
  window_size : Int,
) -> Double {
  average_sleep_hours(get_window_by_index(records, end_idx, window_size))
}

///|
pub fn average_sleep_quality_for(
  records : Array[DailyRecord],
  end_idx : Int,
  window_size : Int,
) -> Double {
  average_sleep_quality(get_window_by_index(records, end_idx, window_size))
}

///|
pub fn average_fatigue_for(
  records : Array[DailyRecord],
  end_idx : Int,
  window_size : Int,
) -> Double {
  average_fatigue(get_window_by_index(records, end_idx, window_size))
}

///|
pub fn average_pain_for(
  records : Array[DailyRecord],
  end_idx : Int,
  window_size : Int,
) -> Double {
  let window = get_window_by_index(records, end_idx, window_size)
  if window.length() == 0 {
    0.0
  } else {
    mean_load_values(window.map(r => r.pain_level))
  }
}

///|
pub fn recovery_band(score : Double) -> RecoveryBand {
  if score >= 85.0 {
    Restored
  } else if score >= 70.0 {
    Ready
  } else if score >= 50.0 {
    Caution
  } else if score >= 0.0 {
    Depleted
  } else {
    Unknown
  }
}

///|
pub fn recovery_band_name(band : RecoveryBand) -> String {
  match band {
    Restored => "restored"
    Ready => "ready"
    Caution => "caution"
    Depleted => "depleted"
    Unknown => "unknown"
  }
}

///|
pub fn depleted_day_count(
  records : Array[DailyRecord],
  weights : RecoveryWeights,
  target_sleep : Double,
  threshold : Double,
) -> Int {
  let mut count = 0
  for record in records {
    if record_recovery_score(record, weights, target_sleep) < threshold {
      count += 1
    }
  }
  count
}

///|
pub fn recovery_load_balance(
  records : Array[DailyRecord],
  end_idx : Int,
  window_size : Int,
  weights : RecoveryWeights,
  target_sleep : Double,
  load_scale : Double,
) -> Double {
  let recovery = average_recovery_score_for(
    records, end_idx, window_size, weights, target_sleep,
  )
  let load = chronic_load_average(records, end_idx, window_size)
  if load_scale <= 0.0 {
    recovery
  } else {
    recovery - clamp_scale(load / load_scale * 100.0, 0.0, 100.0)
  }
}

///|
pub fn recovery_summary(
  records : Array[DailyRecord],
  end_idx : Int,
  window_size : Int,
  weights : RecoveryWeights,
  target_sleep : Double,
) -> RecoverySummary {
  let window = get_window_by_index(records, end_idx, window_size)
  let scores = recovery_scores(window.to_owned(), weights, target_sleep)
  let score = average_recovery_score(scores)
  {
    sample_count: window.length(),
    average_sleep_hours: average_sleep_hours(window),
    sleep_debt_hours: sleep_debt(window.to_owned(), target_sleep),
    sleep_consistency: sleep_consistency(window.to_owned()),
    average_sleep_quality: average_sleep_quality(window),
    average_fatigue: average_fatigue(window),
    maximum_fatigue: maximum_load_values(window.map(r => r.fatigue)),
    average_pain: average_pain_for(records, end_idx, window_size),
    maximum_pain: max_pain_level(window),
    recovery_score: score,
    training_readiness: recovery_load_balance(
      records, end_idx, window_size, weights, target_sleep, 400.0,
    ),
    depleted_days: depleted_day_count(
      window.to_owned(),
      weights,
      target_sleep,
      50.0,
    ),
  }
}

///|
pub fn recovery_trend(
  records : Array[DailyRecord],
  window_size : Int,
  weights : RecoveryWeights,
  target_sleep : Double,
) -> LoadTrend {
  let latest = get_window_by_index(records, records.length() - 1, window_size)
  load_trend(recovery_scores(latest.to_owned(), weights, target_sleep), 2.0)
}

///|
pub fn sleep_compliance(
  records : Array[DailyRecord],
  target_sleep : Double,
) -> Double {
  if records.length() == 0 || target_sleep <= 0.0 {
    0.0
  } else {
    let compliant = records.filter(r => r.sleep_hours >= target_sleep).length()
    compliant.to_double() / records.length().to_double() * 100.0
  }
}

///|
pub fn low_quality_night_count(
  records : Array[DailyRecord],
  threshold : Double,
) -> Int {
  records.filter(r => r.sleep_quality < threshold).length()
}

///|
pub fn high_fatigue_day_count(
  records : Array[DailyRecord],
  threshold : Double,
) -> Int {
  records.filter(r => r.fatigue > threshold).length()
}

///|
pub fn pain_free_day_count(records : Array[DailyRecord]) -> Int {
  records.filter(r => r.pain_level <= 0.0).length()
}
