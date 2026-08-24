///|
/// Stages in a repeatable athlete screening protocol.
pub(all) enum ProtocolStage {
  Ingest
  Validate
  Calculate
  Screen
  Recommend
  Export
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ProtocolStep {
  stage : ProtocolStage
  name : String
  required : Bool
  completed : Bool
  detail : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ScreeningProtocol {
  name : String
  version : String
  steps : Array[ProtocolStep]
  minimum_history : Int
  minimum_quality : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ProtocolResult {
  accepted : Bool
  protocol : ScreeningProtocol
  workflow : WorkflowResult
  steps : Array[ProtocolStep]
  reason : String
} derive(Debug, Eq, ToJson)

///|
pub fn protocol_stage_name(stage : ProtocolStage) -> String {
  match stage {
    Ingest => "ingest"
    Validate => "validate"
    Calculate => "calculate"
    Screen => "screen"
    Recommend => "recommend"
    Export => "export"
  }
}

///|
fn protocol_step(
  stage : ProtocolStage,
  name : String,
  required : Bool,
) -> ProtocolStep {
  { stage, name, required, completed: false, detail: "pending" }
}

///|
pub fn default_screening_protocol() -> ScreeningProtocol {
  {
    name: "daily-injury-risk-screen",
    version: "1.0",
    steps: [
      protocol_step(Ingest, "load telemetry", true),
      protocol_step(Validate, "validate ranges and continuity", true),
      protocol_step(Calculate, "calculate load and recovery metrics", true),
      protocol_step(Screen, "evaluate configured policy", true),
      protocol_step(Recommend, "generate action plan", true),
      protocol_step(Export, "render report", false),
    ],
    minimum_history: 7,
    minimum_quality: 80.0,
  }
}

///|
fn completed_steps(
  protocol : ScreeningProtocol,
  result : WorkflowResult,
) -> Array[ProtocolStep] {
  protocol.steps.map(step => {
    let completed = match step.stage {
      Ingest => result.records.length() > 0
      Validate => result.quality.blocking_issue_count == 0
      Calculate => result.assessment is Some(_)
      Screen => result.assessment is Some(_)
      Recommend =>
        match result.assessment {
          Some(value) => value.action_plan.recommendations.length() >= 0
          None => false
        }
      Export => result.report is Some(_)
    }
    {
      ..step,
      completed,
      detail: if completed {
        "complete"
      } else {
        "incomplete"
      },
    }
  })
}

///|
pub fn run_screening_protocol(
  records : Array[DailyRecord],
  config : WorkflowConfig,
  protocol : ScreeningProtocol,
) -> ProtocolResult {
  let workflow = run_workflow(records, config)
  let steps = completed_steps(protocol, workflow)
  let history_ok = workflow.records.length() >= protocol.minimum_history
  let quality_ok = workflow.quality.score >= protocol.minimum_quality
  let required_complete = steps
    .filter(step => step.required && !step.completed)
    .length() ==
    0
  let accepted = workflow.accepted &&
    history_ok &&
    quality_ok &&
    required_complete
  {
    accepted,
    protocol,
    workflow,
    steps,
    reason: if accepted {
      "protocol completed and evidence is sufficient"
    } else if !history_ok {
      "insufficient history for the configured protocol"
    } else if !quality_ok {
      "telemetry quality is below the configured minimum"
    } else {
      "one or more required protocol stages failed"
    },
  }
}

///|
pub fn protocol_text(result : ProtocolResult) -> String {
  let builder = StringBuilder()
  builder.write_string(
    result.protocol.name +
    " v" +
    result.protocol.version +
    " accepted=" +
    result.accepted.to_string(),
  )
  for step in result.steps {
    builder.write_string(
      "\n[" +
      (if step.completed { "ok" } else { "fail" }) +
      "] " +
      protocol_stage_name(step.stage) +
      " " +
      step.name,
    )
  }
  builder.write_string("\nreason: " + result.reason)
  builder.to_string()
}
