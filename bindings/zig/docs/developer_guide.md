# Developer Guide

## Project Structure

```text
bindings/zig/
├── build.zig              # Zig build system
├── build.zig.zon          # Package metadata
├── src/
│   ├── zig_api.h          # C adapter header (extern "C" declarations)
│   ├── zig_api.cc         # C adapter implementation (C++ code)
│   ├── benchmark.zig      # Public Zig API
│   └── benchmark_test.zig # Unit tests
├── examples/
│   └── basic.zig          # Runnable examples (see `zig build run`)
├── docs/
│   ├── architecture.md    # Architecture overview
│   ├── developer_guide.md # This file
│   └── user_guide.md      # End-user guide
└── README.md              # Quick reference
```

## How to Add a New Binding Function

### Step 1: Add C declaration to `zig_api.h`

```c
void* benchmark_zig_benchmark_new_method(void* benchmark, int param);
```

### Step 2: Implement in `zig_api.cc`

```cpp
void* benchmark_zig_benchmark_new_method(void* b, int param) {
  return static_cast<benchmark::Benchmark*>(b)->NewMethod(param);
}
```

### Step 3: Add Zig wrapper in `benchmark.zig`

```zig
// In Benchmark struct:
pub fn newMethod(self: *Benchmark, param: i32) *Benchmark {
    return .{ .ptr = c.benchmark_zig_benchmark_new_method(self.ptr, param) };
}
```

### Step 4: Add test in `benchmark_test.zig`

```zig
test "new method" {
    benchmark.clearRegisteredBenchmarks();
    _ = benchmark.registerBenchmark("BM_NewMethod", bm_empty)
        .newMethod(42);
    const count = benchmark.run();
    try std.testing.expect(count > 0);
}
```

## Running Tests

```bash
cd bindings/zig
zig build test
```

This runs two independent checks:

1. The native Zig `test` blocks in `src/benchmark_test.zig`, exercising the
   public `benchmark` module directly (`registerBenchmark`, `run`, `State`
   methods, etc.).
2. `test_adapter.cc`, a lower-level C++ smoke test of the `zig_api.h/cc`
   adapter surface, independent of the Zig module.

Both link against the combined archive the same way `zig build run` does
(see [architecture.md](architecture.md#build-system-flow)) — a workaround
for Zig's `lld` not resolving system C++ libraries the way `g++`/`clang++`
do. Pass `-Dclang=true` to use Clang + libc++ instead of the default GCC +
libstdc++ — both are verified to compile, link, and run correctly:

```bash
zig build test -Dclang=true
```

The native test binary is built with a non-default test runner mode
(`.mode = .simple` instead of the build system's default `.server`), because
`benchmark.run()` writes raw benchmark output straight to stdout via the
linked C++ library, which corrupts the build system's structured test IPC
protocol (`--listen=-`) and deadlocks `zig build test` forever if left in
the default mode. See the comment above `native_tests` in `build.zig` for
details. One consequence: `zig build test` doesn't report a Zig-native
per-test pass/fail summary the way a plain `zig test` invocation would —
the test binary's own "N/M test.name...OK" output is printed directly
instead, and the step fails on nonzero exit or a crash.

## Writing and Running Benchmarks

Add benchmark functions to `examples/basic.zig` using the `benchmark` module
(`src/benchmark.zig`) — no C or C++ code required:

```zig
const benchmark = @import("benchmark");

fn bm_my_benchmark(state: *benchmark.State) void {
    while (state.keepRunning()) {
        // work to measure
    }
}

// in main():
_ = benchmark.registerBenchmark("BM_my_benchmark", bm_my_benchmark);
```

Then build and run:

```bash
zig build run
```

This links `examples/basic.zig` against the combined `libbenchmark_combined.a`
produced by the `cmake` step, plus the system's static C++ runtime
(`libstdc++.a`, `libsupc++.a`, `libgcc.a`, `libgcc_eh.a` on Linux — or, with
`-Dclang=true`, `libc++.a`, `libc++abi.a`, `libunwind.a`) — see
[architecture.md](architecture.md#build-system-flow) for why these are
needed and passed explicitly.

To pass benchmark CLI flags through `zig build run`:

```bash
zig build run -- --benchmark_filter=BM_sort --benchmark_min_time=1
```

## Building Standalone vs Via CMake

### Standalone (Zig drives the build)

```bash
zig build                           # builds libbenchmark from source
zig build -Dbenchmark_path=/path    # uses pre-built library
```

### Via CMake (CMake drives the build)

```bash
cd /path/to/google-benchmark
cmake -S . -B build -DBENCHMARK_ENABLE_ZIG_BINDINGS=ON
cmake --build build
cd build && ctest -R zig_bindings_tests
```

## CI Integration

The GitHub Actions workflow in `.github/workflows/test_bindings.yml`
(`zig_bindings` job, `ubuntu-latest` + `macos-latest`) runs different steps
per OS:

- **`ubuntu-latest`**: a single `zig build test` step — this exercises the
  CMake build, the native Zig `test` blocks in `src/benchmark_test.zig`,
  and the `test_adapter.cc` C++ smoke test, all in one command (see
  "Running Tests" above).
- **`macos-latest`**: its own manual steps (`cmake` configure + build,
  compile/run `test_adapter.cc` with `g++`, `zig build-lib
  src/benchmark.zig` to verify the module compiles) — kept separate from
  `zig build test` deliberately. `build.zig`'s `test`/`run` steps locate
  static `libstdc++.a`/`libsupc++.a`/`libgcc.a`/`libgcc_eh.a` archives via
  `g++ -print-file-name=...` (see
  [architecture.md](architecture.md#build-system-flow)) — this is
  GNU-specific, and Apple's toolchain (Clang/libc++, no `libstdc++.a`) is
  not verified to provide equivalents. Unifying the two legs onto
  `zig build test` was considered but not done, since it can't be verified
  without an actual macOS runner and risks silently breaking that leg. Note
  the macOS `test_adapter.cc` step's own `-lstdc++` may have the same
  underlying risk (modern macOS SDKs dropped `libstdc++`) — also unverified,
  left as-is rather than guessed at.
  - `build.zig` now also supports `-Dclang=true` (Clang + static libc++,
    see "Running Tests" above and
    [architecture.md](architecture.md#build-system-flow)) — verified on
    Linux, where it's a genuinely independent toolchain from GCC. This does
    **not** close the macOS gap above: Apple ships Clang by default, but
    typically only a *dynamic* `libc++.dylib`, not the static `libc++.a`
    this build system links as an object file. `zig build test
    -Dclang=true` would still need a static `libc++.a` from somewhere (e.g.
    Homebrew's LLVM) to work on macOS — unverified, not attempted here.

## Code Style

- Zig code follows standard `zig fmt` formatting
- C adapter functions are prefixed with `benchmark_zig_` to avoid symbol collisions
- Zig types use CamelCase for public types (`State`, `Benchmark`, `TimeUnit`)
- Zig functions use camelCase (`keepRunning`, `setBytesProcessed`)

## Debugging

### Building with debug info

```bash
zig build -Doptimize=Debug
```

### Memory debugging

The C++ adapter links against libbenchmark which may allocate. Use AddressSanitizer:

```bash
zig build -Doptimize=Debug -Dsanitize=address
```

### Valgrind

```bash
valgrind ./zig-cache/bin/benchmark_test
```

### Tracing FFI calls

Add `std.log.debug` calls in `benchmark.zig` methods to trace calls across the FFI boundary.
