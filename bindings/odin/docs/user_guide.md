# User Guide — Odin Bindings

## Installation

### Build from source

```bash
cd bindings/odin
cmake -S . -B cmake-build -DCMAKE_BUILD_TYPE=Release
cmake --build cmake-build --parallel
```

This builds `libbenchmark` and the C adapter (`src/odin_api.cc`) and combines
them into `cmake-build/libodin_api.a`, which `src/benchmark.odin` links
against via `foreign import` (see
[architecture.md](architecture.md#build-system-flow)).

### Requirements

- Odin compiler, **nightly** build (the bindings use `"c"` calling-convention
  foreign proc syntax not accepted by the latest stable release as of this
  writing)
- CMake 3.13+
- A C++17 compatible compiler (GCC or Clang)

## First Benchmark

Add your benchmark function to `bindings/odin/examples/basic.odin`, using
the `benchmark` module (`src/benchmark.odin`) — no C or C++ code to write.
Benchmark callbacks must use the `"c"` calling convention, since they are
invoked directly by the C++ adapter with no Odin context of their own:

```odin
package main

import "base:runtime"
import "core:c"
import benchmark "bindings/odin/src"

BM_hello :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    for benchmark.keep_running(state) {
        // Your code here
    }
}

main :: proc() {
    args := [1]cstring{"benchmark"};
    argc := c.int(len(args));
    benchmark.initialize(&argc, cast(^^u8)&args[0]);

    _ = benchmark.register("BM_hello", BM_hello);
    _ = benchmark.run();
}
```

Build and run it:

```bash
cd bindings/odin
odin build examples -out:basic_example -extra-linker-flags:"-lstdc++ -lpthread"
./basic_example
```

`-extra-linker-flags:"-lstdc++ -lpthread"` is required every time — the
combined archive needs the C++ runtime and pthreads, which `odin build`
does not link in automatically (see
[developer_guide.md](developer_guide.md#writing-and-running-benchmarks)).

Output:

```text
Running benchmark
Run on (8 X 3600 MHz CPU s)
Load Average: 0.50, 0.30, 0.10
-----------------------------------------------------
Benchmark           Time             CPU   Iterations
-----------------------------------------------------
BM_hello         123 ns          123 ns      5678901
```

## Common Patterns

`examples/basic.odin` has a complete, runnable version of every pattern
below.

### Throughput Measurement

```odin
BM_throughput :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    n := benchmark.range(state, 0);
    data := make([]u8, n);
    defer delete(data);

    for benchmark.keep_running(state) {
        mem.set(raw_data(data), 0x42, len(data));
    }
    benchmark.set_bytes_processed(state, n * benchmark.iterations(state));
}

// Register with:
bm := benchmark.register("BM_throughput", BM_throughput);
_ = benchmark.range_benchmark(bm, 1 << 10, 1 << 20);
```

### Parameterized Benchmarks

```odin
BM_parameterized :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    n := benchmark.range(state, 0);
    // n varies: 1, 2, 4, 8, 16, ...
    for benchmark.keep_running(state) {
        // work with size n
    }
}

// Register with:
bm := benchmark.register("BM_parameterized", BM_parameterized);
_ = benchmark.range_benchmark(bm, 1, 1 << 16);
```

### Multi-argument Benchmarks

```odin
BM_multi_arg :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    rows := benchmark.range(state, 0);
    cols := benchmark.range(state, 1);
    // work with rows x cols
    for benchmark.keep_running(state) {}
}

// Register with (each args() call adds one combination):
bm := benchmark.register("BM_multi_arg", BM_multi_arg);
bm = benchmark.args(bm, {64, 64});
bm = benchmark.args(bm, {128, 128});
_ = benchmark.args(bm, {256, 256});
```

### Pause/Resume Timing

```odin
BM_with_setup :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    for benchmark.keep_running(state) {
        benchmark.pause_timing(state);
        // Expensive setup (not timed)
        setup_data();
        benchmark.resume_timing(state);
        // Actual work (timed)
        do_work();
    }
}
```

### Multi-threaded Benchmarks

```odin
BM_threaded :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    for benchmark.keep_running(state) {
        // Parallelizable work
    }
}

// Register with (each threads_benchmark() call adds one thread count):
bm := benchmark.register("BM_threaded", BM_threaded);
bm = benchmark.threads_benchmark(bm, 1);
bm = benchmark.threads_benchmark(bm, 2);
bm = benchmark.threads_benchmark(bm, 4);
_ = benchmark.threads_benchmark(bm, 8);
```

### Custom Counters

```odin
BM_custom_counter :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    for benchmark.keep_running(state) {}
    benchmark.set_items_processed(state, benchmark.iterations(state) * 100);
    benchmark.set_label(state, "custom_label");
}
```

### Skip Benchmarks

```odin
BM_conditional :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    when !FEATURE_AVAILABLE {
        benchmark.skip_with_error(state, "feature not available");
        return;
    }
    for benchmark.keep_running(state) {}
}
```

## Command-Line Flags

Pass flags through `initialize`, or straight through to the built binary's
`argv` (both end up in the same place, since `initialize` just forwards
`argc`/`argv` to `benchmark::Initialize`):

```bash
./basic_example --benchmark_filter=BM_hello --benchmark_min_time=0.5s
```

```odin
args := [5]cstring{
    "benchmark",
    "--benchmark_format=console",
    "--benchmark_min_time=0.5s",
    "--benchmark_repetitions=3",
    "--benchmark_filter=BM_hello",
};
argc := c.int(len(args));
benchmark.initialize(&argc, cast(^^u8)&args[0]);
```

Common flags:

| Flag | Description |
| --- | --- |
| `--benchmark_format=console` | Output format (console, json, csv) |
| `--benchmark_min_time=0.5s` | Minimum time per benchmark (needs a unit suffix, e.g. `s`) |
| `--benchmark_repetitions=3` | Number of repetitions |
| `--benchmark_filter=BM_.*` | Regex filter for benchmark names |
| `--benchmark_list_tests` | List all benchmarks without running |
| `--benchmark_report_aggregates_only=true` | Only show aggregates |

## Interpreting Output

```text
BM_sort/8           123 ns          121 ns      5678901
│     │              │                │            │
│     │              │                │            └─ iterations run
│     │              │                └─ CPU time per iteration
│     │              └─ wall-clock time per iteration
│     └─ argument (range(state, 0))
└─ benchmark name
```

- **Time**: Lower is better (unless measuring throughput).
- **CPU vs Time**: If using `use_real_time(bm)`, Time shows wall-clock; otherwise both show CPU time.
- **Iterations**: More iterations means more statistical confidence.

## Caveats

- `benchmark.run()` must be called **at most once per process** —
  google-benchmark's `RunSpecifiedBenchmarks()` corrupts global state and
  crashes if invoked a second time in the same process (an upstream
  limitation, not specific to these bindings; see
  [architecture.md](architecture.md#process-wide-state-caveat)). If you need
  to run different benchmark sets, do it across separate process
  invocations (e.g. via `--benchmark_filter`), not by calling `run()` twice.
- Benchmark callbacks must be declared `proc "c" (state: benchmark.State)` —
  a plain `proc(state: benchmark.State)` will not compile as an argument to
  `register()`, and if the callback calls anything that needs a context
  (allocators, `core:fmt`, etc.) you must set `context = runtime.default_context()`
  as its first statement.
