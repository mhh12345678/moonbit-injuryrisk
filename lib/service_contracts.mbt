///|
/// Service-level contracts for a safe ingest-to-decision request.
pub(all) struct ServiceRequest {
  request_id : String
  athlete_label : String
  records : Array[DailyRecord]
  sessions : Array[TrainingSession]
  config : DecisionRunConfig
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ServiceResponse {
  request_id : String
  accepted : Bool
  status : String
  run : DecisionRun
  performance : PerformanceSnapshot
  response_checksum : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ServiceContractReport {
  request_valid : Bool
  response_valid : Bool
  quality_passed : Bool
  audit_valid : Bool
  export_valid : Bool
  messages : Array[String]
  status : String
} derive(Debug, Eq, ToJson)

///|
pub fn service_request(
  request_id : String,
  athlete_label : String,
  records : Array[DailyRecord],
  sessions : Array[TrainingSession],
  config : DecisionRunConfig,
) -> ServiceRequest {
  { request_id, athlete_label, records, sessions, config }
}

///|
fn service_checksum(response : ServiceResponse) -> String {
  let mut value = response.request_id.length() + response.run.status.length()
  for character in decision_run_summary(response.run) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn execute_service(request : ServiceRequest) -> ServiceResponse {
  let config = {
    risk_policy: request.config.risk_policy,
    monitor_thresholds: request.config.monitor_thresholds,
    quality_gate: request.config.quality_gate,
    load_model: request.config.load_model,
    athlete_label: request.athlete_label,
    run_id: request.request_id,
    include_sessions: request.config.include_sessions,
  }
  let run = run_decision_pipeline(request.records, config)
  let performance = performance_snapshot(request.records, request.sessions, run)
  let base = {
    request_id: request.request_id,
    accepted: run.accepted,
    status: run.status,
    run,
    performance,
    response_checksum: "",
  }
  {
    request_id: base.request_id,
    accepted: base.accepted,
    status: base.status,
    run: base.run,
    performance: base.performance,
    response_checksum: service_checksum(base),
  }
}

///|
pub fn service_request_valid(request : ServiceRequest) -> Bool {
  request.request_id != "" &&
  request.athlete_label != "" &&
  decision_run_config_valid(request.config) &&
  request.records.all(record => record.date != "") &&
  request.sessions.all(session => session.id != "")
}

///|
pub fn service_response_valid(response : ServiceResponse) -> Bool {
  response.request_id != "" &&
  response.response_checksum == service_checksum(response) &&
  decision_run_valid(response.run) &&
  performance_snapshot_valid(response.performance)
}

///|
pub fn validate_service_contract(
  request : ServiceRequest,
  response : ServiceResponse,
) -> ServiceContractReport {
  let request_ok = service_request_valid(request)
  let response_ok = service_response_valid(response)
  let quality_ok = quality_gate_passes(response.run.quality)
  let audit_ok = decision_run_audit_valid(response.run)
  let export_ok = export_bundle_valid(decision_run_export(response.run))
  let messages = []
  if !request_ok {
    messages.push("request contract failed")
  }
  if !response_ok {
    messages.push("response contract failed")
  }
  if !quality_ok {
    messages.push("quality gate rejected input")
  }
  if !audit_ok {
    messages.push("audit trail is invalid")
  }
  if !export_ok {
    messages.push("export bundle is invalid")
  }
  {
    request_valid: request_ok,
    response_valid: response_ok,
    quality_passed: quality_ok,
    audit_valid: audit_ok,
    export_valid: export_ok,
    messages,
    status: if request_ok && response_ok && quality_ok && audit_ok && export_ok {
      "accepted"
    } else {
      "rejected"
    },
  }
}

///|
pub fn service_contract_passes(report : ServiceContractReport) -> Bool {
  report.status == "accepted"
}

///|
pub fn service_contract_message(report : ServiceContractReport) -> String {
  report.status +
  " request=" +
  report.request_valid.to_string() +
  " response=" +
  report.response_valid.to_string() +
  " quality=" +
  report.quality_passed.to_string() +
  " audit=" +
  report.audit_valid.to_string() +
  " export=" +
  report.export_valid.to_string()
}

///|
pub fn service_contract_text(report : ServiceContractReport) -> String {
  let builder = StringBuilder::new()
  builder.write_string(service_contract_message(report))
  for message in report.messages {
    builder.write_string("\n- " + message)
  }
  builder.to_string()
}

///|
pub fn service_status_code(status : String) -> Int {
  match status {
    "accepted" => 200
    "rejected" => 422
    "critical" => 409
    _ => 500
  }
}

///|
pub fn service_response_summary(response : ServiceResponse) -> Array[String] {
  [
    response.request_id,
    response.status,
    response.accepted.to_string(),
    decision_run_latest_risk(response.run).to_string(),
    decision_run_latest_readiness(response.run).to_string(),
    response.performance.quality_score.to_string(),
    response.response_checksum,
  ]
}

///|
pub fn service_response_header() -> Array[String] {
  [
    "request_id", "status", "accepted", "risk", "readiness", "quality", "checksum",
  ]
}

///|
pub fn service_response_csv(response : ServiceResponse) -> String {
  service_response_header().join(",") +
  "\n" +
  service_response_summary(response).join(",")
}

///|
pub fn service_response_export(response : ServiceResponse) -> String {
  export_bundle_text(decision_run_export(response.run))
}

///|
pub fn service_run_id(response : ServiceResponse) -> String {
  response.run.config.run_id
}

///|
pub fn service_action_required(response : ServiceResponse) -> Bool {
  decision_run_requires_action(response.run)
}

///|
pub fn service_recommendation(response : ServiceResponse) -> String {
  decision_run_recommendation(response.run)
}

///|
pub fn service_alerts(response : ServiceResponse) -> Array[MonitoringAlert] {
  monitoring_alerts(response.run.monitoring)
}

///|
pub fn service_events(response : ServiceResponse) -> Array[RiskEvent] {
  response.run.events.events
}

///|
pub fn service_interventions(response : ServiceResponse) -> Array[Intervention] {
  match response.run.interventions {
    Some(plan) => plan.interventions
    None => []
  }
}

///|
pub fn service_contract_valid(report : ServiceContractReport) -> Bool {
  report.status == "accepted" && report.messages.length() == 0
}
