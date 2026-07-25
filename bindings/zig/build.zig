// Build system for Zig bindings to google-benchmark.
//
// Usage:
//   zig build              — build library (runs cmake)
//   zig build test         — run unit tests
//   zig build run          — run example Zig benchmarks

const std = @import("std");

// Zig's bundled `lld` cannot resolve system C++ libraries the way
// `g++`/`clang++` do, so the `test` and `run` steps below link the static
// libstdc++/libgcc archives directly as object files. Ask g++ where they
// live instead of hardcoding a GCC version, so this works with whichever
// GCC major version is installed. Only `test`/`run` need this — a plain
// `zig build` must keep working on machines without g++ (e.g. macOS), so
// failures here are logged, not fatal; `test`/`run` fail later with a clear
// missing-file error instead.
fn gccLibDir(b: *std.Build) []const u8 {
    const result = std.process.Child.run(.{
        .allocator = b.allocator,
        .argv = &.{ "g++", "-print-file-name=libstdc++.a" },
    }) catch {
        std.log.warn("could not run 'g++ -print-file-name=libstdc++.a' — " ++
            "'zig build test'/'zig build run' need g++ with static " ++
            "libstdc++/libgcc archives installed", .{});
        return "";
    };
    const path = std.mem.trimRight(u8, result.stdout, "\n");
    return std.fs.path.dirname(path) orelse "";
}

// Links a Zig executable/test binary against the combined archive and the
// static GNU C++ runtime, the same way for both the `test` and `run` steps.
fn linkCombinedArchive(
    b: *std.Build,
    compile: *std.Build.Step.Compile,
    cmake_step: *std.Build.Step,
    lib_dir: []const u8,
    gcc_lib: []const u8,
) void {
    compile.addObjectFile(.{ .cwd_relative = b.fmt("{s}/libbenchmark_combined.a", .{lib_dir}) });
    compile.addObjectFile(.{ .cwd_relative = b.fmt("{s}/libstdc++.a", .{gcc_lib}) });
    compile.addObjectFile(.{ .cwd_relative = b.fmt("{s}/libsupc++.a", .{gcc_lib}) });
    compile.addObjectFile(.{ .cwd_relative = b.fmt("{s}/libgcc.a", .{gcc_lib}) });
    compile.addObjectFile(.{ .cwd_relative = b.fmt("{s}/libgcc_eh.a", .{gcc_lib}) });
    compile.linkSystemLibrary("pthread");
    compile.linkSystemLibrary("m");
    compile.step.dependOn(cmake_step);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const gcc_lib = gccLibDir(b);

    const benchmark_path = b.option([]const u8, "benchmark_path", "Path to pre-built combined archive directory") orelse "";

    // ---- CMake step ----
    const cmake_step = b.step("cmake", "Build combined archive via CMake");
    var lib_dir: []const u8 = undefined;
    if (benchmark_path.len > 0) {
        lib_dir = benchmark_path;
    } else {
        const cmake_configure = b.addSystemCommand(&.{
            "cmake", "-S", ".", "-B", "cmake-build",
            "-DBENCHMARK_ENABLE_TESTING=OFF",
            "-DBENCHMARK_ENABLE_LTO=OFF",
            "-DBENCHMARK_ENABLE_WERROR=OFF",
            "-DCMAKE_BUILD_TYPE=Release",
        });
        const cmake_build = b.addSystemCommand(&.{
            "cmake", "--build", "cmake-build", "--config", "Release", "--parallel",
        });
        cmake_build.step.dependOn(&cmake_configure.step);
        cmake_step.dependOn(&cmake_build.step);
        lib_dir = "cmake-build";
    }

    // ---- Zig module ----
    const benchmark_module = b.addModule("benchmark", .{
        .root_source_file = b.path("src/benchmark.zig"),
    });
    benchmark_module.addIncludePath(b.path("src"));

    // ---- Tests ----
    // Native Zig unit tests (src/benchmark_test.zig), exercising the public
    // `benchmark` module directly.
    // `addRunArtifact` on a test binary defaults to `.mode = .server`,
    // which makes the build system talk a structured IPC protocol with the
    // test binary over its stdout fd (`--listen=-`). `benchmark.run()`
    // writes raw benchmark tables straight to that same fd via the linked
    // C++ library, corrupting the protocol framing and deadlocking `zig
    // build test` forever (confirmed: identical test content runs fine and
    // fast under a plain `zig test` invocation, which doesn't use this
    // protocol). Forcing `.mode = .simple` — same bundled runner file, just
    // without the handshake — makes `addRunArtifact` skip the protocol
    // entirely; the test binary runs like a normal process instead. No
    // structured per-test summary, but the step still fails on nonzero
    // exit/crash.
    const native_tests = b.addTest(.{
        .root_source_file = b.path("src/benchmark_test.zig"),
        .target = target,
        .optimize = optimize,
        .test_runner = .{
            .path = .{ .cwd_relative = b.fmt("{s}/compiler/test_runner.zig", .{b.graph.zig_lib_directory.path.?}) },
            .mode = .simple,
        },
    });
    native_tests.root_module.addImport("benchmark", benchmark_module);
    linkCombinedArchive(b, native_tests, cmake_step, lib_dir, gcc_lib);

    const run_native_tests = b.addRunArtifact(native_tests);

    // C++ adapter smoke test (test_adapter.cc): a lower-level sanity check
    // of zig_api.h/cc's C ABI surface, independent of the Zig module.
    const compile_test = b.addSystemCommand(&.{
        "zig", "c++", "-std=c++17", "-fno-exceptions",
        "-I", "src", "-I", "../../include",
        "test_adapter.cc",
        b.fmt("-L{s}", .{lib_dir}),
        "-lbenchmark_combined",
        b.fmt("{s}/libstdc++.a", .{gcc_lib}),
        b.fmt("{s}/libsupc++.a", .{gcc_lib}),
        b.fmt("{s}/libgcc.a", .{gcc_lib}),
        "-lpthread", "-lm",
        "-o", "test_adapter",
    });
    compile_test.step.dependOn(cmake_step);

    const run_adapter_test = b.addSystemCommand(&.{"./test_adapter"});
    run_adapter_test.step.dependOn(&compile_test.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_native_tests.step);
    test_step.dependOn(&run_adapter_test.step);

    // ---- Build step ----
    _ = b.step("build", "Build the library");

    // ---- Run step ----
    const exe = b.addExecutable(.{
        .name = "run_benchmarks",
        .root_source_file = b.path("examples/basic.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("benchmark", benchmark_module);
    linkCombinedArchive(b, exe, cmake_step, lib_dir, gcc_lib);

    const run_benchmarks = b.addRunArtifact(exe);
    if (b.args) |args| run_benchmarks.addArgs(args);

    const run_step = b.step("run", "Run example benchmarks");
    run_step.dependOn(&run_benchmarks.step);
}
