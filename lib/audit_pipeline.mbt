///|
/// A reproducible audit record for a screening run.
pub(all) struct AuditEntry {
  stage : String
  status : String
  detail : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PipelineAudit {
  passed : Bool
  entries : Array[AuditEntry]
  input_count : Int
  output_count : Int
  warning_count : Int
} derive(Debug, Eq, ToJson)

///|
fn audit_entry(stage : String, status : String, detail : String) -> AuditEntry {
  { stage, status, detail }
}

///|
pub fn audit_records(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> PipelineAudit {
  let entries = []
  let quality = validate_records(records, default_quality_policy())
  entries.push(
    audit_entry(
      "quality",
      if quality.blocking_issue_count == 0 {
        "pass"
      } else {
        "fail"
      },
      quality_report_text(quality),
    ),
  )
  let sorted = sort_records_by_date(records)
  entries.push(
    audit_entry(
      "ordering",
      if sorted.map(record => record.date) == records.map(record => record.date) {
        "pass"
      } else {
        "normalized"
      },
      "chronological ordering checked",
    ),
  )
  let policy_check = validate_policy(policy)
  entries.push(
    audit_entry(
      "policy",
      if policy_check.valid {
        "pass"
      } else {
        "fail"
      },
      "rules=" + policy.rules.length().to_string(),
    ),
  )
  let timeline = build_timeline(sorted, policy)
  entries.push(
    audit_entry(
      "assessment",
      if timeline.points.length() > 0 {
        "pass"
      } else {
        "empty"
      },
      timeline_text(timeline),
    ),
  )
  let warnings = quality.issue_count + policy_check.warnings.length()
  {
    passed: quality.blocking_issue_count == 0 && policy_check.valid,
    entries,
    input_count: records.length(),
    output_count: timeline.points.length(),
    warning_count: warnings,
  }
}

///|
pub fn audit_text(audit : PipelineAudit) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "passed=" +
    audit.passed.to_string() +
    " input=" +
    audit.input_count.to_string() +
    " output=" +
    audit.output_count.to_string() +
    " warnings=" +
    audit.warning_count.to_string(),
  )
  for entry in audit.entries {
    builder.write_string(
      "\n[" + entry.status + "] " + entry.stage + ": " + entry.detail,
    )
  }
  builder.to_string()
}

///|
pub fn audit_is_reproducible(audit : PipelineAudit) -> Bool {
  audit.passed && audit.input_count >= audit.output_count
}
