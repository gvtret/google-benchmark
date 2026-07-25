// Build system for Zig bindings to google-benchmark.
//
// Usage:
//   zig build              — build library (runs cmake)
//   zig build test         — run unit tests
//   zig build run          — run example Zig benchmarks
//   zig build -Dclang=true <step>  — use Clang + libc++ instead of GCC + libstdc++

const std = @import("std");

// Zig's bundled `lld` cannot resolve system C++ libraries the way
// `g++`/`clang++` do, so the `test` and `run` steps below link the static
// C++ runtime archives directly as object files, located via
// `<compiler> -print-file-name=...` instead of a hardcoded path/version.
// Two runtimes are supported (see the `-Dclang` option below):
//   - GNU (default): g++ + static libstdc++/libsupc++/libgcc/libgcc_eh.
//   - LLVM (-Dclang=true): clang++ + static libc++/libc++abi/libunwind
//     (`-stdlib=libc++`), verified to compile, link, and run correctly.
// Only `test`/`run` need any of this — a plain `zig build` must keep
// working on machines with neither compiler's static archives installed
// (e.g. macOS, where the GNU archives specifically don't exist — see
// docs/architecture.md#build-system-flow), so failures here are logged,
// not fatal; `test`/`run` fail later with a clear missing-file error.
const Toolchain = struct {
    cxx: []const u8,
    stdlib_flag: []const u8,
    // Full resolved paths, one per archive. NOT necessarily all in the same
    // directory: e.g. on Ubuntu's stock LLVM-20 packages, `libc++.a` and
    // `libunwind.a` land in /lib/x86_64-linux-gnu/ while `libc++abi.a`
    // lands in /usr/lib/llvm-20/lib/ — each must be located independently.
    archive_paths: []const []const u8,
};

fn detectToolchain(b: *std.Build, use_clang: bool) Toolchain {
    const cxx: []const u8 = if (use_clang) "clang++" else "g++";
    const stdlib_flag: []const u8 = if (use_clang) "-stdlib=libc++" else "";
    const archives: []const []const u8 = if (use_clang)
        &.{ "libc++.a", "libc++abi.a", "libunwind.a" }
    else
        &.{ "libstdc++.a", "libsupc++.a", "libgcc.a", "libgcc_eh.a" };

    var archive_paths = std.ArrayList([]const u8).initCapacity(b.allocator, archives.len) catch @panic("OOM");
    for (archives) |name| {
        var argv = std.ArrayList([]const u8).init(b.allocator);
        argv.append(cxx) catch @panic("OOM");
        if (stdlib_flag.len > 0) argv.append(stdlib_flag) catch @panic("OOM");
        argv.append(b.fmt("-print-file-name={s}", .{name})) catch @panic("OOM");

        const result = std.process.Child.run(.{
            .allocator = b.allocator,
            .argv = argv.items,
        }) catch {
            std.log.warn("could not run '{s} -print-file-name={s}' — " ++
                "'zig build test'/'zig build run' need {s} with its static " ++
                "C++ runtime installed", .{ cxx, name, cxx });
            archive_paths.append(name) catch @panic("OOM");
            continue;
        };
        const path = std.mem.trimRight(u8, result.stdout, "\n");
        archive_paths.append(path) catch @panic("OOM");
    }
    return .{ .cxx = cxx, .stdlib_flag = stdlib_flag, .archive_paths = archive_paths.items };
}

// Links a Zig executable/test binary against the combined archive and the
// static C++ runtime, the same way for both the `test` and `run` steps.
fn linkCombinedArchive(
    b: *std.Build,
    compile: *std.Build.Step.Compile,
    cmake_step: *std.Build.Step,
    lib_dir: []const u8,
    toolchain: Toolchain,
) void {
    compile.addObjectFile(.{ .cwd_relative = b.fmt("{s}/libbenchmark_combined.a", .{lib_dir}) });
    for (toolchain.archive_paths) |path| {
        compile.addObjectFile(.{ .cwd_relative = path });
    }
    compile.linkSystemLibrary("pthread");
    compile.linkSystemLibrary("m");
    compile.step.dependOn(cmake_step);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const use_clang = b.option(
        bool,
        "clang",
        "Build libbenchmark with Clang + libc++ instead of the system default (GCC + libstdc++). Both are verified to work.",
    ) orelse false;
    const toolchain = detectToolchain(b, use_clang);
    if (use_clang) std.log.info("Building with {s} + libc++", .{toolchain.cxx});

    const benchmark_path = b.option([]const u8, "benchmark_path", "Path to pre-built combined archive directory") orelse "";

    // ---- CMake step ----
    // A separate build directory per toolchain: reconfiguring the same
    // CMake cache with a different CMAKE_CXX_COMPILER breaks CMake's
    // GoogleTest dependency check (confirmed: switching -Dclang without
    // wiping the previous build dir fails with a "Did not find Google
    // Test sources!" error even though BENCHMARK_ENABLE_TESTING=OFF is
    // passed again) — so GCC and Clang builds never share one, and
    // switching back and forth doesn't require manually cleaning.
    const build_dir_name = if (use_clang) "cmake-build-clang" else "cmake-build";
    const cmake_step = b.step("cmake", "Build combined archive via CMake");
    var lib_dir: []const u8 = undefined;
    if (benchmark_path.len > 0) {
        lib_dir = benchmark_path;
    } else {
        var configure_args = std.ArrayList([]const u8).init(b.allocator);
        configure_args.appendSlice(&.{
            "cmake", "-S", ".", "-B", build_dir_name,
            "-DBENCHMARK_ENABLE_TESTING=OFF",
            "-DBENCHMARK_ENABLE_LTO=OFF",
            "-DBENCHMARK_ENABLE_WERROR=OFF",
            "-DCMAKE_BUILD_TYPE=Release",
        }) catch @panic("OOM");
        if (use_clang) {
            configure_args.appendSlice(&.{
                "-DCMAKE_CXX_COMPILER=clang++",
                b.fmt("-DCMAKE_CXX_FLAGS={s}", .{toolchain.stdlib_flag}),
                b.fmt("-DCMAKE_EXE_LINKER_FLAGS={s}", .{toolchain.stdlib_flag}),
                b.fmt("-DCMAKE_SHARED_LINKER_FLAGS={s}", .{toolchain.stdlib_flag}),
            }) catch @panic("OOM");
        }
        const cmake_configure = b.addSystemCommand(configure_args.items);
        const cmake_build = b.addSystemCommand(&.{
            "cmake", "--build", build_dir_name, "--config", "Release", "--parallel",
        });
        cmake_build.step.dependOn(&cmake_configure.step);
        cmake_step.dependOn(&cmake_build.step);
        lib_dir = build_dir_name;
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
    linkCombinedArchive(b, native_tests, cmake_step, lib_dir, toolchain);

    const run_native_tests = b.addRunArtifact(native_tests);

    // C++ adapter smoke test (test_adapter.cc): a lower-level sanity check
    // of zig_api.h/cc's C ABI surface, independent of the Zig module.
    var compile_test_args = std.ArrayList([]const u8).init(b.allocator);
    compile_test_args.appendSlice(&.{
        "zig", "c++", "-std=c++17", "-fno-exceptions",
        "-I", "src", "-I", "../../include",
    }) catch @panic("OOM");
    if (toolchain.stdlib_flag.len > 0) compile_test_args.append(toolchain.stdlib_flag) catch @panic("OOM");
    compile_test_args.appendSlice(&.{
        "test_adapter.cc",
        b.fmt("-L{s}", .{lib_dir}),
        "-lbenchmark_combined",
    }) catch @panic("OOM");
    for (toolchain.archive_paths) |path| {
        compile_test_args.append(path) catch @panic("OOM");
    }
    compile_test_args.appendSlice(&.{ "-lpthread", "-lm", "-o", "test_adapter" }) catch @panic("OOM");
    const compile_test = b.addSystemCommand(compile_test_args.items);
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
    linkCombinedArchive(b, exe, cmake_step, lib_dir, toolchain);

    const run_benchmarks = b.addRunArtifact(exe);
    if (b.args) |args| run_benchmarks.addArgs(args);

    const run_step = b.step("run", "Run example benchmarks");
    run_step.dependOn(&run_benchmarks.step);
}
