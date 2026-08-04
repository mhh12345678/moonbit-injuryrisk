///| Find the index of the daily record matching the target date.
pub fn find_record_index(records : Array[DailyRecord], target_date : String) -> Int? {
  for i in 0..<records.length() {
    if records[i].date == target_date {
      return Some(i)
    }
  }
  None
}

///| Extract an ArrayView for a sliding window ending at target index.
pub fn get_window_by_index(
  records : Array[DailyRecord],
  end_idx : Int,
  window_size : Int
) -> ArrayView[DailyRecord] {
  if end_idx < 0 || end_idx >= records.length() || window_size <= 0 {
    return records[0:0]
  }
  let start_idx = if end_idx - window_size + 1 < 0 {
    0
  } else {
    end_idx - window_size + 1
  }
  records[start_idx : end_idx + 1]
}

///| Compute the average training load (duration * intensity) over a slice.
pub fn average_load(slice : ArrayView[DailyRecord]) -> Double {
  if slice.length() == 0 {
    return 0.0
  }
  let mut sum = 0.0
  for r in slice {
    sum += r.training_duration * r.training_intensity
  }
  sum / slice.length().to_double()
}

///| Compute average sleep hours over a slice.
pub fn average_sleep_hours(slice : ArrayView[DailyRecord]) -> Double {
  if slice.length() == 0 {
    return 0.0
  }
  let mut sum = 0.0
  for r in slice {
    sum += r.sleep_hours
  }
  sum / slice.length().to_double()
}

///| Compute average sleep quality over a slice.
pub fn average_sleep_quality(slice : ArrayView[DailyRecord]) -> Double {
  if slice.length() == 0 {
    return 0.0
  }
  let mut sum = 0.0
  for r in slice {
    sum += r.sleep_quality
  }
  sum / slice.length().to_double()
}

///| Compute maximum pain level over a slice.
pub fn max_pain_level(slice : ArrayView[DailyRecord]) -> Double {
  if slice.length() == 0 {
    return 0.0
  }
  let mut max_val = 0.0
  for r in slice {
    if r.pain_level > max_val {
      max_val = r.pain_level
    }
  }
  max_val
}

///| Compute average fatigue level over a slice.
pub fn average_fatigue(slice : ArrayView[DailyRecord]) -> Double {
  if slice.length() == 0 {
    return 0.0
  }
  let mut sum = 0.0
  for r in slice {
    sum += r.fatigue
  }
  sum / slice.length().to_double()
}

///| Compute the percentage training load spike comparing the acute window
///| ending at `end_idx` with the preceding week.
pub fn compute_load_spike(records : Array[DailyRecord], end_idx : Int) -> Double {
  if end_idx < 0 || end_idx >= records.length() {
    return 0.0
  }
  // Current week acute load (7 days)
  let current_slice = get_window_by_index(records, end_idx, 7)
  let current_avg = average_load(current_slice)
  
  // Preceding week acute load (7 days prior)
  let prev_end_idx = end_idx - 7
  if prev_end_idx < 0 {
    return 0.0 // Not enough history to calculate a spike
  }
  let prev_slice = get_window_by_index(records, prev_end_idx, 7)
  let prev_avg = average_load(prev_slice)

  if prev_avg == 0.0 {
    if current_avg == 0.0 { 0.0 } else { 100.0 }
  } else {
    (current_avg - prev_avg) / prev_avg * 100.0
  }
}
