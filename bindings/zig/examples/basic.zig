// Usage examples for Zig bindings to google-benchmark.
//
// This file demonstrates common benchmarking patterns:
//   1. Basic no-op benchmark (measures loop overhead)
//   2. Batch iteration (keepRunningBatch)
//   3. Throughput benchmark with bytes processed
//   4. Throughput benchmark with items processed
//   5. Parameterized benchmark with variable input size
//   6. Pause/resume timing (exclude setup from measurement)
//   7. Multi-threaded benchmark
//   8. Platform-specific skip
//
// Build and run: zig build run

const std = @import("std");
const builtin = @import("builtin");
const benchmark = @import("benchmark");

// ---- Example 1: Basic benchmark ----
// Measures the overhead of the benchmark loop itself.

fn BM_string_creation(state: *benchmark.State) void {
    while (state.keepRunning()) {
        const s = "Hello, World!";
        std.mem.doNotOptimizeAway(s);
    }
}

// ---- Example 2: Batch iteration ----
// Processes several iterations per keepRunningBatch() call, useful when
// per-call overhead would otherwise dominate a very cheap operation.

fn BM_batched_increment(state: *benchmark.State) void {
    var counter: u64 = 0;
    while (state.keepRunningBatch(64)) {
        counter +%= 1;
    }
    std.mem.doNotOptimizeAway(counter);
}

// ---- Example 3: Throughput benchmark ----
// Reports bytes processed per second for memory bandwidth measurement.

fn BM_memory_write(state: *benchmark.State) void {
    const n: usize = @intCast(state.range(0));
    const data = std.heap.page_allocator.alloc(u8, n) catch return;
    defer std.heap.page_allocator.free(data);

    while (state.keepRunning()) {
        @memset(data, 0x42);
    }
    state.setBytesProcessed(@intCast(n * @as(usize, @intCast(state.iterations()))));
}

// ---- Example 4: Throughput with items ----
// Reports items processed per second.

fn BM_vector_push_back(state: *benchmark.State) void {
    while (state.keepRunning()) {
        var vec = std.ArrayList(u32).init(std.heap.page_allocator);
        defer vec.deinit();
        for (0..1000) |i| {
            vec.append(@intCast(i)) catch break;
        }
    }
    state.setItemsProcessed(state.iterations() * 1000);
}

// ---- Example 5: Parameterized benchmark ----
// Runs the benchmark with different input sizes via .range().

fn BM_sort_merge(state: *benchmark.State) void {
    const n: usize = @intCast(state.range(0));
    var rng = std.Random.DefaultPrng.init(42);
    const allocator = std.heap.page_allocator;

    const arr = allocator.alloc(i32, n) catch return;
    defer allocator.free(arr);

    for (arr) |*item| {
        item.* = rng.random().int(i32);
    }

    while (state.keepRunning()) {
        std.mem.sort(i32, arr, {}, std.sort.asc(i32));
    }
}

// ---- Example 6: Pause/resume timing ----
// The setup phase (data allocation, etc.) is excluded from timing.

fn BM_with_setup(state: *benchmark.State) void {
    while (state.keepRunning()) {
        state.pauseTiming();
        // Expensive setup that should not be timed
        var sink: i64 = 0;
        for (0..1000) |i| {
            sink +%= @intCast(i);
        }
        state.resumeTiming();
        std.mem.doNotOptimizeAway(sink);
    }
}

// ---- Example 7: Threaded benchmark ----
// Runs with 1, 2, and 4 threads to measure parallel scaling.

fn BM_threaded(state: *benchmark.State) void {
    while (state.keepRunning()) {
        // Work that benefits from parallelism
        var sum: i64 = 0;
        for (0..10000) |i| {
            sum +%= @intCast(i);
        }
        std.mem.doNotOptimizeAway(sum);
    }
}

// ---- Example 8: Skip benchmark ----
// Conditionally skip a benchmark based on platform or feature detection.

fn BM_platform_specific(state: *benchmark.State) void {
    if (comptime builtin.target.os.tag != .linux) {
        state.skipWithError("only supported on Linux");
        return;
    }
    while (state.keepRunning()) {}
}

// ---- Main ----
// Parses CLI args, initializes the library, registers benchmarks, and runs.

pub fn main() void {
    const args = std.process.argsAlloc(std.heap.page_allocator) catch return;
    defer std.process.argsFree(std.heap.page_allocator, args);

    benchmark.initialize(args);

    _ = benchmark.registerBenchmark("BM_string_creation", BM_string_creation);

    _ = benchmark.registerBenchmark("BM_batched_increment", BM_batched_increment);

    _ = benchmark.registerBenchmark("BM_memory_write", BM_memory_write)
        .range(1 << 10, 1 << 20);

    _ = benchmark.registerBenchmark("BM_vector_push_back", BM_vector_push_back);

    _ = benchmark.registerBenchmark("BM_sort_merge", BM_sort_merge)
        .range(1 << 0, 1 << 12)
        .unit(.microsecond);

    _ = benchmark.registerBenchmark("BM_with_setup", BM_with_setup);

    _ = benchmark.registerBenchmark("BM_threaded", BM_threaded)
        .threads(1)
        .threads(2)
        .threads(4);

    _ = benchmark.registerBenchmark("BM_platform_specific", BM_platform_specific);

    _ = benchmark.run();
}
