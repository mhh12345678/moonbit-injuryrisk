///|
/// Human-readable explanation of the engine's major outputs.
pub(all) struct Explanation {
  topic : String
  headline : String
  evidence : Array[String]
  caveats : Array[String]
} derive(Debug, Eq, ToJson)

///|
pub fn explain_assessment(assessment : ComprehensiveAssessment) -> Explanation {
  let evidence = [
    "risk level=" + risk_level_name(assessment.risk_level),
    "risk score=" + assessment.risk_score.to_string(),
    "readiness score=" + assessment.readiness_score.to_string(),
    "ACWR=" + assessment.load.acwr.to_string(),
    "recovery score=" + assessment.recovery.recovery_score.to_string(),
  ]
  let caveats = []
  if assessment.quality.missing_date_count > 0 {
    caveats.push("history contains missing dates")
  }
  if assessment.quality.duplicate_date_count > 0 {
    caveats.push("history contains duplicate dates")
  }
  if assessment.quality.blocking_issue_count > 0 {
    caveats.push("blocking data-quality issues must be fixed")
  }
  {
    topic: "injury risk assessment",
    headline: if assessment.risk_level == High {
      "high-risk signals require action"
    } else if assessment.risk_level == Medium {
      "risk signals require monitoring"
    } else {
      "no high-severity risk signal is active"
    },
    evidence,
    caveats,
  }
}

///|
pub fn explanation_text(explanation : Explanation) -> String {
  let builder = StringBuilder::new()
  builder.write_string(explanation.headline)
  builder.write_string("\nEvidence:")
  for item in explanation.evidence {
    builder.write_string("\n- " + item)
  }
  if explanation.caveats.length() > 0 {
    builder.write_string("\nCaveats:")
    for item in explanation.caveats {
      builder.write_string("\n- " + item)
    }
  }
  builder.to_string()
}
