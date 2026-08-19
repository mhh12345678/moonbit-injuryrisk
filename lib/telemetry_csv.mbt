///|
/// A row-level parse problem from the telemetry CSV adapter.
pub(all) struct CsvParseIssue {
  line : Int
  field : String
  message : String
  raw : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct TelemetryCsvResult {
  records : Array[DailyRecord]
  issues : Array[CsvParseIssue]
  header_detected : Bool
  line_count : Int
} derive(Debug, Eq, ToJson)

///|
fn csv_issue(
  line : Int,
  field : String,
  message : String,
  raw : String,
) -> CsvParseIssue {
  { line, field, message, raw }
}

///|
fn parse_decimal(text : StringView) -> Double? {
  let value = text.trim().to_owned()
  if value == "" {
    return None
  }
  let mut negative = false
  let mut started = false
  let mut decimal = false
  let mut decimal_places = 0
  let mut result = 0.0
  for character in value {
    if character == '-' && !started {
      negative = true
      started = true
    } else if character == '+' && !started {
      started = true
    } else if character == '.' && !decimal {
      decimal = true
      started = true
    } else if character >= '0' && character <= '9' {
      started = true
      result = result * 10.0 + (character.to_int() - '0'.to_int()).to_double()
      if decimal {
        decimal_places += 1
      }
    } else {
      return None
    }
  }
  if !started {
    return None
  }
  let mut scale = 1.0
  for _ in 0..<decimal_places {
    scale *= 10.0
  }
  let output = if decimal_places == 0 { result } else { result / scale }
  Some(if negative { -output } else { output })
}

///|
pub fn parse_decimal_value(text : String) -> Double? {
  parse_decimal(text[:])
}

///|
fn split_csv_fields(line : String) -> Array[String] {
  let fields = []
  let builder = StringBuilder::new()
  let mut quoted = false
  let mut escaped_quote = false
  for character in line {
    if character == '"' {
      if quoted && escaped_quote {
        builder.write_char('"')
        escaped_quote = false
      } else {
        quoted = !quoted
        escaped_quote = quoted
      }
    } else if character == ',' && !quoted {
      fields.push(builder.to_string().trim().to_owned())
      builder.reset()
      escaped_quote = false
    } else {
      builder.write_char(character)
      escaped_quote = false
    }
  }
  fields.push(builder.to_string().trim().to_owned())
  fields
}

///|
pub fn csv_fields(line : String) -> Array[String] {
  split_csv_fields(line)
}

///|
fn parse_csv_record(
  fields : Array[String],
  line : Int,
) -> (DailyRecord?, Array[CsvParseIssue]) {
  let issues = []
  if fields.length() < 9 {
    issues.push(
      csv_issue(line, "row", "expected at least nine columns", fields.join(",")),
    )
    return (None, issues)
  }
  let date = fields[0]
  let duration = parse_decimal(fields[1][:])
  let intensity = parse_decimal(fields[2][:])
  let pain = parse_decimal(fields[4][:])
  let sleep = parse_decimal(fields[6][:])
  let quality = parse_decimal(fields[7][:])
  let fatigue = parse_decimal(fields[8][:])
  let numeric = match (duration, intensity, pain, sleep, quality, fatigue) {
    (
      Some(duration),
      Some(intensity),
      Some(pain),
      Some(sleep),
      Some(quality),
      Some(fatigue),
    ) => Some((duration, intensity, pain, sleep, quality, fatigue))
    _ => None
  }
  match numeric {
    Some(values) =>
      (
        Some({
          date,
          training_duration: values.0,
          training_intensity: values.1,
          pain_level: values.2,
          pain_site: if fields[5] == "" {
            None
          } else {
            Some(fields[5])
          },
          sleep_hours: values.3,
          sleep_quality: values.4,
          fatigue: values.5,
        }),
        issues,
      )
    None => {
      issues.push(
        csv_issue(
          line,
          "numeric_value",
          "one or more numeric fields are invalid",
          fields.join(","),
        ),
      )
      (None, issues)
    }
  }
}

///|
pub fn parse_telemetry_csv(text : String) -> TelemetryCsvResult {
  let records = []
  let issues = []
  let mut header = false
  let mut line_number = 0
  for raw_line in text.split("\n") {
    let line = raw_line.trim().to_owned()
    if line == "" {
      continue
    }
    line_number += 1
    if line_number == 1 &&
      (line.has_prefix("date,") || line.has_prefix("Date,")) {
      header = true
      continue
    }
    let fields = split_csv_fields(line)
    let parsed = parse_csv_record(fields, line_number)
    match parsed.0 {
      Some(record) => records.push(record)
      None => ()
    }
    for issue in parsed.1 {
      issues.push(issue)
    }
  }
  { records, issues, header_detected: header, line_count: line_number }
}

///|
pub fn csv_is_usable(result : TelemetryCsvResult) -> Bool {
  result.records.length() > 0 &&
  result.issues.filter(issue => issue.field == "row").length() == 0
}

///|
pub fn csv_result_text(result : TelemetryCsvResult) -> String {
  "lines=" +
  result.line_count.to_string() +
  " records=" +
  result.records.length().to_string() +
  " issues=" +
  result.issues.length().to_string() +
  " header=" +
  result.header_detected.to_string()
}
