///|
test "load metrics zero and short-window boundaries" {
  let empty : Array[DailyRecord] = []
  assert_eq(average_load(empty), 0.0)
  assert_eq(acute_load_sum(empty, 0, 7), 0.0)
  assert_eq(ewma([], 0.5), 0.0)
  assert_eq(workload_monotony([]), 0.0)
  assert_eq(workload_percentile([], 1.0), 0.0)
  let records = generate_healthy_athlete()
  assert_eq(acwr_at(records, 0, 7, 28), 1.0)
  assert_eq(workload_ramp_rate(records, -1, 7, 28), 0.0)
}

///|
test "load metric numerical boundaries" {
  let values : Array[Double] = [0.0, 10.0, 20.0, 30.0]
  assert_eq(total_load_values(values), 60.0)
  assert_eq(mean_load_values(values), 15.0)
  assert_eq(minimum_load_values(values), 0.0)
  assert_eq(maximum_load_values(values), 30.0)
  assert_true(standard_deviation_values(values) > 0.0)
  assert_eq(workload_percentile(values, 20.0), 75.0)
  assert_eq(load_trend(values, 1.0), Rising)
  assert_eq(load_trend([30.0, 20.0, 10.0], 1.0), Falling)
  assert_eq(load_trend([1.0, 1.0, 1.0], 1.0), Stable)
}

///|
test "recovery score and pain boundaries" {
  let healthy = generate_healthy_athlete()
  let weights = default_recovery_weights()
  assert_true(record_recovery_score(healthy[0], weights, 8.0) > 80.0)
  assert_eq(sleep_debt(healthy, 8.0), 0.0)
  assert_eq(pain_free_day_count(healthy), 30)
  let injured = generate_injured_athlete()
  assert_true(max_pain_level(injured) >= 7.0)
  assert_true(summarize_pain(injured, 1.0, 3).persistent_sites.length() > 0)
}
