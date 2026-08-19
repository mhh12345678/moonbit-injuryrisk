///|
test "acceptance packet composes the operational evidence chain" {
  let records = generate_healthy_athlete()
  let packet = acceptance_packet_for_records(records)
  assert_eq(acceptance_packet_record_count(packet), records.length())
  assert_true(acceptance_packet_valid(packet))
  assert_true(acceptance_packet_checksum_matches(packet))
  assert_true(acceptance_packet_has_audit(packet))
  assert_true(acceptance_packet_has_quality(packet))
  assert_true(acceptance_packet_csv(packet).contains("run_id"))
  assert_true(acceptance_packet_report(packet).contains("recommendation="))
  assert_eq(acceptance_packet_metric_names().length(), 12)
  assert_true(acceptance_packet_metrics_valid(packet))
}

///|
test "empty packet and scorecard remain explicit" {
  let empty : Array[DailyRecord] = []
  let packet = acceptance_packet_for_records(empty)
  assert_eq(acceptance_packet_record_count(packet), 0)
  assert_eq(
    acceptance_packet_empty_status(empty),
    acceptance_packet_status_value(packet),
  )
  assert_eq(acceptance_packet_validation_status(packet), "invalid")
  assert_true(acceptance_packet_validation_messages(packet).length() > 0)
  let scorecard = empty_operational_scorecard()
  assert_true(operational_scorecard_valid(scorecard))
  assert_eq(operational_scorecard_status(scorecard), "empty")
  assert_eq(operational_scorecard_page_count([], 10), 0)
  let page = operational_scorecard_page([], -4, -2)
  assert_true(operational_scorecard_page_valid(page))
  assert_true(operational_scorecard_page_is_empty(page))
  assert_eq(operational_scorecard_page_status(page), "empty")
}

///|
test "governance blocks malformed telemetry without corrupting the packet" {
  let invalid : Array[DailyRecord] = [
    DailyRecord::{
      date: "2026-08-01",
      training_duration: -1.0,
      training_intensity: 11.0,
      pain_level: 12.0,
      pain_site: None,
      sleep_hours: 30.0,
      sleep_quality: 6.0,
      fatigue: 11.0,
    },
  ]
  let packet = acceptance_packet_for_records(invalid)
  assert_true(acceptance_packet_blocked(packet))
  assert_true(acceptance_packet_blocking_issue_count(packet) > 0)
  assert_true(acceptance_packet_requires_follow_up(packet))
  assert_true(acceptance_packet_control_count(packet) >= 0)
  assert_eq(acceptance_packet_validation_status(packet), "invalid")
  assert_true(acceptance_packet_validation_messages(packet).length() > 0)
  assert_true(
    acceptance_packet_export_status(packet) == "blocked" ||
    !acceptance_packet_exportable(packet),
  )
}

///|
test "scorecard rows and pagination cover boundary navigation" {
  let records = generate_healthy_athlete()
  let packets = acceptance_packet_batch(records, [
    "2026-08-10", "2026-08-20", "2026-08-30",
  ])
  let scorecard = build_operational_scorecard(packets)
  let rows = operational_scorecard_rows(packets)
  assert_eq(operational_scorecard_count(scorecard), 3)
  assert_eq(operational_scorecard_row_count(rows), 3)
  assert_true(operational_scorecard_rows_valid(rows))
  assert_eq(operational_scorecard_page_count(rows, 2), 2)
  let first = operational_scorecard_page(rows, 0, 2)
  assert_eq(first.rows.length(), 2)
  assert_true(first.has_next)
  assert_true(!first.has_previous)
  let second = operational_scorecard_next_page(rows, first)
  assert_eq(second.rows.length(), 1)
  assert_true(second.has_previous)
  assert_true(!second.has_next)
  let last = operational_scorecard_next_page(rows, second)
  assert_eq(last.offset, second.offset)
  let previous = operational_scorecard_previous_page(rows, second)
  assert_eq(previous.offset, first.offset)
  let oversized = operational_scorecard_page(rows, 999, 20)
  assert_true(operational_scorecard_page_valid(oversized))
  assert_true(operational_scorecard_page_is_empty(oversized))
}

///|
test "service contract and batch comparison stay deterministic" {
  let records = generate_healthy_athlete()
  let config = default_decision_run_config()
  let request = service_request(
    "acceptance-test",
    "athlete",
    records,
    [],
    config,
  )
  assert_true(service_request_valid(request))
  let response = execute_service(request)
  assert_true(service_response_valid(response))
  let contract = validate_service_contract(request, response)
  assert_true(service_contract_valid(contract))
  assert_eq(service_status_code(contract.status), 200)
  let left = acceptance_packet_for_date(records, "2026-08-20")
  let right = acceptance_packet_for_date(records, "2026-08-30")
  let comparison = acceptance_packet_compare(left, right)
  assert_true(acceptance_packet_comparison_valid(comparison))
  assert_true(
    acceptance_packet_comparison_text(comparison).contains("conclusion="),
  )
  let delta = operational_scorecard_delta(
    build_operational_scorecard([left]),
    build_operational_scorecard([right]),
  )
  assert_true(operational_scorecard_delta_valid(delta))
  assert_true(operational_scorecard_delta_text(delta).contains("score_change="))
}

///|
test "input windows and projections reject unsafe ranges" {
  let records = generate_healthy_athlete()
  assert_eq(
    acceptance_packet_filter_valid_records(records).length(),
    records.length(),
  )
  assert_eq(acceptance_packet_valid_record_rate(records), 100.0)
  assert_true(acceptance_packet_has_date(records, records[0].date))
  let window = acceptance_packet_for_window(records, "2026-08-05", "2026-08-10")
  assert_eq(acceptance_packet_record_count(window), 6)
  let projected = acceptance_packet_metric_projection(window, [
    "risk", "quality", "unknown",
  ])
  assert_eq(projected.length(), 3)
  assert_eq(projected[2], 0.0)
  assert_true(acceptance_packet_metric_average(window, ["quality"]) >= 0.0)
  assert_true(
    acceptance_packet_metric_minimum(window, ["quality"]) <=
    acceptance_packet_metric_maximum(window, ["quality"]),
  )
}
