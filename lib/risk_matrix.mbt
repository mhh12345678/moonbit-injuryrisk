///|
/// A small risk matrix used for explainable severity calibration.
pub(all) struct RiskMatrixCell {
  likelihood : Int
  consequence : Int
  score : Int
  level : RiskLevel
} derive(Debug, Eq, ToJson)

///|
pub fn risk_matrix_cell(likelihood : Int, consequence : Int) -> RiskMatrixCell {
  let safe_likelihood = likelihood.max(1).min(5)
  let safe_consequence = consequence.max(1).min(5)
  let score = safe_likelihood * safe_consequence
  {
    likelihood: safe_likelihood,
    consequence: safe_consequence,
    score,
    level: if score >= 15 {
      High
    } else if score >= 8 {
      Medium
    } else {
      Low
    },
  }
}

///|
pub fn risk_matrix_level_name(cell : RiskMatrixCell) -> String {
  risk_level_name(cell.level) + " (" + cell.score.to_string() + "/25)"
}

///|
pub fn risk_matrix_table() -> Array[RiskMatrixCell] {
  let cells = []
  for likelihood in 1..<=5 {
    for consequence in 1..<=5 {
      cells.push(risk_matrix_cell(likelihood, consequence))
    }
  }
  cells
}

///|
pub fn signal_risk_matrix(signal : RiskSignal) -> RiskMatrixCell {
  let likelihood = (signal.confidence * 5.0).to_int().max(1)
  let consequence = match signal.severity {
    Low => 1
    Medium => 3
    High => 5
  }
  risk_matrix_cell(likelihood, consequence)
}
