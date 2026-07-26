package basic_example

import benchmark "../src"

main :: proc() {
    args := [2]cstring{"benchmark", "--benchmark_min_time=0.01"};
    benchmark.initialize(cast(int)len(args), &args);

    bm_empty :: proc(state: benchmark.State) {
        for benchmark.keep_running(state) {}
    }

    _ = benchmark.register("BM_hello", bm_empty);
    _ = benchmark.run();
}
