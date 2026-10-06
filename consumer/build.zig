// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md in the parent directory for what that identifier covers.

//! A package that consumes `proj` from outside.
//!
//! This exists to prove one thing: that a dependent needs only
//! `dep.module("proj")` and gets a working, correctly linked library. If the
//! facade module stopped carrying the compiled C, stopped carrying libm, libdl or
//! pthreads where the target needs them, stopped putting `src/` on the translated
//! header's include path, or if the translated header stopped matching the
//! compiled library, this would stop building or stop producing the coordinate
//! below — and nothing inside the library would notice.
//!
//! Run it with `zig build run`. It exits non-zero if the coordinate disagrees with
//! the independent known answer it states, so it is a check and not a demo.
//!
//! It deliberately does not ask for `dep.artifact("proj")`. A dependent that had to
//! link the archive as well as import the module would prove nothing about the
//! module being self-contained, and would hide a library that forgot to declare its
//! own linkage.
//!
//! It also declares no `link_libc`. The C requirement belongs to the library module,
//! which carries it; a dependent states its own, and this program needs nothing
//! beyond what the library already brings. Adding it here would mask a library that
//! forgot to.
//!
//! `-Dlinkage` and `-Druntime`
//! --------------------------
//! Both are forwarded to the dependency under the names the library declares them,
//! so the same question can be asked of every delivery and of both dispatch routes:
//!
//!     zig build run                            the default: static, linked
//!     zig build run -Dlinkage=dynamic          the shared object, linked
//!     zig build run -Druntime=true             nothing linked; the program names a
//!                                              provider with an explicit load
//!
//! They are forwarded unconditionally rather than only when passed, so this file and
//! the library cannot disagree about their defaults: this file states `static` and
//! `false`, which is what `build.zig` defaults to.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // The library's own defaults, restated. `build.zig` refuses to configure when
    // the manifest version and the compiled upstream version disagree, so a value
    // here cannot drift into describing a different release.
    const linkage = b.option(
        std.builtin.LinkMode,
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

    // PROJ's datum data is not compiled into the library. `build.zig:59-64`
    // states that `EMBED_RESOURCE_FILES` is off upstream, so nothing carries
    // `proj.db`, and PROJ's own resolution order is `PROJ_DATA` first
    // (`src/filemanager.cpp:1119-1127`). Without this the program below runs,
    // finds no database, and stops at `error.NoDatabase` before it reaches a
    // coordinate.
    //
    // The directory and the step that fills it both come from the dependency,
    // so the consumer learns them the same way it learns the artifact. This is
    // `dep.builder`, the build graph the dependency ran in; `getInstallPath`
    // and `getInstallStep` are the library's own accessors
    // (`lib/std/Build.zig:1928` and `:1119`).
    const dep_builder = dep.builder;
    run_exe.step.dependOn(dep_builder.getInstallStep());
    run_exe.setEnvironmentVariable("PROJ_DATA", dep_builder.getInstallPath(.prefix, "share/proj"));
    // `PROJ_NETWORK=OFF` is read as off unless the value is `ON`, `YES` or
    // `TRUE` (`src/filemanager.cpp:1994-1998`), so "no network" is a property
    // of this gate rather than of the machine. `PROJ_USER_WRITABLE_DIRECTORY`
    // is left alone, exactly as the library's own run steps leave it.
    run_exe.setEnvironmentVariable("PROJ_NETWORK", "OFF");
    if (b.args) |args| run_exe.addArgs(args);
    const run_step = b.step("run", "Build and run the consumer program");
    run_step.dependOn(&run_exe.step);
}