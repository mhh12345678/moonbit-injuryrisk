///|
/// Stable service queries avoid coupling callers to the internal decision graph.
pub(all) enum ServiceQueryKind {
  QueryStatus
  QueryRisk
  QueryReadiness
  QueryQuality
  QueryActions
  QueryAlerts
  QueryEvents
  QueryInterventions
  QueryRecommendation
  QueryCoverage
  QueryAudit
  QueryExport
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ServiceQueryResult {
  kind : ServiceQueryKind
  key : String
  value : String
  numeric_value : Double
  available : Bool
  actionable : Bool
  explanation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ServiceQueryBatch {
  run_id : String
  results : Array[ServiceQueryResult]
  available_count : Int
  actionable_count : Int
  status : String
} derive(Debug, Eq, ToJson)

///|
pub fn service_query_kind_name(kind : ServiceQueryKind) -> String {
  match kind {
    QueryStatus => "status"
    QueryRisk => "risk"
    QueryReadiness => "readiness"
    QueryQuality => "quality"
    QueryActions => "actions"
    QueryAlerts => "alerts"
    QueryEvents => "events"
    QueryInterventions => "interventions"
    QueryRecommendation => "recommendation"
    QueryCoverage => "coverage"
    QueryAudit => "audit"
    QueryExport => "export"
  }
}

///|
pub fn service_query_kinds() -> Array[ServiceQueryKind] {
  [
    QueryStatus,
    QueryRisk,
    QueryReadiness,
    QueryQuality,
    QueryActions,
    QueryAlerts,
    QueryEvents,
    QueryInterventions,
    QueryRecommendation,
    QueryCoverage,
    QueryAudit,
    QueryExport,
  ]
}

///|
fn service_query(
  kind : ServiceQueryKind,
  run : DecisionRun,
) -> ServiceQueryResult {
  match kind {
    QueryStatus =>
      {
        kind,
        key: "status",
        value: run.status,
        numeric_value: 0.0,
        available: true,
        actionable: decision_run_requires_action(run),
        explanation: "decision run status",
      }
    QueryRisk => {
      let value = decision_run_latest_risk(run)
      {
        kind,
        key: "risk",
        value: value.to_string(),
        numeric_value: value,
        available: run.latest is Some(_),
        actionable: value >= 40.0,
        explanation: "latest composite risk score",
      }
    }
    QueryReadiness => {
      let value = decision_run_latest_readiness(run)
      {
        kind,
        key: "readiness",
        value: value.to_string(),
        numeric_value: value,
        available: run.latest is Some(_),
        actionable: value < 65.0,
        explanation: "latest readiness score",
      }
    }
    QueryQuality => {
      let value = run.quality.report.score
      {
        kind,
        key: "quality",
        value: value.to_string(),
        numeric_value: value,
        available: true,
        actionable: value < 80.0,
        explanation: "quality gate score",
      }
    }
    QueryActions => {
      let value = decision_run_action_count(run)
      {
        kind,
        key: "actions",
        value: value.to_string(),
        numeric_value: value.to_double(),
        available: true,
        actionable: value > 0,
        explanation: "open coach workspace actions",
      }
    }
    QueryAlerts => {
      let value = decision_run_alert_count(run)
      {
        kind,
        key: "alerts",
        value: value.to_string(),
        numeric_value: value.to_double(),
        available: true,
        actionable: value > 0,
        explanation: "monitoring alerts",
      }
    }
    QueryEvents => {
      let value = decision_run_event_count(run)
      {
        kind,
        key: "events",
        value: value.to_string(),
        numeric_value: value.to_double(),
        available: true,
        actionable: value > 0,
        explanation: "risk events",
      }
    }
    QueryInterventions => {
      let value = decision_run_intervention_count(run)
      {
        kind,
        key: "interventions",
        value: value.to_string(),
        numeric_value: value.to_double(),
        available: true,
        actionable: value > 0,
        explanation: "planned interventions",
      }
    }
    QueryRecommendation =>
      {
        kind,
        key: "recommendation",
        value: decision_run_recommendation(run),
        numeric_value: 0.0,
        available: true,
        actionable: decision_run_requires_action(run),
        explanation: "deterministic next action",
      }
    QueryCoverage => {
      let value = run.quality.report.valid_record_count.to_double() /
        run.quality.report.record_count.max(1).to_double() *
        100.0
      {
        kind,
        key: "coverage",
        value: value.to_string(),
        numeric_value: value,
        available: true,
        actionable: value < 80.0,
        explanation: "valid record coverage",
      }
    }
    QueryAudit => {
      let valid = decision_run_audit_valid(run)
      {
        kind,
        key: "audit",
        value: valid.to_string(),
        numeric_value: if valid {
          1.0
        } else {
          0.0
        },
        available: true,
        actionable: !valid,
        explanation: "audit trail verification",
      }
    }
    QueryExport => {
      let valid = export_bundle_valid(decision_run_export(run))
      {
        kind,
        key: "export",
        value: valid.to_string(),
        numeric_value: if valid {
          1.0
        } else {
          0.0
        },
        available: true,
        actionable: !valid,
        explanation: "export bundle verification",
      }
    }
  }
}

///|
pub fn query_run(
  run : DecisionRun,
  kind : ServiceQueryKind,
) -> ServiceQueryResult {
  service_query(kind, run)
}

///|
pub fn query_run_all(run : DecisionRun) -> ServiceQueryBatch {
  let results = service_query_kinds().map(kind => service_query(kind, run))
  let available = results.filter(result => result.available).length()
  let actionable = results.filter(result => result.actionable).length()
  {
    run_id: run.config.run_id,
    results,
    available_count: available,
    actionable_count: actionable,
    status: if actionable > 0 {
      "action"
    } else {
      "stable"
    },
  }
}

///|
pub fn service_query_by_kind(
  batch : ServiceQueryBatch,
  kind : ServiceQueryKind,
) -> ServiceQueryResult? {
  for result in batch.results {
    if result.kind == kind {
      return Some(result)
    }
  }
  None
}

///|
pub fn service_query_by_key(
  batch : ServiceQueryBatch,
  key : String,
) -> ServiceQueryResult? {
  for result in batch.results {
    if result.key == key {
      return Some(result)
    }
  }
  None
}

///|
pub fn service_query_results(
  batch : ServiceQueryBatch,
) -> Array[ServiceQueryResult] {
  batch.results
}

///|
pub fn service_query_available(
  batch : ServiceQueryBatch,
) -> Array[ServiceQueryResult] {
  batch.results.filter(result => result.available)
}

///|
pub fn service_query_unavailable(
  batch : ServiceQueryBatch,
) -> Array[ServiceQueryResult] {
  batch.results.filter(result => !result.available)
}

///|
pub fn service_query_actionable(
  batch : ServiceQueryBatch,
) -> Array[ServiceQueryResult] {
  batch.results.filter(result => result.actionable)
}

///|
pub fn service_query_available_count(batch : ServiceQueryBatch) -> Int {
  batch.available_count
}

///|
pub fn service_query_actionable_count(batch : ServiceQueryBatch) -> Int {
  batch.actionable_count
}

///|
pub fn service_query_count(batch : ServiceQueryBatch) -> Int {
  batch.results.length()
}

///|
pub fn service_query_run_id(batch : ServiceQueryBatch) -> String {
  batch.run_id
}

///|
pub fn service_query_status(batch : ServiceQueryBatch) -> String {
  batch.status
}

///|
pub fn service_query_value(batch : ServiceQueryBatch, key : String) -> String {
  match service_query_by_key(batch, key) {
    Some(result) => result.value
    None => ""
  }
}

///|
pub fn service_query_numeric(batch : ServiceQueryBatch, key : String) -> Double {
  match service_query_by_key(batch, key) {
    Some(result) => result.numeric_value
    None => 0.0
  }
}

///|
pub fn service_query_explanation(
  batch : ServiceQueryBatch,
  key : String,
) -> String {
  match service_query_by_key(batch, key) {
    Some(result) => result.explanation
    None => ""
  }
}

///|
pub fn service_query_is_actionable(
  batch : ServiceQueryBatch,
  key : String,
) -> Bool {
  match service_query_by_key(batch, key) {
    Some(result) => result.actionable
    None => false
  }
}

///|
pub fn service_query_keys(batch : ServiceQueryBatch) -> Array[String] {
  batch.results.map(result => result.key)
}

///|
pub fn service_query_values(batch : ServiceQueryBatch) -> Array[String] {
  batch.results.map(result => result.value)
}

///|
pub fn service_query_numeric_values(batch : ServiceQueryBatch) -> Array[Double] {
  batch.results.map(result => result.numeric_value)
}

///|
pub fn service_query_actionable_keys(
  batch : ServiceQueryBatch,
) -> Array[String] {
  service_query_actionable(batch).map(result => result.key)
}

///|
pub fn service_query_required_keys() -> Array[String] {
  ["status", "risk", "readiness", "quality", "audit", "export"]
}

///|
pub fn service_query_missing_keys(batch : ServiceQueryBatch) -> Array[String] {
  service_query_required_keys().filter(key => {
    !service_query_keys(batch).contains(key)
  })
}

///|
pub fn service_query_complete(batch : ServiceQueryBatch) -> Bool {
  service_query_missing_keys(batch).length() == 0
}

///|
pub fn service_query_result_valid(result : ServiceQueryResult) -> Bool {
  result.key != "" &&
  result.value != "" &&
  result.explanation != "" &&
  result.numeric_value.is_nan() == false
}

///|
pub fn service_query_batch_valid(batch : ServiceQueryBatch) -> Bool {
  batch.run_id != "" &&
  batch.results.all(result => service_query_result_valid(result)) &&
  batch.available_count >= 0 &&
  batch.actionable_count >= 0 &&
  batch.available_count <= batch.results.length() &&
  batch.actionable_count <= batch.results.length()
}

///|
pub fn service_query_result_text(result : ServiceQueryResult) -> String {
  service_query_kind_name(result.kind) +
  " value=" +
  result.value +
  " available=" +
  result.available.to_string() +
  " actionable=" +
  result.actionable.to_string() +
  " explanation=" +
  result.explanation
}

///|
pub fn service_query_text(batch : ServiceQueryBatch) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "run=" +
    batch.run_id +
    " status=" +
    batch.status +
    " available=" +
    batch.available_count.to_string() +
    " actionable=" +
    batch.actionable_count.to_string(),
  )
  for result in batch.results {
    builder.write_string("\n" + service_query_result_text(result))
  }
  builder.to_string()
}

///|
pub fn service_query_csv_header() -> String {
  "kind,key,value,numeric_value,available,actionable,explanation"
}

///|
pub fn service_query_csv(result : ServiceQueryResult) -> String {
  service_query_kind_name(result.kind) +
  "," +
  result.key +
  "," +
  result.value +
  "," +
  result.numeric_value.to_string() +
  "," +
  result.available.to_string() +
  "," +
  result.actionable.to_string() +
  "," +
  result.explanation
}

///|
pub fn service_query_batch_csv(batch : ServiceQueryBatch) -> String {
  let builder = StringBuilder()
  builder.write_string(service_query_csv_header())
  for result in batch.results {
    builder.write_string("\n" + service_query_csv(result))
  }
  builder.to_string()
}

///|
pub fn service_query_summary_header() -> Array[String] {
  ["run_id", "status", "count", "available", "actionable", "complete"]
}

///|
pub fn service_query_summary(batch : ServiceQueryBatch) -> Array[String] {
  [
    batch.run_id,
    batch.status,
    batch.results.length().to_string(),
    batch.available_count.to_string(),
    batch.actionable_count.to_string(),
    service_query_complete(batch).to_string(),
  ]
}

///|
pub fn service_query_summary_csv(batch : ServiceQueryBatch) -> String {
  service_query_summary_header().join(",") +
  "\n" +
  service_query_summary(batch).join(",")
}

///|
pub fn service_query_recommendation(batch : ServiceQueryBatch) -> String {
  if !service_query_batch_valid(batch) {
    "repair query response"
  } else if batch.actionable_count > 0 {
    "review actionable query results"
  } else {
    "query response is stable"
  }
}

///|
pub fn service_query_status_code(batch : ServiceQueryBatch) -> Int {
  if !service_query_batch_valid(batch) {
    422
  } else if batch.actionable_count > 0 {
    206
  } else {
    200
  }
}

///|
pub fn service_query_checksum(batch : ServiceQueryBatch) -> String {
  let mut value = batch.run_id.length() + batch.results.length()
  for character in service_query_text(batch) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn service_query_reproducible(
  left : ServiceQueryBatch,
  right : ServiceQueryBatch,
) -> Bool {
  service_query_checksum(left) == service_query_checksum(right)
}

///|
pub fn service_query_contract(batch : ServiceQueryBatch) -> Array[String] {
  [
    batch.run_id,
    batch.status,
    service_query_status_code(batch).to_string(),
    service_query_complete(batch).to_string(),
    service_query_recommendation(batch),
    service_query_checksum(batch),
  ]
}

///|
pub fn service_query_risk(batch : ServiceQueryBatch) -> Double {
  service_query_numeric(batch, "risk")
}

///|
pub fn service_query_readiness(batch : ServiceQueryBatch) -> Double {
  service_query_numeric(batch, "readiness")
}

///|
pub fn service_query_quality(batch : ServiceQueryBatch) -> Double {
  service_query_numeric(batch, "quality")
}

///|
pub fn service_query_coverage(batch : ServiceQueryBatch) -> Double {
  service_query_numeric(batch, "coverage")
}

///|
pub fn service_query_actions(batch : ServiceQueryBatch) -> Int {
  service_query_numeric(batch, "actions").to_int()
}

///|
pub fn service_query_alerts(batch : ServiceQueryBatch) -> Int {
  service_query_numeric(batch, "alerts").to_int()
}

///|
pub fn service_query_events(batch : ServiceQueryBatch) -> Int {
  service_query_numeric(batch, "events").to_int()
}

///|
pub fn service_query_interventions(batch : ServiceQueryBatch) -> Int {
  service_query_numeric(batch, "interventions").to_int()
}

///|
pub fn service_query_audit_valid(batch : ServiceQueryBatch) -> Bool {
  service_query_value(batch, "audit") == "true"
}

///|
pub fn service_query_export_valid(batch : ServiceQueryBatch) -> Bool {
  service_query_value(batch, "export") == "true"
}
