///|
/// Signal matrices expose which evidence is driving an assessment or run.
pub(all) struct SignalMatrixCell {
  kind : SignalKind
  name : String
  count : Int
  average_value : Double
  maximum_value : Double
  average_confidence : Double
  highest_severity : RiskLevel
  actions : Array[String]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct SignalMatrix {
  date : String
  cells : Array[SignalMatrixCell]
  total_signals : Int
  active_kinds : Int
  weighted_score : Double
  dominant_kind : String
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct SignalMatrixComparison {
  left_date : String
  right_date : String
  left_score : Double
  right_score : Double
  score_change : Double
  newly_active : Array[String]
  cleared : Array[String]
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
pub fn signal_matrix_kinds() -> Array[SignalKind] {
  [
    Workload,
    Recovery,
    Sleep,
    Pain,
    Fatigue,
    LoadSpike,
    Monotony,
    Trend,
    DataQuality,
    MissingHistory,
  ]
}

///|
fn signal_matrix_highest(left : RiskLevel, right : RiskLevel) -> RiskLevel {
  left.max(right)
}

///|
fn signal_matrix_cell(
  signals : Array[RiskSignal],
  kind : SignalKind,
) -> SignalMatrixCell {
  let values = signals.filter(signal => signal.kind == kind)
  let actions = values
    .map(signal => signal.action)
    .filter(action => action != "")
  {
    kind,
    name: signal_kind_name(kind),
    count: values.length(),
    average_value: mean_load_values(values.map(signal => signal.value)),
    maximum_value: maximum_load_values(values.map(signal => signal.value)),
    average_confidence: mean_load_values(
      values.map(signal => signal.confidence),
    ),
    highest_severity: values.fold(init=Low, (highest, signal) => {
      signal_matrix_highest(highest, signal.severity)
    }),
    actions,
  }
}

///|
fn signal_matrix_dominant_name(cells : Array[SignalMatrixCell]) -> String {
  if cells.length() == 0 {
    "none"
  } else {
    let mut result = cells[0]
    for cell in cells {
      if cell.count > result.count ||
        (
          cell.count == result.count &&
          cell.maximum_value > result.maximum_value
        ) {
        result = cell
      }
    }
    result.name
  }
}

///|
pub fn signal_matrix_from_signals(
  date : String,
  signals : Array[RiskSignal],
) -> SignalMatrix {
  let cells = signal_matrix_kinds().map(kind => {
    signal_matrix_cell(signals, kind)
  })
  let active = cells.filter(cell => cell.count > 0)
  let score = signals
    .fold(init=0.0, (total, signal) => total + signal.value * signal.confidence)
    .min(100.0)
  {
    date,
    cells,
    total_signals: signals.length(),
    active_kinds: active.length(),
    weighted_score: score,
    dominant_kind: signal_matrix_dominant_name(active),
    status: if signals.any(signal => signal.severity == High) {
      "high"
    } else if signals.any(signal => signal.severity == Medium) {
      "medium"
    } else if signals.length() > 0 {
      "low"
    } else {
      "empty"
    },
  }
}

///|
pub fn signal_matrix_from_assessment(
  assessment : ComprehensiveAssessment,
) -> SignalMatrix {
  signal_matrix_from_signals(assessment.date, assessment.signals.signals)
}

///|
pub fn signal_matrix_for_date(
  records : Array[DailyRecord],
  date : String,
  policy : RiskPolicy,
) -> SignalMatrix? {
  match assess_comprehensive(records, date, policy) {
    Some(assessment) => Some(signal_matrix_from_assessment(assessment))
    None => None
  }
}

///|
pub fn signal_matrix_cells(matrix : SignalMatrix) -> Array[SignalMatrixCell] {
  matrix.cells
}

///|
pub fn signal_matrix_cell_by_kind(
  matrix : SignalMatrix,
  kind : SignalKind,
) -> SignalMatrixCell? {
  for cell in matrix.cells {
    if cell.kind == kind {
      return Some(cell)
    }
  }
  None
}

///|
pub fn signal_matrix_cell_by_name(
  matrix : SignalMatrix,
  name : String,
) -> SignalMatrixCell? {
  for cell in matrix.cells {
    if cell.name == name {
      return Some(cell)
    }
  }
  None
}

///|
pub fn signal_matrix_active_cells(
  matrix : SignalMatrix,
) -> Array[SignalMatrixCell] {
  matrix.cells.filter(cell => cell.count > 0)
}

///|
pub fn signal_matrix_empty_cells(
  matrix : SignalMatrix,
) -> Array[SignalMatrixCell] {
  matrix.cells.filter(cell => cell.count == 0)
}

///|
pub fn signal_matrix_active_names(matrix : SignalMatrix) -> Array[String] {
  signal_matrix_active_cells(matrix).map(cell => cell.name)
}

///|
pub fn signal_matrix_empty_names(matrix : SignalMatrix) -> Array[String] {
  signal_matrix_empty_cells(matrix).map(cell => cell.name)
}

///|
pub fn signal_matrix_signal_count(
  matrix : SignalMatrix,
  kind : SignalKind,
) -> Int {
  match signal_matrix_cell_by_kind(matrix, kind) {
    Some(cell) => cell.count
    None => 0
  }
}

///|
pub fn signal_matrix_average(
  matrix : SignalMatrix,
  kind : SignalKind,
) -> Double {
  match signal_matrix_cell_by_kind(matrix, kind) {
    Some(cell) => cell.average_value
    None => 0.0
  }
}

///|
pub fn signal_matrix_maximum(
  matrix : SignalMatrix,
  kind : SignalKind,
) -> Double {
  match signal_matrix_cell_by_kind(matrix, kind) {
    Some(cell) => cell.maximum_value
    None => 0.0
  }
}

///|
pub fn signal_matrix_kind_confidence(
  matrix : SignalMatrix,
  kind : SignalKind,
) -> Double {
  match signal_matrix_cell_by_kind(matrix, kind) {
    Some(cell) => cell.average_confidence
    None => 0.0
  }
}

///|
pub fn signal_matrix_severity(
  matrix : SignalMatrix,
  kind : SignalKind,
) -> RiskLevel {
  match signal_matrix_cell_by_kind(matrix, kind) {
    Some(cell) => cell.highest_severity
    None => Low
  }
}

///|
pub fn signal_matrix_actions(
  matrix : SignalMatrix,
  kind : SignalKind,
) -> Array[String] {
  match signal_matrix_cell_by_kind(matrix, kind) {
    Some(cell) => cell.actions
    None => []
  }
}

///|
pub fn signal_matrix_actionable_cells(
  matrix : SignalMatrix,
) -> Array[SignalMatrixCell] {
  matrix.cells.filter(cell => {
    cell.highest_severity != Low || cell.actions.length() > 0
  })
}

///|
pub fn signal_matrix_actionable_names(matrix : SignalMatrix) -> Array[String] {
  signal_matrix_actionable_cells(matrix).map(cell => cell.name)
}

///|
pub fn signal_matrix_action_count(matrix : SignalMatrix) -> Int {
  signal_matrix_actionable_cells(matrix).fold(init=0, (total, cell) => {
    total + cell.actions.length()
  })
}

///|
pub fn signal_matrix_dominant(matrix : SignalMatrix) -> String {
  matrix.dominant_kind
}

///|
pub fn signal_matrix_status(matrix : SignalMatrix) -> String {
  matrix.status
}

///|
pub fn signal_matrix_score(matrix : SignalMatrix) -> Double {
  matrix.weighted_score
}

///|
pub fn signal_matrix_kind_count(matrix : SignalMatrix) -> Int {
  matrix.active_kinds
}

///|
pub fn signal_matrix_total_count(matrix : SignalMatrix) -> Int {
  matrix.total_signals
}

///|
pub fn signal_matrix_severity_counts(matrix : SignalMatrix) -> Array[Int] {
  [
    matrix.cells
    .filter(cell => cell.highest_severity == Low && cell.count > 0)
    .length(),
    matrix.cells.filter(cell => cell.highest_severity == Medium).length(),
    matrix.cells.filter(cell => cell.highest_severity == High).length(),
  ]
}

///|
pub fn signal_matrix_status_code(matrix : SignalMatrix) -> Int {
  if matrix.status == "high" {
    3
  } else if matrix.status == "medium" {
    2
  } else if matrix.status == "low" {
    1
  } else {
    0
  }
}

///|
pub fn signal_matrix_needs_review(matrix : SignalMatrix) -> Bool {
  matrix.status == "high" ||
  matrix.status == "medium" ||
  matrix.active_kinds == 0
}

///|
pub fn signal_matrix_is_clear(matrix : SignalMatrix) -> Bool {
  matrix.total_signals == 0
}

///|
pub fn signal_matrix_is_critical(matrix : SignalMatrix) -> Bool {
  matrix.status == "high"
}

///|
pub fn signal_matrix_confidence(matrix : SignalMatrix) -> Double {
  mean_load_values(
    signal_matrix_active_cells(matrix).map(cell => cell.average_confidence),
  )
}

///|
pub fn signal_matrix_coverage(matrix : SignalMatrix) -> Double {
  if matrix.cells.length() == 0 {
    0.0
  } else {
    matrix.active_kinds.to_double() / matrix.cells.length().to_double() * 100.0
  }
}

///|
pub fn signal_matrix_density(matrix : SignalMatrix) -> Double {
  if matrix.cells.length() == 0 {
    0.0
  } else {
    matrix.total_signals.to_double() / matrix.cells.length().to_double()
  }
}

///|
pub fn signal_matrix_cell_valid(cell : SignalMatrixCell) -> Bool {
  cell.name != "" &&
  cell.count >= 0 &&
  cell.average_value >= 0.0 &&
  cell.maximum_value >= cell.average_value &&
  cell.average_confidence >= 0.0 &&
  cell.average_confidence <= 1.0 &&
  cell.actions.all(action => action != "")
}

///|
pub fn signal_matrix_valid(matrix : SignalMatrix) -> Bool {
  matrix.date != "" &&
  matrix.total_signals >= 0 &&
  matrix.active_kinds >= 0 &&
  matrix.active_kinds <= matrix.cells.length() &&
  matrix.weighted_score >= 0.0 &&
  matrix.weighted_score <= 100.0 &&
  matrix.cells.all(cell => signal_matrix_cell_valid(cell))
}

///|
pub fn signal_matrix_checksum(matrix : SignalMatrix) -> String {
  let mut value = matrix.date.length() + matrix.total_signals
  for character in signal_matrix_text(matrix) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn signal_matrix_reproducible(
  left : SignalMatrix,
  right : SignalMatrix,
) -> Bool {
  signal_matrix_checksum(left) == signal_matrix_checksum(right)
}

///|
pub fn signal_matrix_cell_text(cell : SignalMatrixCell) -> String {
  cell.name +
  " count=" +
  cell.count.to_string() +
  " average=" +
  cell.average_value.to_string() +
  " maximum=" +
  cell.maximum_value.to_string() +
  " confidence=" +
  cell.average_confidence.to_string() +
  " severity=" +
  risk_level_name(cell.highest_severity) +
  " actions=" +
  cell.actions.join(";")
}

///|
pub fn signal_matrix_text(matrix : SignalMatrix) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "date=" +
    matrix.date +
    " status=" +
    matrix.status +
    " score=" +
    matrix.weighted_score.to_string() +
    " signals=" +
    matrix.total_signals.to_string() +
    " active_kinds=" +
    matrix.active_kinds.to_string() +
    " dominant=" +
    matrix.dominant_kind,
  )
  for cell in matrix.cells {
    builder.write_string("\n" + signal_matrix_cell_text(cell))
  }
  builder.to_string()
}

///|
pub fn signal_matrix_cell_csv_header() -> String {
  "kind,name,count,average_value,maximum_value,average_confidence,highest_severity,actions"
}

///|
pub fn signal_matrix_cell_csv(cell : SignalMatrixCell) -> String {
  signal_kind_name(cell.kind) +
  "," +
  cell.name +
  "," +
  cell.count.to_string() +
  "," +
  cell.average_value.to_string() +
  "," +
  cell.maximum_value.to_string() +
  "," +
  cell.average_confidence.to_string() +
  "," +
  risk_level_name(cell.highest_severity) +
  "," +
  cell.actions.join(";")
}

///|
pub fn signal_matrix_csv(matrix : SignalMatrix) -> String {
  let builder = StringBuilder()
  builder.write_string(signal_matrix_cell_csv_header())
  for cell in matrix.cells {
    builder.write_string("\n" + signal_matrix_cell_csv(cell))
  }
  builder.to_string()
}

///|
pub fn signal_matrix_summary_header() -> Array[String] {
  [
    "date", "status", "score", "signals", "active_kinds", "dominant", "coverage",
    "confidence",
  ]
}

///|
pub fn signal_matrix_summary(matrix : SignalMatrix) -> Array[String] {
  [
    matrix.date,
    matrix.status,
    matrix.weighted_score.to_string(),
    matrix.total_signals.to_string(),
    matrix.active_kinds.to_string(),
    matrix.dominant_kind,
    signal_matrix_coverage(matrix).to_string(),
    signal_matrix_confidence(matrix).to_string(),
  ]
}

///|
pub fn signal_matrix_summary_csv(matrix : SignalMatrix) -> String {
  signal_matrix_summary_header().join(",") +
  "\n" +
  signal_matrix_summary(matrix).join(",")
}

///|
pub fn signal_matrix_compare(
  left : SignalMatrix,
  right : SignalMatrix,
) -> SignalMatrixComparison {
  let left_names = signal_matrix_active_names(left)
  let right_names = signal_matrix_active_names(right)
  {
    left_date: left.date,
    right_date: right.date,
    left_score: left.weighted_score,
    right_score: right.weighted_score,
    score_change: right.weighted_score - left.weighted_score,
    newly_active: right_names.filter(name => !left_names.contains(name)),
    cleared: left_names.filter(name => !right_names.contains(name)),
    conclusion: if right.weighted_score < left.weighted_score {
      "signal burden decreased"
    } else if right.weighted_score > left.weighted_score {
      "signal burden increased"
    } else {
      "signal burden is stable"
    },
  }
}

///|
pub fn signal_matrix_comparison_text(
  comparison : SignalMatrixComparison,
) -> String {
  comparison.left_date +
  " -> " +
  comparison.right_date +
  " score_change=" +
  comparison.score_change.to_string() +
  " newly_active=" +
  comparison.newly_active.join(",") +
  " cleared=" +
  comparison.cleared.join(",") +
  " conclusion=" +
  comparison.conclusion
}

///|
pub fn signal_matrix_newly_active(
  left : SignalMatrix,
  right : SignalMatrix,
) -> Array[String] {
  signal_matrix_compare(left, right).newly_active
}

///|
pub fn signal_matrix_cleared(
  left : SignalMatrix,
  right : SignalMatrix,
) -> Array[String] {
  signal_matrix_compare(left, right).cleared
}

///|
pub fn signal_matrix_score_change(
  left : SignalMatrix,
  right : SignalMatrix,
) -> Double {
  right.weighted_score - left.weighted_score
}

///|
pub fn signal_matrix_dominant_changed(
  left : SignalMatrix,
  right : SignalMatrix,
) -> Bool {
  left.dominant_kind != right.dominant_kind
}

///|
pub fn signal_matrix_has_kind(matrix : SignalMatrix, kind : SignalKind) -> Bool {
  signal_matrix_signal_count(matrix, kind) > 0
}

///|
pub fn signal_matrix_has_action(matrix : SignalMatrix, action : String) -> Bool {
  matrix.cells.any(cell => cell.actions.contains(action))
}

///|
pub fn signal_matrix_all_actions(matrix : SignalMatrix) -> Array[String] {
  let actions = []
  for cell in matrix.cells {
    for action in cell.actions {
      if !actions.contains(action) {
        actions.push(action)
      }
    }
  }
  actions
}

///|
pub fn signal_matrix_action_text(matrix : SignalMatrix) -> String {
  signal_matrix_all_actions(matrix).join("; ")
}

///|
pub fn signal_matrix_recommendation(matrix : SignalMatrix) -> String {
  if matrix.status == "high" {
    "pause progression and review high-severity evidence"
  } else if matrix.status == "medium" {
    "stabilize the next load and review medium-severity evidence"
  } else if matrix.status == "low" {
    "continue monitoring the active signals"
  } else {
    "collect telemetry before making a risk decision"
  }
}

///|
pub fn signal_matrix_review_days(matrix : SignalMatrix) -> Int {
  if matrix.status == "high" {
    0
  } else if matrix.status == "medium" {
    1
  } else if matrix.status == "low" {
    3
  } else {
    7
  }
}

///|
pub fn signal_matrix_review_label(matrix : SignalMatrix) -> String {
  "review_in_" + signal_matrix_review_days(matrix).to_string() + "_days"
}

///|
pub fn signal_matrix_contract(matrix : SignalMatrix) -> Array[String] {
  [
    matrix.date,
    matrix.status,
    matrix.weighted_score.to_string(),
    signal_matrix_valid(matrix).to_string(),
    signal_matrix_needs_review(matrix).to_string(),
    signal_matrix_recommendation(matrix),
    signal_matrix_checksum(matrix),
  ]
}

///|
pub fn signal_matrix_quality(matrix : SignalMatrix) -> String {
  if !signal_matrix_valid(matrix) {
    "invalid"
  } else if matrix.active_kinds == 0 {
    "empty"
  } else if signal_matrix_confidence(matrix) < 0.7 {
    "limited"
  } else {
    "usable"
  }
}

///|
pub fn signal_matrix_quality_score(matrix : SignalMatrix) -> Double {
  signal_matrix_confidence(matrix) * 100.0
}

///|
pub fn signal_matrix_actionable_percent(matrix : SignalMatrix) -> Double {
  if matrix.cells.length() == 0 {
    0.0
  } else {
    signal_matrix_actionable_cells(matrix).length().to_double() /
    matrix.cells.length().to_double() *
    100.0
  }
}

///|
pub fn signal_matrix_high_severity_names(
  matrix : SignalMatrix,
) -> Array[String] {
  matrix.cells
  .filter(cell => cell.highest_severity == High)
  .map(cell => cell.name)
}

///|
pub fn signal_matrix_medium_severity_names(
  matrix : SignalMatrix,
) -> Array[String] {
  matrix.cells
  .filter(cell => cell.highest_severity == Medium)
  .map(cell => cell.name)
}

///|
pub fn signal_matrix_low_severity_names(matrix : SignalMatrix) -> Array[String] {
  matrix.cells
  .filter(cell => cell.highest_severity == Low && cell.count > 0)
  .map(cell => cell.name)
}

///|
pub fn signal_matrix_severity_names(matrix : SignalMatrix) -> Array[String] {
  let names = signal_matrix_high_severity_names(matrix) +
    signal_matrix_medium_severity_names(matrix) +
    signal_matrix_low_severity_names(matrix)
  names
}

///|
pub fn signal_matrix_kind_metrics(
  matrix : SignalMatrix,
  kind : SignalKind,
) -> Array[String] {
  [
    signal_matrix_signal_count(matrix, kind).to_string(),
    signal_matrix_average(matrix, kind).to_string(),
    signal_matrix_maximum(matrix, kind).to_string(),
    signal_matrix_kind_confidence(matrix, kind).to_string(),
    risk_level_name(signal_matrix_severity(matrix, kind)),
  ]
}

///|
pub fn signal_matrix_kind_metrics_csv(
  matrix : SignalMatrix,
  kind : SignalKind,
) -> String {
  signal_kind_name(kind) +
  "," +
  signal_matrix_kind_metrics(matrix, kind).join(",")
}

///|
pub fn signal_matrix_kind_metrics_header() -> String {
  "kind,count,average,maximum,confidence,severity"
}

///|
pub fn signal_matrix_kind_metrics_csv_all(matrix : SignalMatrix) -> String {
  let builder = StringBuilder()
  builder.write_string(signal_matrix_kind_metrics_header())
  for kind in signal_matrix_kinds() {
    builder.write_string("\n" + signal_matrix_kind_metrics_csv(matrix, kind))
  }
  builder.to_string()
}

///|
pub fn signal_matrix_date(matrix : SignalMatrix) -> String {
  matrix.date
}

///|
pub fn signal_matrix_latest_status(matrix : SignalMatrix) -> String {
  matrix.status
}

///|
pub fn signal_matrix_exportable(matrix : SignalMatrix) -> Bool {
  signal_matrix_valid(matrix) && matrix.date != ""
}

///|
pub fn signal_matrix_export_status(matrix : SignalMatrix) -> String {
  if signal_matrix_exportable(matrix) {
    "exportable"
  } else {
    "blocked"
  }
}

///|
pub fn signal_matrix_report_line(matrix : SignalMatrix) -> String {
  matrix.date +
  " status=" +
  matrix.status +
  " score=" +
  matrix.weighted_score.to_string() +
  " dominant=" +
  matrix.dominant_kind +
  " review=" +
  signal_matrix_needs_review(matrix).to_string()
}
