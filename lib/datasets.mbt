///| Helper to format date string for day index.
fn make_date_string(day_index : Int) -> String {
  let padded = if day_index < 10 {
    "0\{day_index}"
  } else {
    "\{day_index}"
  }
  "2026-08-\{padded}"
}

///| Generate 30 days of data for a healthy athlete with balanced workload and recovery.
pub fn generate_healthy_athlete() -> Array[DailyRecord] {
  let records = []
  for day in 1..=30 {
    records.push({
      date: make_date_string(day),
      training_duration: 45.0,
      training_intensity: 5.0, // load = 225.0
      pain_level: 0.0,
      pain_site: None,
      sleep_hours: 8.0,
      sleep_quality: 4.0,
      fatigue: 3.0
    })
  }
  records
}

///| Generate 30 days of data demonstrating a sudden spike in training workload in the final week.
pub fn generate_workload_spike_athlete() -> Array[DailyRecord] {
  let records = []
  // Days 1 to 23: Baseline workload
  for day in 1..=23 {
    records.push({
      date: make_date_string(day),
      training_duration: 30.0,
      training_intensity: 4.0, // load = 120.0
      pain_level: 0.0,
      pain_site: None,
      sleep_hours: 7.5,
      sleep_quality: 4.0,
      fatigue: 3.0
    })
  }
  // Days 24 to 30: Workload spike
  for day in 24..=30 {
    records.push({
      date: make_date_string(day),
      training_duration: 90.0,
      training_intensity: 8.0, // load = 720.0
      pain_level: 1.0,
      pain_site: Some("Left Calf"),
      sleep_hours: 7.0,
      sleep_quality: 3.5,
      fatigue: 5.0
    })
  }
  records
}

///| Generate 30 days of data demonstrating sleep deprivation and high subjective fatigue.
pub fn generate_overtired_athlete() -> Array[DailyRecord] {
  let records = []
  // Days 1 to 23: Good sleep and recovery
  for day in 1..=23 {
    records.push({
      date: make_date_string(day),
      training_duration: 40.0,
      training_intensity: 5.0,
      pain_level: 0.0,
      pain_site: None,
      sleep_hours: 8.0,
      sleep_quality: 4.5,
      fatigue: 3.0
    })
  }
  // Days 24 to 30: Sleep deprivation and exhaustion
  for day in 24..=30 {
    records.push({
      date: make_date_string(day),
      training_duration: 40.0,
      training_intensity: 5.0,
      pain_level: 0.0,
      pain_site: None,
      sleep_hours: 5.0, // Deprived
      sleep_quality: 2.0, // Poor quality
      fatigue: 8.0 // High subjective fatigue
    })
  }
  records
}

///| Generate 30 days of data demonstrating rising joint/muscle pain.
pub fn generate_injured_athlete() -> Array[DailyRecord] {
  let records = []
  // Days 1 to 25: Baseline training, minimal pain
  for day in 1..=25 {
    records.push({
      date: make_date_string(day),
      training_duration: 50.0,
      training_intensity: 5.0,
      pain_level: 0.5,
      pain_site: None,
      sleep_hours: 7.8,
      sleep_quality: 4.0,
      fatigue: 3.0
    })
  }
  // Days 26 to 30: Sudden onset of severe knee pain
  for day in 26..=30 {
    records.push({
      date: make_date_string(day),
      training_duration: 30.0,
      training_intensity: 4.0,
      pain_level: 7.0, // Severe pain
      pain_site: Some("Right Patellar Tendon"),
      sleep_hours: 6.5,
      sleep_quality: 3.0,
      fatigue: 5.0
    })
  }
  records
}

///| Get a default list of rule configurations for athlete risk stratification.
pub fn get_default_rules() -> Array[Rule] {
  [
    {
      name: "ACWR Danger Spike",
      metric: Metric::ACWR,
      op: Operator::GreaterThan,
      threshold: 1.5,
      window_size: 28,
      severity: RiskLevel::High,
      description: "Acute training load is significantly higher than chronic baseline, posing high injury risk."
    },
    {
      name: "Severe Sleep Deprivation",
      metric: Metric::SleepHours,
      op: Operator::LessThan,
      threshold: 6.0,
      window_size: 7,
      severity: RiskLevel::High,
      description: "Rolling 7-day average sleep duration falls below 6 hours, critical for healing and cognitive alert."
    },
    {
      name: "Moderate Sleep Deficiency",
      metric: Metric::SleepHours,
      op: Operator::LessThan,
      threshold: 7.0,
      window_size: 7,
      severity: RiskLevel::Medium,
      description: "Rolling 7-day average sleep duration is below the target 7 hours."
    },
    {
      name: "High Localized Pain",
      metric: Metric::PainLevel,
      op: Operator::GreaterThan,
      threshold: 4.0,
      window_size: 3,
      severity: RiskLevel::High,
      description: "Athlete reports a localized pain score exceeding 4.0 within the last 3 days."
    },
    {
      name: "Extreme Subjective Fatigue",
      metric: Metric::FatigueLevel,
      op: Operator::GreaterThan,
      threshold: 7.0,
      window_size: 7,
      severity: RiskLevel::Medium,
      description: "Rolling 7-day subjective fatigue level is elevated (above 7.0)."
    },
    {
      name: "Workload Spike (Week-over-Week)",
      metric: Metric::LoadSpike,
      op: Operator::GreaterThan,
      threshold: 50.0,
      window_size: 7,
      severity: RiskLevel::Medium,
      description: "Training load has increased by more than 50% compared to the previous week."
    }
  ]
}
