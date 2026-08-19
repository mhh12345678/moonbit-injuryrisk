///|
/// Forecast review records comparing projected guardrails with observed outcomes.
pub(all) struct ForecastReview {
  date : String
  proposed_change : Double
  maximum_acwr : Double
  minimum_recovery : Double
  observed_acwr : Double
  observed_recovery : Double
  forecast_band : ForecastBand
  accurate_band : Bool
  error : Double
  note : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ForecastReviewSummary {
  reviews : Array[ForecastReview]
  count : Int
  accurate_count : Int
  accuracy_percent : Double
  average_error : Double
  optimistic_count : Int
  conservative_count : Int
  status : String
} derive(Debug, Eq, ToJson)

///|
fn observed_band(
  acwr : Double,
  recovery : Double,
  policy : RiskPolicy,
) -> ForecastBand {
  classify_forecast(acwr, recovery, policy.high_acwr)
}

///|
fn band_rank(band : ForecastBand) -> Int {
  match band {
    Safe => 0
    Caution => 1
    Unsafe => 2
    Unknown => -1
  }
}

///|
pub fn review_forecast(
  forecast : TrainingForecast,
  observed : ComprehensiveAssessment,
  policy : RiskPolicy,
) -> ForecastReview {
  let observed_band_value = observed_band(
    observed.load.acwr,
    observed.recovery.recovery_score,
    policy,
  )
  let forecast_band_value = if forecast.points.length() == 0 {
    ForecastBand::Unknown
  } else {
    forecast.points[forecast.points.length() - 1].band
  }
  let error = (forecast.maximum_acwr - observed.load.acwr).abs() +
    (forecast.minimum_recovery - observed.recovery.recovery_score).abs() / 100.0
  {
    date: observed.date,
    proposed_change: forecast.proposed_change_percent,
    maximum_acwr: forecast.maximum_acwr,
    minimum_recovery: forecast.minimum_recovery,
    observed_acwr: observed.load.acwr,
    observed_recovery: observed.recovery.recovery_score,
    forecast_band: forecast_band_value,
    accurate_band: band_rank(forecast_band_value) ==
    band_rank(observed_band_value),
    error,
    note: if band_rank(forecast_band_value) == band_rank(observed_band_value) {
      "forecast band matched observed band"
    } else {
      "forecast band differed from observed band"
    },
  }
}

///|
pub fn summarize_forecast_reviews(
  reviews : Array[ForecastReview],
) -> ForecastReviewSummary {
  let accurate = reviews.filter(review => review.accurate_band).length()
  let optimistic = reviews
    .filter(review => {
      band_rank(review.forecast_band) <
      band_rank(
        observed_band(
          review.observed_acwr,
          review.observed_recovery,
          default_risk_policy(),
        ),
      )
    })
    .length()
  let conservative = reviews
    .filter(review => {
      band_rank(review.forecast_band) >
      band_rank(
        observed_band(
          review.observed_acwr,
          review.observed_recovery,
          default_risk_policy(),
        ),
      )
    })
    .length()
  {
    reviews,
    count: reviews.length(),
    accurate_count: accurate,
    accuracy_percent: if reviews.length() == 0 {
      0.0
    } else {
      accurate.to_double() / reviews.length().to_double() * 100.0
    },
    average_error: mean_load_values(reviews.map(review => review.error)),
    optimistic_count: optimistic,
    conservative_count: conservative,
    status: if reviews.length() == 0 {
      "empty"
    } else if accurate.to_double() / reviews.length().to_double() >= 0.80 {
      "reliable"
    } else {
      "review"
    },
  }
}

///|
pub fn forecast_review_accuracy(summary : ForecastReviewSummary) -> Double {
  summary.accuracy_percent
}

///|
pub fn forecast_review_needs_calibration(
  summary : ForecastReviewSummary,
) -> Bool {
  summary.accuracy_percent < 70.0 || summary.average_error > 20.0
}

///|
pub fn forecast_review_recommendation(
  summary : ForecastReviewSummary,
) -> String {
  if summary.status == "empty" {
    "collect observed outcomes"
  } else if summary.optimistic_count > summary.conservative_count {
    "lower projected recovery or load assumptions"
  } else if forecast_review_needs_calibration(summary) {
    "review forecast window and thresholds"
  } else {
    "forecast behavior is acceptable for planning"
  }
}

///|
pub fn forecast_review_latest(
  summary : ForecastReviewSummary,
) -> ForecastReview? {
  if summary.reviews.length() == 0 {
    None
  } else {
    Some(summary.reviews[summary.reviews.length() - 1])
  }
}

///|
pub fn forecast_review_high_error(
  summary : ForecastReviewSummary,
  threshold : Double,
) -> Array[ForecastReview] {
  summary.reviews.filter(review => review.error > threshold)
}

///|
pub fn forecast_review_optimistic(
  summary : ForecastReviewSummary,
) -> Array[ForecastReview] {
  summary.reviews.filter(review => {
    review.forecast_band == Safe && review.observed_acwr >= 1.5
  })
}

///|
pub fn forecast_review_conservative(
  summary : ForecastReviewSummary,
) -> Array[ForecastReview] {
  summary.reviews.filter(review => {
    review.forecast_band == Unsafe && review.observed_acwr < 1.5
  })
}

///|
pub fn forecast_review_text(review : ForecastReview) -> String {
  review.date +
  " change=" +
  review.proposed_change.to_string() +
  "% forecast_acwr=" +
  review.maximum_acwr.to_string() +
  " observed_acwr=" +
  review.observed_acwr.to_string() +
  " forecast_recovery=" +
  review.minimum_recovery.to_string() +
  " observed_recovery=" +
  review.observed_recovery.to_string() +
  " accurate=" +
  review.accurate_band.to_string() +
  " error=" +
  review.error.to_string()
}

///|
pub fn forecast_review_summary_text(summary : ForecastReviewSummary) -> String {
  "status=" +
  summary.status +
  " count=" +
  summary.count.to_string() +
  " accuracy=" +
  summary.accuracy_percent.to_string() +
  "% error=" +
  summary.average_error.to_string() +
  " optimistic=" +
  summary.optimistic_count.to_string() +
  " conservative=" +
  summary.conservative_count.to_string() +
  " action=" +
  forecast_review_recommendation(summary)
}

///|
pub fn forecast_review_csv_header() -> String {
  "date,proposed_change,maximum_acwr,minimum_recovery,observed_acwr,observed_recovery,forecast_band,accurate,error,note"
}

///|
pub fn forecast_review_csv(review : ForecastReview) -> String {
  review.date +
  "," +
  review.proposed_change.to_string() +
  "," +
  review.maximum_acwr.to_string() +
  "," +
  review.minimum_recovery.to_string() +
  "," +
  review.observed_acwr.to_string() +
  "," +
  review.observed_recovery.to_string() +
  "," +
  forecast_band_name(review.forecast_band) +
  "," +
  review.accurate_band.to_string() +
  "," +
  review.error.to_string() +
  "," +
  review.note
}

///|
pub fn forecast_reviews_csv(summary : ForecastReviewSummary) -> String {
  let builder = StringBuilder::new()
  builder.write_string(forecast_review_csv_header())
  for review in summary.reviews {
    builder.write_string("\n")
    builder.write_string(forecast_review_csv(review))
  }
  builder.to_string()
}

///|
pub fn forecast_review_valid(review : ForecastReview) -> Bool {
  review.date != "" &&
  review.maximum_acwr >= 0.0 &&
  review.minimum_recovery >= 0.0 &&
  review.minimum_recovery <= 100.0 &&
  review.observed_acwr >= 0.0 &&
  review.observed_recovery >= 0.0 &&
  review.observed_recovery <= 100.0 &&
  review.error >= 0.0
}
