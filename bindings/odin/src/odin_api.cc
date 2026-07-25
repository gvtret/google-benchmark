// C adapter implementation for Odin bindings to google-benchmark.
//
// Each function wraps a C++ benchmark:: method, casting the opaque void* back
// to the appropriate C++ type. The extern "C" linkage ensures C-compatible
// symbol names for Odin's foreign import.

#include "odin_api.h"

#include "benchmark/benchmark.h"

// ---- Lifecycle ----

extern "C" void benchmark_odin_initialize(int* argc, char** argv) {
  ::benchmark::Initialize(argc, argv);
}

extern "C" size_t benchmark_odin_run(void) {
  return ::benchmark::RunSpecifiedBenchmarks();
}

extern "C" void benchmark_odin_clear_registered_benchmarks(void) {
  ::benchmark::ClearRegisteredBenchmarks();
}

extern "C" void benchmark_odin_add_custom_context(const char* key, const char* value) {
  ::benchmark::AddCustomContext(key, value);
}

// ---- Benchmark registration ----

extern "C" void* benchmark_odin_register_benchmark(const char* name, benchmark_odin_fn fn) {
  return ::benchmark::RegisterBenchmark(
      name, [fn](benchmark::State& st) { fn(&st); });
}

// ---- Benchmark configuration ----

extern "C" void benchmark_odin_benchmark_arg(void* b, int64_t x) {
  static_cast<benchmark::Benchmark*>(b)->Arg(x);
}

extern "C" void benchmark_odin_benchmark_range(void* b, int64_t start, int64_t limit) {
  static_cast<benchmark::Benchmark*>(b)->Range(start, limit);
}

extern "C" void benchmark_odin_benchmark_dense_range(void* b, int64_t start, int64_t limit, int step) {
  static_cast<benchmark::Benchmark*>(b)->DenseRange(start, limit, step);
}

extern "C" void benchmark_odin_benchmark_args(void* b, const int64_t* args, size_t len) {
  std::vector<int64_t> v(args, args + len);
  static_cast<benchmark::Benchmark*>(b)->Args(v);
}

extern "C" void benchmark_odin_benchmark_unit(void* b, int unit) {
  static_cast<benchmark::Benchmark*>(b)->Unit(
      static_cast<benchmark::TimeUnit>(unit));
}

extern "C" void benchmark_odin_benchmark_threads(void* b, int t) {
  static_cast<benchmark::Benchmark*>(b)->Threads(t);
}

extern "C" void benchmark_odin_benchmark_thread_range(void* b, int min_threads, int max_threads) {
  static_cast<benchmark::Benchmark*>(b)->ThreadRange(min_threads, max_threads);
}

extern "C" void benchmark_odin_benchmark_min_time(void* b, double t) {
  static_cast<benchmark::Benchmark*>(b)->MinTime(t);
}

extern "C" void benchmark_odin_benchmark_iterations(void* b, int64_t n) {
  static_cast<benchmark::Benchmark*>(b)->Iterations(n);
}

extern "C" void benchmark_odin_benchmark_repetitions(void* b, int n) {
  static_cast<benchmark::Benchmark*>(b)->Repetitions(n);
}

extern "C" void benchmark_odin_benchmark_use_real_time(void* b) {
  static_cast<benchmark::Benchmark*>(b)->UseRealTime();
}

extern "C" void benchmark_odin_benchmark_use_manual_time(void* b) {
  static_cast<benchmark::Benchmark*>(b)->UseManualTime();
}

extern "C" void benchmark_odin_benchmark_complexity(void* b, int complexity) {
  static_cast<benchmark::Benchmark*>(b)->Complexity(
      static_cast<benchmark::BigO>(complexity));
}

extern "C" const char* benchmark_odin_benchmark_name(void* b) {
  return static_cast<benchmark::Benchmark*>(b)->GetName();
}

// ---- State methods ----

extern "C" bool benchmark_odin_state_keep_running(void* s) {
  return static_cast<benchmark::State*>(s)->KeepRunning();
}

extern "C" bool benchmark_odin_state_keep_running_batch(void* s, int64_t n) {
  return static_cast<benchmark::State*>(s)->KeepRunningBatch(n);
}

extern "C" void benchmark_odin_state_pause_timing(void* s) {
  static_cast<benchmark::State*>(s)->PauseTiming();
}

extern "C" void benchmark_odin_state_resume_timing(void* s) {
  static_cast<benchmark::State*>(s)->ResumeTiming();
}

extern "C" void benchmark_odin_state_skip_with_error(void* s, const char* msg) {
  static_cast<benchmark::State*>(s)->SkipWithError(msg);
}

extern "C" void benchmark_odin_state_set_bytes_processed(void* s, int64_t bytes) {
  static_cast<benchmark::State*>(s)->SetBytesProcessed(bytes);
}

extern "C" void benchmark_odin_state_set_items_processed(void* s, int64_t items) {
  static_cast<benchmark::State*>(s)->SetItemsProcessed(items);
}

extern "C" void benchmark_odin_state_set_label(void* s, const char* label) {
  static_cast<benchmark::State*>(s)->SetLabel(label);
}

extern "C" void benchmark_odin_state_set_complexity_n(void* s, int64_t n) {
  static_cast<benchmark::State*>(s)->SetComplexityN(n);
}

extern "C" int64_t benchmark_odin_state_range(void* s, size_t pos) {
  return static_cast<benchmark::State*>(s)->range(pos);
}

extern "C" int64_t benchmark_odin_state_iterations(void* s) {
  return static_cast<benchmark::State*>(s)->iterations();
}

extern "C" int benchmark_odin_state_threads(void* s) {
  return static_cast<benchmark::State*>(s)->threads();
}

extern "C" int benchmark_odin_state_thread_index(void* s) {
  return static_cast<benchmark::State*>(s)->thread_index();
}
