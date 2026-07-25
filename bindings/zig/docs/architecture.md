# Architecture

## Layer Diagram

```text
┌──────────────────────────────────────────────────┐
│                  Zig Application                 │
│  benchmark.registerBenchmark("BM_Foo", foo)      │
│  benchmark.run()                                 │
└───────────────────┬──────────────────────────────┘
                    │ @cImport / extern functions
┌───────────────────▼──────────────────────────────┐
│              benchmark.zig (Zig API)             │
│  State, Benchmark, TimeUnit — idiomatic wrappers │
│  comptime trampoline for callbacks               │
└───────────────────┬──────────────────────────────┘
                    │ C function calls
┌───────────────────▼──────────────────────────────┐
│           zig_api.h / zig_api.cc (C adapter)     │
│  extern "C" functions wrapping C++ methods       │
│  void* opaque pointers for State & Benchmark     │
└───────────────────┬──────────────────────────────┘
                    │ #include "benchmark/benchmark.h"
┌───────────────────▼──────────────────────────────┐
│           libbenchmark.so / .a (C++)             │
│  benchmark::Initialize, RunSpecifiedBenchmarks,  │
│  RegisterBenchmark, State, Benchmark classes     │
└──────────────────────────────────────────────────┘
```

## Why Three Layers?

The google-benchmark library is pure C++. Zig has zero-cost C interop but cannot call C++ directly (name mangling, classes, exceptions, templates). The C adapter layer:

1. Provides an `extern "C"` interface that Zig can call via `@cImport`
2. Casts `void*` back to C++ types internally
3. Keeps the Zig side simple — no C++ knowledge required from the user

This is the same pattern used by the Rust bindings (which use `cxx` for similar reasons).

## Callback Trampoline

When a benchmark function is registered, the flow is:

```text
Zig: registerBenchmark("BM_foo", my_fn)
  → Zig generates a comptime trampoline: S.trampoline
  → calls c.benchmark_zig_register_benchmark("BM_foo", &S.trampoline)

C++ adapter:
  → benchmark::RegisterBenchmark("BM_foo", lambda)
  → lambda captures the C function pointer
  → when benchmark runs, lambda calls fn(&state) with State* cast to void*

Zig trampoline:
  → receives void* (the State*)
  → wraps it in Zig State struct
  → calls user's function
```

The trampoline is generated at compile time per benchmark function, avoiding heap allocation and dynamic dispatch.

## Opaque Pointers

`State` and `Benchmark` are C++ classes with complex internal state. Rather than replicating their layout in Zig (which would be fragile and tie the binding to a specific library version), we pass them as `void*` through the C boundary:

- Zig: `State { ptr: *anyopaque }` — thin wrapper, methods call C functions
- C adapter: `static_cast<benchmark::State*>(s)->Method()` — safe downcast
- The pointers are never dereferenced from Zig code

This makes the binding resilient to internal changes in libbenchmark.

## String Conversion

Zig strings are `(pointer, length)` pairs. C strings are null-terminated. At the boundary:

- **Zig → C**: Functions accept `[*:0]const u8` (sentinel-terminated). The caller ensures null termination.
- **C → Zig**: `benchmark_zig_benchmark_name()` returns `const char*`. The Zig wrapper uses `std.mem.span()` to convert.

For user-provided strings (e.g., `registerBenchmark`, `addCustomContext`), the convention is to accept `[*:0]const u8`, which Zig enforces as null-terminated at compile time.

## Build System Flow

```text
zig build cmake  (dependency of test/run, rarely invoked directly)
  → cmake -S . -B cmake-build (builds libbenchmark + zig_api.cc as C++)
  → produces cmake-build/libbenchmark_combined.a (libbenchmark.a + zig_api.o combined)

zig build test
  → depends on: cmake
  → zig c++ test_adapter.cc -lbenchmark_combined <system libstdc++.a/libsupc++.a/libgcc.a> -o test_adapter
  → runs ./test_adapter (C++ smoke test of the zig_api.h/cc adapter surface)

zig build run
  → depends on: cmake
  → zig build-exe examples/basic.zig (imports the `benchmark` Zig module)
      + cmake-build/libbenchmark_combined.a
      + system libstdc++.a / libsupc++.a / libgcc.a / libgcc_eh.a (as object files)
  → runs the resulting run_benchmarks binary
```

Alternatively, `-Dbenchmark_path=/path/to/dir` (a directory containing
`libbenchmark_combined.a`) skips the CMake step and links against a
pre-built library.

Note: `zig build-exe`/`zig c++` use Zig's bundled `lld`, which cannot resolve
system C++ libraries automatically the way `g++`/`clang++` do. Both the
`test` and `run` steps work around this by passing `libstdc++.a`,
`libsupc++.a`, `libgcc.a`, and (for `run`) `libgcc_eh.a` explicitly —
`libgcc_eh.a` supplies the `_Unwind_*` symbols used by C++ exception
tables that `libgcc.a` alone does not provide.

The directory containing these archives is not hardcoded to a specific GCC
version — `build.zig`'s `gccLibDir()` runs `g++ -print-file-name=libstdc++.a`
and takes its `dirname()`, so whatever GCC major version is installed works.
This lookup only runs `g++`; if it's missing, `zig build` alone still
succeeds (with a warning) since the plain build doesn't need it — only
`test`/`run` do. See [README.md](../README.md#prerequisites) for what to
install and how.

## Thread Safety

- google-benchmark's `State` is thread-local by design — each thread gets its own `State` instance
- The C adapter uses no global mutable state
- The Zig trampoline function is `comptime`-generated per benchmark, so no shared state
- Safe to register benchmarks from multiple threads (though this is uncommon)

## Error Handling

- C++ exceptions from libbenchmark are caught at the C adapter boundary (the adapter compiles with `-fno-exceptions` if the library is built without exceptions)
- `SkipWithError` translates to a Zig-level skip (no error propagation needed)
- Allocation failures in Zig are handled with `catch` at the call site
