///|
test "policy and comprehensive assessment boundary paths" {
  let healthy = generate_healthy_athlete()
  let policy = default_risk_policy()
  let assessment = assess_latest(healthy, policy).unwrap()
  assert_eq(assessment.risk_level, Low)
  assert_true(assessment.readiness_score >= 0.0)
  assert_true(assessment.readiness_score <= 100.0)
  assert_true(
    assessment_summary(
      assessment.date,
      assessment.risk_level,
      assessment.risk_score,
      assessment.readiness_score,
      assessment.load,
      assessment.recovery,
      assessment.signals.signal_count,
    ) !=
    "",
  )
  let missing = assess_comprehensive(healthy, "2026-09-01", policy)
  assert_true(missing is None)
  let decisions = evaluate_policy(healthy, healthy.length() - 1, policy)
  assert_eq(decisions.length(), policy.rules.length())
  assert_true(highest_policy_risk(decisions) is Low)
  assert_true(check_assessment_contract(assessment).passed)
}

///|
test "csv ingestion and workflow failure paths" {
  assert_eq(parse_decimal_value("60"), Some(60.0))
  assert_eq(parse_decimal_value("7.5"), Some(7.5))
  assert_eq(csv_fields("2026-08-01,60,6,360,0,,8,4,2").length(), 9)
  let csv =
    #|date,training_duration,training_intensity,load,pain_level,pain_site,sleep_hours,sleep_quality,fatigue
    #|2026-08-01,60,6,360,0,,8,4,2
    #|2026-08-02,30,4,120,1,"left, calf",7.5,3,4
  let result = parse_telemetry_csv(csv)
  assert_true(csv_is_usable(result))
  assert_eq(result.records.length(), 2)
  assert_eq(result.issues.length(), 0)
  let workflow = run_csv_workflow(csv, default_workflow_config())
  assert_true(workflow.assessment is Some(_))
  assert_true(workflow.report is Some(_))
  assert_eq(workflow_stage_status(workflow).length(), 5)
  let bad = parse_telemetry_csv("date,training_duration\n2026-08-01,-\n")
  assert_true(bad.issues.length() > 0)
  assert_true(!csv_is_usable(bad))
}

///|
test "scenario, plan, timeline, cohort and report APIs" {
  let policy = default_risk_policy()
  let spike = generate_scenario(WorkloadSpike, 30)
  let spike_assessment = assess_latest(spike, policy).unwrap()
  assert_true(
    spike_assessment.risk_level == High || spike_assessment.risk_level == Medium,
  )
  assert_true(
    scenario_matches_expectation(WorkloadSpike, Some(spike_assessment)),
  )
  let timeline = build_timeline(spike, policy)
  assert_eq(timeline.points.length(), 30)
  assert_true(timeline.high_risk_days > 0 || timeline.medium_risk_days > 0)
  let plan = build_training_plan(
    "demo",
    "2026-09-01",
    Build,
    500.0,
    7,
    policy,
    spike,
  )
  assert_eq(plan.days.length(), 7)
  assert_true(plan_rest_days(plan).length() > 0)
  let report = summarize_cohort(
    [
      athlete_series("a", spike),
      athlete_series("b", generate_healthy_athlete()),
    ],
    policy,
  )
  assert_eq(report.athlete_count, 2)
  assert_eq(report.screened_count, 2)
  let rendered = render_assessment(spike_assessment, default_report_options())
  assert_true(rendered.body.length() > 100)
  assert_true(
    report_for_records(
      spike,
      spike[spike.length() - 1].date,
      policy,
      default_report_options(),
    )
    is Some(_),
  )
}

///|
test "store session decision and contract APIs" {
  let records = generate_healthy_athlete()
  let store = new_telemetry_store(records, default_quality_policy())
  assert_true(store_is_continuous(store))
  assert_true(record_at_date(store, "2026-08-01") is Some(_))
  let replaced = replace_record(store, { ..records[0], training_intensity: 6.0 })
  assert_true(replaced.1.accepted)
  let sessions = sessions_from_records(records, Endurance)
  assert_eq(summarize_sessions(sessions, 7.0).session_count, records.length())
  let decision = decision_for_records(records, default_risk_policy()).unwrap()
  assert_true(decision.allowed_load_change >= -100.0)
  assert_true(contract_report_passes(check_record_contract(records)))
  assert_true(project_summary(records).length() > 0)
}
