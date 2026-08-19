///|
/// Numeric utilities shared by policy and dashboard calculations.
pub(all) struct WeightedValue {
  value : Double
  weight : Double
} derive(Debug, Eq, ToJson)

///|
pub fn bounded(value : Double, minimum : Double, maximum : Double) -> Double {
  if minimum > maximum {
    minimum
  } else if value < minimum {
    minimum
  } else if value > maximum {
    maximum
  } else {
    value
  }
}

///|
pub fn normalize(value : Double, minimum : Double, maximum : Double) -> Double {
  if maximum <= minimum {
    0.0
  } else {
    bounded((value - minimum) / (maximum - minimum), 0.0, 1.0)
  }
}

///|
pub fn weighted_average(values : ArrayView[WeightedValue]) -> Double {
  let mut total = 0.0
  let mut weights = 0.0
  for item in values {
    if item.weight > 0.0 {
      total += item.value * item.weight
      weights += item.weight
    }
  }
  if weights == 0.0 {
    0.0
  } else {
    total / weights
  }
}

///|
pub fn weighted_risk_level(score : Double) -> RiskLevel {
  if score >= 66.67 {
    High
  } else if score >= 33.34 {
    Medium
  } else {
    Low
  }
}

///|
pub fn geometric_mean(values : ArrayView[Double]) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let mut product = 1.0
  for value in values {
    if value <= 0.0 {
      return 0.0
    }
    product *= value
  }
  @math.pow(product, 1.0 / values.length().to_double())
}

///|
pub fn harmonic_mean(values : ArrayView[Double]) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let mut denominator = 0.0
  for value in values {
    if value <= 0.0 {
      return 0.0
    }
    denominator += 1.0 / value
  }
  values.length().to_double() / denominator
}

///|
pub fn quantile(values : ArrayView[Double], fraction : Double) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let sorted = values.to_owned()
  sorted.sort()
  let position = bounded(fraction, 0.0, 1.0) * (sorted.length() - 1).to_double()
  let lower = position.to_int()
  let upper = lower.min(sorted.length() - 1)
  if lower == upper {
    sorted[lower]
  } else {
    sorted[lower] +
    (sorted[upper] - sorted[lower]) * (position - lower.to_double())
  }
}

///|
pub fn interquartile_range(values : ArrayView[Double]) -> Double {
  quantile(values, 0.75) - quantile(values, 0.25)
}

///|
pub fn mean_absolute_error(
  actual : ArrayView[Double],
  predicted : ArrayView[Double],
) -> Double {
  let count = actual.length().min(predicted.length())
  if count == 0 {
    0.0
  } else {
    let mut total = 0.0
    for index in 0..<count {
      total += (actual[index] - predicted[index]).abs()
    }
    total / count.to_double()
  }
}

///|
pub fn root_mean_square_error(
  actual : ArrayView[Double],
  predicted : ArrayView[Double],
) -> Double {
  let count = actual.length().min(predicted.length())
  if count == 0 {
    0.0
  } else {
    let mut total = 0.0
    for index in 0..<count {
      let error = actual[index] - predicted[index]
      total += error * error
    }
    (total / count.to_double()).sqrt()
  }
}

///|
pub fn covariance(
  left : ArrayView[Double],
  right : ArrayView[Double],
) -> Double {
  let count = left.length().min(right.length())
  if count == 0 {
    return 0.0
  }
  let left_mean = mean_load_values(left[:count])
  let right_mean = mean_load_values(right[:count])
  let mut total = 0.0
  for index in 0..<count {
    total += (left[index] - left_mean) * (right[index] - right_mean)
  }
  total / count.to_double()
}

///|
pub fn correlation(
  left : ArrayView[Double],
  right : ArrayView[Double],
) -> Double {
  let denominator = standard_deviation_values(left) *
    standard_deviation_values(right)
  if denominator == 0.0 {
    0.0
  } else {
    covariance(left, right) / denominator
  }
}

///|
pub fn score_distance(
  left : ArrayView[Double],
  right : ArrayView[Double],
) -> Double {
  let count = left.length().min(right.length())
  let mut total = 0.0
  for index in 0..<count {
    let delta = left[index] - right[index]
    total += delta * delta
  }
  total.sqrt()
}

///|
pub fn threshold_breach_count(
  values : ArrayView[Double],
  threshold : Double,
  above : Bool,
) -> Int {
  if above {
    values.filter(value => value > threshold).length()
  } else {
    values.filter(value => value < threshold).length()
  }
}

///|
pub fn numeric_summary(values : ArrayView[Double]) -> String {
  "count=" +
  values.length().to_string() +
  " mean=" +
  mean_load_values(values).to_string() +
  " median=" +
  robust_median(values).to_string() +
  " q1=" +
  quantile(values, 0.25).to_string() +
  " q3=" +
  quantile(values, 0.75).to_string() +
  " sd=" +
  standard_deviation_values(values).to_string()
}
