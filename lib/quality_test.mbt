///|
test "quality report catches invalid and missing telemetry" {
  let invalid : Array[DailyRecord] = [
    DailyRecord::{
      date: "2026-02-30",
      training_duration: -1.0,
      training_intensity: 11.0,
      pain_level: 12.0,
      pain_site: None,
      sleep_hours: 30.0,
      sleep_quality: 6.0,
      fatigue: 11.0,
    },
  ]
  let report = validate_records(invalid, default_quality_policy())
  assert_true(report.blocking_issue_count >= 6)
  assert_true(has_blocking_quality_issue(report))
  assert_eq(quality_band(report.score), "poor")
  let valid = generate_healthy_athlete()
  let gaps = valid.filter(record => record.date != "2026-08-10")
  assert_eq(missing_dates(gaps).length(), 1)
  assert_eq(fill_missing_records(gaps, 8.0).length(), 30)
}

///|
test "quality normalization is stable" {
  let records = generate_healthy_athlete()
  let duplicate = records[0]
  let combined = [duplicate, records[0], records[1]]
  let normalized = normalize_records(combined)
  assert_eq(normalized.length(), 2)
  assert_eq(completeness_ratio(normalized), 1.0)
}
