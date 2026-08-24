///|
/// Operational intervention categories produced from risk evidence.
pub(all) enum InterventionKind {
  Rest
  LoadReduction
  LoadHold
  RecoveryRoutine
  SleepPlan
  PainReview
  DataRepair
  TechniqueReview
  ReturnToTraining
  QualifiedReferral
} derive(Debug, Eq, ToJson)

///|
pub(all) enum InterventionStatus {
  Proposed
  Accepted
  InProgress
  Completed
  Deferred
  Cancelled
} derive(Debug, Eq, ToJson)

///|
pub(all) struct Intervention {
  id : String
  date : String
  kind : InterventionKind
  status : InterventionStatus
  priority : RecommendationPriority
  title : String
  rationale : String
  steps : Array[String]
  expected_load_change_percent : Double
  review_after_days : Int
  owner : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct InterventionPlan {
  anchor_date : String
  interventions : Array[Intervention]
  target_load_change_percent : Double
  rest_days : Int
  review_date : String
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct InterventionReview {
  intervention_id : String
  before_risk : Double
  after_risk : Double
  before_readiness : Double
  after_readiness : Double
  risk_change : Double
  readiness_change : Double
  effective : Bool
  note : String
} derive(Debug, Eq, ToJson)

///|
pub fn intervention_kind_name(kind : InterventionKind) -> String {
  match kind {
    Rest => "rest"
    LoadReduction => "load_reduction"
    LoadHold => "load_hold"
    RecoveryRoutine => "recovery_routine"
    SleepPlan => "sleep_plan"
    PainReview => "pain_review"
    DataRepair => "data_repair"
    TechniqueReview => "technique_review"
    ReturnToTraining => "return_to_training"
    QualifiedReferral => "qualified_referral"
  }
}

///|
pub fn intervention_status_name(status : InterventionStatus) -> String {
  match status {
    Proposed => "proposed"
    Accepted => "accepted"
    InProgress => "in_progress"
    Completed => "completed"
    Deferred => "deferred"
    Cancelled => "cancelled"
  }
}

///|
fn intervention(
  id : String,
  date : String,
  kind : InterventionKind,
  priority : RecommendationPriority,
  title : String,
  rationale : String,
  steps : Array[String],
  load_change : Double,
  review_days : Int,
  owner : String,
) -> Intervention {
  {
    id,
    date,
    kind,
    status: Proposed,
    priority,
    title,
    rationale,
    steps,
    expected_load_change_percent: load_change,
    review_after_days: review_days,
    owner,
  }
}

///|
fn rest_intervention(
  date : String,
  days : Int,
  reason : String,
) -> Intervention {
  intervention(
    "intervention-" + date + "-rest",
    date,
    Rest,
    Immediate,
    "schedule recovery days",
    reason,
    [
      "remove high-intensity work", "keep check-ins active", "review symptoms before resuming progression",
    ],
    -100.0,
    days.max(1),
    "coach",
  )
}

///|
fn load_reduction_intervention(
  date : String,
  change : Double,
  reason : String,
) -> Intervention {
  intervention(
    "intervention-" + date + "-load",
    date,
    LoadReduction,
    Soon,
    "reduce the next training load",
    reason,
    [
      "cap duration and intensity", "avoid stacking high-load sessions", "compare actual load with the cap",
    ],
    change.min(0.0),
    2,
    "coach",
  )
}

///|
fn load_hold_intervention(date : String, reason : String) -> Intervention {
  intervention(
    "intervention-" + date + "-hold",
    date,
    LoadHold,
    Monitor,
    "hold current progression",
    reason,
    [
      "keep the planned load unchanged", "collect one more recovery observation",
      "reassess the progression guardrail",
    ],
    0.0,
    2,
    "coach",
  )
}

///|
fn recovery_intervention(date : String, reason : String) -> Intervention {
  intervention(
    "intervention-" + date + "-recovery",
    date,
    RecoveryRoutine,
    Soon,
    "reinforce recovery routine",
    reason,
    [
      "complete a morning check-in", "protect sleep opportunity", "use low-load movement if tolerated",
    ],
    -10.0,
    3,
    "athlete",
  )
}

///|
fn sleep_intervention(date : String, reason : String) -> Intervention {
  intervention(
    "intervention-" + date + "-sleep",
    date,
    SleepPlan,
    Soon,
    "protect sleep opportunity",
    reason,
    [
      "set a consistent sleep window", "remove avoidable late-session load", "record sleep quality next morning",
    ],
    -5.0,
    3,
    "athlete",
  )
}

///|
fn pain_intervention(date : String, reason : String) -> Intervention {
  intervention(
    "intervention-" + date + "-pain",
    date,
    PainReview,
    Immediate,
    "review pain signal",
    reason,
    [
      "record location and aggravating activity", "avoid automatic progression",
      "route persistent pain to a qualified professional",
    ],
    -30.0,
    1,
    "qualified-reviewer",
  )
}

///|
fn quality_intervention(date : String, reason : String) -> Intervention {
  intervention(
    "intervention-" + date + "-quality",
    date,
    DataRepair,
    Soon,
    "repair telemetry before interpretation",
    reason,
    [
      "inspect invalid fields", "resolve duplicate dates", "rerun the quality contract",
    ],
    0.0,
    1,
    "data-owner",
  )
}

///|
fn referral_intervention(date : String, reason : String) -> Intervention {
  intervention(
    "intervention-" + date + "-referral",
    date,
    QualifiedReferral,
    Immediate,
    "refer for qualified review",
    reason,
    [
      "pause automated progression", "attach the evidence summary", "record the review outcome",
    ],
    -50.0,
    1,
    "qualified-reviewer",
  )
}

///|
fn add_recommendation_intervention(
  date : String,
  recommendation : Recommendation,
  index : Int,
) -> Intervention {
  let kind = match recommendation.priority {
    Immediate => QualifiedReferral
    Soon => LoadReduction
    Monitor => LoadHold
    Positive => RecoveryRoutine
  }
  let change = match recommendation.priority {
    Immediate => -40.0
    Soon => -20.0
    Monitor => 0.0
    Positive => 5.0
  }
  intervention(
    "intervention-" + date + "-recommendation-" + index.to_string(),
    date,
    kind,
    recommendation.priority,
    recommendation.title,
    recommendation.rationale,
    [recommendation.action, recommendation.expected_effect],
    change,
    2,
    "coach",
  )
}

///|
fn assessment_interventions(
  assessment : ComprehensiveAssessment,
) -> Array[Intervention] {
  let interventions = []
  if assessment.risk_level == High {
    interventions.push(
      rest_intervention(assessment.date, 2, assessment.summary),
    )
    interventions.push(
      referral_intervention(
        assessment.date,
        "high risk level requires qualified review",
      ),
    )
  } else if assessment.risk_level == Medium {
    interventions.push(
      load_reduction_intervention(assessment.date, -20.0, assessment.summary),
    )
  } else if assessment.readiness_score < 80.0 {
    interventions.push(
      load_hold_intervention(
        assessment.date,
        "readiness is below the progression target",
      ),
    )
  }
  if assessment.recovery.sleep_debt_hours > 2.0 {
    interventions.push(
      sleep_intervention(
        assessment.date,
        "sleep debt is above the recovery watch threshold",
      ),
    )
  }
  if assessment.recovery.recovery_score < 60.0 {
    interventions.push(
      recovery_intervention(
        assessment.date,
        "recovery score is below the operational floor",
      ),
    )
  }
  let pain_signals = assessment.signals.signals.filter(signal => {
    signal.kind == Pain
  })
  if pain_signals.length() > 0 {
    interventions.push(
      pain_intervention(assessment.date, pain_signals[0].evidence),
    )
  }
  if assessment.quality.issue_count > 0 {
    interventions.push(
      quality_intervention(
        assessment.date,
        quality_report_text(assessment.quality),
      ),
    )
  }
  for index, recommendation in assessment.action_plan.recommendations {
    interventions.push(
      add_recommendation_intervention(assessment.date, recommendation, index),
    )
  }
  interventions
}

///|
fn unique_interventions(
  interventions : Array[Intervention],
) -> Array[Intervention] {
  let output : Array[Intervention] = []
  for item in interventions {
    if output.filter(existing => existing.id == item.id).length() == 0 {
      output.push(item)
    }
  }
  output
}

///|
pub fn interventions_for_assessment(
  assessment : ComprehensiveAssessment,
) -> Array[Intervention] {
  unique_interventions(assessment_interventions(assessment))
}

///|
pub fn interventions_for_monitor(run : MonitoringRun) -> Array[Intervention] {
  let interventions = []
  for monitor in run.monitors {
    match monitor.assessment {
      Some(assessment) =>
        for item in assessment_interventions(assessment) {
          interventions.push(item)
        }
      None =>
        for alert in monitor.alerts {
          if alert.kind == MissingTelemetry {
            interventions.push(
              quality_intervention(monitor.date, alert.explanation),
            )
          }
        }
    }
  }
  unique_interventions(interventions)
}

///|
fn plan_review_date(anchor : String, review_days : Int) -> String {
  match parse_date(anchor) {
    Some(date) =>
      match add_days(date, review_days.max(0)) {
        Some(value) => format_date(value)
        None => anchor
      }
    None => anchor
  }
}

///|
fn plan_status(interventions : Array[Intervention]) -> String {
  if interventions.any(item => item.priority == Immediate) {
    "immediate"
  } else if interventions.any(item => item.priority == Soon) {
    "planned"
  } else if interventions.length() > 0 {
    "monitor"
  } else {
    "clear"
  }
}

///|
pub fn build_intervention_plan(
  assessment : ComprehensiveAssessment,
) -> InterventionPlan {
  let interventions = interventions_for_assessment(assessment)
  let review_days = interventions.fold(init=1, (days, item) => {
    days.max(item.review_after_days)
  })
  {
    anchor_date: assessment.date,
    interventions,
    target_load_change_percent: assessment.action_plan.load_change_percent,
    rest_days: assessment.action_plan.rest_days,
    review_date: plan_review_date(assessment.date, review_days),
    status: plan_status(interventions),
  }
}

///|
pub fn build_latest_intervention_plan(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> InterventionPlan? {
  match assess_latest(records, policy) {
    Some(assessment) => Some(build_intervention_plan(assessment))
    None => None
  }
}

///|
fn replace_intervention_status(
  item : Intervention,
  status : InterventionStatus,
) -> Intervention {
  {
    id: item.id,
    date: item.date,
    kind: item.kind,
    status,
    priority: item.priority,
    title: item.title,
    rationale: item.rationale,
    steps: item.steps,
    expected_load_change_percent: item.expected_load_change_percent,
    review_after_days: item.review_after_days,
    owner: item.owner,
  }
}

///|
pub fn update_intervention_status(
  plan : InterventionPlan,
  intervention_id : String,
  status : InterventionStatus,
) -> InterventionPlan {
  let items = plan.interventions.copy()
  for index, item in items {
    if item.id == intervention_id {
      items[index] = replace_intervention_status(item, status)
    }
  }
  {
    anchor_date: plan.anchor_date,
    interventions: items,
    target_load_change_percent: plan.target_load_change_percent,
    rest_days: plan.rest_days,
    review_date: plan.review_date,
    status: plan_status(items),
  }
}

///|
pub fn accept_all_interventions(plan : InterventionPlan) -> InterventionPlan {
  let items = plan.interventions.map(item => {
    replace_intervention_status(item, Accepted)
  })
  {
    anchor_date: plan.anchor_date,
    interventions: items,
    target_load_change_percent: plan.target_load_change_percent,
    rest_days: plan.rest_days,
    review_date: plan.review_date,
    status: plan_status(items),
  }
}

///|
pub fn complete_intervention(
  plan : InterventionPlan,
  intervention_id : String,
) -> InterventionPlan {
  update_intervention_status(plan, intervention_id, Completed)
}

///|
pub fn pending_interventions(plan : InterventionPlan) -> Array[Intervention] {
  plan.interventions.filter(item => {
    item.status != Completed && item.status != Cancelled
  })
}

///|
pub fn completed_interventions(plan : InterventionPlan) -> Array[Intervention] {
  plan.interventions.filter(item => item.status == Completed)
}

///|
pub fn intervention_count_by_kind(
  plan : InterventionPlan,
  kind : InterventionKind,
) -> Int {
  plan.interventions.filter(item => item.kind == kind).length()
}

///|
pub fn intervention_completion_percent(plan : InterventionPlan) -> Double {
  if plan.interventions.length() == 0 {
    0.0
  } else {
    completed_interventions(plan).length().to_double() /
    plan.interventions.length().to_double() *
    100.0
  }
}

///|
pub fn intervention_plan_is_safe(plan : InterventionPlan) -> Bool {
  plan.target_load_change_percent <= 0.0 ||
  plan.rest_days > 0 ||
  pending_interventions(plan).length() == 0
}

///|
pub fn review_intervention(
  intervention : Intervention,
  before : ComprehensiveAssessment,
  after : ComprehensiveAssessment,
) -> InterventionReview {
  let risk_change = after.risk_score - before.risk_score
  let readiness_change = after.readiness_score - before.readiness_score
  let effective = risk_change <= 0.0 && readiness_change >= -5.0
  {
    intervention_id: intervention.id,
    before_risk: before.risk_score,
    after_risk: after.risk_score,
    before_readiness: before.readiness_score,
    after_readiness: after.readiness_score,
    risk_change,
    readiness_change,
    effective,
    note: if effective {
      "risk did not worsen after the intervention"
    } else {
      "review intervention adherence and new evidence"
    },
  }
}

///|
pub fn intervention_plan_text(plan : InterventionPlan) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "status=" +
    plan.status +
    " anchor=" +
    plan.anchor_date +
    " review=" +
    plan.review_date,
  )
  builder.write_string(
    " load_change=" +
    plan.target_load_change_percent.to_string() +
    "% rest_days=" +
    plan.rest_days.to_string(),
  )
  for item in plan.interventions {
    builder.write_string(
      "\n- [" +
      intervention_status_name(item.status) +
      "] " +
      item.title +
      " (" +
      intervention_kind_name(item.kind) +
      ")",
    )
    builder.write_string(" reason=" + item.rationale)
  }
  builder.to_string()
}

///|
pub fn intervention_csv_header() -> String {
  "id,date,kind,status,priority,title,load_change,review_after_days,owner"
}

///|
pub fn intervention_csv(item : Intervention) -> String {
  item.id +
  "," +
  item.date +
  "," +
  intervention_kind_name(item.kind) +
  "," +
  intervention_status_name(item.status) +
  "," +
  recommendation_priority_name(item.priority) +
  "," +
  item.title +
  "," +
  item.expected_load_change_percent.to_string() +
  "," +
  item.review_after_days.to_string() +
  "," +
  item.owner
}

///|
pub fn intervention_plan_csv(plan : InterventionPlan) -> String {
  let builder = StringBuilder()
  builder.write_string(intervention_csv_header())
  for item in plan.interventions {
    builder.write_string("\n")
    builder.write_string(intervention_csv(item))
  }
  builder.to_string()
}

///|
pub fn intervention_plan_valid(plan : InterventionPlan) -> Bool {
  plan.anchor_date != "" &&
  plan.review_date != "" &&
  plan.rest_days >= 0 &&
  plan.interventions.all(item => {
    item.id != "" && item.title != "" && item.review_after_days >= 0
  })
}

///|
pub fn intervention_priority_counts(plan : InterventionPlan) -> Array[Int] {
  [
    plan.interventions.filter(item => item.priority == Immediate).length(),
    plan.interventions.filter(item => item.priority == Soon).length(),
    plan.interventions.filter(item => item.priority == Monitor).length(),
    plan.interventions.filter(item => item.priority == Positive).length(),
  ]
}

///|
pub fn intervention_owner_names(plan : InterventionPlan) -> Array[String] {
  let owners = []
  for item in plan.interventions {
    if !owners.contains(item.owner) {
      owners.push(item.owner)
    }
  }
  owners
}

///|
pub fn intervention_steps(plan : InterventionPlan) -> Array[String] {
  let steps = []
  for item in plan.interventions {
    for step in item.steps {
      steps.push(step)
    }
  }
  steps
}

///|
pub fn intervention_action_required(plan : InterventionPlan) -> Bool {
  pending_interventions(plan).any(item => {
    item.priority == Immediate || item.priority == Soon
  })
}
