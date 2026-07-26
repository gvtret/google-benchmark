# Developer Guide — Odin Bindings

## Project Structure

```text
bindings/odin/
├── CMakeLists.txt         # Builds libbenchmark + the C adapter into
│                           # cmake-build/libodin_api.a
├── src/
│   ├── odin_api.h          # C adapter header (extern "C" declarations)
│   ├── odin_api.cc         # C adapter implementation (C++ code)
│   └── benchmark.odin      # Public Odin API (foreign import + wrappers)
├── tests/
│   └── benchmark_test.odin # `odin test` package
├── examples/
│   └── basic.odin          # Runnable examples (`odin build examples`)
├── docs/
│   ├── architecture.md     # Architecture overview
│   ├── developer_guide.md  # This file
│   └── user_guide.md       # End-user guide
├── build.odin              # Standalone `odin run .` placeholder — prints
│                           # a pointer to the real entry points (examples/)
└── README.md                # Quick reference
```

`tests/` and `examples/` are separate Odin packages/directories deliberately:
Odin requires every `.odin` file in a directory to declare the same
`package` name, and `build.odin` (at the repo root, `package build`) would
otherwise collide with a test or example package placed alongside it.

## How to Add a New Binding Function

### Step 1: Add the C declaration to `src/odin_api.h`

```c
void* benchmark_odin_benchmark_new_method(void* benchmark, int param);
```

### Step 2: Implement it in `src/odin_api.cc`

```cpp
extern "C" void* benchmark_odin_benchmark_new_method(void* b, int param) {
  return static_cast<benchmark::Benchmark*>(b)->NewMethod(param);
}
```

### Step 3: Declare it in the `foreign odin_api { ... }` block and add a wrapper in `src/benchmark.odin`

```odin
// In the foreign odin_api { ... } block:
benchmark_odin_benchmark_new_method :: proc(benchmark: rawptr, param: c.int) -> rawptr ---

// Free-function wrapper (Odin has no method-call syntax):
new_method :: proc(self: Benchmark, param: int) -> Benchmark {
    benchmark_odin_benchmark_new_method(self.ptr, c.int(param));
    return self;
}
```

Every C adapter function must be declared once in the `foreign odin_api { ... }`
block in `src/benchmark.odin` — the compiler will not find it otherwise, and
there is no automatic discovery of foreign symbols.

### Step 4: Add coverage in `tests/benchmark_test.odin`

Register the new configuration inside the single existing
`all_benchmarks_run` test proc (see "Why one test?" below) rather than
adding a new `@(test)` proc:

```odin
bm_new := gb.register("BM_NewMethod", bm_empty);
_ = gb.new_method(bm_new, 42);
```

## Running Tests

```bash
cd bindings/odin
cmake -S . -B cmake-build -DCMAKE_BUILD_TYPE=Release
cmake --build cmake-build --parallel
odin test tests -extra-linker-flags:"-lstdc++ -lpthread"
```

### Why one test?

`tests/benchmark_test.odin` contains a single `@(test) all_benchmarks_run`
proc that registers every benchmark configuration and calls `gb.run()`
exactly once. This is not a style preference: `benchmark::RunSpecifiedBenchmarks()`
corrupts global state and segfaults if called more than once in the same
process (reproduced independently in plain C++, unrelated to Odin — see
[architecture.md](architecture.md#process-wide-state-caveat)). Since Odin's
test runner executes all `@(test)` procs in one process, splitting the
assertions across multiple test procs (each calling `run()`) would crash
after the first one. Add new coverage to the existing test proc, not a new one.

`odin test` defaults to running tests across multiple threads
(`-define:ODIN_TEST_THREADS=n`), but since there is only one `@(test)` proc
here, that setting has no effect on this package.

## Writing and Running Benchmarks

Add benchmark functions to `examples/basic.odin` using the `benchmark`
module (`src/benchmark.odin`) — no C or C++ code required. Benchmark
callbacks must use the `"c"` calling convention and set up an Odin context
if they call anything that needs one:

```odin
import "base:runtime"
import benchmark "../src"

bm_my_benchmark :: proc "c" (state: benchmark.State) {
    context = runtime.default_context();
    for benchmark.keep_running(state) {
        // work to measure
    }
}

// in main():
_ = benchmark.register("BM_my_benchmark", bm_my_benchmark);
```

Then build and run:

```bash
odin build examples -out:basic_example -extra-linker-flags:"-lstdc++ -lpthread"
./basic_example
```

`-extra-linker-flags:"-lstdc++ -lpthread"` is required every time: the
combined archive (`cmake-build/libodin_api.a`) needs the C++ runtime and
pthreads, which `odin build`/`odin test` do not link in automatically. See
[architecture.md](architecture.md#build-system-flow).

To pass benchmark CLI flags through to the binary:

```bash
./basic_example --benchmark_filter=BM_sort --benchmark_min_time=1s
```

## Code Style

- Odin code uses `snake_case` for procedures and variables.
- Types use `PascalCase` (`State`, `Benchmark`, `TimeUnit`, `BigO`).
- C adapter functions are prefixed with `benchmark_odin_` to avoid symbol collisions.
- `Benchmark`/`State` "methods" are free procedures taking the wrapper struct as an explicit first argument (`gb.range_benchmark(bm, ...)`), not method-call syntax — Odin does not support `bm.range_benchmark(...)` for free procedures.
- C strings crossing the FFI boundary use Odin's `cstring` type.

## Debugging

### Building with debug info

```bash
odin build examples -debug -extra-linker-flags:"-lstdc++ -lpthread"
```

### Valgrind

```bash
valgrind ./basic_example
```

### Tracing FFI calls

Add `fmt.println` calls in `src/benchmark.odin` wrapper procedures to trace
calls across the FFI boundary, or use `gdb`/`lldb` directly on the built
binary — the C adapter and libbenchmark are compiled with debug info
available via `-DCMAKE_BUILD_TYPE=RelWithDebInfo` passed to the CMake step.
