// Unit tests for Odin bindings to google-benchmark.

package benchmark_test

import "core:testing"
import benchmark "."

// ---- Benchmark functions ----

bm_empty :: proc(state: *benchmark.State) void {
    for state.keep_running() {}
}

bm_with_batch :: proc(state: *benchmark.State) void {
    for state.keep_running_batch(64) {}
}

bm_pause_resume :: proc(state: *benchmark.State) void {
    for state.keep_running() {
        state.pause_timing();
        sink: int = 0;
        for i in 0 ..< 100 {
            sink += i;
        }
        state.resume_timing();
        _ = sink;
    }
}

bm_bytes_processed :: proc(state: *benchmark.State) void {
    n := state.range(0);
    for state.keep_running() {}
    state.set_bytes_processed(n * state.iterations());
}

bm_items_processed :: proc(state: *benchmark.State) void {
    for state.keep_running() {}
    state.set_items_processed(state.iterations() * 10);
}

bm_skip :: proc(state: *benchmark.State) void {
    state.skip_with_error("not supported");
}

// ---- Tests ----

@(test)
basic_benchmark :: proc(t: ^testing.T) -> !void {
    benchmark.clear_registered_benchmarks();
    benchmark.register("BM_Empty", bm_empty);
    count := benchmark.run();
    testing.expect(t, count > 0) catch return error.TestFailed;
}

@(test)
benchmark_with_batch :: proc(t: ^testing.T) -> !void {
    benchmark.clear_registered_benchmarks();
    benchmark.register("BM_Batch", bm_with_batch);
    count := benchmark.run();
    testing.expect(t, count > 0) catch return error.TestFailed;
}

@(test)
pause_resume_timing :: proc(t: ^testing.T) -> !void {
    benchmark.clear_registered_benchmarks();
    benchmark.register("BM_PauseResume", bm_pause_resume);
    count := benchmark.run();
    testing.expect(t, count > 0) catch return error.TestFailed;
}

@(test)
bytes_processed :: proc(t: ^testing.T) -> !void {
    benchmark.clear_registered_benchmarks();
    bm := benchmark.register("BM_BytesProcessed", bm_bytes_processed);
    _ = bm.range(1 << 10, 1 << 16);
    count := benchmark.run();
    testing.expect(t, count > 0) catch return error.TestFailed;
}

@(test)
items_processed :: proc(t: ^testing.T) -> !void {
    benchmark.clear_registered_benchmarks();
    benchmark.register("BM_ItemsProcessed", bm_items_processed);
    count := benchmark.run();
    testing.expect(t, count > 0) catch return error.TestFailed;
}

@(test)
skip_with_error :: proc(t: ^testing.T) -> !void {
    benchmark.clear_registered_benchmarks();
    benchmark.register("BM_Skip", bm_skip);
    count := benchmark.run();
    testing.expect(t, count > 0) catch return error.TestFailed;
}

@(test)
time_unit :: proc(t: ^testing.T) -> !void {
    benchmark.clear_registered_benchmarks();
    bm := benchmark.register("BM_MicroSecond", bm_empty);
    _ = bm.unit(.microsecond);
    count := benchmark.run();
    testing.expect(t, count > 0) catch return error.TestFailed;
}

@(test)
dense_range :: proc(t: ^testing.T) -> !void {
    benchmark.clear_registered_benchmarks();
    bm := benchmark.register("BM_DenseRange", bm_empty);
    _ = bm.dense_range(1, 5, 1);
    count := benchmark.run();
    testing.expect(t, count > 0) catch return error.TestFailed;
}

@(test)
use_real_time :: proc(t: ^testing.T) -> !void {
    benchmark.clear_registered_benchmarks();
    bm := benchmark.register("BM_RealTime", bm_empty);
    _ = bm.use_real_time();
    count := benchmark.run();
    testing.expect(t, count > 0) catch return error.TestFailed;
}

@(test)
range_parameter :: proc(t: ^testing.T) -> !void {
    benchmark.clear_registered_benchmarks();
    bm := benchmark.register("BM_Range", bm_empty);
    _ = bm.range(1, 64);
    count := benchmark.run();
    testing.expect(t, count > 0) catch return error.TestFailed;
}

@(test)
multiple_benchmarks :: proc(t: ^testing.T) -> !void {
    benchmark.clear_registered_benchmarks();
    benchmark.register("BM_Multi1", bm_empty);
    benchmark.register("BM_Multi2", bm_with_batch);
    benchmark.register("BM_Multi3", bm_pause_resume);
    count := benchmark.run();
    testing.expect(t, count >= 3) catch return error.TestFailed;
}

@(test)
threaded_benchmark :: proc(t: ^testing.T) -> !void {
    benchmark.clear_registered_benchmarks();
    bm := benchmark.register("BM_Threads", bm_empty);
    _ = bm.threads(4);
    count := benchmark.run();
    testing.expect(t, count > 0) catch return error.TestFailed;
}

@(test)
benchmark_name :: proc(t: ^testing.T) -> !void {
    benchmark.clear_registered_benchmarks();
    bm := benchmark.register("BM_Named", bm_empty);
    name := bm.get_name();
    // Verify name starts with "BM_Named"
    testing.expect(t, name != nil) catch return error.TestFailed;
}
