///|
/// Concrete actions that can be attached to a risk signal.
pub(all) enum RecoveryActionKind {
  Rest
  Sleep
  Hydration
  Mobility
  LoadReduction
  ClinicalReview
  DataRepair
  Continue
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RecoveryAction {
  kind : RecoveryActionKind
  title : String
  priority : RecommendationPriority
  duration_days : Int
  load_change_percent : Double
  reason : String
  completion_check : String
} derive(Debug, Eq, ToJson)

///|
pub fn recovery_action_name(kind : RecoveryActionKind) -> String {
  match kind {
    Rest => "rest"
    Sleep => "sleep"
    Hydration => "hydration"
    Mobility => "mobility"
    LoadReduction => "load-reduction"
    ClinicalReview => "clinical-review"
    DataRepair => "data-repair"
    Continue => "continue"
  }
}

///|
fn action(
  kind : RecoveryActionKind,
  title : String,
  priority : RecommendationPriority,
  duration_days : Int,
  load_change_percent : Double,
  reason : String,
  completion_check : String,
) -> RecoveryAction {
  {
    kind,
    title,
    priority,
    duration_days,
    load_change_percent,
    reason,
    completion_check,
  }
}

///|
pub fn action_for_signal(signal : RiskSignal) -> RecoveryAction {
  match signal.kind {
    Pain =>
      action(
        ClinicalReview,
        "Review pain before loading",
        Immediate,
        1,
        -40.0,
        signal.evidence,
        "pain remains below 3/10 for two days",
      )
    Workload | LoadSpike | Monotony =>
      action(
        LoadReduction,
        "Reduce acute training load",
        Soon,
        3,
        -20.0,
        signal.evidence,
        "ACWR returns below policy threshold",
      )
    Sleep | Recovery | Fatigue =>
      action(
        Sleep,
        "Protect recovery opportunity",
        Soon,
        3,
        -10.0,
        signal.evidence,
        "sleep and fatigue return to target",
      )
    DataQuality | MissingHistory =>
      action(
        DataRepair,
        "Repair telemetry baseline",
        Immediate,
        1,
        0.0,
        signal.evidence,
        "quality score reaches 90 or higher",
      )
    Trend =>
      action(
        Mobility,
        "Add a low-load transition day",
        Monitor,
        1,
        -10.0,
        signal.evidence,
        "trend slope returns to stable",
      )
  }
}

///|
pub fn actions_from_assessment(
  assessment : ComprehensiveAssessment,
) -> Array[RecoveryAction] {
  if assessment.signals.signal_count == 0 {
    [
      action(
        Continue,
        "Continue planned progression",
        Positive,
        0,
        0.0,
        "no active risk signals",
        "readiness remains above 75",
      ),
    ]
  } else {
    assessment.signals.signals.map(signal => action_for_signal(signal))
  }
}

///|
pub fn strongest_action(actions : Array[RecoveryAction]) -> RecoveryAction? {
  if actions.length() == 0 {
    None
  } else {
    let mut strongest = actions[0]
    for item in actions {
      let current = match item.priority {
        Immediate => 4
        Soon => 3
        Monitor => 2
        Positive => 1
      }
      let best = match strongest.priority {
        Immediate => 4
        Soon => 3
        Monitor => 2
        Positive => 1
      }
      if current > best {
        strongest = item
      }
    }
    Some(strongest)
  }
}

///|
pub fn action_plan_load_change(actions : Array[RecoveryAction]) -> Double {
  if actions.length() == 0 {
    0.0
  } else {
    let mut total = 0.0
    for item in actions {
      total += item.load_change_percent
    }
    total / actions.length().to_double()
  }
}

///|
pub fn action_text(action : RecoveryAction) -> String {
  "[" +
  recommendation_priority_name(action.priority) +
  "] " +
  action.title +
  " duration=" +
  action.duration_days.to_string() +
  "d change=" +
  action.load_change_percent.to_string() +
  "% check=" +
  action.completion_check
}

///|
pub fn action_catalog() -> Array[RecoveryAction] {
  [
    action(
      Rest,
      "Complete a rest day",
      Soon,
      1,
      -100.0,
      "acute load is elevated",
      "next day has zero training load",
    ),
    action(
      Sleep,
      "Extend sleep opportunity",
      Soon,
      3,
      -10.0,
      "sleep debt is accumulating",
      "average sleep reaches eight hours",
    ),
    action(
      Hydration,
      "Restore hydration routine",
      Monitor,
      1,
      0.0,
      "recovery support action",
      "daily routine is recorded",
    ),
    action(
      Mobility,
      "Use low-load mobility",
      Monitor,
      2,
      -15.0,
      "stiffness or fatigue is elevated",
      "pain does not increase",
    ),
    action(
      LoadReduction,
      "Reduce training load",
      Soon,
      3,
      -20.0,
      "load guardrail is crossed",
      "acute load returns to baseline",
    ),
    action(
      ClinicalReview,
      "Request clinical review",
      Immediate,
      1,
      -40.0,
      "persistent or severe pain",
      "review is documented",
    ),
    action(
      DataRepair,
      "Repair data quality",
      Immediate,
      1,
      0.0,
      "incomplete telemetry",
      "quality score is acceptable",
    ),
    action(
      Continue,
      "Continue planned progression",
      Positive,
      0,
      0.0,
      "signals are clear",
      "readiness remains stable",
    ),
  ]
}
