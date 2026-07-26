// Usage examples for Odin bindings to google-benchmark.
//
// This file demonstrates common benchmarking patterns:
//   1. Basic no-op benchmark (measures loop overhead)
//   2. Batch iteration (keep_running_batch)
//   3. Throughput benchmark with bytes processed
//   4. Throughput benchmark with items processed
//   5. Parameterized benchmark with variable input size
//   6. Pause/resume timing (exclude setup from measurement)
//   7. Multi-threaded benchmark
//   8. Platform-specific skip
//   9. Multi-argument benchmark (args)
//
// Build and run: odin build examples -out:basic_example -extra-linker-flags:"-lstdc++ -lpthread"
//                 ./basic_example

package basic_example

import "base:runtime"
import "core:c"
import "core:math/rand"
import "core:mem"
import "core:slice"
import benchmark "../src"

// Package-level sinks that benchmark bodies write into, so the compiler
// cannot optimize away the work being measured.
sink_string: string
sink_int:    int
sink_i64:    i64

// ---- Example 1: Basic benchmark ----
// Measures the overhead of the benchmark loop itself.

BM_string_creation :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    for benchmark.keep_running(state) {
        sink_string = "Hello, World!";
    }
}

// ---- Example 2: Batch iteration ----
// Processes several iterations per keep_running_batch() call, useful when
// per-call overhead would otherwise dominate a very cheap operation.

BM_batched_increment :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    counter: u64 = 0;
    for benchmark.keep_running_batch(state, 64) {
        counter += 1;
    }
    sink_i64 = i64(counter);
}

// ---- Example 3: Throughput benchmark ----
// Reports bytes processed per second for memory bandwidth measurement.

BM_memory_write :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    n := benchmark.range(state, 0);
    data := make([]u8, n);
    defer delete(data);

    for benchmark.keep_running(state) {
        mem.set(raw_data(data), 0x42, len(data));
    }
    benchmark.set_bytes_processed(state, n * benchmark.iterations(state));
}

// ---- Example 4: Throughput with items ----
// Reports items processed per second.

BM_dynamic_array_append :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    for benchmark.keep_running(state) {
        arr: [dynamic]int;
        for i in 0 ..< 1000 {
            append(&arr, i);
        }
        delete(arr);
    }
    benchmark.set_items_processed(state, benchmark.iterations(state) * 1000);
}

// ---- Example 5: Parameterized benchmark ----
// Runs the benchmark with different input sizes via range().

BM_sort_merge :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    n := benchmark.range(state, 0);
    arr := make([]int, n);
    defer delete(arr);
    for &v in arr {
        v = rand.int_max(1_000_000);
    }

    for benchmark.keep_running(state) {
        benchmark.pause_timing(state);
        unsorted := slice.clone(arr);
        benchmark.resume_timing(state);

        slice.sort(unsorted);

        delete(unsorted);
    }
}

// ---- Example 6: Pause/resume timing ----
// The setup phase (data allocation, etc.) is excluded from timing.

BM_with_setup :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    for benchmark.keep_running(state) {
        benchmark.pause_timing(state);
        // Expensive setup that should not be timed.
        sink: int = 0;
        for i in 0 ..< 1000 {
            sink += i;
        }
        benchmark.resume_timing(state);
        sink_int = sink;
    }
}

// ---- Example 7: Threaded benchmark ----
// Runs with 1, 2, and 4 threads to measure parallel scaling.

BM_threaded :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    for benchmark.keep_running(state) {
        sum: i64 = 0;
        for i in 0 ..< 10000 {
            sum += i64(i);
        }
        sink_i64 = sum;
    }
}

// ---- Example 8: Skip benchmark ----
// Conditionally skip a benchmark based on platform detection.

BM_platform_specific :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    when ODIN_OS != .Linux {
        benchmark.skip_with_error(state, "only supported on Linux");
        return;
    }
    for benchmark.keep_running(state) {}
}

// ---- Example 9: Multi-argument benchmark ----
// Registers several (rows, cols) combinations via args().

BM_multi_arg :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    rows := benchmark.range(state, 0);
    cols := benchmark.range(state, 1);
    for benchmark.keep_running(state) {
        sink_int = rows * cols;
    }
}

// ---- Main ----
// Parses CLI args, initializes the library, registers benchmarks, and runs.

main :: proc() {
    args := [1]cstring{"benchmark"};
    argc := c.int(len(args));
    benchmark.initialize(&argc, cast(^^u8)&args[0]);

    _ = benchmark.register("BM_string_creation", BM_string_creation);

    _ = benchmark.register("BM_batched_increment", BM_batched_increment);

    bm_memory_write := benchmark.register("BM_memory_write", BM_memory_write);
    _ = benchmark.range_benchmark(bm_memory_write, 1 << 10, 1 << 20);

    _ = benchmark.register("BM_dynamic_array_append", BM_dynamic_array_append);

    bm_sort_merge := benchmark.register("BM_sort_merge", BM_sort_merge);
    bm_sort_merge = benchmark.range_benchmark(bm_sort_merge, 1 << 0, 1 << 12);
    _ = benchmark.unit(bm_sort_merge, .microsecond);

    _ = benchmark.register("BM_with_setup", BM_with_setup);

    bm_threaded := benchmark.register("BM_threaded", BM_threaded);
    bm_threaded = benchmark.threads_benchmark(bm_threaded, 1);
    bm_threaded = benchmark.threads_benchmark(bm_threaded, 2);
    _ = benchmark.threads_benchmark(bm_threaded, 4);

    _ = benchmark.register("BM_platform_specific", BM_platform_specific);

    bm_multi_arg := benchmark.register("BM_multi_arg", BM_multi_arg);
    bm_multi_arg = benchmark.args(bm_multi_arg, {64, 64});
    bm_multi_arg = benchmark.args(bm_multi_arg, {128, 128});
    _ = benchmark.args(bm_multi_arg, {256, 256});

    _ = benchmark.run();
}
