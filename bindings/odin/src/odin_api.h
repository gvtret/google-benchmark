// C adapter layer for Odin bindings to google-benchmark.
//
// This header provides an extern "C" interface that wraps the C++
// google-benchmark library. Odin imports this via @cImport / foreign import.
//
// Design: all C++ types (benchmark::State, benchmark::Benchmark) are passed as
// opaque void* pointers. The Odin side wraps them in typed structs. Benchmark
// configuration methods return void so Odin can implement fluent chaining by
// returning self.

#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ---- Lifecycle ----

// Initialize the benchmark library with command-line arguments.
// Must be called before benchmark_odin_run().
void benchmark_odin_initialize(int* argc, char** argv);

// Run all registered benchmarks and return the number of benchmarks executed.
size_t benchmark_odin_run(void);

// Remove all registered benchmarks.
void benchmark_odin_clear_registered_benchmarks(void);

// Add a custom key-value context to benchmark output (e.g., for JSON reports).
void benchmark_odin_add_custom_context(const char* key, const char* value);

// ---- Benchmark registration ----

// Callback type: receives an opaque State* pointer for each iteration.
typedef void (*benchmark_odin_fn)(void* state);

// Register a benchmark with the given name and callback.
// Returns an opaque Benchmark* pointer for configuration (arg, range, threads,
// etc.).
void* benchmark_odin_register_benchmark(const char* name, benchmark_odin_fn fn);

// ---- Benchmark configuration ----
// All methods take an opaque Benchmark* and return void.
// Odin wraps them as: method :: (self: Benchmark, ...) Benchmark { c_api(...);
// return self; }

// Add a single argument value to the benchmark.
void benchmark_odin_benchmark_arg(void* benchmark, int64_t x);

// Add a range of arguments from start to limit (doubles each step).
void benchmark_odin_benchmark_range(void* benchmark, int64_t start,
                                    int64_t limit);

// Add a dense range of arguments from start to limit with given step.
void benchmark_odin_benchmark_dense_range(void* benchmark, int64_t start,
                                          int64_t limit, int step);

// Add explicit argument values from an array.
void benchmark_odin_benchmark_args(void* benchmark, const int64_t* args,
                                   size_t len);

// Set the time unit for display (0=ns, 1=us, 2=ms, 3=s).
void benchmark_odin_benchmark_unit(void* benchmark, int unit);

// Set the number of threads for this benchmark.
void benchmark_odin_benchmark_threads(void* benchmark, int t);

// Run with thread count from min_threads to max_threads.
void benchmark_odin_benchmark_thread_range(void* benchmark, int min_threads,
                                           int max_threads);

// Set minimum run time in seconds.
void benchmark_odin_benchmark_min_time(void* benchmark, double t);

// Set exact iteration count (disables automatic iteration selection).
void benchmark_odin_benchmark_iterations(void* benchmark, int64_t n);

// Set number of repetitions.
void benchmark_odin_benchmark_repetitions(void* benchmark, int n);

// Use wall-clock time instead of CPU time.
void benchmark_odin_benchmark_use_real_time(void* benchmark);

// Use manual time control (call SetIterationTime manually).
void benchmark_odin_benchmark_use_manual_time(void* benchmark);

// Set complexity mode (-1=auto, 0=O(n), 1=O(n log n), 2=O(1), 3=O(n^2)).
void benchmark_odin_benchmark_complexity(void* benchmark, int complexity);

// Get the benchmark name as a null-terminated string.
const char* benchmark_odin_benchmark_name(void* benchmark);

// ---- State methods ----
// These are called from within the benchmark callback to control iteration
// and report metrics.

// Returns true if the benchmark should continue running (call in a while loop).
bool benchmark_odin_state_keep_running(void* state);

// Run n iterations in a batch (more efficient than calling keep_running n
// times).
bool benchmark_odin_state_keep_running_batch(void* state, int64_t n);

// Pause the benchmark timer (for expensive setup not to be timed).
void benchmark_odin_state_pause_timing(void* state);

// Resume the benchmark timer after pause_timing().
void benchmark_odin_state_resume_timing(void* state);

// Skip this benchmark with an error message.
void benchmark_odin_state_skip_with_error(void* state, const char* msg);

// Report bytes processed per iteration (for throughput metrics).
void benchmark_odin_state_set_bytes_processed(void* state, int64_t bytes);

// Report items processed per iteration (for throughput metrics).
void benchmark_odin_state_set_items_processed(void* state, int64_t items);

// Set a label for this benchmark run.
void benchmark_odin_state_set_label(void* state, const char* label);

// Set the complexity parameter N for big-O analysis.
void benchmark_odin_state_set_complexity_n(void* state, int64_t n);

// Get the range argument at the given position (0-indexed).
int64_t benchmark_odin_state_range(void* state, size_t pos);

// Get the number of iterations completed so far.
int64_t benchmark_odin_state_iterations(void* state);

// Get the total number of threads.
int benchmark_odin_state_threads(void* state);

// Get the current thread index (0-based).
int benchmark_odin_state_thread_index(void* state);

#ifdef __cplusplus
}
#endif
