# Google Benchmark Odin Bindings

Odin bindings for the [Google Benchmark](https://github.com/google/benchmark) microbenchmark library.

## Prerequisites

- Odin compiler (latest stable)
- CMake 3.13+
- C++17 compatible compiler (GCC, Clang, or MSVC)

## Quick Start

```odin
package main

import benchmark "bindings/odin/src"
import "core:os"

BM_hello :: proc(state: *benchmark.State) void {
    for state.keep_running() {
        // your code to benchmark
    }
}

main :: proc() {
    benchmark.initialize(os.args_v[0..])
    benchmark.register("BM_hello", BM_hello, {})
    _ = benchmark.run()
}
```

## Building

### Build libbenchmark via CMake

```bash
cd bindings/odin
cmake -S . -B cmake-build -DCMAKE_BUILD_TYPE=Release
cmake --build cmake-build --parallel
```

### Build and run tests

```bash
cd bindings/odin
odin build src -out:benchmark_test
./benchmark_test
```

## API

### Types

- `State` — Passed to benchmark callbacks, controls iteration and metrics
- `Benchmark` — Configuration handle (fluent API, methods return self)
- `TimeUnit` — Time display unit (nanosecond, microsecond, millisecond, second)
- `BigO` — Complexity mode (auto, O(n), O(n log n), O(1), O(n²))

### Functions

| Function | Description |
|---|---|
| `initialize(args)` | Initialize the benchmark library |
| `run()` | Run all registered benchmarks, returns count |
| `register(name, func)` | Register a benchmark function |
| `add_custom_context(key, value)` | Add custom context to output |
| `clear_registered_benchmarks()` | Remove all registered benchmarks |

### State Methods

| Method | Description |
|---|---|
| `keep_running()` | Returns true if benchmark should continue |
| `keep_running_batch(n)` | Process n iterations at once |
| `pause_timing()` | Pause the timer |
| `resume_timing()` | Resume the timer |
| `skip_with_error(msg)` | Skip with error message |
| `set_bytes_processed(n)` | Report bytes per iteration |
| `set_items_processed(n)` | Report items per iteration |
| `set_label(str)` | Set a label |
| `set_complexity_n(n)` | Set complexity parameter N |
| `range(pos)` | Get range argument at position |
| `iterations()` | Get iteration count |
| `threads()` | Get thread count |
| `thread_index()` | Get current thread index |

### Benchmark Configuration (fluent API)

All methods return `Benchmark` for chaining.

| Method | Description |
|---|---|
| `arg(x)` | Add a single argument |
| `range(start, limit)` | Add range (doubles each step) |
| `dense_range(start, limit, step)` | Add dense range |
| `unit(time_unit)` | Set time unit |
| `threads(n)` | Set thread count |
| `thread_range(min, max)` | Run with thread range |
| `min_time(t)` | Set minimum run time |
| `iterations(n)` | Set iteration count |
| `repetitions(n)` | Set repetition count |
| `use_real_time()` | Use wall-clock time |
| `use_manual_time()` | Use manual time control |
| `complexity(bigo)` | Set complexity mode |
| `get_name()` | Get benchmark name |
