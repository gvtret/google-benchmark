// Idiomatic Odin API for google-benchmark.
//
// This module provides a safe interface to the C++ google-benchmark
// library via the C adapter layer (odin_api.h/cc).
//
// Usage:
//   import benchmark "bindings/odin/src"
//   benchmark.initialize(...)
//   benchmark.register("BM_hello", BM_hello, {})
//   benchmark.run()

package benchmark

import "core:c"

// ---- Foreign imports from C adapter ----

foreign import "odin_api"

// ---- Types ----

TimeUnit :: enum {
    nanosecond,
    microsecond,
    millisecond,
    second,
};

BigO :: enum {
    auto_,
    o_n,
    o_n_log_n,
    o_1,
    o_n2,
};

State :: struct {
    ptr: rawptr,
};

Benchmark :: struct {
    ptr: rawptr,
};

// ---- State methods (file-scope procs taking State as first param) ----

keep_running :: proc(self: State) -> bool {
    return c.benchmark_odin_state_keep_running(self.ptr);
}

keep_running_batch :: proc(self: State, n: int) -> bool {
    return c.benchmark_odin_state_keep_running_batch(self.ptr, n);
}

pause_timing :: proc(self: State) {
    c.benchmark_odin_state_pause_timing(self.ptr);
}

resume_timing :: proc(self: State) {
    c.benchmark_odin_state_resume_timing(self.ptr);
}

skip_with_error :: proc(self: State, msg: cstring) {
    c.benchmark_odin_state_skip_with_error(self.ptr, msg);
}

set_bytes_processed :: proc(self: State, bytes: int) {
    c.benchmark_odin_state_set_bytes_processed(self.ptr, bytes);
}

set_items_processed :: proc(self: State, items: int) {
    c.benchmark_odin_state_set_items_processed(self.ptr, items);
}

set_label :: proc(self: State, label: cstring) {
    c.benchmark_odin_state_set_label(self.ptr, label);
}

set_complexity_n :: proc(self: State, n: int) {
    c.benchmark_odin_state_set_complexity_n(self.ptr, n);
}

range :: proc(self: State, pos: int) -> int {
    return c.benchmark_odin_state_range(self.ptr, pos);
}

iterations :: proc(self: State) -> int {
    return c.benchmark_odin_state_iterations(self.ptr);
}

threads :: proc(self: State) -> int {
    return c.benchmark_odin_state_threads(self.ptr);
}

thread_index :: proc(self: State) -> int {
    return c.benchmark_odin_state_thread_index(self.ptr);
}

// ---- Benchmark methods (file-scope procs taking Benchmark as first param) ----

arg :: proc(self: Benchmark, x: int) -> Benchmark {
    c.benchmark_odin_benchmark_arg(self.ptr, x);
    return self;
}

range_benchmark :: proc(self: Benchmark, start, limit: int) -> Benchmark {
    c.benchmark_odin_benchmark_range(self.ptr, start, limit);
    return self;
}

dense_range :: proc(self: Benchmark, start, limit: int, step: int) -> Benchmark {
    c.benchmark_odin_benchmark_dense_range(self.ptr, start, limit, step);
    return self;
}

unit :: proc(self: Benchmark, u: TimeUnit) -> Benchmark {
    c.benchmark_odin_benchmark_unit(self.ptr, int(u));
    return self;
}

threads_benchmark :: proc(self: Benchmark, t: int) -> Benchmark {
    c.benchmark_odin_benchmark_threads(self.ptr, t);
    return self;
}

thread_range :: proc(self: Benchmark, min_t, max_t: int) -> Benchmark {
    c.benchmark_odin_benchmark_thread_range(self.ptr, min_t, max_t);
    return self;
}

min_time :: proc(self: Benchmark, t: f64) -> Benchmark {
    c.benchmark_odin_benchmark_min_time(self.ptr, t);
    return self;
}

iterations_benchmark :: proc(self: Benchmark, n: int) -> Benchmark {
    c.benchmark_odin_benchmark_iterations(self.ptr, n);
    return self;
}

repetitions :: proc(self: Benchmark, n: int) -> Benchmark {
    c.benchmark_odin_benchmark_repetitions(self.ptr, n);
    return self;
}

use_real_time :: proc(self: Benchmark) -> Benchmark {
    c.benchmark_odin_benchmark_use_real_time(self.ptr);
    return self;
}

use_manual_time :: proc(self: Benchmark) -> Benchmark {
    c.benchmark_odin_benchmark_use_manual_time(self.ptr);
    return self;
}

complexity :: proc(self: Benchmark, b: BigO) -> Benchmark {
    c.benchmark_odin_benchmark_complexity(self.ptr, int(b));
    return self;
}

get_name :: proc(self: Benchmark) -> cstring {
    return c.benchmark_odin_benchmark_name(self.ptr);
}

// ---- Public functions ----

initialize :: proc(argc_: ^c.int, argv_: ^^u8) {
    c.benchmark_odin_initialize(argc_, argv_);
}

run :: proc() -> int {
    return int(c.benchmark_odin_run());
}

register :: proc(name: cstring, func: proc(State)) -> Benchmark {
    trampoline :: proc(state_ptr: rawptr) -> void {
        if state_ptr == nil { return; }
        s := State{ .ptr = state_ptr };
        func(s);
    }

    result := c.benchmark_odin_register_benchmark(name, trampoline);
    return Benchmark{ .ptr = result };
}

add_custom_context :: proc(key, value: cstring) {
    c.benchmark_odin_add_custom_context(key, value);
}

clear_registered_benchmarks :: proc() {
    c.benchmark_odin_clear_registered_benchmarks();
}
