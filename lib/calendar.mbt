///|
/// A validated calendar date used by the time-series utilities.
pub(all) struct DateParts {
  year : Int
  month : Int
  day : Int
} derive(Debug, Eq, ToJson)

///|
/// An inclusive date interval.
pub(all) struct DateRange {
  start : DateParts
  end : DateParts
} derive(Debug, Eq, ToJson)

///|
/// Classify the direction of a date comparison.
pub(all) enum DateOrder {
  Before
  Same
  After
} derive(Debug, Eq, ToJson)

///|
fn is_leap_year(year : Int) -> Bool {
  year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)
}

///|
pub fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if is_leap_year(year) { 29 } else { 28 }
    _ => 0
  }
}

///|
pub fn valid_date(date : DateParts) -> Bool {
  date.year >= 1 &&
  date.month >= 1 &&
  date.month <= 12 &&
  date.day >= 1 &&
  date.day <= days_in_month(date.year, date.month)
}

///|
fn digit_at(text : String, index : Int) -> Int? {
  if index < 0 || index >= text.length() {
    return None
  }
  let value = text[index].to_int()
  if value >= '0'.to_int() && value <= '9'.to_int() {
    Some(value - '0'.to_int())
  } else {
    None
  }
}

///|
fn fixed_number(text : String, start : Int, width : Int) -> Int? {
  if width <= 0 || start < 0 || start + width > text.length() {
    return None
  }
  let mut value = 0
  for i in start..<(start + width) {
    match digit_at(text, i) {
      Some(digit) => value = value * 10 + digit
      None => return None
    }
  }
  Some(value)
}

///|
/// Parse an ISO-8601 calendar date in `YYYY-MM-DD` form.
pub fn parse_date(text : String) -> DateParts? {
  if text.length() != 10 || text[4] != '-' || text[7] != '-' {
    return None
  }
  let year = fixed_number(text, 0, 4)
  let month = fixed_number(text, 5, 2)
  let day = fixed_number(text, 8, 2)
  match (year, month, day) {
    (Some(year), Some(month), Some(day)) => {
      let date = { year, month, day }
      if valid_date(date) {
        Some(date)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
pub fn format_date(date : DateParts) -> String {
  let year = if date.year < 10 {
    "000" + date.year.to_string()
  } else if date.year < 100 {
    "00" + date.year.to_string()
  } else if date.year < 1000 {
    "0" + date.year.to_string()
  } else {
    date.year.to_string()
  }
  let month = if date.month < 10 {
    "0" + date.month.to_string()
  } else {
    date.month.to_string()
  }
  let day = if date.day < 10 {
    "0" + date.day.to_string()
  } else {
    date.day.to_string()
  }
  "\{year}-\{month}-\{day}"
}

///|
pub fn compare_dates(left : DateParts, right : DateParts) -> DateOrder {
  if left.year < right.year ||
    (left.year == right.year && left.month < right.month) ||
    (
      left.year == right.year &&
      left.month == right.month &&
      left.day < right.day
    ) {
    Before
  } else if left == right {
    Same
  } else {
    After
  }
}

///|
fn days_before_year(year : Int) -> Int {
  let y = year - 1
  365 * y + y / 4 - y / 100 + y / 400
}

///|
fn days_before_month(year : Int, month : Int) -> Int {
  let mut total = 0
  for value in 1..<month {
    total += days_in_month(year, value)
  }
  total
}

///|
/// Convert a valid date to a monotonically increasing day ordinal.
pub fn date_ordinal(date : DateParts) -> Int {
  days_before_year(date.year) +
  days_before_month(date.year, date.month) +
  date.day -
  1
}

///|
/// Convert a day ordinal produced by `date_ordinal` back to a calendar date.
pub fn ordinal_date(ordinal : Int) -> DateParts? {
  if ordinal < 0 {
    return None
  }
  let mut year = 1
  let mut remaining = ordinal
  let mut year_days = if is_leap_year(year) { 366 } else { 365 }
  while remaining >= year_days {
    remaining -= year_days
    year += 1
    year_days = if is_leap_year(year) { 366 } else { 365 }
  }
  let mut month = 1
  while remaining >= days_in_month(year, month) {
    remaining -= days_in_month(year, month)
    month += 1
  }
  Some({ year, month, day: remaining + 1 })
}

///|
pub fn days_between(left : DateParts, right : DateParts) -> Int {
  date_ordinal(right) - date_ordinal(left)
}

///|
pub fn add_days(date : DateParts, offset : Int) -> DateParts? {
  ordinal_date(date_ordinal(date) + offset)
}

///|
pub fn make_date_range(start : DateParts, end : DateParts) -> DateRange? {
  if !valid_date(start) ||
    !valid_date(end) ||
    compare_dates(start, end) is After {
    None
  } else {
    Some({ start, end })
  }
}

///|
pub fn range_length(range : DateRange) -> Int {
  days_between(range.start, range.end) + 1
}

///|
pub fn dates_in_range(range : DateRange) -> Array[DateParts] {
  let values = Array::new(capacity=range_length(range))
  let mut ordinal = date_ordinal(range.start)
  let end = date_ordinal(range.end)
  while ordinal <= end {
    match ordinal_date(ordinal) {
      Some(date) => values.push(date)
      None => ()
    }
    ordinal += 1
  }
  values
}

///|
pub fn dates_in_records(records : Array[DailyRecord]) -> Array[DateParts] {
  let dates = Array::new(capacity=records.length())
  for record in records {
    match parse_date(record.date) {
      Some(date) => dates.push(date)
      None => ()
    }
  }
  dates
}

///|
pub fn sort_records_by_date(records : Array[DailyRecord]) -> Array[DailyRecord] {
  let sorted = records.copy()
  for i in 1..<sorted.length() {
    let current = sorted[i]
    let mut position = i
    while position > 0 {
      let previous = parse_date(sorted[position - 1].date)
      let current_date = parse_date(current.date)
      if previous is Some(previous) &&
        current_date is Some(current_date) &&
        compare_dates(previous, current_date) is After {
        sorted[position] = sorted[position - 1]
        position -= 1
      } else {
        break
      }
    }
    sorted[position] = current
  }
  sorted
}

///|
pub fn duplicate_date_indices(records : Array[DailyRecord]) -> Array[Int] {
  let duplicates = []
  for i in 0..<records.length() {
    for j in 0..<i {
      if records[i].date == records[j].date {
        duplicates.push(i)
        break
      }
    }
  }
  duplicates
}

///|
pub fn missing_dates(records : Array[DailyRecord]) -> Array[String] {
  if records.length() == 0 {
    return []
  }
  let sorted = sort_records_by_date(records)
  let first = parse_date(sorted[0].date)
  let last = parse_date(sorted[sorted.length() - 1].date)
  let missing = []
  match (first, last) {
    (Some(first), Some(last)) => {
      let known = sorted.map(r => r.date)
      for date in dates_in_range({ start: first, end: last }) {
        let formatted = format_date(date)
        if !known.contains(formatted) {
          missing.push(formatted)
        }
      }
    }
    _ => ()
  }
  missing
}

///|
pub fn date_is_in_range(date : DateParts, range : DateRange) -> Bool {
  !(compare_dates(date, range.start) is Before) &&
  !(compare_dates(date, range.end) is After)
}
