# Architecture — Odin Bindings

## Layer Diagram

```
Odin Application Code
    │
    ▼
benchmark.odig (Odin API)
    │
    ▼
odin_api.h / odin_api.cc (C adapter)
    │
    ▼
libbenchmark_combined.a (C++)
```

## Components

### 1. C Adapter (`odin_api.h` / `odin_api.cc`)

The C adapter provides an `extern "C"` interface that wraps the C++ google-benchmark library. Odin imports this via foreign import.

- All C++ types are passed as opaque `void*` pointers
- Benchmark configuration methods return void (Odin implements fluent chaining)
- The adapter casts `void*` back to `benchmark::Benchmark*` or `benchmark::State*`

### 2. Odin API (`benchmark.odig`)

The Odin module provides idiomatic types and procedures:

- `State` struct wraps the opaque pointer with methods
- `Benchmark` struct wraps the opaque pointer with fluent configuration
- `TimeUnit` and `BigO` enums map to C++ enums
- `initialize()`, `run()`, `register()` provide the lifecycle API

### 3. Combined Archive (`libbenchmark_combined.a`)

Built via CMake, this static archive contains:
- libbenchmark (the C++ benchmark library)
- The C adapter (compiled with the same compiler as libbenchmark)

This ensures all C++ symbols use the same ABI.

## Build Flow

```
1. cmake builds libbenchmark + odin_api.cc → libbenchmark_combined.a
2. odin build compiles benchmark.odig + links against libbenchmark_combined.a
3. odin test runs the test binary
```

## Design Decisions

1. **Opaque pointers**: State and Benchmark are `rawptr` in Odin, wrapped in typed structs
2. **Fluent API**: All Benchmark configuration methods return self for chaining
3. **C callback**: register() uses a trampoline that bridges Odin proc to C function pointer
4. **Combined archive**: Avoids ABI mismatches between compilers
