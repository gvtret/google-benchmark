// Build configuration for Odin bindings to google-benchmark.
//
// Build with:
//   odin build src -out:benchmark_test
//
// Or link against libbenchmark_combined.a and run tests.

package build

import "core:os"
import "core:fmt"

main :: proc() {
    fmt.println("Google Benchmark Odin Bindings")
    fmt.println("Build with: odin build src -out:benchmark_test")
}
