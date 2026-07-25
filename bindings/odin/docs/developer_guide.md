# Developer Guide — Odin Bindings

## Project Structure

```
bindings/odin/
├── src/
│   ├── odin_api.h         # C adapter header
│   ├── odin_api.cc        # C adapter implementation
│   ├── benchmark.odig     # Odin API module
│   └── benchmark_test.odig # Tests
├── docs/
│   ├── architecture.md
│   ├── developer_guide.md
│   └── user_guide.md
├── examples/              # Usage examples
├── build.odin             # Build configuration
└── README.md              # Quick reference
```

## Adding a New Binding Function

1. Add declaration to `odin_api.h`
2. Implement in `odin_api.cc`
3. Add wrapper in `benchmark.odig`
4. Add test in `benchmark_test.odig`

## Running Tests

```bash
cd bindings/odin
odin build src -out:benchmark_test
./benchmark_test
```

## Build System

The build uses CMake to compile libbenchmark and the C adapter into a combined static archive. Odin then links against this archive.

```bash
cmake -S . -B cmake-build -DCMAKE_BUILD_TYPE=Release
cmake --build cmake-build --parallel
odin build src -out:benchmark_test
```

## Code Style

- Odin uses snake_case for procedures and variables
- Types use PascalCase (State, Benchmark, TimeUnit)
- Foreign imports use `foreign import "odin_api"`
- C strings are `cstring` type in Odin
