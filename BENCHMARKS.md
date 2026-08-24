# Injury Risk Benchmarks

This benchmark is deterministic and runs entirely from generated in-memory
telemetry. It creates a 120-day progressive workload, executes 100 complete
latest-assessment passes, and reports a checksum over the resulting scores.
The checksum makes the result useful as a regression signal in addition to a
wall-clock measurement.

## Command

```bash
moon run --target native --release cmd/bench
```

Expected deterministic output:

```text
iterations=100 records=120 assessments=100 high_risk=100 checksum=9326.41248108302
```

## Local Measurement

Measured on Windows in the local development environment on 2026-08-24 with
MoonBit stable `0.1.20260824`, Moonc `0.10.10`, and a warm native release
executable. The release executable was built once with `moon build`; the five
measurements below used PowerShell `Measure-Command` around the executable and
were taken after one warm-up run.

| Run | Wall time |
| ---: | ---: |
| 1 | 248.78 ms |
| 2 | 237.40 ms |
| 3 | 249.48 ms |
| 4 | 233.23 ms |
| 5 | 217.93 ms |
| Median | 237.40 ms |
| Mean | 237.36 ms |

The values are intended for regression comparison on the same or a similar
machine. They are not a claim about clinical accuracy or a universal hardware
throughput limit.

## Test Snapshot

On the same date and toolchain, all-target tests passed 28 of 28 tests on
wasm, wasm-gc, JavaScript, and native. The native coverage report recorded
3,740 covered lines out of 18,337 instrumented MoonBit lines (20.40%).
