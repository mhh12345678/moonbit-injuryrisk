///|
/// A stable description of the workload distribution in a record set.
pub(all) struct LoadSummary {
  sample_count : Int
  training_days : Int
  rest_days : Int
  total_load : Double
  average_load : Double
  minimum_load : Double
  maximum_load : Double
  standard_deviation : Double
  coefficient_of_variation : Double
  monotony : Double
  strain : Double
  acute_load : Double
  chronic_load : Double
  acwr : Double
  ramp_rate : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) enum LoadTrend {
  Rising
  Stable
  Falling
  Volatile
  InsufficientData
} derive(Debug, Eq, ToJson)

///|
pub(all) enum LoadWindow {
  Sum
  Average
  ExponentiallyWeighted(decay~ : Double)
} derive(Debug, Eq, ToJson)

///|
fn safe_ratio(numerator : Double, denominator : Double) -> Double {
  if denominator == 0.0 {
    if numerator == 0.0 {
      0.0
    } else {
      100.0
    }
  } else {
    numerator / denominator
  }
}

///|
pub fn daily_training_load(record : DailyRecord) -> Double {
  record.training_duration * record.training_intensity
}

///|
pub fn bounded_training_load(record : DailyRecord) -> Double {
  let load = daily_training_load(record)
  if load < 0.0 {
    0.0
  } else {
    load
  }
}

///|
pub fn training_loads(records : Array[DailyRecord]) -> Array[Double] {
  records.map(record => daily_training_load(record))
}

///|
pub fn bounded_training_loads(records : Array[DailyRecord]) -> Array[Double] {
  records.map(record => bounded_training_load(record))
}

///|
pub fn total_load_values(values : ArrayView[Double]) -> Double {
  let mut total = 0.0
  for value in values {
    total += value
  }
  total
}

///|
pub fn mean_load_values(values : ArrayView[Double]) -> Double {
  if values.length() == 0 {
    0.0
  } else {
    total_load_values(values) / values.length().to_double()
  }
}

///|
pub fn minimum_load_values(values : ArrayView[Double]) -> Double {
  if values.length() == 0 {
    0.0
  } else {
    let mut result = values[0]
    for value in values {
      if value < result {
        result = value
      }
    }
    result
  }
}

///|
pub fn maximum_load_values(values : ArrayView[Double]) -> Double {
  if values.length() == 0 {
    0.0
  } else {
    let mut result = values[0]
    for value in values {
      if value > result {
        result = value
      }
    }
    result
  }
}

///|
pub fn variance_load_values(values : ArrayView[Double]) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let mean = mean_load_values(values)
  let mut sum = 0.0
  for value in values {
    let delta = value - mean
    sum += delta * delta
  }
  sum / values.length().to_double()
}

///|
pub fn standard_deviation_values(values : ArrayView[Double]) -> Double {
  variance_load_values(values).sqrt()
}

///|
pub fn coefficient_of_variation_values(values : ArrayView[Double]) -> Double {
  let mean = mean_load_values(values)
  if mean == 0.0 {
    0.0
  } else {
    standard_deviation_values(values) / mean
  }
}

///|
pub fn training_day_count(records : Array[DailyRecord]) -> Int {
  let mut count = 0
  for record in records {
    if daily_training_load(record) > 0.0 {
      count += 1
    }
  }
  count
}

///|
pub fn rest_day_count(records : Array[DailyRecord]) -> Int {
  records.length() - training_day_count(records)
}

///|
pub fn acute_load_sum(
  records : Array[DailyRecord],
  end_idx : Int,
  window_size : Int,
) -> Double {
  total_load_values(
    get_window_by_index(records, end_idx, window_size).map(r => {
      daily_training_load(r)
    }),
  )
}

///|
pub fn chronic_load_average(
  records : Array[DailyRecord],
  end_idx : Int,
  window_size : Int,
) -> Double {
  let window = get_window_by_index(records, end_idx, window_size)
  if window.length() == 0 {
    0.0
  } else {
    average_load(window)
  }
}

///|
pub fn acwr_at(
  records : Array[DailyRecord],
  end_idx : Int,
  acute_window : Int,
  chronic_window : Int,
) -> Double {
  let acute = chronic_load_average(records, end_idx, acute_window)
  let chronic = chronic_load_average(records, end_idx, chronic_window)
  safe_ratio(acute, chronic)
}

///|
pub fn ewma(values : ArrayView[Double], decay : Double) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let weight = if decay < 0.0 { 0.0 } else if decay > 1.0 { 1.0 } else { decay }
  let mut result = values[0]
  for i in 1..<values.length() {
    result = weight * values[i] + (1.0 - weight) * result
  }
  result
}

///|
pub fn rolling_metric(
  records : Array[DailyRecord],
  window_size : Int,
  window : LoadWindow,
) -> Array[Double] {
  let output = Array::new(capacity=records.length())
  for i in 0..<records.length() {
    let slice = get_window_by_index(records, i, window_size)
    let values = slice.map(r => daily_training_load(r))
    let value = match window {
      Sum => total_load_values(values)
      Average => mean_load_values(values)
      ExponentiallyWeighted(decay~) => ewma(values, decay)
    }
    output.push(value)
  }
  output
}

///|
pub fn workload_monotony(values : ArrayView[Double]) -> Double {
  let deviation = standard_deviation_values(values)
  if deviation == 0.0 {
    if mean_load_values(values) == 0.0 {
      0.0
    } else {
      100.0
    }
  } else {
    mean_load_values(values) / deviation
  }
}

///|
pub fn workload_strain(values : ArrayView[Double]) -> Double {
  total_load_values(values) * workload_monotony(values)
}

///|
pub fn workload_ramp_rate(
  records : Array[DailyRecord],
  end_idx : Int,
  recent_window : Int,
  baseline_window : Int,
) -> Double {
  if end_idx < 0 ||
    end_idx >= records.length() ||
    recent_window <= 0 ||
    baseline_window <= 0 {
    return 0.0
  }
  let recent = chronic_load_average(records, end_idx, recent_window)
  let baseline_end = end_idx - recent_window
  if baseline_end < 0 {
    return 0.0
  }
  let baseline = chronic_load_average(records, baseline_end, baseline_window)
  safe_ratio(recent - baseline, baseline)
}

///|
pub fn workload_percentile(
  values : ArrayView[Double],
  value : Double,
) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let below = values.filter(item => item <= value).length()
  below.to_double() / values.length().to_double() * 100.0
}

///|
pub fn load_z_score(values : ArrayView[Double], value : Double) -> Double {
  let deviation = standard_deviation_values(values)
  if deviation == 0.0 {
    0.0
  } else {
    (value - mean_load_values(values)) / deviation
  }
}

///|
pub fn consecutive_training_days(records : Array[DailyRecord]) -> Array[Int] {
  let runs = []
  let mut current = 0
  for record in records {
    if daily_training_load(record) > 0.0 {
      current += 1
    } else {
      if current > 0 {
        runs.push(current)
      }
      current = 0
    }
  }
  if current > 0 {
    runs.push(current)
  }
  runs
}

///|
pub fn longest_training_block(records : Array[DailyRecord]) -> Int {
  let runs = consecutive_training_days(records)
  maximum_load_values(runs.map(value => value.to_double())).to_int()
}

///|
pub fn load_trend(values : ArrayView[Double], tolerance : Double) -> LoadTrend {
  if values.length() < 2 {
    return InsufficientData
  }
  let first = values[0]
  let last = values[values.length() - 1]
  let change = last - first
  let limit = if tolerance < 0.0 { 0.0 } else { tolerance }
  if change > limit {
    return Rising
  }
  if change < -limit {
    return Falling
  }
  let mut direction_changes = 0
  for i in 2..<values.length() {
    let previous_delta = values[i - 1] - values[i - 2]
    let current_delta = values[i] - values[i - 1]
    if previous_delta * current_delta < 0.0 {
      direction_changes += 1
    }
  }
  if direction_changes >= values.length() / 2 {
    Volatile
  } else {
    Stable
  }
}

///|
pub fn summarize_load(
  records : Array[DailyRecord],
  end_idx : Int,
  acute_window : Int,
  chronic_window : Int,
  baseline_window : Int,
) -> LoadSummary {
  let values = training_loads(records)
  let acute = chronic_load_average(records, end_idx, acute_window)
  let chronic = chronic_load_average(records, end_idx, chronic_window)
  let ramp = workload_ramp_rate(records, end_idx, acute_window, baseline_window)
  {
    sample_count: records.length(),
    training_days: training_day_count(records),
    rest_days: rest_day_count(records),
    total_load: total_load_values(values),
    average_load: mean_load_values(values),
    minimum_load: minimum_load_values(values),
    maximum_load: maximum_load_values(values),
    standard_deviation: standard_deviation_values(values),
    coefficient_of_variation: coefficient_of_variation_values(values),
    monotony: workload_monotony(values),
    strain: workload_strain(values),
    acute_load: acute,
    chronic_load: chronic,
    acwr: safe_ratio(acute, chronic),
    ramp_rate: ramp,
  }
}

///|
pub fn summarize_load_window(
  records : Array[DailyRecord],
  window_size : Int,
) -> LoadSummary {
  let index = records.length() - 1
  summarize_load(records, index, window_size, window_size, window_size)
}
