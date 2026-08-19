///|
fn main {
  let result = @lib.run_benchmark(100, 120)
  println(@lib.benchmark_result_text(result))
}
