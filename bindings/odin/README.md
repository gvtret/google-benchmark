# Google Benchmark Odin Bindings

Odin bindings for the [Google Benchmark](https://github.com/google/benchmark) microbenchmark library.

See also: [User Guide](docs/user_guide.md) (patterns and CLI flags),
[Developer Guide](docs/developer_guide.md) (project layout, adding bindings,
tests), [Architecture](docs/architecture.md) (how the FFI boundary works).
`examples/basic.odin` has nine complete, runnable examples covering every
pattern below.

## Prerequisites

- Odin compiler, **nightly** build (the bindings use `"c"` calling-convention
  foreign proc syntax not accepted by the latest stable release as of this
  writing)
- CMake 3.13+
- C++17 compatible compiler (GCC or Clang)

## Quick Start

```odin
package main

import "base:runtime"
import "core:c"
import benchmark "bindings/odin/src"

BM_hello :: proc "c" (state: benchmark.State) {
    context = runtime.default_context()
    for benchmark.keep_running(state) {
        // your code to benchmark
    }
}

main :: proc() {
    args := [1]cstring{"benchmark"}
    argc := c.int(len(args))
    benchmark.initialize(&argc, cast(^^u8)&args[0])
    _ = benchmark.register("BM_hello", BM_hello)
    _ = benchmark.run()
}
```

Benchmark functions must use the `"c"` calling convention (`proc "c" (state: benchmark.State)`)
since they are called directly from the C++ adapter with no Odin context — set
`context = runtime.default_context()` as the first line of the callback if it calls into
anything that needs a context (allocators, etc.).

## Building

### Build libbenchmark and the C adapter via CMake

```bash
cd bindings/odin
cmake -S . -B cmake-build -DCMAKE_BUILD_TYPE=Release
cmake --build cmake-build --parallel
```

This produces `cmake-build/libodin_api.a` (google-benchmark + the C adapter combined),
which `src/benchmark.odin` links against via `foreign import`.

### Run the example

```bash
cd bindings/odin
odin build examples -out:basic_example -extra-linker-flags:"-lstdc++ -lpthread"
./basic_example
```

### Run tests

```bash
cd bindings/odin
odin test tests -extra-linker-flags:"-lstdc++ -lpthread"
```

Note: all `gb.run()` assertions live in a single `@(test)` proc. Upstream
google-benchmark's `RunSpecifiedBenchmarks()` corrupts global state if called more than
once per process (reproducible in plain C++, independent of these bindings), so tests
register every benchmark configuration and call `run()` exactly once.

## API

### Types

- `State` — Passed to benchmark callbacks, controls iteration and metrics
- `Benchmark` — Configuration handle (passed explicitly as the first argument to the
  functions below, all of which return `Benchmark` so calls can be chained via `bm = gb.foo(bm, ...)`)
- `TimeUnit` — Time display unit (nanosecond, microsecond, millisecond, second)
- `BigO` — Complexity mode (auto, O(n), O(n log n), O(1), O(n²))

Odin has no method-call sugar for free procedures, so all functions below are called as
`gb.function_name(value, ...)`, not `value.function_name(...)`.

### Functions

| Function | Description |
| --- | --- |
| `initialize(argc, argv)` | Initialize the benchmark library |
| `run()` | Run all registered benchmarks, returns count |
| `register(name, func)` | Register a benchmark function |
| `add_custom_context(key, value)` | Add custom context to output |
| `clear_registered_benchmarks()` | Remove all registered benchmarks |

### State Functions

| Function | Description |
| --- | --- |
| `keep_running(state)` | Returns true if benchmark should continue |
| `keep_running_batch(state, n)` | Process n iterations at once |
| `pause_timing(state)` | Pause the timer |
| `resume_timing(state)` | Resume the timer |
| `skip_with_error(state, msg)` | Skip with error message |
| `set_bytes_processed(state, n)` | Report bytes per iteration |
| `set_items_processed(state, n)` | Report items per iteration |
| `set_label(state, str)` | Set a label |
| `set_complexity_n(state, n)` | Set complexity parameter N |
| `range(state, pos)` | Get range argument at position |
| `iterations(state)` | Get iteration count |
| `threads(state)` | Get thread count |
| `thread_index(state)` | Get current thread index |

### Benchmark Configuration

All functions take `Benchmark` as the first argument and return `Benchmark`.

| Function | Description |
| --- | --- |
| `arg(bm, x)` | Add a single argument |
| `args(bm, values)` | Add one multi-argument combination, e.g. `args(bm, {64, 64})` |
| `range_benchmark(bm, start, limit)` | Add range (doubles each step) |
| `dense_range(bm, start, limit, step)` | Add dense range |
| `unit(bm, time_unit)` | Set time unit |
| `threads_benchmark(bm, n)` | Set thread count |
| `thread_range(bm, min, max)` | Run with thread range |
| `min_time(bm, t)` | Set minimum run time |
| `iterations_benchmark(bm, n)` | Set iteration count |
| `repetitions(bm, n)` | Set repetition count |
| `use_real_time(bm)` | Use wall-clock time |
| `use_manual_time(bm)` | Use manual time control |
| `complexity(bm, bigo)` | Set complexity mode |
| `get_name(bm)` | Get benchmark name |
