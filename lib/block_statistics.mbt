///|
/// Training-block statistics for planning, review, and longitudinal reporting.
pub(all) struct BlockStatistics {
  start_date : String
  end_date : String
  day_count : Int
  training_days : Int
  recovery_days : Int
  total_load : Double
  average_load : Double
  peak_load : Double
  load_stddev : Double
  monotony : Double
  strain : Double
  average_sleep : Double
  average_recovery : Double
  average_pain : Double
  average_fatigue : Double
  quality_score : Double
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct BlockComparison {
  left : BlockStatistics
  right : BlockStatistics
  load_change : Double
  recovery_change : Double
  sleep_change : Double
  pain_change : Double
  fatigue_change : Double
  strain_change : Double
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
pub fn block_statistics(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> BlockStatistics {
  let sorted = sort_records_by_date(records)
  let loads = training_loads(sorted)
  let assessment = assess_latest(sorted, policy)
  let status = match assessment {
    Some(value) => risk_level_name(value.risk_level)
    None => "empty"
  }
  {
    start_date: if sorted.length() == 0 {
      ""
    } else {
      sorted[0].date
    },
    end_date: if sorted.length() == 0 {
      ""
    } else {
      sorted[sorted.length() - 1].date
    },
    day_count: sorted.length(),
    training_days: training_day_count(sorted),
    recovery_days: rest_day_count(sorted),
    total_load: total_load_values(loads),
    average_load: mean_load_values(loads),
    peak_load: maximum_load_values(loads),
    load_stddev: standard_deviation_values(loads),
    monotony: workload_monotony(loads),
    strain: workload_strain(loads),
    average_sleep: average_sleep_hours(sorted),
    average_recovery: mean_load_values(
      recovery_scores(sorted, policy.recovery_weights, policy.sleep_target),
    ),
    average_pain: mean_load_values(sorted.map(record => record.pain_level)),
    average_fatigue: mean_load_values(sorted.map(record => record.fatigue)),
    quality_score: validate_records(sorted, default_quality_policy()).score,
    status,
  }
}

///|
pub fn block_statistics_for_range(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  range : DateRange,
) -> BlockStatistics {
  block_statistics(records_in_date_range(records, range), policy)
}

///|
pub fn compare_blocks(
  left : BlockStatistics,
  right : BlockStatistics,
) -> BlockComparison {
  let load_change = percentage_change(left.average_load, right.average_load)
  let recovery_change = right.average_recovery - left.average_recovery
  let sleep_change = right.average_sleep - left.average_sleep
  let pain_change = right.average_pain - left.average_pain
  let fatigue_change = right.average_fatigue - left.average_fatigue
  let strain_change = right.strain - left.strain
  {
    left,
    right,
    load_change,
    recovery_change,
    sleep_change,
    pain_change,
    fatigue_change,
    strain_change,
    conclusion: if load_change > 10.0 && recovery_change < -5.0 {
      "load increased and recovery declined"
    } else if load_change < -10.0 && recovery_change > 5.0 {
      "deload improved recovery"
    } else if pain_change > 1.0 || fatigue_change > 1.0 {
      "symptoms increased"
    } else {
      "block change is within a mixed band"
    },
  }
}

///|
pub fn block_load_profile(
  block : BlockStatistics,
  records : Array[DailyRecord],
) -> Array[Double] {
  training_loads(
    records_in_date_range(records, {
      start: parse_date(block.start_date).unwrap(),
      end: parse_date(block.end_date).unwrap(),
    }),
  )
}

///|
pub fn block_load_cv(block : BlockStatistics) -> Double {
  if block.average_load == 0.0 {
    0.0
  } else {
    block.load_stddev / block.average_load
  }
}

///|
pub fn block_training_ratio(block : BlockStatistics) -> Double {
  if block.day_count == 0 {
    0.0
  } else {
    block.training_days.to_double() / block.day_count.to_double()
  }
}

///|
pub fn block_recovery_ratio(block : BlockStatistics) -> Double {
  if block.day_count == 0 {
    0.0
  } else {
    block.recovery_days.to_double() / block.day_count.to_double()
  }
}

///|
pub fn block_sleep_compliance(
  block : BlockStatistics,
  target : Double,
) -> Double {
  if target <= 0.0 {
    0.0
  } else {
    (block.average_sleep / target).min(1.0) * 100.0
  }
}

///|
pub fn block_pain_burden(block : BlockStatistics) -> Double {
  block.average_pain + block.average_fatigue * 0.5
}

///|
pub fn block_is_balanced(block : BlockStatistics) -> Bool {
  block_recovery_ratio(block) >= 0.15 &&
  block.monotony < 2.0 &&
  block_pain_burden(block) < 7.0
}

///|
pub fn block_needs_deload(block : BlockStatistics) -> Bool {
  block.strain > 4000.0 || block.monotony > 2.0 || block.average_recovery < 60.0
}

///|
pub fn block_needs_data_review(block : BlockStatistics) -> Bool {
  block.quality_score < 80.0 || block.day_count < 7
}

///|
pub fn block_recommendation(block : BlockStatistics) -> String {
  if block_needs_data_review(block) {
    "collect or repair block telemetry"
  } else if block_needs_deload(block) {
    "schedule a lower-load block"
  } else if block_is_balanced(block) {
    "block distribution is balanced"
  } else {
    "review load distribution and recovery"
  }
}

///|
pub fn block_status_code(block : BlockStatistics) -> Int {
  match block.status {
    "high" => 3
    "medium" => 2
    "low" => 1
    "empty" => 4
    _ => 0
  }
}

///|
pub fn block_metric(block : BlockStatistics, metric : String) -> Double {
  match metric {
    "load" => block.average_load
    "peak_load" => block.peak_load
    "stddev" => block.load_stddev
    "monotony" => block.monotony
    "strain" => block.strain
    "sleep" => block.average_sleep
    "recovery" => block.average_recovery
    "pain" => block.average_pain
    "fatigue" => block.average_fatigue
    "quality" => block.quality_score
    _ => 0.0
  }
}

///|
pub fn block_metric_names() -> Array[String] {
  [
    "load", "peak_load", "stddev", "monotony", "strain", "sleep", "recovery", "pain",
    "fatigue", "quality",
  ]
}

///|
pub fn block_action_metrics(block : BlockStatistics) -> Array[String] {
  block_metric_names().filter(metric => {
    match metric {
      "monotony" => block.monotony >= 2.0
      "strain" => block.strain >= 4000.0
      "sleep" => block.average_sleep < 7.0
      "recovery" => block.average_recovery < 60.0
      "pain" => block.average_pain > 3.0
      "fatigue" => block.average_fatigue > 6.0
      "quality" => block.quality_score < 80.0
      _ => false
    }
  })
}

///|
pub fn block_summary_text(block : BlockStatistics) -> String {
  block.start_date +
  ".." +
  block.end_date +
  " days=" +
  block.day_count.to_string() +
  " training=" +
  block.training_days.to_string() +
  " recovery=" +
  block.recovery_days.to_string() +
  " load=" +
  block.total_load.to_string() +
  " average=" +
  block.average_load.to_string() +
  " peak=" +
  block.peak_load.to_string() +
  " monotony=" +
  block.monotony.to_string() +
  " strain=" +
  block.strain.to_string() +
  " recovery_score=" +
  block.average_recovery.to_string() +
  " status=" +
  block.status +
  " action=" +
  block_recommendation(block)
}

///|
pub fn block_comparison_text(comparison : BlockComparison) -> String {
  comparison.left.start_date +
  ".." +
  comparison.left.end_date +
  " vs " +
  comparison.right.start_date +
  ".." +
  comparison.right.end_date +
  " load_change=" +
  comparison.load_change.to_string() +
  "% recovery_change=" +
  comparison.recovery_change.to_string() +
  " pain_change=" +
  comparison.pain_change.to_string() +
  " fatigue_change=" +
  comparison.fatigue_change.to_string() +
  " conclusion=" +
  comparison.conclusion
}

///|
pub fn block_csv_header() -> String {
  "start_date,end_date,day_count,training_days,recovery_days,total_load,average_load,peak_load,load_stddev,monotony,strain,average_sleep,average_recovery,average_pain,average_fatigue,quality_score,status"
}

///|
pub fn block_csv(block : BlockStatistics) -> String {
  block.start_date +
  "," +
  block.end_date +
  "," +
  block.day_count.to_string() +
  "," +
  block.training_days.to_string() +
  "," +
  block.recovery_days.to_string() +
  "," +
  block.total_load.to_string() +
  "," +
  block.average_load.to_string() +
  "," +
  block.peak_load.to_string() +
  "," +
  block.load_stddev.to_string() +
  "," +
  block.monotony.to_string() +
  "," +
  block.strain.to_string() +
  "," +
  block.average_sleep.to_string() +
  "," +
  block.average_recovery.to_string() +
  "," +
  block.average_pain.to_string() +
  "," +
  block.average_fatigue.to_string() +
  "," +
  block.quality_score.to_string() +
  "," +
  block.status
}

///|
pub fn blocks_csv(blocks : Array[BlockStatistics]) -> String {
  let builder = StringBuilder::new()
  builder.write_string(block_csv_header())
  for block in blocks {
    builder.write_string("\n")
    builder.write_string(block_csv(block))
  }
  builder.to_string()
}

///|
pub fn block_valid(block : BlockStatistics) -> Bool {
  block.day_count >= 0 &&
  block.training_days >= 0 &&
  block.recovery_days >= 0 &&
  block.total_load >= 0.0 &&
  block.average_load >= 0.0 &&
  block.peak_load >= 0.0 &&
  block.load_stddev >= 0.0 &&
  block.monotony >= 0.0 &&
  block.strain >= 0.0 &&
  block.quality_score >= 0.0 &&
  block.quality_score <= 100.0
}
