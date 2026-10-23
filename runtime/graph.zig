// SPDX-License-Identifier: MIT
//
// Fork-authored. `FORK-LICENSE.md` records the owner's authorization of that
// grant for this file, and `../COPYING` holds upstream's own MIT-style text.

//! Assemble a target-specific runtime dispatch from its translated C module.
//! Runtime builds import the dispatch and must not link the C archive.

const std = @import("std");

/// Translate-C step used to generate a runtime module.
pub const TranslateModule = *std.Build.Step.TranslateC;

/// Namespace passed to `runtime/sync.c`; it must match `runtime/library.zig`.
/// Give each SDK copy in one program a distinct prefix.
const sync_prefix = "proj_rt";

/// Translated C-library externs kept direct; empty because these headers declare none.
const libc_noise = "";

/// Provider exports that may be absent; empty because this header has no conditional functions.
const provider_optional = "";

/// Provider exports not required by this facade; empty for this translated header.
const provider_excluded = "";

/// Adds the loader core module for linked builds.
/// It provides `LoadSource` and `LoadError` without adding loader code.
pub fn createCoreModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path("runtime/loader.zig"),
        .target = target,
        .optimize = optimize,
        // The Unix backend calls `dlopen`, which is libc. Nothing in this module
        // is compiled into a linked build, so this costs nothing there.
        .link_libc = true,
    });
}

/// Adds a runtime-loaded C module for this target and translation.
pub fn createModule(
    b: *std.Build,
    translate: TranslateModule,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const core = createCoreModule(b, target, optimize);

    const library = b.createModule(.{
        .root_source_file = b.path("runtime/library.zig"),
        .target = target,
        .optimize = optimize,
    });
    library.addImport("rt", core);

    return createDispatchModule(b, translate, target, optimize, core, library);
}

/// Generated dispatch and patched native translation.
const GeneratedSources = struct {
    native: std.Build.LazyPath,
    dispatch: std.Build.LazyPath,
};

fn createDispatchModule(
    b: *std.Build,
    translate: TranslateModule,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    core: *std.Build.Module,
    library: *std.Build.Module,
) *std.Build.Module {
    const sources = generateDispatch(b, translate, target);

    const dispatch = b.createModule(.{
        .root_source_file = sources.dispatch,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    dispatch.addImport("rt", core);
    dispatch.addImport("library", library);

    // Re-exported declarations keep their nominal identity; c_routed redirects
    // members nested in translated types to the dispatch.
    const native = b.createModule(.{
        .root_source_file = sources.native,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    native.addImport("c_routed", dispatch);
    dispatch.addImport("c_native", native);
    dispatch.addCSourceFiles(.{
        .files = &.{"runtime/sync.c"},
        .flags = &.{b.fmt("-DRT_SYNC_PREFIX={s}", .{sync_prefix})},
        .language = .c,
    });
    return dispatch;
}

/// Runs the host generator on this target's translation.
/// The target triple keeps generated programs distinct in multi-target builds.
fn generateDispatch(
    b: *std.Build,
    translate: TranslateModule,
    target: std.Build.ResolvedTarget,
) GeneratedSources {
    const generator = b.addExecutable(.{
        .name = b.fmt("proj-runtime-generate-{s}", .{
            target.result.zigTriple(b.allocator) catch @panic("unspellable target"),
        }),
        .root_module = b.createModule(.{
            .root_source_file = b.path("runtime/generate.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });

    const run = b.addRunArtifact(generator);
    run.addArg("--library");
    run.addArg("proj");
    run.addArg("--translate");
    run.addFileArg(translate.getOutput());
    if (libc_noise.len != 0) {
        run.addArg("--noise");
        run.addArg(libc_noise);
    }
    if (provider_optional.len != 0) {
        run.addArg("--optional");
        run.addArg(provider_optional);
    }
    if (provider_excluded.len != 0) {
        run.addArg("--exclude");
        run.addArg(provider_excluded);
    }
    run.addArg("--native-output");
    const native_source = run.addOutputFileArg("native.zig");
    run.addArg("--output");
    const dispatch_source = run.addOutputFileArg("dispatch.zig");
    return .{ .native = native_source, .dispatch = dispatch_source };
}
