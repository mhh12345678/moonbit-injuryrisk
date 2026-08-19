///|
/// Direction of a metric across an ordered observation series.
pub(all) enum TrendDirection {
  Improving
  Worsening
  Stable
  Oscillating
  Unknown
} derive(Debug, Eq, ToJson)

///|
pub(all) struct TrendPoint {
  index : Int
  value : Double
  delta : Double
  percent_change : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct TrendSummary {
  sample_count : Int
  first_value : Double
  last_value : Double
  minimum : Double
  maximum : Double
  mean : Double
  slope : Double
  intercept : Double
  r_squared : Double
  percent_change : Double
  direction : TrendDirection
  turning_points : Int
} derive(Debug, Eq, ToJson)

///|
fn trend_ratio(first : Double, last : Double) -> Double {
  if first == 0.0 {
    if last == 0.0 {
      0.0
    } else {
      100.0
    }
  } else {
    (last - first) / first * 100.0
  }
}

///|
pub fn percentage_change(first : Double, last : Double) -> Double {
  trend_ratio(first, last)
}

///|
pub fn moving_average(
  values : ArrayView[Double],
  window_size : Int,
) -> Array[Double] {
  let output = []
  if window_size <= 0 {
    return output
  }
  for index in 0..<values.length() {
    let start = if index - window_size + 1 < 0 {
      0
    } else {
      index - window_size + 1
    }
    output.push(mean_load_values(values[start:index + 1]))
  }
  output
}

///|
pub fn first_differences(values : ArrayView[Double]) -> Array[Double] {
  let deltas = []
  if values.length() < 2 {
    return deltas
  }
  for index in 1..<values.length() {
    deltas.push(values[index] - values[index - 1])
  }
  deltas
}

///|
pub fn trend_points(values : ArrayView[Double]) -> Array[TrendPoint] {
  let points = []
  for index, value in values {
    let previous = if index == 0 { value } else { values[index - 1] }
    points.push({
      index,
      value,
      delta: value - previous,
      percent_change: trend_ratio(previous, value),
    })
  }
  points
}

///|
pub fn linear_slope(values : ArrayView[Double]) -> Double {
  let n = values.length()
  if n < 2 {
    return 0.0
  }
  let x_mean = (n - 1).to_double() / 2.0
  let y_mean = mean_load_values(values)
  let mut numerator = 0.0
  let mut denominator = 0.0
  for index in 0..<n {
    let x = index.to_double()
    numerator += (x - x_mean) * (values[index] - y_mean)
    denominator += (x - x_mean) * (x - x_mean)
  }
  if denominator == 0.0 {
    0.0
  } else {
    numerator / denominator
  }
}

///|
pub fn linear_intercept(values : ArrayView[Double]) -> Double {
  if values.length() == 0 {
    0.0
  } else {
    mean_load_values(values) -
    linear_slope(values) * (values.length() - 1).to_double() / 2.0
  }
}

///|
pub fn predicted_value(values : ArrayView[Double], index : Int) -> Double {
  linear_slope(values) * index.to_double() + linear_intercept(values)
}

///|
pub fn r_squared(values : ArrayView[Double]) -> Double {
  if values.length() < 2 {
    return 0.0
  }
  let mean = mean_load_values(values)
  let mut total = 0.0
  let mut residual = 0.0
  for index in 0..<values.length() {
    let difference = values[index] - mean
    total += difference * difference
    let error = values[index] - predicted_value(values, index)
    residual += error * error
  }
  if total == 0.0 {
    1.0
  } else {
    1.0 - residual / total
  }
}

///|
pub fn turning_point_count(
  values : ArrayView[Double],
  tolerance : Double,
) -> Int {
  if values.length() < 3 {
    return 0
  }
  let mut count = 0
  let limit = if tolerance < 0.0 { 0.0 } else { tolerance }
  for index in 1..<(values.length() - 1) {
    let previous = values[index] - values[index - 1]
    let next = values[index + 1] - values[index]
    if previous.abs() > limit && next.abs() > limit && previous * next < 0.0 {
      count += 1
    }
  }
  count
}

///|
pub fn classify_trend(
  values : ArrayView[Double],
  slope_threshold : Double,
  turning_point_limit : Int,
) -> TrendDirection {
  if values.length() < 2 {
    return Unknown
  }
  let slope = linear_slope(values)
  let limit = if slope_threshold < 0.0 { 0.0 } else { slope_threshold }
  let turns = turning_point_count(values, limit)
  if turns > turning_point_limit {
    Oscillating
  } else if slope > limit {
    Improving
  } else if slope < -limit {
    Worsening
  } else {
    Stable
  }
}

///|
pub fn trend_direction_name(direction : TrendDirection) -> String {
  match direction {
    Improving => "improving"
    Worsening => "worsening"
    Stable => "stable"
    Oscillating => "oscillating"
    Unknown => "unknown"
  }
}

///|
pub fn summarize_trend(
  values : ArrayView[Double],
  slope_threshold : Double,
  turning_point_limit : Int,
) -> TrendSummary {
  let first = if values.length() == 0 { 0.0 } else { values[0] }
  let last = if values.length() == 0 {
    0.0
  } else {
    values[values.length() - 1]
  }
  {
    sample_count: values.length(),
    first_value: first,
    last_value: last,
    minimum: minimum_load_values(values),
    maximum: maximum_load_values(values),
    mean: mean_load_values(values),
    slope: linear_slope(values),
    intercept: linear_intercept(values),
    r_squared: r_squared(values),
    percent_change: trend_ratio(first, last),
    direction: classify_trend(values, slope_threshold, turning_point_limit),
    turning_points: turning_point_count(values, slope_threshold),
  }
}

///|
pub fn compare_trends(
  left : ArrayView[Double],
  right : ArrayView[Double],
) -> Double {
  if left.length() == 0 || right.length() == 0 {
    0.0
  } else {
    linear_slope(right) - linear_slope(left)
  }
}

///|
pub fn exponential_smoothing(
  values : ArrayView[Double],
  alpha : Double,
) -> Array[Double] {
  let output = []
  if values.length() == 0 {
    return output
  }
  let weight = if alpha < 0.0 { 0.0 } else if alpha > 1.0 { 1.0 } else { alpha }
  let mut current = values[0]
  output.push(current)
  for index in 1..<values.length() {
    current = weight * values[index] + (1.0 - weight) * current
    output.push(current)
  }
  output
}

///|
pub fn robust_median(values : ArrayView[Double]) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let sorted = values.to_owned()
  sorted.sort()
  let middle = sorted.length() / 2
  if sorted.length() % 2 == 0 {
    (sorted[middle - 1] + sorted[middle]) / 2.0
  } else {
    sorted[middle]
  }
}

///|
pub fn median_absolute_deviation(values : ArrayView[Double]) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let median = robust_median(values)
  robust_median(values.map(value => (value - median).abs()))
}

///|
pub fn outlier_indices(
  values : ArrayView[Double],
  z_limit : Double,
) -> Array[Int] {
  let indices = []
  let median = robust_median(values)
  let deviation = median_absolute_deviation(values)
  let limit = if z_limit < 0.0 { 0.0 } else { z_limit }
  if deviation == 0.0 {
    return indices
  }
  for index in 0..<values.length() {
    if (values[index] - median).abs() / deviation > limit {
      indices.push(index)
    }
  }
  indices
}

///|
pub fn trend_summary_text(summary : TrendSummary) -> String {
  "trend=" +
  trend_direction_name(summary.direction) +
  " change=" +
  summary.percent_change.to_string() +
  "%" +
  " slope=" +
  summary.slope.to_string() +
  " r2=" +
  summary.r_squared.to_string()
}
