///|
/// Cohort slices for comparing training groups without hiding small samples.
pub(all) enum CohortSegmentKind {
  CohortLowRisk
  CohortMediumRisk
  CohortHighRisk
  CohortLowReadiness
  CohortHighLoad
  CohortLowCoverage
  CohortPainWatch
  CohortRecoveryWatch
} derive(Debug, Eq, ToJson)

///|
pub(all) struct CohortSegment {
  kind : CohortSegmentKind
  name : String
  athlete_ids : Array[String]
  sample_count : Int
  mean_risk : Double
  mean_readiness : Double
  mean_load : Double
  mean_recovery : Double
  mean_pain : Double
  coverage_percent : Double
  usable : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct CohortComparison {
  left_name : String
  right_name : String
  risk_difference : Double
  readiness_difference : Double
  load_difference : Double
  recovery_difference : Double
  relative_risk_percent : Double
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
pub fn cohort_segment_name(kind : CohortSegmentKind) -> String {
  match kind {
    CohortLowRisk => "low_risk"
    CohortMediumRisk => "medium_risk"
    CohortHighRisk => "high_risk"
    CohortLowReadiness => "low_readiness"
    CohortHighLoad => "high_load"
    CohortLowCoverage => "low_coverage"
    CohortPainWatch => "pain_watch"
    CohortRecoveryWatch => "recovery_watch"
  }
}

///|
fn segment_filter(
  rows : Array[PopulationRow],
  kind : CohortSegmentKind,
) -> Array[PopulationRow] {
  match kind {
    CohortLowRisk => rows.filter(row => row.risk_level == Low)
    CohortMediumRisk => rows.filter(row => row.risk_level == Medium)
    CohortHighRisk => rows.filter(row => row.risk_level == High)
    CohortLowReadiness => rows.filter(row => row.readiness_score < 60.0)
    CohortHighLoad =>
      rows.filter(row => {
        row.load >= population_metric_percentile(rows, PopulationLoad, 0.75)
      })
    CohortLowCoverage => rows.filter(row => row.coverage_percent < 80.0)
    CohortPainWatch => rows.filter(row => row.pain >= 4.0)
    CohortRecoveryWatch => rows.filter(row => row.recovery < 60.0)
  }
}

///|
pub fn build_cohort_segment(
  rows : Array[PopulationRow],
  kind : CohortSegmentKind,
) -> CohortSegment {
  let selected = segment_filter(rows, kind)
  {
    kind,
    name: cohort_segment_name(kind),
    athlete_ids: selected.map(row => row.athlete_id),
    sample_count: selected.fold(init=0, (total, row) => total + row.sample_count),
    mean_risk: mean_load_values(selected.map(row => row.risk_score)),
    mean_readiness: mean_load_values(selected.map(row => row.readiness_score)),
    mean_load: mean_load_values(selected.map(row => row.load)),
    mean_recovery: mean_load_values(selected.map(row => row.recovery)),
    mean_pain: mean_load_values(selected.map(row => row.pain)),
    coverage_percent: mean_load_values(
      selected.map(row => row.coverage_percent),
    ),
    usable: selected.length() >= 2,
  }
}

///|
pub fn all_cohort_segments(rows : Array[PopulationRow]) -> Array[CohortSegment] {
  cohort_segment_kinds().map(kind => build_cohort_segment(rows, kind))
}

///|
pub fn cohort_segment_kinds() -> Array[CohortSegmentKind] {
  [
    CohortLowRisk,
    CohortMediumRisk,
    CohortHighRisk,
    CohortLowReadiness,
    CohortHighLoad,
    CohortLowCoverage,
    CohortPainWatch,
    CohortRecoveryWatch,
  ]
}

///|
pub fn cohort_segment_for_name(
  segments : Array[CohortSegment],
  name : String,
) -> CohortSegment? {
  for segment in segments {
    if segment.name == name {
      return Some(segment)
    }
  }
  None
}

///|
pub fn cohort_segment_overlap(
  left : CohortSegment,
  right : CohortSegment,
) -> Array[String] {
  left.athlete_ids.filter(id => right.athlete_ids.contains(id))
}

///|
pub fn cohort_segment_union(
  left : CohortSegment,
  right : CohortSegment,
) -> Array[String] {
  let ids = left.athlete_ids.copy()
  for id in right.athlete_ids {
    if !ids.contains(id) {
      ids.push(id)
    }
  }
  ids
}

///|
pub fn cohort_segment_exclusive(
  left : CohortSegment,
  right : CohortSegment,
) -> Array[String] {
  left.athlete_ids.filter(id => !right.athlete_ids.contains(id))
}

///|
pub fn compare_cohort_segments(
  left : CohortSegment,
  right : CohortSegment,
) -> CohortComparison {
  let relative = percentage_change(right.mean_risk, left.mean_risk)
  {
    left_name: left.name,
    right_name: right.name,
    risk_difference: left.mean_risk - right.mean_risk,
    readiness_difference: left.mean_readiness - right.mean_readiness,
    load_difference: left.mean_load - right.mean_load,
    recovery_difference: left.mean_recovery - right.mean_recovery,
    relative_risk_percent: relative,
    conclusion: if left.mean_risk > right.mean_risk + 10.0 {
      "left segment has higher risk"
    } else if right.mean_risk > left.mean_risk + 10.0 {
      "right segment has higher risk"
    } else {
      "risk levels are similar"
    },
  }
}

///|
pub fn largest_cohort_segment(
  segments : Array[CohortSegment],
) -> CohortSegment? {
  if segments.length() == 0 {
    return None
  }
  let mut best = segments[0]
  for segment in segments {
    if segment.athlete_ids.length() > best.athlete_ids.length() {
      best = segment
    }
  }
  Some(best)
}

///|
pub fn smallest_usable_cohort_segment(
  segments : Array[CohortSegment],
) -> CohortSegment? {
  let usable = segments.filter(segment => segment.usable)
  if usable.length() == 0 {
    return None
  }
  let mut best = usable[0]
  for segment in usable {
    if segment.athlete_ids.length() < best.athlete_ids.length() {
      best = segment
    }
  }
  Some(best)
}

///|
pub fn cohort_segment_actionable(
  segments : Array[CohortSegment],
) -> Array[CohortSegment] {
  segments.filter(segment => {
    segment.kind == CohortHighRisk ||
    segment.kind == CohortLowReadiness ||
    segment.kind == CohortLowCoverage ||
    segment.kind == CohortPainWatch
  })
}

///|
pub fn cohort_segment_sample_warning(segment : CohortSegment) -> Bool {
  !segment.usable || segment.athlete_ids.length() < 5
}

///|
pub fn cohort_segment_quality(segments : Array[CohortSegment]) -> String {
  if segments.length() == 0 {
    "empty"
  } else if segments.any(segment => cohort_segment_sample_warning(segment)) {
    "small_samples_present"
  } else {
    "usable"
  }
}

///|
pub fn cohort_segment_summary_text(segment : CohortSegment) -> String {
  segment.name +
  " athletes=" +
  segment.athlete_ids.length().to_string() +
  " samples=" +
  segment.sample_count.to_string() +
  " risk=" +
  segment.mean_risk.to_string() +
  " readiness=" +
  segment.mean_readiness.to_string() +
  " coverage=" +
  segment.coverage_percent.to_string() +
  "% usable=" +
  segment.usable.to_string()
}

///|
pub fn cohort_comparison_text(comparison : CohortComparison) -> String {
  comparison.left_name +
  " vs " +
  comparison.right_name +
  " risk_delta=" +
  comparison.risk_difference.to_string() +
  " readiness_delta=" +
  comparison.readiness_difference.to_string() +
  " conclusion=" +
  comparison.conclusion
}

///|
pub fn cohort_segment_csv_header() -> String {
  "name,athlete_count,sample_count,mean_risk,mean_readiness,mean_load,mean_recovery,mean_pain,coverage_percent,usable"
}

///|
pub fn cohort_segment_csv(segment : CohortSegment) -> String {
  segment.name +
  "," +
  segment.athlete_ids.length().to_string() +
  "," +
  segment.sample_count.to_string() +
  "," +
  segment.mean_risk.to_string() +
  "," +
  segment.mean_readiness.to_string() +
  "," +
  segment.mean_load.to_string() +
  "," +
  segment.mean_recovery.to_string() +
  "," +
  segment.mean_pain.to_string() +
  "," +
  segment.coverage_percent.to_string() +
  "," +
  segment.usable.to_string()
}

///|
pub fn cohort_segments_csv(segments : Array[CohortSegment]) -> String {
  let builder = StringBuilder()
  builder.write_string(cohort_segment_csv_header())
  for segment in segments {
    builder.write_string("\n")
    builder.write_string(cohort_segment_csv(segment))
  }
  builder.to_string()
}

///|
pub fn cohort_segment_valid(segment : CohortSegment) -> Bool {
  segment.name != "" &&
  segment.sample_count >= 0 &&
  segment.mean_risk >= 0.0 &&
  segment.mean_risk <= 100.0 &&
  segment.mean_readiness >= 0.0 &&
  segment.mean_readiness <= 100.0 &&
  segment.coverage_percent >= 0.0 &&
  segment.coverage_percent <= 100.0
}
