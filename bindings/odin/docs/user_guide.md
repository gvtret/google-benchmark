# User Guide — Odin Bindings

## Installation

### Build from source

```bash
cd bindings/odin
cmake -S . -B cmake-build -DCMAKE_BUILD_TYPE=Release
cmake --build cmake-build --parallel
```

## First Benchmark

```odin
package main

import benchmark "bindings/odin/src"
import "core:os"

BM_hello :: proc(state: *benchmark.State) void {
    for state.keep_running() {
        // Your code here
    }
}

main :: proc() {
    benchmark.initialize(os.args_v[0..])
    benchmark.register("BM_hello", BM_hello, {})
    _ = benchmark.run()
}
```

## Common Patterns

### Throughput

```odin
BM_throughput :: proc(state: *benchmark.State) void {
    n := state.range(0)
    for state.keep_running() {
        // work with size n
    }
    state.set_bytes_processed(n * state.iterations())
}

// Register with:
_ = bm.range(1 << 10, 1 << 20)
```

### Parameterized Benchmarks

```odin
BM_parameterized :: proc(state: *benchmark.State) void {
    n := state.range(0)
    // n varies: 1, 2, 4, 8, ...
    for state.keep_running() {}
}

// Register with:
_ = bm.range(1, 1 << 16)
```

### Pause/Resume Timing

```odin
BM_with_setup :: proc(state: *benchmark.State) void {
    for state.keep_running() {
        state.pause_timing()
        // Expensive setup (not timed)
        state.resume_timing()
        // Actual work (timed)
    }
}
```

### Multi-threaded

```odin
BM_threaded :: proc(state: *benchmark.State) void {
    for state.keep_running() {}
}

// Register with:
_ = bm.threads(1).threads(2).threads(4).threads(8)
```

### Skip Benchmarks

```odin
BM_conditional :: proc(state: *benchmark.State) void {
    if feature_is_available() == false {
        state.skip_with_error("feature not available")
        return
    }
    for state.keep_running() {}
}
```

## Command-Line Flags

Pass flags through `initialize`:

```odin
args := [_]cstring{
    "benchmark",
    "--benchmark_format=console",
    "--benchmark_min_time=0.5",
    "--benchmark_repetitions=3",
    "--benchmark_filter=BM_hello",
}
benchmark.initialize(args[0..])
```
