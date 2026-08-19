///|
test "calendar parser and leap-year boundaries" {
  assert_true(parse_date("2026-02-28") is Some(_))
  assert_true(parse_date("2026-02-29") is None)
  assert_true(parse_date("2024-02-29") is Some(_))
  assert_true(parse_date("2026-04-31") is None)
  assert_true(parse_date("2026/08/01") is None)
  assert_eq(days_in_month(2024, 2), 29)
  assert_eq(days_in_month(2100, 2), 28)
  assert_eq(days_in_month(2000, 2), 29)
}

///|
test "calendar ordinal and range boundaries" {
  let start = parse_date("2026-12-31").unwrap()
  let next = add_days(start, 1).unwrap()
  assert_eq(format_date(next), "2027-01-01")
  let previous = add_days(next, -1).unwrap()
  assert_eq(previous, start)
  assert_eq(days_between(start, next), 1)
  let range = make_date_range(start, next).unwrap()
  assert_eq(range_length(range), 2)
  assert_eq(dates_in_range(range).length(), 2)
  assert_true(make_date_range(next, start) is None)
}

///|
test "record ordering duplicates and missing dates" {
  let records : Array[DailyRecord] = [
    DailyRecord::{
      date: "2026-08-03",
      training_duration: 1.0,
      training_intensity: 1.0,
      pain_level: 0.0,
      pain_site: None,
      sleep_hours: 8.0,
      sleep_quality: 4.0,
      fatigue: 2.0,
    },
    DailyRecord::{
      date: "2026-08-01",
      training_duration: 1.0,
      training_intensity: 1.0,
      pain_level: 0.0,
      pain_site: None,
      sleep_hours: 8.0,
      sleep_quality: 4.0,
      fatigue: 2.0,
    },
    DailyRecord::{
      date: "2026-08-03",
      training_duration: 2.0,
      training_intensity: 2.0,
      pain_level: 0.0,
      pain_site: None,
      sleep_hours: 8.0,
      sleep_quality: 4.0,
      fatigue: 2.0,
    },
  ]
  let sorted = sort_records_by_date(records)
  assert_eq(sorted[0].date, "2026-08-01")
  assert_eq(duplicate_date_indices(records), [2])
  assert_eq(missing_dates(records), ["2026-08-02"])
}
