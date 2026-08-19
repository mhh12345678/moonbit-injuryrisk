///|
/// Deterministic record transformations are explicit and reported to callers.
pub(all) enum RecordTransformKind {
  TransformClamp
  TransformSort
  TransformDeduplicate
  TransformFillMissing
  TransformFilterRange
  TransformRepairDates
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RecordTransformRule {
  kind : RecordTransformKind
  enabled : Bool
  minimum_duration : Double
  maximum_duration : Double
  minimum_intensity : Double
  maximum_intensity : Double
  fill_sleep_hours : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RecordTransformLog {
  kind : RecordTransformKind
  input_count : Int
  output_count : Int
  changed_count : Int
  removed_count : Int
  message : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RecordTransformResult {
  records : Array[DailyRecord]
  logs : Array[RecordTransformLog]
  input_count : Int
  output_count : Int
  changed_count : Int
  removed_count : Int
  valid : Bool
  status : String
} derive(Debug, Eq, ToJson)

///|
pub fn default_record_transform_rule() -> RecordTransformRule {
  {
    kind: TransformClamp,
    enabled: true,
    minimum_duration: 0.0,
    maximum_duration: 1440.0,
    minimum_intensity: 0.0,
    maximum_intensity: 10.0,
    fill_sleep_hours: 8.0,
  }
}

///|
pub fn record_transform_kind_name(kind : RecordTransformKind) -> String {
  match kind {
    TransformClamp => "clamp"
    TransformSort => "sort"
    TransformDeduplicate => "deduplicate"
    TransformFillMissing => "fill_missing"
    TransformFilterRange => "filter_range"
    TransformRepairDates => "repair_dates"
  }
}

///|
pub fn record_transform_kinds() -> Array[RecordTransformKind] {
  [
    TransformClamp,
    TransformSort,
    TransformDeduplicate,
    TransformFillMissing,
    TransformFilterRange,
    TransformRepairDates,
  ]
}

///|
pub fn record_transform_rule_valid(rule : RecordTransformRule) -> Bool {
  rule.minimum_duration >= 0.0 &&
  rule.maximum_duration >= rule.minimum_duration &&
  rule.minimum_intensity >= 0.0 &&
  rule.maximum_intensity >= rule.minimum_intensity &&
  rule.fill_sleep_hours >= 0.0 &&
  rule.fill_sleep_hours <= 24.0
}

///|
fn transform_clamp_record(
  record : DailyRecord,
  rule : RecordTransformRule,
) -> DailyRecord {
  {
    date: record.date,
    training_duration: record.training_duration
    .max(rule.minimum_duration)
    .min(rule.maximum_duration),
    training_intensity: record.training_intensity
    .max(rule.minimum_intensity)
    .min(rule.maximum_intensity),
    pain_level: record.pain_level.max(0.0).min(10.0),
    pain_site: record.pain_site,
    sleep_hours: record.sleep_hours.max(0.0).min(24.0),
    sleep_quality: record.sleep_quality.max(0.0).min(5.0),
    fatigue: record.fatigue.max(0.0).min(10.0),
  }
}

///|
fn transform_record_changed(left : DailyRecord, right : DailyRecord) -> Bool {
  left.training_duration != right.training_duration ||
  left.training_intensity != right.training_intensity ||
  left.pain_level != right.pain_level ||
  left.sleep_hours != right.sleep_hours ||
  left.sleep_quality != right.sleep_quality ||
  left.fatigue != right.fatigue
}

///|
fn transform_clamp(
  records : Array[DailyRecord],
  rule : RecordTransformRule,
) -> Array[DailyRecord] {
  records.map(record => transform_clamp_record(record, rule))
}

///|
fn transform_sort(records : Array[DailyRecord]) -> Array[DailyRecord] {
  sort_records_by_date(records)
}

///|
fn transform_deduplicate(records : Array[DailyRecord]) -> Array[DailyRecord] {
  let values = []
  let dates = []
  for record in sort_records_by_date(records) {
    if !dates.contains(record.date) {
      values.push(record)
      dates.push(record.date)
    }
  }
  values
}

///|
fn transform_filter(
  records : Array[DailyRecord],
  rule : RecordTransformRule,
) -> Array[DailyRecord] {
  records.filter(record => {
    record.training_duration >= rule.minimum_duration &&
    record.training_duration <= rule.maximum_duration &&
    record.training_intensity >= rule.minimum_intensity &&
    record.training_intensity <= rule.maximum_intensity
  })
}

///|
fn transform_repair_dates(records : Array[DailyRecord]) -> Array[DailyRecord] {
  records.filter(record => parse_date(record.date) is Some(_))
}

///|
fn transform_log(
  kind : RecordTransformKind,
  input : Array[DailyRecord],
  output : Array[DailyRecord],
  changed : Int,
  message : String,
) -> RecordTransformLog {
  {
    kind,
    input_count: input.length(),
    output_count: output.length(),
    changed_count: changed,
    removed_count: input.length() - output.length(),
    message,
  }
}

///|
pub fn apply_record_transform(
  records : Array[DailyRecord],
  rule : RecordTransformRule,
) -> RecordTransformResult {
  let mut current = records
  let logs = []
  let mut changed = 0
  let mut removed = 0
  if rule.enabled {
    let next = transform_clamp(current, rule)
    let count = 0
    for index in 0..<current.length() {
      if transform_record_changed(current[index], next[index]) {
        changed += 1
      }
    }
    logs.push(
      transform_log(
        TransformClamp,
        current,
        next,
        count,
        "clamped numeric fields",
      ),
    )
    current = next
    let next = transform_sort(current)
    logs.push(
      transform_log(TransformSort, current, next, 0, "sorted records by date"),
    )
    current = next
    let next = transform_deduplicate(current)
    removed += current.length() - next.length()
    logs.push(
      transform_log(
        TransformDeduplicate,
        current,
        next,
        current.length() - next.length(),
        "kept the first record for each date",
      ),
    )
    current = next
    let next = transform_filter(current, rule)
    removed += current.length() - next.length()
    logs.push(
      transform_log(
        TransformFilterRange,
        current,
        next,
        current.length() - next.length(),
        "filtered records outside configured duration and intensity",
      ),
    )
    current = next
    let next = transform_repair_dates(current)
    removed += current.length() - next.length()
    logs.push(
      transform_log(
        TransformRepairDates,
        current,
        next,
        current.length() - next.length(),
        "removed records with invalid dates",
      ),
    )
    current = next
  }
  {
    records: current,
    logs,
    input_count: records.length(),
    output_count: current.length(),
    changed_count: changed,
    removed_count: removed,
    valid: record_transform_rule_valid(rule) &&
    current.all(record => record.date != ""),
    status: if !record_transform_rule_valid(rule) {
      "invalid_rule"
    } else if current.length() == 0 {
      "empty"
    } else if changed > 0 || removed > 0 {
      "normalized"
    } else {
      "unchanged"
    },
  }
}

///|
pub fn apply_record_transform_default(
  records : Array[DailyRecord],
) -> RecordTransformResult {
  apply_record_transform(records, default_record_transform_rule())
}

///|
pub fn record_transform_accepts(result : RecordTransformResult) -> Bool {
  result.valid && result.status != "invalid_rule"
}

///|
pub fn record_transform_changed(result : RecordTransformResult) -> Bool {
  result.changed_count > 0
}

///|
pub fn record_transform_removed(result : RecordTransformResult) -> Bool {
  result.removed_count > 0
}

///|
pub fn record_transform_needs_review(result : RecordTransformResult) -> Bool {
  result.status == "normalized" || !result.valid
}

///|
pub fn record_transform_log_by_kind(
  result : RecordTransformResult,
  kind : RecordTransformKind,
) -> RecordTransformLog? {
  for log in result.logs {
    if log.kind == kind {
      return Some(log)
    }
  }
  None
}

///|
pub fn record_transform_log_count(result : RecordTransformResult) -> Int {
  result.logs.length()
}

///|
pub fn record_transform_log_messages(
  result : RecordTransformResult,
) -> Array[String] {
  result.logs.map(log => log.message)
}

///|
pub fn record_transform_log_kinds(
  result : RecordTransformResult,
) -> Array[String] {
  result.logs.map(log => record_transform_kind_name(log.kind))
}

///|
pub fn record_transform_input_dates(
  result : RecordTransformResult,
) -> Array[String] {
  result.records.map(record => record.date)
}

///|
pub fn record_transform_output_loads(
  result : RecordTransformResult,
) -> Array[Double] {
  training_loads(result.records)
}

///|
pub fn record_transform_output_quality(
  result : RecordTransformResult,
) -> Double {
  validate_records(result.records, default_quality_policy()).score
}

///|
pub fn record_transform_output_coverage(
  result : RecordTransformResult,
) -> Double {
  completeness_ratio(result.records) * 100.0
}

///|
pub fn record_transform_checksum(result : RecordTransformResult) -> String {
  let mut value = result.input_count + result.output_count
  for character in record_transform_text(result) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn record_transform_valid(result : RecordTransformResult) -> Bool {
  result.valid &&
  result.input_count >= 0 &&
  result.output_count >= 0 &&
  result.output_count <= result.input_count + result.changed_count &&
  result.removed_count >= 0 &&
  result.logs.all(log => {
    log.input_count >= log.output_count && log.changed_count >= 0
  })
}

///|
pub fn record_transform_log_valid(log : RecordTransformLog) -> Bool {
  log.input_count >= 0 &&
  log.output_count >= 0 &&
  log.output_count <= log.input_count &&
  log.changed_count >= 0 &&
  log.removed_count >= 0 &&
  log.message != ""
}

///|
pub fn record_transform_logs_valid(result : RecordTransformResult) -> Bool {
  result.logs.all(log => record_transform_log_valid(log))
}

///|
pub fn record_transform_text(result : RecordTransformResult) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "status=" +
    result.status +
    " input=" +
    result.input_count.to_string() +
    " output=" +
    result.output_count.to_string() +
    " changed=" +
    result.changed_count.to_string() +
    " removed=" +
    result.removed_count.to_string() +
    " valid=" +
    result.valid.to_string(),
  )
  for log in result.logs {
    builder.write_string(
      "\n" +
      record_transform_kind_name(log.kind) +
      " " +
      log.message +
      " input=" +
      log.input_count.to_string() +
      " output=" +
      log.output_count.to_string() +
      " changed=" +
      log.changed_count.to_string() +
      " removed=" +
      log.removed_count.to_string(),
    )
  }
  builder.to_string()
}

///|
pub fn record_transform_log_text(log : RecordTransformLog) -> String {
  record_transform_kind_name(log.kind) +
  " input=" +
  log.input_count.to_string() +
  " output=" +
  log.output_count.to_string() +
  " changed=" +
  log.changed_count.to_string() +
  " removed=" +
  log.removed_count.to_string() +
  " message=" +
  log.message
}

///|
pub fn record_transform_csv_header() -> String {
  "kind,input_count,output_count,changed_count,removed_count,message"
}

///|
pub fn record_transform_log_csv(log : RecordTransformLog) -> String {
  record_transform_kind_name(log.kind) +
  "," +
  log.input_count.to_string() +
  "," +
  log.output_count.to_string() +
  "," +
  log.changed_count.to_string() +
  "," +
  log.removed_count.to_string() +
  "," +
  log.message
}

///|
pub fn record_transform_csv(result : RecordTransformResult) -> String {
  let builder = StringBuilder::new()
  builder.write_string(record_transform_csv_header())
  for log in result.logs {
    builder.write_string("\n" + record_transform_log_csv(log))
  }
  builder.to_string()
}

///|
pub fn record_transform_summary_header() -> Array[String] {
  [
    "status", "input_count", "output_count", "changed_count", "removed_count", "valid",
    "quality", "coverage",
  ]
}

///|
pub fn record_transform_summary(
  result : RecordTransformResult,
) -> Array[String] {
  [
    result.status,
    result.input_count.to_string(),
    result.output_count.to_string(),
    result.changed_count.to_string(),
    result.removed_count.to_string(),
    result.valid.to_string(),
    record_transform_output_quality(result).to_string(),
    record_transform_output_coverage(result).to_string(),
  ]
}

///|
pub fn record_transform_summary_csv(result : RecordTransformResult) -> String {
  record_transform_summary_header().join(",") +
  "\n" +
  record_transform_summary(result).join(",")
}

///|
pub fn record_transform_recommendation(
  result : RecordTransformResult,
) -> String {
  if !result.valid {
    "repair the transform rule or input dates"
  } else if result.removed_count > 0 {
    "review removed rows before using the normalized set"
  } else if result.changed_count > 0 {
    "retain the transformation log with the analysis"
  } else {
    "records were unchanged"
  }
}

///|
pub fn record_transform_contract(
  result : RecordTransformResult,
) -> Array[String] {
  [
    result.status,
    record_transform_accepts(result).to_string(),
    record_transform_needs_review(result).to_string(),
    record_transform_recommendation(result),
    record_transform_checksum(result),
  ]
}

///|
pub fn record_transform_date_range(
  result : RecordTransformResult,
) -> Array[String] {
  if result.records.length() == 0 {
    []
  } else {
    [result.records[0].date, result.records[result.records.length() - 1].date]
  }
}

///|
pub fn record_transform_record_count(result : RecordTransformResult) -> Int {
  result.records.length()
}

///|
pub fn record_transform_first(result : RecordTransformResult) -> DailyRecord? {
  if result.records.length() == 0 {
    None
  } else {
    Some(result.records[0])
  }
}

///|
pub fn record_transform_last(result : RecordTransformResult) -> DailyRecord? {
  if result.records.length() == 0 {
    None
  } else {
    Some(result.records[result.records.length() - 1])
  }
}

///|
pub fn record_transform_load_average(result : RecordTransformResult) -> Double {
  mean_load_values(record_transform_output_loads(result))
}

///|
pub fn record_transform_load_peak(result : RecordTransformResult) -> Double {
  maximum_load_values(record_transform_output_loads(result))
}

///|
pub fn record_transform_load_deviation(
  result : RecordTransformResult,
) -> Double {
  standard_deviation_values(record_transform_output_loads(result))
}

///|
pub fn record_transform_exportable(result : RecordTransformResult) -> Bool {
  record_transform_valid(result) && record_transform_logs_valid(result)
}

///|
pub fn record_transform_export_status(result : RecordTransformResult) -> String {
  if record_transform_exportable(result) {
    "exportable"
  } else {
    "blocked"
  }
}
