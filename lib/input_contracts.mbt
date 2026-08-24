///|
/// Input contracts for service boundaries and ingestion adapters.
pub(all) enum InputContractStatus {
  InputAccepted
  InputRejected
  InputNormalized
  InputNeedsReview
} derive(Debug, Eq, ToJson)

///|
pub(all) struct InputContractResult {
  status : InputContractStatus
  record_count : Int
  valid_count : Int
  issue_count : Int
  duplicate_count : Int
  missing_count : Int
  normalized_count : Int
  messages : Array[String]
  records : Array[DailyRecord]
} derive(Debug, Eq, ToJson)

///|
pub fn input_contract_status_name(status : InputContractStatus) -> String {
  match status {
    InputAccepted => "accepted"
    InputRejected => "rejected"
    InputNormalized => "normalized"
    InputNeedsReview => "needs_review"
  }
}

///|
fn input_message(report : QualityReport) -> Array[String] {
  let messages = []
  if report.blocking_issue_count > 0 {
    messages.push("blocking issues are present")
  }
  if report.duplicate_date_count > 0 {
    messages.push("duplicate dates were detected")
  }
  if report.missing_date_count > 0 {
    messages.push("missing dates were detected")
  }
  if report.issue_count == 0 {
    messages.push("input passed field validation")
  }
  messages
}

///|
pub fn evaluate_input_contract(
  records : Array[DailyRecord],
  normalize : Bool,
) -> InputContractResult {
  let report = validate_records(records, default_quality_policy())
  let normalized = if normalize { normalize_records(records) } else { records }
  let status = if report.blocking_issue_count > 0 {
    InputRejected
  } else if normalize && normalized.length() != records.length() {
    InputNormalized
  } else if report.issue_count > 0 {
    InputNeedsReview
  } else {
    InputAccepted
  }
  {
    status,
    record_count: records.length(),
    valid_count: report.valid_record_count,
    issue_count: report.issue_count,
    duplicate_count: report.duplicate_date_count,
    missing_count: report.missing_date_count,
    normalized_count: normalized.length(),
    messages: input_message(report),
    records: normalized,
  }
}

///|
pub fn input_contract_accepts(result : InputContractResult) -> Bool {
  result.status == InputAccepted || result.status == InputNormalized
}

///|
pub fn input_contract_needs_review(result : InputContractResult) -> Bool {
  result.status == InputNeedsReview
}

///|
pub fn input_contract_rejected(result : InputContractResult) -> Bool {
  result.status == InputRejected
}

///|
pub fn input_contract_missing_dates(result : InputContractResult) -> Int {
  result.missing_count
}

///|
pub fn input_contract_duplicate_dates(result : InputContractResult) -> Int {
  result.duplicate_count
}

///|
pub fn input_contract_valid_ratio(result : InputContractResult) -> Double {
  if result.record_count == 0 {
    0.0
  } else {
    result.valid_count.to_double() / result.record_count.to_double()
  }
}

///|
pub fn input_contract_normalization_ratio(
  result : InputContractResult,
) -> Double {
  if result.record_count == 0 {
    0.0
  } else {
    result.normalized_count.to_double() / result.record_count.to_double()
  }
}

///|
pub fn input_contract_repair(
  result : InputContractResult,
) -> InputContractResult {
  let repaired = fill_missing_records(result.records, 8.0)
  evaluate_input_contract(repaired, true)
}

///|
pub fn input_contract_dates(result : InputContractResult) -> Array[String] {
  result.records.map(record => record.date)
}

///|
pub fn input_contract_loads(result : InputContractResult) -> Array[Double] {
  training_loads(result.records)
}

///|
pub fn input_contract_has_negative_load(result : InputContractResult) -> Bool {
  result.records.any(record => {
    record.training_duration < 0.0 || record.training_intensity < 0.0
  })
}

///|
pub fn input_contract_has_out_of_range(result : InputContractResult) -> Bool {
  result.records.any(record => {
    record.training_intensity > 10.0 ||
    record.pain_level > 10.0 ||
    record.sleep_quality > 5.0 ||
    record.fatigue > 10.0
  })
}

///|
pub fn input_contract_message(result : InputContractResult) -> String {
  input_contract_status_name(result.status) +
  " records=" +
  result.record_count.to_string() +
  " valid=" +
  result.valid_count.to_string() +
  " issues=" +
  result.issue_count.to_string() +
  " duplicates=" +
  result.duplicate_count.to_string() +
  " missing=" +
  result.missing_count.to_string()
}

///|
pub fn input_contract_text(result : InputContractResult) -> String {
  let builder = StringBuilder()
  builder.write_string(input_contract_message(result))
  for message in result.messages {
    builder.write_string("\n- " + message)
  }
  builder.to_string()
}

///|
pub fn input_contract_csv_header() -> String {
  "status,record_count,valid_count,issue_count,duplicate_count,missing_count,normalized_count"
}

///|
pub fn input_contract_csv(result : InputContractResult) -> String {
  input_contract_status_name(result.status) +
  "," +
  result.record_count.to_string() +
  "," +
  result.valid_count.to_string() +
  "," +
  result.issue_count.to_string() +
  "," +
  result.duplicate_count.to_string() +
  "," +
  result.missing_count.to_string() +
  "," +
  result.normalized_count.to_string()
}

///|
pub fn input_contract_statuses() -> Array[String] {
  [
    input_contract_status_name(InputAccepted),
    input_contract_status_name(InputRejected),
    input_contract_status_name(InputNormalized),
    input_contract_status_name(InputNeedsReview),
  ]
}

///|
pub fn input_contract_valid(result : InputContractResult) -> Bool {
  result.record_count >= 0 &&
  result.valid_count >= 0 &&
  result.issue_count >= 0 &&
  result.duplicate_count >= 0 &&
  result.missing_count >= 0 &&
  result.normalized_count >= 0 &&
  result.records.length() == result.normalized_count
}
