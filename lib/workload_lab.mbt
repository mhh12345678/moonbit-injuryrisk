///|
/// Training load distribution indicators for coach-facing analysis.
pub(all) struct WorkloadDistribution {
  total_load : Double
  low_intensity_load : Double
  moderate_intensity_load : Double
  high_intensity_load : Double
  low_share : Double
  moderate_share : Double
  high_share : Double
  hard_easy_ratio : Double
  session_density : Double
  training_days : Int
  rest_days : Int
} derive(Debug, Eq, ToJson)

///|
pub(all) struct LoadBand {
  lower : Double
  upper : Double
  count : Int
  total_load : Double
} derive(Debug, Eq, ToJson)

///|
fn share(value : Double, total : Double) -> Double {
  if total == 0.0 {
    0.0
  } else {
    value / total * 100.0
  }
}

///|
pub fn low_intensity(
  records : Array[DailyRecord],
  upper : Double,
) -> Array[DailyRecord] {
  records.filter(record => record.training_intensity < upper)
}

///|
pub fn moderate_intensity(
  records : Array[DailyRecord],
  lower : Double,
  upper : Double,
) -> Array[DailyRecord] {
  records.filter(record => {
    record.training_intensity >= lower && record.training_intensity < upper
  })
}

///|
pub fn high_intensity(
  records : Array[DailyRecord],
  lower : Double,
) -> Array[DailyRecord] {
  records.filter(record => record.training_intensity >= lower)
}

///|
pub fn hard_easy_ratio(
  records : Array[DailyRecord],
  hard_threshold : Double,
  easy_threshold : Double,
) -> Double {
  let hard = total_load_values(
    training_loads(high_intensity(records, hard_threshold)),
  )
  let easy = total_load_values(
    training_loads(low_intensity(records, easy_threshold)),
  )
  if easy == 0.0 {
    if hard == 0.0 {
      0.0
    } else {
      100.0
    }
  } else {
    hard / easy
  }
}

///|
pub fn summarize_workload_distribution(
  records : Array[DailyRecord],
  easy_upper : Double,
  hard_lower : Double,
) -> WorkloadDistribution {
  let low = low_intensity(records, easy_upper)
  let high = high_intensity(records, hard_lower)
  let moderate = moderate_intensity(records, easy_upper, hard_lower)
  let total = total_load_values(training_loads(records))
  {
    total_load: total,
    low_intensity_load: total_load_values(training_loads(low)),
    moderate_intensity_load: total_load_values(training_loads(moderate)),
    high_intensity_load: total_load_values(training_loads(high)),
    low_share: share(total_load_values(training_loads(low)), total),
    moderate_share: share(total_load_values(training_loads(moderate)), total),
    high_share: share(total_load_values(training_loads(high)), total),
    hard_easy_ratio: hard_easy_ratio(records, hard_lower, easy_upper),
    session_density: if records.length() == 0 {
      0.0
    } else {
      total / records.length().to_double()
    },
    training_days: training_day_count(records),
    rest_days: rest_day_count(records),
  }
}

///|
pub fn load_bands(
  records : Array[DailyRecord],
  boundaries : Array[Double],
) -> Array[LoadBand] {
  let bands = []
  if boundaries.length() < 2 {
    return bands
  }
  for index in 0..<(boundaries.length() - 1) {
    let lower = boundaries[index]
    let upper = boundaries[index + 1]
    let selected = records.filter(record => {
      let value = record.training_intensity
      value >= lower && value < upper
    })
    bands.push({
      lower,
      upper,
      count: selected.length(),
      total_load: total_load_values(training_loads(selected)),
    })
  }
  bands
}

///|
pub fn high_intensity_day_ratio(
  records : Array[DailyRecord],
  threshold : Double,
) -> Double {
  if records.length() == 0 {
    0.0
  } else {
    high_intensity(records, threshold).length().to_double() /
    records.length().to_double()
  }
}

///|
pub fn load_concentration(
  records : Array[DailyRecord],
  top_days : Int,
) -> Double {
  let values = training_loads(records)
  let sorted = values.copy()
  sorted.sort()
  let take = top_days.max(0).min(sorted.length())
  let top = if take == 0 {
    0.0
  } else {
    total_load_values(sorted[sorted.length() - take:])
  }
  let total = total_load_values(values)
  if total == 0.0 {
    0.0
  } else {
    top / total * 100.0
  }
}

///|
pub fn workload_distribution_text(
  distribution : WorkloadDistribution,
) -> String {
  "total=" +
  distribution.total_load.to_string() +
  " low=" +
  distribution.low_share.to_string() +
  "%" +
  " moderate=" +
  distribution.moderate_share.to_string() +
  "%" +
  " high=" +
  distribution.high_share.to_string() +
  "%" +
  " hard_easy=" +
  distribution.hard_easy_ratio.to_string() +
  " rest_days=" +
  distribution.rest_days.to_string()
}
