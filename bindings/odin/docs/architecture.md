# Architecture — Odin Bindings

## Layer Diagram

```text
┌───────────────────────────────────────────────────┐
│                 Odin Application                  │
│  benchmark.register("BM_Foo", foo)                │
│  benchmark.run()                                  │
└───────────────────┬───────────────────────────────┘
                    │ foreign import (static link)
┌───────────────────▼────────────────────────────────┐
│              benchmark.odin (Odin API)             │
│  State, Benchmark — thin rawptr wrappers           │
│  register() passes a "c"-convention proc straight  │
│  through to the adapter (no trampoline)            │
└───────────────────┬────────────────────────────────┘
                    │ extern "C" function calls
┌───────────────────▼────────────────────────────────┐
│         odin_api.h / odin_api.cc (C adapter)       │
│  extern "C" functions wrapping C++ methods         │
│  void* opaque pointers for State & Benchmark       │
└───────────────────┬────────────────────────────────┘
                    │ #include "benchmark/benchmark.h"
┌───────────────────▼────────────────────────────────┐
│              libodin_api.a (C++, static)           │
│  benchmark::Initialize, RunSpecifiedBenchmarks,    │
│  RegisterBenchmark, State, Benchmark classes       │
└────────────────────────────────────────────────────┘
```

## Why Three Layers?

google-benchmark is pure C++. Odin's `foreign import` can only bind to C-ABI
symbols (no name-mangled C++ classes, templates, or exceptions). The C
adapter layer (`odin_api.h`/`odin_api.cc`):

1. Provides an `extern "C"` interface Odin can declare in a `foreign odin_api { ... }` block.
2. Casts `void*` back to the real C++ types (`benchmark::State*`, `benchmark::Benchmark*`) internally.
3. Keeps the Odin side simple — no C++ knowledge required from the user.

This mirrors the approach used by the [Zig bindings](../../zig/docs/architecture.md) for the same reason.

## No Trampoline — Direct "c" Callback

Unlike the Zig bindings (which generate a `comptime` trampoline per
benchmark function), the Odin bindings pass the user's callback straight
through to C with no wrapper function at all:

```text
Odin: register("BM_foo", my_fn)
  → my_fn must be proc "c" (state: State)
  → transmute(proc "c" (rawptr))my_fn is passed directly to
    benchmark_odin_register_benchmark("BM_foo", my_fn)

C++ adapter:
  → benchmark::RegisterBenchmark("BM_foo", lambda)
  → lambda captures the C function pointer (fn)
  → when the benchmark runs, lambda calls fn(&state), i.e. my_fn(&state)

my_fn (Odin, "c" convention):
  → receives the State* as its single rawptr-sized argument
  → State is `struct { ptr: rawptr }` — one pointer field, so its C ABI
    layout is identical to a bare pointer; no unwrapping step is needed
```

This works only because `State` has exactly one `rawptr` field. A trampoline
that closes over the user's function (as the Zig binding's `comptime`
trampoline does) is **not possible** in Odin: procedures declared with the
`"c"` calling convention cannot capture surrounding variables — there is no
hidden context/closure parameter for them, unlike the default `"odin"`
convention. An earlier draft of this binding attempted exactly that pattern
and failed to compile with "Undeclared name" for the captured variable.

## Opaque Pointers

`State` and `Benchmark` are C++ classes with complex internal state. Rather
than replicating their layout in Odin (fragile, and ties the binding to a
specific libbenchmark version), they are passed as `rawptr` through the C
boundary:

- Odin: `State :: struct { ptr: rawptr }` / `Benchmark :: struct { ptr: rawptr }` — thin wrappers; all "methods" are free procedures taking the wrapper as an explicit first argument.
- C adapter: `static_cast<benchmark::State*>(s)->Method()` — safe downcast.
- The pointers are never dereferenced from Odin code.

Odin has no method-call syntax for free procedures (`x.foo()` does not
resolve to `pkg.foo(x)` the way it might in some other languages), so the
"fluent" `Benchmark` configuration API is written as ordinary function calls
that take and return `Benchmark`:

```odin
bm := benchmark.register("BM_foo", BM_foo)
bm = benchmark.range_benchmark(bm, 1, 1 << 16)
bm = benchmark.threads_benchmark(bm, 4)
```

## Numeric Types

The C adapter's signatures use fixed-width C types (`int64_t`, `int`,
`size_t`, `double`, `bool`). Odin's `int`/`f64` do not implicitly convert to
these — every wrapper procedure in `benchmark.odin` casts explicitly (e.g.
`c.int64_t(n)`) at the call site. This is enforced by the Odin compiler, not
a style choice.

## Build System Flow

```text
1. cmake builds libbenchmark + odin_api.cc, then combines both into
   cmake-build/libodin_api.a (see CMakeLists.txt's combine_libs target).
2. src/benchmark.odin's `foreign import odin_api "../cmake-build/libodin_api.a"`
   links directly against that archive by path (not via -l/-L search).
3. `odin build` / `odin test` additionally need `-extra-linker-flags:"-lstdc++ -lpthread"`
   on the command line, since libodin_api.a itself needs the C++ runtime and
   pthreads, which Odin's linker invocation does not pull in automatically.
```

## Process-Wide State Caveat

`benchmark::RunSpecifiedBenchmarks()` is not safe to call more than once per
process — doing so corrupts global reporter state and segfaults. This is a
property of google-benchmark itself, not the Odin bindings (reproduced
independently in a minimal C++ program with no Odin involved). Any Odin
program embedding these bindings should call `benchmark.run()` at most once.
This is why `tests/benchmark_test.odin` registers every benchmark
configuration in a single `@(test)` proc instead of one `run()` call per test.

## Thread Safety

- google-benchmark's `State` is created per-thread for threaded benchmarks; the C adapter holds no global mutable state of its own.
- Registration (`register()`, `clear_registered_benchmarks()`) and `run()` are not designed to be called concurrently — call them from a single thread, before/after the benchmark run.
