// Idiomatic Odin API for google-benchmark.
//
// This module provides a safe interface to the C++ google-benchmark
// library via the C adapter layer (odin_api.h/cc).
//
// Usage:
//   import benchmark "bindings/odin/src"
//   benchmark.initialize(os.args_v[0..])
//   benchmark.register("BM_hello", BM_hello, {})
//   benchmark.run()

package benchmark

import "core:c"
import "core:os"

// ---- Foreign imports from C adapter ----

foreign import "odin_api" {
    // Link against libbenchmark_combined.a (or system library)
}

// ---- Opaque types ----

State = struct {
    ptr: rawptr,

    keep_running :: proc(self: State) -> bool {
        return c.benchmark_odin_state_keep_running(self.ptr);
    }

    keep_running_batch :: proc(self: State, n: int) -> bool {
        return c.benchmark_odin_state_keep_running_batch(self.ptr, n);
    }

    pause_timing :: proc(self: State) void {
        c.benchmark_odin_state_pause_timing(self.ptr);
    }

    resume_timing :: proc(self: State) void {
        c.benchmark_odin_state_resume_timing(self.ptr);
    }

    skip_with_error :: proc(self: State, msg: cstring) void {
        c.benchmark_odin_state_skip_with_error(self.ptr, msg);
    }

    set_bytes_processed :: proc(self: State, bytes: int) void {
        c.benchmark_odin_state_set_bytes_processed(self.ptr, bytes);
    }

    set_items_processed :: proc(self: State, items: int) void {
        c.benchmark_odin_state_set_items_processed(self.ptr, items);
    }

    set_label :: proc(self: State, label: cstring) void {
        c.benchmark_odin_state_set_label(self.ptr, label);
    }

    set_complexity_n :: proc(self: State, n: int) void {
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
};

Benchmark = struct {
    ptr: rawptr,

    arg :: proc(self: Benchmark, x: int) -> Benchmark {
        c.benchmark_odin_benchmark_arg(self.ptr, x);
        return self;
    }

    range :: proc(self: Benchmark, start, limit: int) -> Benchmark {
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

    threads :: proc(self: Benchmark, t: int) -> Benchmark {
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

    iterations :: proc(self: Benchmark, n: int) -> Benchmark {
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
};

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

// ---- Public functions ----

initialize :: proc(args: []cstring) void {
    argc: c.int = c.int(len(args));
    argv_buf: [64][*c]u8 = ---;
    argv_buf[len] = nil;
    for arg, i in args {
        argv_buf[i] = c.CAST([*c]u8, arg);
    }
    c.benchmark_odin_initialize(&argc, &argv_buf);
}

run :: proc() -> int {
    return int(c.benchmark_odin_run());
}

register :: proc(name: cstring, func: proc(State), $Config: struct {} = .{}) -> Benchmark {
    _ = Config;
    S :: struct {
        state: State,
    };

    trampoline :: proc(state_ptr: rawptr) callconv(.c) void {
        if state_ptr == nil return;
        s := State{ .ptr = state_ptr };
        func(s);
    }

    result := c.benchmark_odin_register_benchmark(name, trampoline);
    return Benchmark{ .ptr = result };
}

add_custom_context :: proc(key, value: cstring) void {
    c.benchmark_odin_add_custom_context(key, value);
}

clear_registered_benchmarks :: proc() void {
    c.benchmark_odin_clear_registered_benchmarks();
}
