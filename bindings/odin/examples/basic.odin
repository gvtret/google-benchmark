package basic_example

import "core:c"
import "base:runtime"
import benchmark "../src"

bm_empty :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    for benchmark.keep_running(state) {}
}

main :: proc() {
    args := [2]cstring{"benchmark", "--benchmark_min_time=0.01"};
    argc := c.int(len(args));
    benchmark.initialize(&argc, cast(^^u8)&args[0]);

    _ = benchmark.register("BM_hello", bm_empty);
    _ = benchmark.run();
}
