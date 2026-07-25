// Unit tests for Zig bindings to google-benchmark.
//
// `benchmark.run()` (google-benchmark's `RunSpecifiedBenchmarks()`) is not
// safe to call more than once per process — Zig's test runner executes all
// `test` blocks in one process, and calling it repeatedly (once per test,
// as this file used to do) segfaults or hangs nondeterministically due to
// internal global state that isn't fully reset between runs. So there is
// exactly one `run()` call in this whole file: all benchmark patterns
// (keepRunning, keepRunningBatch, pause/resume timing, throughput metrics,
// parameterized benchmarks, threading, skipping) are registered together
// and executed in a single call, matching how a real Zig benchmark binary
// (examples/basic.zig) uses the API. The one test that doesn't need
// `run()` (checking a registered benchmark's name) stays separate.

const std = @import("std");
const benchmark = @import("benchmark");

/// Prevent the compiler from optimizing away a variable or computation.
/// Used in benchmarks to ensure the measured code is not eliminated.
fn volatile_sink(ptr: anytype) void {
    @as(*volatile @TypeOf(ptr.*), ptr).* = ptr.*;
}

// ---- Benchmark functions (callbacks passed to registerBenchmark) ----

// Minimal no-op benchmark: measures bare loop overhead.
fn bm_empty(state: *benchmark.State) void {
    while (state.keepRunning()) {}
}

// Benchmark using batch iteration (processes 64 iterations per call).
fn bm_with_batch(state: *benchmark.State) void {
    while (state.keepRunningBatch(64)) {}
}

// Benchmark with pause/resume timing: setup phase is excluded from measurement.
fn bm_pause_resume(state: *benchmark.State) void {
    while (state.keepRunning()) {
        state.pauseTiming();
        // "expensive" setup — not timed
        var sink: i64 = 0;
        for (0..100) |i| {
            sink += @intCast(i);
        }
        state.resumeTiming();
        // Prevent optimizer from removing the setup loop
        volatile_sink(&sink);
    }
}

// Throughput benchmark: reports bytes processed per iteration.
fn bm_bytes_processed(state: *benchmark.State) void {
    const n: i64 = state.range(0);
    while (state.keepRunning()) {
        const data: [1024]u8 = [_]u8{0x42} ** 1024;
        _ = data;
    }
    state.setBytesProcessed(n * state.iterations());
}

// Throughput benchmark: reports items processed per iteration.
fn bm_items_processed(state: *benchmark.State) void {
    while (state.keepRunning()) {
        // simulate processing items
    }
    state.setItemsProcessed(state.iterations() * 10);
}

// Benchmark with a custom label in output.
fn bm_with_label(state: *benchmark.State) void {
    while (state.keepRunning()) {}
    state.setLabel("my_label");
}

// Benchmark that reads a range parameter.
fn bm_range_1(state: *benchmark.State) void {
    _ = state.range(0);
    while (state.keepRunning()) {}
}

// Multi-threaded benchmark stub.
fn bm_threads_fn(state: *benchmark.State) void {
    while (state.keepRunning()) {}
}

// Benchmark that immediately skips with an error message.
fn bm_skip(state: *benchmark.State) void {
    state.skipWithError("not supported on this platform");
}

// ---- Unit tests ----

// Registers one benchmark per API pattern (batch iteration, pause/resume
// timing, throughput metrics, parameterized args, threading, skipping,
// time units) and runs them all together in a single `run()` call. See the
// file header for why this must not be split into one `run()` per test.
test "registers and runs all benchmark patterns" {
    benchmark.clearRegisteredBenchmarks();

    _ = benchmark.registerBenchmark("BM_Empty", bm_empty);

    _ = benchmark.registerBenchmark("BM_Batch", bm_with_batch);

    _ = benchmark.registerBenchmark("BM_PauseResume", bm_pause_resume);

    _ = benchmark.registerBenchmark("BM_BytesProcessed", bm_bytes_processed)
        .range(1 << 10, 1 << 16);

    _ = benchmark.registerBenchmark("BM_ItemsProcessed", bm_items_processed);

    _ = benchmark.registerBenchmark("BM_Label", bm_with_label);

    _ = benchmark.registerBenchmark("BM_Range", bm_range_1)
        .range(1, 64);

    _ = benchmark.registerBenchmark("BM_Threads", bm_threads_fn)
        .threads(4);

    _ = benchmark.registerBenchmark("BM_MicroSecond", bm_empty)
        .unit(.microsecond);

    _ = benchmark.registerBenchmark("BM_Skip", bm_skip);

    _ = benchmark.registerBenchmark("BM_DenseRange", bm_empty)
        .denseRange(1, 5, 1);

    _ = benchmark.registerBenchmark("BM_RealTime", bm_empty)
        .useRealTime();

    const count = benchmark.run();
    try std.testing.expect(count >= 11);
}

// Verify benchmark name is retrievable after registration. Doesn't call
// run(), so it's safe alongside the test above regardless of run() safety.
test "benchmark name" {
    benchmark.clearRegisteredBenchmarks();
    const b = benchmark.registerBenchmark("BM_Named", bm_empty);
    const name = b.getName();
    const expected = "BM_Named";
    for (expected, 0..) |ch, i| {
        try std.testing.expectEqual(ch, name[i]);
    }
}
