package benchmark_test

import "base:runtime"
import "core:c"
import "core:testing"
import gb "../src"

// ---- Benchmark functions ----

bm_empty :: proc "c" (state: gb.State) {
    context = runtime.default_context();
    for gb.keep_running(state) {}
}

bm_with_batch :: proc "c" (state: gb.State) {
    context = runtime.default_context();
    for gb.keep_running_batch(state, 64) {}
}

bm_pause_resume :: proc "c" (state: gb.State) {
    context = runtime.default_context();
    for gb.keep_running(state) {
        gb.pause_timing(state);
        sink: int = 0;
        for i in 0 ..< 100 {
            sink += i;
        }
        gb.resume_timing(state);
        _ = sink;
    }
}

bm_bytes_processed :: proc "c" (state: gb.State) {
    context = runtime.default_context();
    n := gb.range(state, 0);
    for gb.keep_running(state) {}
    gb.set_bytes_processed(state, n * gb.iterations(state));
}

bm_items_processed :: proc "c" (state: gb.State) {
    context = runtime.default_context();
    for gb.keep_running(state) {}
    gb.set_items_processed(state, gb.iterations(state) * 10);
}

bm_skip :: proc "c" (state: gb.State) {
    context = runtime.default_context();
    gb.skip_with_error(state, "not supported");
}

// ---- Tests ----
//
// google-benchmark's RunSpecifiedBenchmarks() corrupts global state if
// called more than once per process (reproduced independently in plain
// C++, so this is a limitation of the upstream library, not this
// binding). All benchmark-running assertions therefore live in a single
// test that registers every configuration and calls gb.run() exactly once.

@(test)
all_benchmarks_run :: proc(t: ^testing.T) {
    args := [1]cstring{"benchmark_test"};
    argc := c.int(len(args));
    gb.initialize(&argc, cast(^^u8)&args[0]);

    gb.clear_registered_benchmarks();

    _ = gb.register("BM_Empty", bm_empty);
    _ = gb.register("BM_Batch", bm_with_batch);
    _ = gb.register("BM_PauseResume", bm_pause_resume);

    bm_bytes := gb.register("BM_BytesProcessed", bm_bytes_processed);
    _ = gb.range_benchmark(bm_bytes, 1 << 10, 1 << 16);

    _ = gb.register("BM_ItemsProcessed", bm_items_processed);
    _ = gb.register("BM_Skip", bm_skip);

    bm_unit := gb.register("BM_MicroSecond", bm_empty);
    _ = gb.unit(bm_unit, .microsecond);

    bm_dense := gb.register("BM_DenseRange", bm_empty);
    _ = gb.dense_range(bm_dense, 1, 5, 1);

    bm_real_time := gb.register("BM_RealTime", bm_empty);
    _ = gb.use_real_time(bm_real_time);

    bm_range := gb.register("BM_Range", bm_empty);
    _ = gb.range_benchmark(bm_range, 1, 64);

    bm_threads := gb.register("BM_Threads", bm_empty);
    _ = gb.threads_benchmark(bm_threads, 4);

    bm_multi_arg := gb.register("BM_MultiArg", bm_empty);
    bm_multi_arg = gb.args(bm_multi_arg, {64, 64});
    _ = gb.args(bm_multi_arg, {128, 128});

    bm_named := gb.register("BM_Named", bm_empty);
    name := gb.get_name(bm_named);
    if name == nil || name != "BM_Named" {
        testing.fail(t);
    }

    count := gb.run();
    if count <= 0 {
        testing.fail(t);
    }
}
