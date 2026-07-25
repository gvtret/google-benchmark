# Google Benchmark Zig Bindings

Zig bindings for the [Google Benchmark](https://github.com/google/benchmark) microbenchmark library.

## Prerequisites

- **Zig 0.14.x** — this binding uses 0.14-specific APIs (e.g.
  `std.process.argsAlloc`'s `[]const [:0]const u8` return type,
  `std.mem.doNotOptimizeAway`) and 0.14 syntax rules (no `///` doc comments
  directly above `test` blocks). Other versions are untested and may not
  build. Download from <https://ziglang.org/download/> (no package manager
  install needed — it's a single self-contained archive to unpack onto
  `PATH`).
- **CMake 3.13+** — builds `libbenchmark` itself.
- **A C++17 compiler** — used by CMake to build `libbenchmark`. GCC, Clang,
  or MSVC all work for the plain `zig build` step.
- **A static C++ runtime, for `zig build test` and `zig build run`** —
  these two steps link against static C++ runtime archives directly as
  object files, because Zig's bundled `lld` cannot resolve system C++
  libraries the way `g++`/`clang++` do (see
  [docs/architecture.md](docs/architecture.md#build-system-flow)). Two
  toolchains are supported, both verified to compile, link, and run
  correctly:
  - **GCC + libstdc++ (default)** — `g++` with static
    `libstdc++.a`/`libsupc++.a`/`libgcc.a`/`libgcc_eh.a`, located via
    `g++ -print-file-name=libstdc++.a` (any installed GCC version works,
    nothing is hardcoded).
  - **Clang + libc++ (`-Dclang=true`)** — `clang++` with static
    `libc++.a`/`libc++abi.a`/`libunwind.a` (`-stdlib=libc++`), located via
    `clang++ -stdlib=libc++ -print-file-name=libc++.a`. A fully independent
    toolchain with no GCC/GNU runtime involved at all.

  Plain `zig build` does not need either and works without them (e.g. on
  macOS, where the GCC+libstdc++ archives specifically don't exist by
  default); only `test` and `run` require one of the two.

### Installing g++ with static libstdc++/libgcc archives

On Debian/Ubuntu, installing `g++` already pulls these in as a transitive
dependency (verified: `g++` → `g++-<N>-<arch>` → `libstdc++-<N>-dev` /
`libgcc-<N>-dev`, which ship the `.a` archives, not just the `.so`):

```bash
sudo apt install g++ cmake
```

On Fedora/RHEL (`dnf`), the static archives ship in a separate package from
the compiler:

```bash
sudo dnf install gcc-c++ libstdc++-static cmake
```

On Arch Linux (`pacman`), `gcc` ships the static archives directly:

```bash
sudo pacman -S gcc cmake
```

To check your system already has everything `zig build test`/`zig build run`
need:

```bash
g++ -print-file-name=libstdc++.a   # must NOT print just "libstdc++.a" back —
                                    # that means it wasn't found
```

### Installing Clang + static libc++ (optional, for `-Dclang=true`)

On Debian/Ubuntu, the static archives ship in separate `-dev` packages from
the compiler:

```bash
sudo apt install clang libc++-dev libc++abi-dev cmake
```

Don't add `libunwind-dev` explicitly — `libc++-dev` already pulls in the
matching LLVM `libunwind-*-dev` as a transitive dependency, and it
*conflicts* with GNU's `libunwind-dev` package if both are requested
together (verified: this fails apt's dependency resolution with
`Unable to satisfy dependencies`). `build.zig` locates each archive
independently, since (also verified) `libc++.a`/`libunwind.a` and
`libc++abi.a` don't necessarily live in the same directory — e.g. on
Ubuntu's stock LLVM-20 packages, `libc++abi.a` lands under
`/usr/lib/llvm-20/lib/` while the other two land in the generic
`/lib/x86_64-linux-gnu/`.

Check it's all there the same way:

```bash
clang++ -stdlib=libc++ -print-file-name=libc++.a   # must NOT print "libc++.a" back
clang++ -stdlib=libc++ -print-file-name=libc++abi.a
clang++ -print-file-name=libunwind.a
```

**Not verified on macOS**: Apple ships Clang as the system default, but
typically only a *dynamic* `libc++.dylib` — not the static `libc++.a` this
build system needs to work around Zig's `lld` limitation (see above). A
Homebrew LLVM install (`brew install llvm`) may provide the static archive;
this hasn't been tested here (no macOS machine available in this
environment). If you try it and it doesn't work out of the box, that's the
first thing to check.

## Quick Start

```zig
const benchmark = @import("benchmark");

fn BM_hello(state: *benchmark.State) void {
    while (state.keepRunning()) {
        // your code to benchmark here
    }
}

pub fn main() void {
    const args = std.process.argsAlloc(std.heap.page_allocator) catch return;
    defer std.process.argsFree(std.heap.page_allocator, args);

    benchmark.initialize(args);
    _ = benchmark.registerBenchmark("BM_hello", BM_hello);
    _ = benchmark.run();
}
```

## Building

### Standalone (builds libbenchmark from source)

```bash
cd bindings/zig
zig build
```

### Against pre-installed libbenchmark

```bash
cd bindings/zig
zig build -Dbenchmark_path=/path/to/lib
```

### Via CMake (from project root)

```bash
cmake -S . -B build -DBENCHMARK_ENABLE_ZIG_BINDINGS=ON
cmake --build build
cd build && ctest -R zig_bindings_tests
```

## Running Tests

```bash
cd bindings/zig
zig build test
```

To use Clang + libc++ instead of the default GCC + libstdc++:

```bash
zig build test -Dclang=true
```

## Writing and Running Benchmarks

Add benchmark functions to `examples/basic.zig` using the `benchmark` module shown
above — no C or C++ code needed — then:

```bash
cd bindings/zig
zig build run
```

Also supports `-Dclang=true` the same way as `zig build test` above.

Pass benchmark CLI flags after `--`:

```bash
zig build run -- --benchmark_filter=BM_hello --benchmark_min_time=0.5
```

See [docs/developer_guide.md](docs/developer_guide.md#writing-and-running-benchmarks)
for details on how `zig build run` links against the library.

## API

### Top-level functions

| Function | Description |
|---|---|
| `initialize(args)` | Initialize the benchmark library |
| `run()` | Run all registered benchmarks, returns count |
| `registerBenchmark(name, func)` | Register a benchmark function, returns `*Benchmark` for chaining |
| `addCustomContext(key, value)` | Add custom context to JSON output |
| `clearRegisteredBenchmarks()` | Remove all registered benchmarks |

### `State`

| Method | Description |
|---|---|
| `keepRunning()` | Returns true if the benchmark should continue |
| `keepRunningBatch(n)` | Returns true, processes `n` iterations at once |
| `pauseTiming()` | Pause the benchmark timer |
| `resumeTiming()` | Resume the benchmark timer |
| `skipWithError(msg)` | Skip this benchmark with an error message |
| `setBytesProcessed(n)` | Report bytes processed per iteration |
| `setItemsProcessed(n)` | Report items processed per iteration |
| `setLabel(str)` | Set a label for this iteration |
| `setComplexityN(n)` | Set the complexity parameter N |
| `range(pos)` | Get the range argument at position `pos` |
| `iterations()` | Get the number of iterations run |
| `threads()` | Get the number of threads |
| `threadIndex()` | Get the current thread index |

### `Benchmark`

All configuration methods return `*Benchmark` for fluent chaining.

| Method | Description |
|---|---|
| `arg(x)` | Add a single argument |
| `range(start, limit)` | Add a range of arguments (doubles each time) |
| `denseRange(start, limit, step)` | Add a dense range (adds each step) |
| `args(list)` | Add a list of arguments |
| `unit(time_unit)` | Set the time unit |
| `threads(n)` | Set the number of threads |
| `threadRange(min, max)` | Run with thread count from min to max |
| `minTime(t)` | Set minimum run time in seconds |
| `iterations(n)` | Set exact iteration count |
| `repetitions(n)` | Set number of repetitions |
| `useRealTime()` | Use wall-clock time instead of CPU time |
| `useManualTime()` | Use manual time control |
| `complexity(bigo)` | Set complexity mode |
| `getName()` | Get the benchmark name |

### Enums

```zig
pub const TimeUnit = enum(c_int) {
    nanosecond, microsecond, millisecond, second,
};

pub const BigO = enum(c_int) {
    auto, o_n, o_n_log_n, o_1, o_n2,
};
```
