// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md in the parent directory for what that identifier covers.

//! Exercises the `proj` dependency through its published module.
//! The consumer links no native artifact or source from the package.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Forward linkage/runtime options with defaults aligned to the dependency.
    const linkage = b.option(
        std.lang.LinkMode,
        "linkage",
        "Forwarded to the library: which native artifact it delivers. The " ++
            "default is the library's own default, a static archive.",
    ) orelse .static;
    const runtime_loaded = b.option(
        bool,
        "runtime",
        "Forwarded to the library: resolve the native entry points at run time " ++
            "instead of linking them. The default is the library's own default, " ++
            "the linked route.",
    ) orelse false;

    const dep = b.dependency("proj", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
        .runtime = runtime_loaded,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("proj", dep.module("proj"));

    const exe = b.addExecutable(.{
        .name = "proj-consumer",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    run_exe.has_side_effects = true;

    // Run from the dependency's installed data directory.
    const dep_builder = dep.builder;
    run_exe.step.dependOn(dep_builder.getInstallStep());
    run_exe.setCwd(.{ .relative = .{ .base = .install_prefix, .sub_path = "share/proj" } });
    run_exe.setEnvironmentVariable("PROJ_DATA", ".");
    // Disable networking so results do not depend on external grids.
    run_exe.setEnvironmentVariable("PROJ_NETWORK", "OFF");
    run_exe.addPassthruArgs();
    const run_step = b.step("run", "Build and run the consumer program");
    run_step.dependOn(&run_exe.step);
}
