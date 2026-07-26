// Placeholder entry point for `odin run .` at the bindings/odin root.
// It intentionally does not build or run benchmarks itself — see
// examples/basic.odin for a real, runnable benchmark program, and
// docs/developer_guide.md for the full build/test/run commands.
package build

import "core:fmt"

main :: proc() {
    fmt.println("Google Benchmark Odin Bindings")
    fmt.println("Build with: odin run examples/")
}
