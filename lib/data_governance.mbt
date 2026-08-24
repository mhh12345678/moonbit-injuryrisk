///|
/// Data governance keeps athlete telemetry explainable, reviewable, and bounded.
pub(all) enum GovernanceStatus {
  GovernanceReady
  GovernanceReview
  GovernanceBlocked
  GovernanceEmpty
} derive(Debug, Eq, ToJson)

///|
pub(all) enum GovernanceIssueKind {
  GovernanceMissing
  GovernanceInvalid
  GovernanceDuplicate
  GovernanceStale
  GovernanceOutOfRange
  GovernanceConflict
} derive(Debug, Eq, ToJson)

///|
pub(all) struct GovernanceIssue {
  id : String
  kind : GovernanceIssueKind
  record_index : Int
  date : String
  field : String
  severity : Int
  message : String
  repair : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct DataRetentionPolicy {
  maximum_days : Int
  minimum_days : Int
  allow_anonymized_export : Bool
  require_audit : Bool
  require_quality_gate : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct DataLineage {
  source : String
  import_id : String
  record_count : Int
  normalized_count : Int
  quality_score : Double
  checksum : String
  transformations : Array[String]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct GovernanceReport {
  status : GovernanceStatus
  record_count : Int
  valid_count : Int
  issue_count : Int
  blocking_count : Int
  issues : Array[GovernanceIssue]
  lineage : DataLineage
  retention : DataRetentionPolicy
  score : Double
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub fn governance_status_name(status : GovernanceStatus) -> String {
  match status {
    GovernanceReady => "ready"
    GovernanceReview => "review"
    GovernanceBlocked => "blocked"
    GovernanceEmpty => "empty"
  }
}

///|
pub fn governance_issue_kind_name(kind : GovernanceIssueKind) -> String {
  match kind {
    GovernanceMissing => "missing"
    GovernanceInvalid => "invalid"
    GovernanceDuplicate => "duplicate"
    GovernanceStale => "stale"
    GovernanceOutOfRange => "out_of_range"
    GovernanceConflict => "conflict"
  }
}

///|
pub fn default_data_retention_policy() -> DataRetentionPolicy {
  {
    maximum_days: 3650,
    minimum_days: 1,
    allow_anonymized_export: true,
    require_audit: true,
    require_quality_gate: true,
  }
}

///|
pub fn data_retention_policy_valid(policy : DataRetentionPolicy) -> Bool {
  policy.maximum_days > 0 &&
  policy.minimum_days >= 0 &&
  policy.maximum_days >= policy.minimum_days
}

///|
fn governance_issue(
  id : String,
  kind : GovernanceIssueKind,
  index : Int,
  date : String,
  field : String,
  severity : Int,
  message : String,
  repair : String,
) -> GovernanceIssue {
  { id, kind, record_index: index, date, field, severity, message, repair }
}

///|
fn governance_record_issues(
  record : DailyRecord,
  index : Int,
) -> Array[GovernanceIssue] {
  let issues = []
  if record.date == "" {
    issues.push(
      governance_issue(
        "missing-date-" + index.to_string(),
        GovernanceMissing,
        index,
        record.date,
        "date",
        3,
        "record has no date",
        "supply an ISO date",
      ),
    )
  }
  if record.training_duration < 0.0 {
    issues.push(
      governance_issue(
        "duration-" + index.to_string(),
        GovernanceOutOfRange,
        index,
        record.date,
        "training_duration",
        3,
        "duration is negative",
        "replace with a non-negative duration",
      ),
    )
  }
  if record.training_intensity < 0.0 || record.training_intensity > 10.0 {
    issues.push(
      governance_issue(
        "intensity-" + index.to_string(),
        GovernanceOutOfRange,
        index,
        record.date,
        "training_intensity",
        3,
        "intensity is outside the RPE range",
        "clamp or repair intensity",
      ),
    )
  }
  if record.pain_level < 0.0 || record.pain_level > 10.0 {
    issues.push(
      governance_issue(
        "pain-" + index.to_string(),
        GovernanceOutOfRange,
        index,
        record.date,
        "pain_level",
        2,
        "pain is outside the configured range",
        "repair pain value",
      ),
    )
  }
  if record.sleep_hours < 0.0 || record.sleep_hours > 24.0 {
    issues.push(
      governance_issue(
        "sleep-" + index.to_string(),
        GovernanceOutOfRange,
        index,
        record.date,
        "sleep_hours",
        2,
        "sleep duration is outside a day",
        "repair sleep duration",
      ),
    )
  }
  if record.sleep_quality < 0.0 || record.sleep_quality > 5.0 {
    issues.push(
      governance_issue(
        "sleep-quality-" + index.to_string(),
        GovernanceOutOfRange,
        index,
        record.date,
        "sleep_quality",
        2,
        "sleep quality is outside the scale",
        "repair sleep quality",
      ),
    )
  }
  if record.fatigue < 0.0 || record.fatigue > 10.0 {
    issues.push(
      governance_issue(
        "fatigue-" + index.to_string(),
        GovernanceOutOfRange,
        index,
        record.date,
        "fatigue",
        2,
        "fatigue is outside the scale",
        "repair fatigue value",
      ),
    )
  }
  issues
}

///|
fn governance_duplicate_issues(
  records : Array[DailyRecord],
) -> Array[GovernanceIssue] {
  let issues = []
  for index, record in records {
    for previous in 0..<index {
      if records[previous].date == record.date && record.date != "" {
        issues.push(
          governance_issue(
            "duplicate-" + index.to_string(),
            GovernanceDuplicate,
            index,
            record.date,
            "date",
            2,
            "date appears more than once",
            "merge or choose one record",
          ),
        )
        break
      }
    }
  }
  issues
}

///|
fn governance_quality_score(
  records : Array[DailyRecord],
  issues : Array[GovernanceIssue],
) -> Double {
  if records.length() == 0 {
    0.0
  } else {
    (100.0 - issues.length().to_double() / records.length().to_double() * 100.0).max(
      0.0,
    )
  }
}

///|
fn governance_status(
  records : Array[DailyRecord],
  issues : Array[GovernanceIssue],
) -> GovernanceStatus {
  if records.length() == 0 {
    GovernanceEmpty
  } else if issues.any(issue => issue.severity >= 3) {
    GovernanceBlocked
  } else if issues.length() > 0 {
    GovernanceReview
  } else {
    GovernanceReady
  }
}

///|
fn governance_recommendation(
  status : GovernanceStatus,
  issues : Array[GovernanceIssue],
) -> String {
  match status {
    GovernanceEmpty => "collect telemetry before analysis"
    GovernanceBlocked => "repair blocking input fields before analysis"
    GovernanceReview =>
      if issues.any(issue => issue.kind == GovernanceDuplicate) {
        "deduplicate dates before export"
      } else {
        "review non-blocking input findings"
      }
    GovernanceReady => "input is ready for deterministic analysis"
  }
}

///|
fn governance_lineage(
  records : Array[DailyRecord],
  issues : Array[GovernanceIssue],
) -> DataLineage {
  let normalized = records
    .filter(record => {
      record.date != "" &&
      record.training_duration >= 0.0 &&
      record.training_intensity >= 0.0
    })
    .length()
  let transforms = []
  if normalized != records.length() {
    transforms.push("removed_invalid_rows")
  }
  if issues.any(issue => issue.kind == GovernanceDuplicate) {
    transforms.push("detected_duplicate_dates")
  }
  let base = {
    source: "daily_records",
    import_id: "local-ingest",
    record_count: records.length(),
    normalized_count: normalized,
    quality_score: governance_quality_score(records, issues),
    checksum: "",
    transformations: transforms,
  }
  {
    source: base.source,
    import_id: base.import_id,
    record_count: base.record_count,
    normalized_count: base.normalized_count,
    quality_score: base.quality_score,
    checksum: governance_lineage_checksum(base),
    transformations: base.transformations,
  }
}

///|
fn governance_lineage_checksum(lineage : DataLineage) -> String {
  let mut value = lineage.record_count + lineage.normalized_count
  for
    character in lineage.source +
    lineage.import_id +
    lineage.transformations.join(",") {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn govern_records(
  records : Array[DailyRecord],
  retention : DataRetentionPolicy,
) -> GovernanceReport {
  let issues = []
  for index, record in records {
    for issue in governance_record_issues(record, index) {
      issues.push(issue)
    }
  }
  for issue in governance_duplicate_issues(records) {
    issues.push(issue)
  }
  let lineage = governance_lineage(records, issues)
  let status = governance_status(records, issues)
  {
    status,
    record_count: records.length(),
    valid_count: records.length() -
    issues.filter(issue => issue.severity >= 3).length(),
    issue_count: issues.length(),
    blocking_count: issues.filter(issue => issue.severity >= 3).length(),
    issues,
    lineage,
    retention,
    score: governance_quality_score(records, issues),
    recommendation: governance_recommendation(status, issues),
  }
}

///|
pub fn govern_records_default(records : Array[DailyRecord]) -> GovernanceReport {
  govern_records(records, default_data_retention_policy())
}

///|
pub fn governance_accepts(report : GovernanceReport) -> Bool {
  report.status == GovernanceReady || report.status == GovernanceReview
}

///|
pub fn governance_blocks(report : GovernanceReport) -> Bool {
  report.status == GovernanceBlocked
}

///|
pub fn governance_needs_review(report : GovernanceReport) -> Bool {
  report.status == GovernanceReview || report.issue_count > 0
}

///|
pub fn governance_ready(report : GovernanceReport) -> Bool {
  report.status == GovernanceReady && report.issue_count == 0
}

///|
pub fn governance_issue_by_id(
  report : GovernanceReport,
  id : String,
) -> GovernanceIssue? {
  for issue in report.issues {
    if issue.id == id {
      return Some(issue)
    }
  }
  None
}

///|
pub fn governance_issues_by_kind(
  report : GovernanceReport,
  kind : GovernanceIssueKind,
) -> Array[GovernanceIssue] {
  report.issues.filter(issue => issue.kind == kind)
}

///|
pub fn governance_issues_by_field(
  report : GovernanceReport,
  field : String,
) -> Array[GovernanceIssue] {
  report.issues.filter(issue => issue.field == field)
}

///|
pub fn governance_blocking_issues(
  report : GovernanceReport,
) -> Array[GovernanceIssue] {
  report.issues.filter(issue => issue.severity >= 3)
}

///|
pub fn governance_warning_issues(
  report : GovernanceReport,
) -> Array[GovernanceIssue] {
  report.issues.filter(issue => issue.severity < 3)
}

///|
pub fn governance_issue_ids(report : GovernanceReport) -> Array[String] {
  report.issues.map(issue => issue.id)
}

///|
pub fn governance_issue_fields(report : GovernanceReport) -> Array[String] {
  let fields = []
  for issue in report.issues {
    if !fields.contains(issue.field) {
      fields.push(issue.field)
    }
  }
  fields
}

///|
pub fn governance_issue_kinds(report : GovernanceReport) -> Array[String] {
  let kinds = []
  for issue in report.issues {
    let name = governance_issue_kind_name(issue.kind)
    if !kinds.contains(name) {
      kinds.push(name)
    }
  }
  kinds
}

///|
pub fn governance_issue_count(
  report : GovernanceReport,
  kind : GovernanceIssueKind,
) -> Int {
  governance_issues_by_kind(report, kind).length()
}

///|
pub fn governance_highest_severity(report : GovernanceReport) -> Int {
  report.issues.fold(init=0, (maximum, issue) => maximum.max(issue.severity))
}

///|
pub fn governance_average_severity(report : GovernanceReport) -> Double {
  mean_load_values(report.issues.map(issue => issue.severity.to_double()))
}

///|
pub fn governance_score(report : GovernanceReport) -> Double {
  report.score
}

///|
pub fn governance_status_code(report : GovernanceReport) -> Int {
  match report.status {
    GovernanceReady => 200
    GovernanceReview => 206
    GovernanceBlocked => 422
    GovernanceEmpty => 204
  }
}

///|
pub fn governance_status_text(report : GovernanceReport) -> String {
  governance_status_name(report.status)
}

///|
pub fn governance_recommendation_text(report : GovernanceReport) -> String {
  report.recommendation
}

///|
pub fn governance_valid(report : GovernanceReport) -> Bool {
  data_retention_policy_valid(report.retention) &&
  report.record_count >= 0 &&
  report.valid_count >= 0 &&
  report.valid_count <= report.record_count &&
  report.issue_count == report.issues.length() &&
  report.blocking_count == governance_blocking_issues(report).length() &&
  report.score >= 0.0 &&
  report.score <= 100.0
}

///|
pub fn governance_issue_valid(issue : GovernanceIssue) -> Bool {
  issue.id != "" &&
  issue.record_index >= 0 &&
  issue.severity >= 1 &&
  issue.severity <= 3 &&
  issue.field != "" &&
  issue.message != "" &&
  issue.repair != ""
}

///|
pub fn governance_lineage_valid(lineage : DataLineage) -> Bool {
  lineage.source != "" &&
  lineage.import_id != "" &&
  lineage.record_count >= 0 &&
  lineage.normalized_count >= 0 &&
  lineage.normalized_count <= lineage.record_count &&
  lineage.quality_score >= 0.0 &&
  lineage.quality_score <= 100.0 &&
  lineage.checksum == governance_lineage_checksum(lineage)
}

///|
pub fn governance_issues_valid(report : GovernanceReport) -> Bool {
  report.issues.all(issue => governance_issue_valid(issue))
}

///|
pub fn governance_contract(report : GovernanceReport) -> Array[String] {
  [
    governance_status_name(report.status),
    report.score.to_string(),
    report.record_count.to_string(),
    report.issue_count.to_string(),
    report.blocking_count.to_string(),
    governance_valid(report).to_string(),
    report.lineage.checksum,
  ]
}

///|
pub fn governance_checksum(report : GovernanceReport) -> String {
  let mut value = report.record_count + report.issue_count
  for character in governance_contract(report).join("|") {
    value = (value * 33 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn governance_reproducible(
  left : GovernanceReport,
  right : GovernanceReport,
) -> Bool {
  governance_checksum(left) == governance_checksum(right)
}

///|
pub fn governance_issue_text(issue : GovernanceIssue) -> String {
  issue.id +
  " " +
  governance_issue_kind_name(issue.kind) +
  " index=" +
  issue.record_index.to_string() +
  " date=" +
  issue.date +
  " field=" +
  issue.field +
  " severity=" +
  issue.severity.to_string() +
  " message=" +
  issue.message +
  " repair=" +
  issue.repair
}

///|
pub fn governance_text(report : GovernanceReport) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "status=" +
    governance_status_name(report.status) +
    " records=" +
    report.record_count.to_string() +
    " valid=" +
    report.valid_count.to_string() +
    " issues=" +
    report.issue_count.to_string() +
    " blocking=" +
    report.blocking_count.to_string() +
    " score=" +
    report.score.to_string(),
  )
  builder.write_string("\nrecommendation=" + report.recommendation)
  for issue in report.issues {
    builder.write_string("\n" + governance_issue_text(issue))
  }
  builder.to_string()
}

///|
pub fn governance_lineage_text(lineage : DataLineage) -> String {
  "source=" +
  lineage.source +
  " import=" +
  lineage.import_id +
  " records=" +
  lineage.record_count.to_string() +
  " normalized=" +
  lineage.normalized_count.to_string() +
  " quality=" +
  lineage.quality_score.to_string() +
  " checksum=" +
  lineage.checksum +
  " transforms=" +
  lineage.transformations.join(",")
}

///|
pub fn governance_issue_csv_header() -> String {
  "id,kind,record_index,date,field,severity,message,repair"
}

///|
pub fn governance_issue_csv(issue : GovernanceIssue) -> String {
  issue.id +
  "," +
  governance_issue_kind_name(issue.kind) +
  "," +
  issue.record_index.to_string() +
  "," +
  issue.date +
  "," +
  issue.field +
  "," +
  issue.severity.to_string() +
  "," +
  issue.message +
  "," +
  issue.repair
}

///|
pub fn governance_csv(report : GovernanceReport) -> String {
  let builder = StringBuilder()
  builder.write_string(governance_issue_csv_header())
  for issue in report.issues {
    builder.write_string("\n" + governance_issue_csv(issue))
  }
  builder.to_string()
}

///|
pub fn governance_summary_header() -> Array[String] {
  [
    "status", "records", "valid", "issues", "blocking", "score", "recommendation",
  ]
}

///|
pub fn governance_summary(report : GovernanceReport) -> Array[String] {
  [
    governance_status_name(report.status),
    report.record_count.to_string(),
    report.valid_count.to_string(),
    report.issue_count.to_string(),
    report.blocking_count.to_string(),
    report.score.to_string(),
    report.recommendation,
  ]
}

///|
pub fn governance_summary_csv(report : GovernanceReport) -> String {
  governance_summary_header().join(",") +
  "\n" +
  governance_summary(report).join(",")
}

///|
pub fn governance_retention_text(policy : DataRetentionPolicy) -> String {
  "maximum_days=" +
  policy.maximum_days.to_string() +
  " minimum_days=" +
  policy.minimum_days.to_string() +
  " anonymized_export=" +
  policy.allow_anonymized_export.to_string() +
  " audit=" +
  policy.require_audit.to_string() +
  " quality_gate=" +
  policy.require_quality_gate.to_string()
}

///|
pub fn governance_lineage_csv(lineage : DataLineage) -> String {
  lineage.source +
  "," +
  lineage.import_id +
  "," +
  lineage.record_count.to_string() +
  "," +
  lineage.normalized_count.to_string() +
  "," +
  lineage.quality_score.to_string() +
  "," +
  lineage.checksum +
  "," +
  lineage.transformations.join(";")
}

///|
pub fn governance_lineage_csv_header() -> String {
  "source,import_id,record_count,normalized_count,quality_score,checksum,transformations"
}

///|
pub fn governance_exportable(report : GovernanceReport) -> Bool {
  governance_valid(report) && !governance_blocks(report)
}

///|
pub fn governance_export_status(report : GovernanceReport) -> String {
  if governance_exportable(report) {
    "exportable"
  } else {
    "blocked"
  }
}

///|
pub fn governance_repairable(report : GovernanceReport) -> Bool {
  report.issues.all(issue => issue.repair != "")
}

///|
pub fn governance_repair_fields(report : GovernanceReport) -> Array[String] {
  report.issues.map(issue => issue.field)
}

///|
pub fn governance_repair_plan(report : GovernanceReport) -> Array[String] {
  report.issues.map(issue => issue.field + ": " + issue.repair)
}

///|
pub fn governance_missing_fields(report : GovernanceReport) -> Array[String] {
  governance_issues_by_kind(report, GovernanceMissing).map(issue => issue.field)
}

///|
pub fn governance_duplicate_dates(report : GovernanceReport) -> Array[String] {
  governance_issues_by_kind(report, GovernanceDuplicate).map(issue => issue.date)
}

///|
pub fn governance_out_of_range_fields(
  report : GovernanceReport,
) -> Array[String] {
  governance_issues_by_kind(report, GovernanceOutOfRange).map(issue => {
    issue.field
  })
}

///|
pub fn governance_has_missing(report : GovernanceReport) -> Bool {
  governance_issues_by_kind(report, GovernanceMissing).length() > 0
}

///|
pub fn governance_has_duplicates(report : GovernanceReport) -> Bool {
  governance_issues_by_kind(report, GovernanceDuplicate).length() > 0
}

///|
pub fn governance_has_range_errors(report : GovernanceReport) -> Bool {
  governance_issues_by_kind(report, GovernanceOutOfRange).length() > 0
}

///|
pub fn governance_quality_band(report : GovernanceReport) -> String {
  if report.score >= 90.0 {
    "excellent"
  } else if report.score >= 80.0 {
    "good"
  } else if report.score >= 60.0 {
    "watch"
  } else {
    "poor"
  }
}

///|
pub fn governance_quality_passes(
  report : GovernanceReport,
  floor : Double,
) -> Bool {
  report.score >= floor && report.blocking_count == 0
}

///|
pub fn governance_record_coverage(report : GovernanceReport) -> Double {
  if report.record_count == 0 {
    0.0
  } else {
    report.valid_count.to_double() / report.record_count.to_double() * 100.0
  }
}

///|
pub fn governance_issue_rate(report : GovernanceReport) -> Double {
  if report.record_count == 0 {
    0.0
  } else {
    report.issue_count.to_double() / report.record_count.to_double() * 100.0
  }
}

///|
pub fn governance_blocking_rate(report : GovernanceReport) -> Double {
  if report.record_count == 0 {
    0.0
  } else {
    report.blocking_count.to_double() / report.record_count.to_double() * 100.0
  }
}

///|
pub fn governance_issue_density(report : GovernanceReport) -> Double {
  governance_issue_rate(report) + governance_blocking_rate(report)
}

///|
pub fn governance_operational_status(report : GovernanceReport) -> String {
  if governance_blocks(report) {
    "blocked"
  } else if governance_needs_review(report) {
    "review"
  } else {
    "ready"
  }
}

///|
pub fn governance_review_priority(report : GovernanceReport) -> Int {
  if governance_blocks(report) {
    3
  } else if governance_needs_review(report) {
    2
  } else {
    0
  }
}

///|
pub fn governance_review_label(report : GovernanceReport) -> String {
  "priority_" + governance_review_priority(report).to_string()
}

///|
pub fn governance_issue_messages(report : GovernanceReport) -> Array[String] {
  report.issues.map(issue => issue.message)
}

///|
pub fn governance_repair_messages(report : GovernanceReport) -> Array[String] {
  report.issues.map(issue => issue.repair)
}

///|
pub fn governance_transformations(report : GovernanceReport) -> Array[String] {
  report.lineage.transformations
}

///|
pub fn governance_transformed(report : GovernanceReport) -> Bool {
  report.lineage.transformations.length() > 0
}

///|
pub fn governance_normalization_rate(report : GovernanceReport) -> Double {
  if report.record_count == 0 {
    0.0
  } else {
    report.lineage.normalized_count.to_double() /
    report.record_count.to_double() *
    100.0
  }
}

///|
pub fn governance_source(report : GovernanceReport) -> String {
  report.lineage.source
}

///|
pub fn governance_import_id(report : GovernanceReport) -> String {
  report.lineage.import_id
}

///|
pub fn governance_checksum_value(report : GovernanceReport) -> String {
  governance_checksum(report)
}

///|
pub fn governance_report_contract(report : GovernanceReport) -> Array[String] {
  [
    governance_status_text(report),
    governance_quality_band(report),
    governance_operational_status(report),
    governance_export_status(report),
    governance_review_label(report),
    governance_checksum_value(report),
  ]
}
