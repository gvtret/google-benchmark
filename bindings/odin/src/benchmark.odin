// Idiomatic Odin API for google-benchmark.
//
// This module provides a safe interface to the C++ google-benchmark
// library via the C adapter layer (odin_api.h/cc).
//
// Key design decisions (see docs/architecture.md for the full rationale):
//   - State and Benchmark are opaque rawptr wrapped in typed Odin structs.
//   - Benchmark configuration procedures return self for fluent chaining,
//     e.g. `bm = range_benchmark(bm, 8, 1 << 20)`. Odin has no method-call
//     syntax, so these are free procedures, not methods.
//   - register() passes the user's "c"-convention callback straight
//     through to the C adapter (no trampoline — see register() below).
//
// Usage:
//   import benchmark "bindings/odin/src"
//
//   BM_hello :: proc "c" (state: benchmark.State) {
//       for benchmark.keep_running(state) { /* ... */ }
//   }
//
//   argc := c.int(len(args))
//   benchmark.initialize(&argc, cast(^^u8)&args[0])
//   _ = benchmark.register("BM_hello", BM_hello)
//   _ = benchmark.run()

package benchmark

import "core:c"

// ---- Foreign imports from C adapter ----

foreign import odin_api "../cmake-build/libodin_api.a"

@(default_calling_convention = "c")
foreign odin_api {
    benchmark_odin_initialize                    :: proc(argc: ^c.int, argv: ^^u8) ---
    benchmark_odin_run                           :: proc() -> c.size_t ---
    benchmark_odin_clear_registered_benchmarks   :: proc() ---
    benchmark_odin_add_custom_context            :: proc(key, value: cstring) ---

    benchmark_odin_register_benchmark            :: proc(name: cstring, fn: proc "c" (rawptr)) -> rawptr ---

    benchmark_odin_benchmark_arg                 :: proc(benchmark: rawptr, x: c.int64_t) ---
    benchmark_odin_benchmark_range                :: proc(benchmark: rawptr, start, limit: c.int64_t) ---
    benchmark_odin_benchmark_dense_range          :: proc(benchmark: rawptr, start, limit: c.int64_t, step: c.int) ---
    benchmark_odin_benchmark_args                 :: proc(benchmark: rawptr, args: [^]c.int64_t, len: c.size_t) ---
    benchmark_odin_benchmark_unit                 :: proc(benchmark: rawptr, unit: c.int) ---
    benchmark_odin_benchmark_threads              :: proc(benchmark: rawptr, t: c.int) ---
    benchmark_odin_benchmark_thread_range         :: proc(benchmark: rawptr, min_threads, max_threads: c.int) ---
    benchmark_odin_benchmark_min_time             :: proc(benchmark: rawptr, t: c.double) ---
    benchmark_odin_benchmark_iterations           :: proc(benchmark: rawptr, n: c.int64_t) ---
    benchmark_odin_benchmark_repetitions          :: proc(benchmark: rawptr, n: c.int) ---
    benchmark_odin_benchmark_use_real_time        :: proc(benchmark: rawptr) ---
    benchmark_odin_benchmark_use_manual_time      :: proc(benchmark: rawptr) ---
    benchmark_odin_benchmark_complexity           :: proc(benchmark: rawptr, complexity: c.int) ---
    benchmark_odin_benchmark_name                 :: proc(benchmark: rawptr) -> cstring ---

    benchmark_odin_state_keep_running             :: proc(state: rawptr) -> c.bool ---
    benchmark_odin_state_keep_running_batch       :: proc(state: rawptr, n: c.int64_t) -> c.bool ---
    benchmark_odin_state_pause_timing             :: proc(state: rawptr) ---
    benchmark_odin_state_resume_timing            :: proc(state: rawptr) ---
    benchmark_odin_state_skip_with_error          :: proc(state: rawptr, msg: cstring) ---
    benchmark_odin_state_set_bytes_processed      :: proc(state: rawptr, bytes: c.int64_t) ---
    benchmark_odin_state_set_items_processed      :: proc(state: rawptr, items: c.int64_t) ---
    benchmark_odin_state_set_label                :: proc(state: rawptr, label: cstring) ---
    benchmark_odin_state_set_complexity_n         :: proc(state: rawptr, n: c.int64_t) ---
    benchmark_odin_state_range                    :: proc(state: rawptr, pos: c.size_t) -> c.int64_t ---
    benchmark_odin_state_iterations               :: proc(state: rawptr) -> c.int64_t ---
    benchmark_odin_state_threads                  :: proc(state: rawptr) -> c.int ---
    benchmark_odin_state_thread_index             :: proc(state: rawptr) -> c.int ---
}

// ---- Types ----

// Time unit for benchmark display output.
TimeUnit :: enum {
    nanosecond,
    microsecond,
    millisecond,
    second,
};

// Complexity mode for big-O analysis benchmarks.
BigO :: enum {
    auto_,
    o_n,
    o_n_log_n,
    o_1,
    o_n2,
};

// Opaque wrapper around benchmark::State, passed to benchmark callbacks.
// The procedures below (taking State as their first argument) control
// iteration and report metrics.
State :: struct {
    ptr: rawptr,
};

// Opaque wrapper around benchmark::Benchmark, returned by register() to
// configure a benchmark. The procedures below (taking Benchmark as their
// first argument) all return Benchmark for chaining, e.g.
// `bm = range_benchmark(bm, 1, 1 << 16)`.
Benchmark :: struct {
    ptr: rawptr,
};

// ---- State methods (file-scope procs taking State as first param) ----

// Returns true if the benchmark should continue running.
// Call in a loop: `for keep_running(state) { ... }`
keep_running :: proc(self: State) -> bool {
    return bool(benchmark_odin_state_keep_running(self.ptr));
}

// Run n iterations as a batch (more efficient than keep_running in a loop).
keep_running_batch :: proc(self: State, n: int) -> bool {
    return bool(benchmark_odin_state_keep_running_batch(self.ptr, c.int64_t(n)));
}

// Pause the benchmark timer (for expensive setup not to be timed).
pause_timing :: proc(self: State) {
    benchmark_odin_state_pause_timing(self.ptr);
}

// Resume the benchmark timer after pause_timing().
resume_timing :: proc(self: State) {
    benchmark_odin_state_resume_timing(self.ptr);
}

// Skip this benchmark with an error message.
skip_with_error :: proc(self: State, msg: cstring) {
    benchmark_odin_state_skip_with_error(self.ptr, msg);
}

// Report bytes processed per iteration (for throughput metrics).
set_bytes_processed :: proc(self: State, bytes: int) {
    benchmark_odin_state_set_bytes_processed(self.ptr, c.int64_t(bytes));
}

// Report items processed per iteration (for throughput metrics).
set_items_processed :: proc(self: State, items: int) {
    benchmark_odin_state_set_items_processed(self.ptr, c.int64_t(items));
}

// Set a label for this benchmark run.
set_label :: proc(self: State, label: cstring) {
    benchmark_odin_state_set_label(self.ptr, label);
}

// Set the complexity parameter N for big-O analysis.
set_complexity_n :: proc(self: State, n: int) {
    benchmark_odin_state_set_complexity_n(self.ptr, c.int64_t(n));
}

// Get the range argument at the given position (0-indexed).
range :: proc(self: State, pos: int) -> int {
    return int(benchmark_odin_state_range(self.ptr, c.size_t(pos)));
}

// Get the number of iterations completed so far.
iterations :: proc(self: State) -> int {
    return int(benchmark_odin_state_iterations(self.ptr));
}

// Get the total number of threads.
threads :: proc(self: State) -> int {
    return int(benchmark_odin_state_threads(self.ptr));
}

// Get the current thread index (0-based).
thread_index :: proc(self: State) -> int {
    return int(benchmark_odin_state_thread_index(self.ptr));
}

// ---- Benchmark methods (file-scope procs taking Benchmark as first param) ----

// Add a single argument value.
arg :: proc(self: Benchmark, x: int) -> Benchmark {
    benchmark_odin_benchmark_arg(self.ptr, c.int64_t(x));
    return self;
}

// Add one multi-argument value combination, e.g. args(bm, {64, 64}) for a
// benchmark taking two range() parameters. Call multiple times to register
// several combinations (each call adds one, it does not replace).
args :: proc(self: Benchmark, values: []int) -> Benchmark {
    buf := make([]c.int64_t, len(values));
    defer delete(buf);
    for v, i in values {
        buf[i] = c.int64_t(v);
    }
    benchmark_odin_benchmark_args(self.ptr, raw_data(buf), c.size_t(len(buf)));
    return self;
}

// Add a range of arguments from start to limit (doubles each step).
range_benchmark :: proc(self: Benchmark, start, limit: int) -> Benchmark {
    benchmark_odin_benchmark_range(self.ptr, c.int64_t(start), c.int64_t(limit));
    return self;
}

// Add a dense range of arguments from start to limit with the given step.
dense_range :: proc(self: Benchmark, start, limit: int, step: int) -> Benchmark {
    benchmark_odin_benchmark_dense_range(self.ptr, c.int64_t(start), c.int64_t(limit), c.int(step));
    return self;
}

// Set the time unit for display.
unit :: proc(self: Benchmark, u: TimeUnit) -> Benchmark {
    benchmark_odin_benchmark_unit(self.ptr, c.int(u));
    return self;
}

// Set the number of threads for this benchmark. Call multiple times to add
// several thread-count configurations (each call adds one).
threads_benchmark :: proc(self: Benchmark, t: int) -> Benchmark {
    benchmark_odin_benchmark_threads(self.ptr, c.int(t));
    return self;
}

// Run with thread count from min_t to max_t.
thread_range :: proc(self: Benchmark, min_t, max_t: int) -> Benchmark {
    benchmark_odin_benchmark_thread_range(self.ptr, c.int(min_t), c.int(max_t));
    return self;
}

// Set minimum run time in seconds.
min_time :: proc(self: Benchmark, t: f64) -> Benchmark {
    benchmark_odin_benchmark_min_time(self.ptr, c.double(t));
    return self;
}

// Set exact iteration count (disables automatic iteration selection).
iterations_benchmark :: proc(self: Benchmark, n: int) -> Benchmark {
    benchmark_odin_benchmark_iterations(self.ptr, c.int64_t(n));
    return self;
}

// Set number of repetitions.
repetitions :: proc(self: Benchmark, n: int) -> Benchmark {
    benchmark_odin_benchmark_repetitions(self.ptr, c.int(n));
    return self;
}

// Use wall-clock time instead of CPU time.
use_real_time :: proc(self: Benchmark) -> Benchmark {
    benchmark_odin_benchmark_use_real_time(self.ptr);
    return self;
}

// Use manual time control (call set_iteration_time equivalents manually).
use_manual_time :: proc(self: Benchmark) -> Benchmark {
    benchmark_odin_benchmark_use_manual_time(self.ptr);
    return self;
}

// Set complexity mode for big-O analysis.
complexity :: proc(self: Benchmark, b: BigO) -> Benchmark {
    benchmark_odin_benchmark_complexity(self.ptr, c.int(b));
    return self;
}

// Get the benchmark name.
get_name :: proc(self: Benchmark) -> cstring {
    return benchmark_odin_benchmark_name(self.ptr);
}

// ---- Public functions ----

// Initialize the benchmark library with command-line arguments.
// Must be called before register() and run().
initialize :: proc(argc_: ^c.int, argv_: ^^u8) {
    benchmark_odin_initialize(argc_, argv_);
}

// Run all registered benchmarks. Returns the number of benchmarks executed.
// Do not call more than once per process — see the "Process-Wide State
// Caveat" in docs/architecture.md.
run :: proc() -> int {
    return int(benchmark_odin_run());
}

// Register a benchmark with the given name and callback, returning a
// Benchmark for fluent configuration chaining, e.g.
// `bm = range_benchmark(register("BM_Foo", my_func), 8, 1 << 20)`.
//
// func must use the "c" calling convention: proc "c" (state: State).
// State wraps a single rawptr and is ABI-compatible with a bare pointer,
// so it is passed straight through to the C adapter without a trampoline.
register :: proc(name: cstring, func: proc "c" (State)) -> Benchmark {
    result := benchmark_odin_register_benchmark(name, transmute(proc "c" (rawptr))func);
    return Benchmark{ptr = result};
}

// Add a custom key-value context to benchmark output (e.g. for JSON reports).
add_custom_context :: proc(key, value: cstring) {
    benchmark_odin_add_custom_context(key, value);
}

// Remove all registered benchmarks.
clear_registered_benchmarks :: proc() {
    benchmark_odin_clear_registered_benchmarks();
}
