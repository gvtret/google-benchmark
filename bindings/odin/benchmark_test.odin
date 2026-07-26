package benchmark_test

import "core:testing"
import gb "src"

// ---- Benchmark functions ----

bm_empty :: proc(state: gb.State) {
    for gb.keep_running(state) {}
}

bm_with_batch :: proc(state: gb.State) {
    for gb.keep_running_batch(state, 64) {}
}

bm_pause_resume :: proc(state: gb.State) {
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

bm_bytes_processed :: proc(state: gb.State) {
    n := gb.range(state, 0);
    for gb.keep_running(state) {}
    gb.set_bytes_processed(state, n * gb.iterations(state));
}

bm_items_processed :: proc(state: gb.State) {
    for gb.keep_running(state) {}
    gb.set_items_processed(state, gb.iterations(state) * 10);
}

bm_skip :: proc(state: gb.State) {
    gb.skip_with_error(state, "not supported");
}

// ---- Tests ----

@(test)
basic_benchmark :: proc(t: ^testing.T) {
    gb.clear_registered_benchmarks();
    _ = gb.register("BM_Empty", bm_empty, {});
    count := gb.run();
    if count <= 0 {
        testing.fail(t);
    }
}

@(test)
benchmark_with_batch :: proc(t: ^testing.T) {
    gb.clear_registered_benchmarks();
    _ = gb.register("BM_Batch", bm_with_batch, {});
    count := gb.run();
    if count <= 0 {
        testing.fail(t);
    }
}

@(test)
pause_resume_timing :: proc(t: ^testing.T) {
    gb.clear_registered_benchmarks();
    _ = gb.register("BM_PauseResume", bm_pause_resume, {});
    count := gb.run();
    if count <= 0 {
        testing.fail(t);
    }
}

@(test)
bytes_processed :: proc(t: ^testing.T) {
    gb.clear_registered_benchmarks();
    bm := gb.register("BM_BytesProcessed", bm_bytes_processed, {});
    _ = bm.range_benchmark(1 << 10, 1 << 16);
    count := gb.run();
    if count <= 0 {
        testing.fail(t);
    }
}

@(test)
items_processed :: proc(t: ^testing.T) {
    gb.clear_registered_benchmarks();
    _ = gb.register("BM_ItemsProcessed", bm_items_processed, {});
    count := gb.run();
    if count <= 0 {
        testing.fail(t);
    }
}

@(test)
skip_with_error :: proc(t: ^testing.T) {
    gb.clear_registered_benchmarks();
    _ = gb.register("BM_Skip", bm_skip, {});
    count := gb.run();
    if count <= 0 {
        testing.fail(t);
    }
}

@(test)
time_unit :: proc(t: ^testing.T) {
    gb.clear_registered_benchmarks();
    bm := gb.register("BM_MicroSecond", bm_empty, {});
    _ = bm.unit(.microsecond);
    count := gb.run();
    if count <= 0 {
        testing.fail(t);
    }
}

@(test)
dense_range :: proc(t: ^testing.T) {
    gb.clear_registered_benchmarks();
    bm := gb.register("BM_DenseRange", bm_empty, {});
    _ = bm.dense_range(1, 5, 1);
    count := gb.run();
    if count <= 0 {
        testing.fail(t);
    }
}

@(test)
use_real_time :: proc(t: ^testing.T) {
    gb.clear_registered_benchmarks();
    bm := gb.register("BM_RealTime", bm_empty, {});
    _ = bm.use_real_time();
    count := gb.run();
    if count <= 0 {
        testing.fail(t);
    }
}

@(test)
range_parameter :: proc(t: ^testing.T) {
    gb.clear_registered_benchmarks();
    bm := gb.register("BM_Range", bm_empty, {});
    _ = bm.range_benchmark(1, 64);
    count := gb.run();
    if count <= 0 {
        testing.fail(t);
    }
}

@(test)
multiple_benchmarks :: proc(t: ^testing.T) {
    gb.clear_registered_benchmarks();
    _ = gb.register("BM_Multi1", bm_empty, {});
    _ = gb.register("BM_Multi2", bm_with_batch, {});
    _ = gb.register("BM_Multi3", bm_pause_resume, {});
    count := gb.run();
    if count < 3 {
        testing.fail(t);
    }
}

@(test)
threaded_benchmark :: proc(t: ^testing.T) {
    gb.clear_registered_benchmarks();
    bm := gb.register("BM_Threads", bm_empty, {});
    _ = bm.threads_benchmark(4);
    count := gb.run();
    if count <= 0 {
        testing.fail(t);
    }
}

@(test)
benchmark_name :: proc(t: ^testing.T) {
    gb.clear_registered_benchmarks();
    bm := gb.register("BM_Named", bm_empty, {});
    name := bm.get_name();
    if name == nil {
        testing.fail(t);
    }
}
