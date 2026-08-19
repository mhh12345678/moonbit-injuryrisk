///|
test "numeric and forecast boundaries remain finite" {
  let empty : Array[Double] = []
  assert_eq(bounded(-1.0, 0.0, 1.0), 0.0)
  assert_eq(normalize(4.0, 4.0, 4.0), 0.0)
  assert_eq(geometric_mean(empty), 0.0)
  assert_eq(harmonic_mean([0.0, 2.0]), 0.0)
  assert_eq(quantile([1.0, 2.0, 3.0], 2.0), 3.0)
  assert_eq(threshold_breach_count([1.0, 2.0, 3.0], 2.0, true), 1)
  assert_eq(threshold_breach_count([1.0, 2.0, 3.0], 2.0, false), 1)
  let policy = default_risk_policy()
  let forecast = forecast_training([], policy, 0, 50.0)
  assert_eq(forecast.points.length(), 0)
  assert_eq(forecast.minimum_recovery, 0.0)
  assert_true(progression_guardrail([], policy, 0.0).allowed)
}

///|
test "empty workload and adherence paths are explicit" {
  let empty : Array[DailyRecord] = []
  let distribution = summarize_workload_distribution(empty, 5.0, 8.0)
  assert_eq(distribution.training_days, 0)
  assert_eq(distribution.rest_days, 0)
  assert_eq(distribution.total_load, 0.0)
  assert_eq(load_bands(empty, [1.0]).length(), 0)
  assert_eq(high_intensity_day_ratio(empty, 8.0), 0.0)
  assert_eq(load_concentration(empty, 3), 0.0)
  assert_eq(recovery_adherence_percent(empty, 8.0, 4.0), 0.0)
  assert_eq(pain_reporting_percent(empty), 0.0)
  let target = training_target("2026-09-01", 0.0, 0.0, Recovery, true)
  let row = assess_target(target, None, 70.0)
  assert_true(row.status is NotRecorded)
  assert_eq(adherence_report([target], empty, 70.0).not_recorded_count, 1)
}

///|
test "workflow protocol batch and dashboard compose" {
  let records = generate_healthy_athlete()
  let policy = default_risk_policy()
  let workflow = run_workflow(records, default_workflow_config())
  assert_true(workflow_is_accepted(workflow))
  let protocol = run_screening_protocol(
    records,
    default_workflow_config(),
    default_screening_protocol(),
  )
  assert_true(protocol.accepted)
  assert_eq(protocol.steps.length(), 6)
  let plan = propose_microcycle(records, policy, "2026-09-01", 7, 5.0)
  assert_eq(plan.days.length(), 7)
  assert_true(microcycle_rest_ratio(plan) > 0.0)
  assert_true(review_microcycle(plan, records).adherence_percent >= 0.0)
  let batch = batch_report_for_records(records, policy)
  assert_eq(batch.row_count, records.length())
  assert_true(batch_report_csv(batch).contains("risk_level"))
  let assessment = assess_latest(records, policy).unwrap()
  let dashboard = dashboard_snapshot(assessment)
  assert_true(dashboard_snapshot_text(dashboard).contains("status="))
  assert_true(dashboard_csv(dashboard).contains("quality_score"))
  let timeline = build_timeline(records, policy)
  assert_eq(dashboard_range(timeline).start_date, records[0].date)
  let snapshot = project_snapshot(records)
  assert_true(project_snapshot_text(snapshot).contains("status="))
}

///|
test "csv, store and report failures stay observable" {
  let empty_csv = parse_telemetry_csv("")
  assert_true(!csv_is_usable(empty_csv))
  assert_true(csv_result_text(empty_csv).contains("issues="))
  let records = generate_healthy_athlete()
  let store = new_telemetry_store(records, default_quality_policy())
  let removed = remove_record(store, records[10].date)
  assert_true(removed.1.accepted)
  assert_true(!store_is_continuous(removed.0))
  assert_eq(store_retained_dates(removed.0).length(), records.length() - 1)
  let report = quick_report(records)
  assert_true(report.contains("risk="))
  assert_true(library_capabilities().length() >= 6)
  assert_true(project_status(records).length() > 0)
}
