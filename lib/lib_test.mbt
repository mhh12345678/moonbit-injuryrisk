///| Test date searching boundary conditions
test "find_record_index boundary cases" {
  let records = generate_healthy_athlete()
  
  // Valid search
  let idx1 = find_record_index(records, "2026-08-15")
  debug_inspect(idx1, content="Some(14)")
  
  // Underflow search
  let idx2 = find_record_index(records, "2026-08-00")
  debug_inspect(idx2, content="None")
  
  // Overflow search
  let idx3 = find_record_index(records, "2026-08-32")
  debug_inspect(idx3, content="None")
}

///| Test sliding window slicing boundaries
test "get_window_by_index slicing logic" {
  let records = generate_healthy_athlete()
  
  // Standard window (7 days) ending at index 14
  let win1 = get_window_by_index(records, 14, 7)
  debug_inspect(win1.length(), content="7")
  debug_inspect(win1[0].date, content="\"2026-08-09\"")
  debug_inspect(win1[6].date, content="\"2026-08-15\"")

  // Truncated window (asking 7 days at start of records)
  let win2 = get_window_by_index(records, 2, 7)
  debug_inspect(win2.length(), content="3")
  debug_inspect(win2[0].date, content="\"2026-08-01\"")
  debug_inspect(win2[2].date, content="\"2026-08-03\"")

  // Out of bounds end index
  let win3 = get_window_by_index(records, -1, 7)
  debug_inspect(win3.length(), content="0")
  
  let win4 = get_window_by_index(records, 30, 7)
  debug_inspect(win4.length(), content="0")

  // Invalid window size
  let win5 = get_window_by_index(records, 10, 0)
  debug_inspect(win5.length(), content="0")
}

///| Test training load averages and ACWR calculation
test "average_load and ACWR math" {
  let records = generate_workload_spike_athlete()
  
  // Stable period (acute load at index 10)
  let acute_stable = get_window_by_index(records, 10, 7)
  let acute_load_stable = average_load(acute_stable)
  debug_inspect(acute_load_stable, content=(
    #|120
  ))

  // Spiked period (acute load at index 29 - final day)
  let acute_spiked = get_window_by_index(records, 29, 7)
  let acute_load_spiked = average_load(acute_spiked)
  debug_inspect(acute_load_spiked, content=(
    #|720
  ))

  // Chronic load at final day (mix of 21 days at 120 and 7 days at 720)
  let chronic_spiked = get_window_by_index(records, 29, 28)
  let chronic_load_spiked = average_load(chronic_spiked)
  debug_inspect(chronic_load_spiked, content=(
    #|270
  ))

  // ACWR calculation on day 30 (index 29)
  let acwr = acute_load_spiked / chronic_load_spiked
  debug_inspect(acwr, content="2.6666666666666665")
}

///| Test rule evaluations against boundary values
test "rule evaluation thresholds" {
  let records = generate_healthy_athlete()
  let rules = get_default_rules()
  
  // Target rule: "Severe Sleep Deprivation" (sleep < 6.0)
  let sleep_rule = rules[1]
  
  // Day 15: sleep is 8.0 (should NOT trigger)
  let res_healthy = evaluate_rule(records, 14, sleep_rule)
  debug_inspect(res_healthy.triggered, content="false")

  // Generate data right at boundary values
  let boundary_records = [
    DailyRecord::{
      date: "2026-08-01",
      training_duration: 0.0,
      training_intensity: 0.0,
      pain_level: 0.0,
      pain_site: None,
      sleep_hours: 6.0, // exactly threshold
      sleep_quality: 5.0,
      fatigue: 1.0
    },
    DailyRecord::{
      date: "2026-08-02",
      training_duration: 0.0,
      training_intensity: 0.0,
      pain_level: 0.0,
      pain_site: None,
      sleep_hours: 5.99, // just below threshold
      sleep_quality: 5.0,
      fatigue: 1.0
    },
    DailyRecord::{
      date: "2026-08-03",
      training_duration: 0.0,
      training_intensity: 0.0,
      pain_level: 0.0,
      pain_site: None,
      sleep_hours: 6.01, // just above threshold
      sleep_quality: 5.0,
      fatigue: 1.0
    }
  ]

  // At 6.0, op is LessThan (6.0 < 6.0 is false)
  let res_boundary = evaluate_rule(boundary_records, 0, sleep_rule)
  debug_inspect(res_boundary.triggered, content="false")

  // At 5.99, op is LessThan (5.99 < 6.0 is true)
  let res_below = evaluate_rule(boundary_records, 1, sleep_rule)
  debug_inspect(res_below.triggered, content="true")

  // At 6.01, op is LessThan (6.01 < 6.0 is false)
  let res_above = evaluate_rule(boundary_records, 2, sleep_rule)
  debug_inspect(res_above.triggered, content="false")
}

///| Test overall risk assessment outputs
test "assess_injury_risk scenarios" {
  let rules = get_default_rules()

  // Scenario 1: Healthy athlete
  let healthy = generate_healthy_athlete()
  let assessment_healthy = assess_injury_risk(healthy, "2026-08-30", rules)
  assert_true(assessment_healthy is Some(_))
  let result_healthy = assessment_healthy.unwrap()
  debug_inspect(result_healthy.risk_level, content="Low")

  // Scenario 2: Workload spike athlete
  let spiked = generate_workload_spike_athlete()
  let assessment_spiked = assess_injury_risk(spiked, "2026-08-30", rules)
  assert_true(assessment_spiked is Some(_))
  let result_spiked = assessment_spiked.unwrap()
  debug_inspect(result_spiked.risk_level, content="High") // High due to ACWR > 1.5 and pain

  // Scenario 3: Overtired athlete
  let tired = generate_overtired_athlete()
  let assessment_tired = assess_injury_risk(tired, "2026-08-30", rules)
  assert_true(assessment_tired is Some(_))
  let result_tired = assessment_tired.unwrap()
  debug_inspect(result_tired.risk_level, content="High") // High due to sleep hours < 6.0

  // Scenario 4: Injured athlete
  let injured = generate_injured_athlete()
  let assessment_injured = assess_injury_risk(injured, "2026-08-30", rules)
  assert_true(assessment_injured is Some(_))
  let result_injured = assessment_injured.unwrap()
  debug_inspect(result_injured.risk_level, content="High") // High due to pain level > 4.0
}
