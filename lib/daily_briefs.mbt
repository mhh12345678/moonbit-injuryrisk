///|
/// Human-readable daily brief assembled from the deterministic pipeline.
pub(all) struct DailyBrief {
  date : String
  headline : String
  risk_level : RiskLevel
  risk_score : Double
  readiness_score : Double
  load_summary : String
  recovery_summary : String
  top_signal : String
  action : String
  data_note : String
  follow_up : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct BriefSeries {
  briefs : Array[DailyBrief]
  high_count : Int
  action_count : Int
  average_risk : Double
  average_readiness : Double
  status : String
} derive(Debug, Eq, ToJson)

///|
fn brief_headline(assessment : ComprehensiveAssessment) -> String {
  if assessment.risk_level == High {
    "high-risk training day"
  } else if assessment.risk_level == Medium {
    "monitor training stress"
  } else if assessment.readiness_score >= 80.0 {
    "ready for planned progression"
  } else {
    "stable but recovery should be monitored"
  }
}

///|
fn brief_signal(assessment : ComprehensiveAssessment) -> String {
  if assessment.signals.signals.length() == 0 {
    "no active risk signal"
  } else {
    assessment.signals.signals[0].title +
    ": " +
    assessment.signals.signals[0].evidence
  }
}

///|
pub fn daily_brief(assessment : ComprehensiveAssessment) -> DailyBrief {
  {
    date: assessment.date,
    headline: brief_headline(assessment),
    risk_level: assessment.risk_level,
    risk_score: assessment.risk_score,
    readiness_score: assessment.readiness_score,
    load_summary: "acute=" +
    assessment.load.acute_load.to_string() +
    " chronic=" +
    assessment.load.chronic_load.to_string() +
    " acwr=" +
    assessment.load.acwr.to_string(),
    recovery_summary: "score=" +
    assessment.recovery.recovery_score.to_string() +
    " sleep_debt=" +
    assessment.recovery.sleep_debt_hours.to_string() +
    " fatigue=" +
    assessment.recovery.average_fatigue.to_string(),
    top_signal: brief_signal(assessment),
    action: assessment.action_plan.focus,
    data_note: quality_report_text(assessment.quality),
    follow_up: if assessment.risk_level == High {
      "review before next session"
    } else {
      "next daily check-in"
    },
  }
}

///|
pub fn daily_brief_for_date(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  date : String,
) -> DailyBrief? {
  match assess_comprehensive(records, date, policy) {
    Some(assessment) => Some(daily_brief(assessment))
    None => None
  }
}

///|
pub fn daily_briefs(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> Array[DailyBrief] {
  let sorted = sort_records_by_date(records)
  let output = []
  for record in sorted {
    match daily_brief_for_date(sorted, policy, record.date) {
      Some(brief) => output.push(brief)
      None => ()
    }
  }
  output
}

///|
pub fn brief_series(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> BriefSeries {
  let briefs = daily_briefs(records, policy)
  {
    briefs,
    high_count: briefs.filter(brief => brief.risk_level == High).length(),
    action_count: briefs
    .filter(brief => brief.risk_level != Low || brief.readiness_score < 70.0)
    .length(),
    average_risk: mean_load_values(briefs.map(brief => brief.risk_score)),
    average_readiness: mean_load_values(
      briefs.map(brief => brief.readiness_score),
    ),
    status: if briefs.any(brief => brief.risk_level == High) {
      "action_required"
    } else if briefs.any(brief => brief.risk_level == Medium) {
      "watch"
    } else {
      "stable"
    },
  }
}

///|
pub fn brief_high_risk_dates(series : BriefSeries) -> Array[String] {
  series.briefs
  .filter(brief => brief.risk_level == High)
  .map(brief => brief.date)
}

///|
pub fn brief_action_dates(series : BriefSeries) -> Array[String] {
  series.briefs
  .filter(brief => brief.risk_level != Low || brief.readiness_score < 70.0)
  .map(brief => brief.date)
}

///|
pub fn brief_latest(series : BriefSeries) -> DailyBrief? {
  if series.briefs.length() == 0 {
    None
  } else {
    Some(series.briefs[series.briefs.length() - 1])
  }
}

///|
pub fn brief_risk_trend(series : BriefSeries) -> LoadTrend {
  load_trend(series.briefs.map(brief => brief.risk_score), 0.1)
}

///|
pub fn brief_readiness_trend(series : BriefSeries) -> LoadTrend {
  load_trend(series.briefs.map(brief => brief.readiness_score), 0.1)
}

///|
pub fn brief_requires_review(brief : DailyBrief) -> Bool {
  brief.risk_level == High ||
  brief.risk_score >= 40.0 ||
  brief.readiness_score < 60.0
}

///|
pub fn brief_text(brief : DailyBrief) -> String {
  brief.date +
  " " +
  brief.headline +
  " risk=" +
  brief.risk_score.to_string() +
  " readiness=" +
  brief.readiness_score.to_string() +
  "\nload: " +
  brief.load_summary +
  "\nrecovery: " +
  brief.recovery_summary +
  "\nsignal: " +
  brief.top_signal +
  "\naction: " +
  brief.action +
  "\ndata: " +
  brief.data_note +
  "\nfollow_up: " +
  brief.follow_up
}

///|
pub fn brief_series_text(series : BriefSeries) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "status=" +
    series.status +
    " briefs=" +
    series.briefs.length().to_string() +
    " high=" +
    series.high_count.to_string() +
    " actions=" +
    series.action_count.to_string() +
    " average_risk=" +
    series.average_risk.to_string() +
    " average_readiness=" +
    series.average_readiness.to_string(),
  )
  for brief in series.briefs {
    builder.write_string("\n\n" + brief_text(brief))
  }
  builder.to_string()
}

///|
pub fn daily_brief_csv_header() -> String {
  "date,headline,risk_level,risk_score,readiness_score,load_summary,recovery_summary,top_signal,action,follow_up"
}

///|
pub fn daily_brief_csv(brief : DailyBrief) -> String {
  brief.date +
  "," +
  brief.headline +
  "," +
  risk_level_name(brief.risk_level) +
  "," +
  brief.risk_score.to_string() +
  "," +
  brief.readiness_score.to_string() +
  "," +
  brief.load_summary +
  "," +
  brief.recovery_summary +
  "," +
  brief.top_signal +
  "," +
  brief.action +
  "," +
  brief.follow_up
}

///|
pub fn brief_series_csv(series : BriefSeries) -> String {
  let builder = StringBuilder()
  builder.write_string(daily_brief_csv_header())
  for brief in series.briefs {
    builder.write_string("\n")
    builder.write_string(daily_brief_csv(brief))
  }
  builder.to_string()
}

///|
pub fn daily_brief_valid(brief : DailyBrief) -> Bool {
  brief.date != "" &&
  brief.headline != "" &&
  brief.risk_score >= 0.0 &&
  brief.risk_score <= 100.0 &&
  brief.readiness_score >= 0.0 &&
  brief.readiness_score <= 100.0 &&
  brief.action != ""
}
