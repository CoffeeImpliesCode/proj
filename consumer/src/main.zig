// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md in the parent directory for what that identifier covers.

//! Consumes the `proj` package the way an outside project would.
//!
//! Everything here goes through the published surface only: `b.dependency` and
//! `dep.module("proj")` in `../build.zig`, and `@import("proj")` here. No path
//! reaches into the library's own tree, nothing is imported from its tests or its
//! examples, and the archive is never linked a second time by hand. If this builds
//! and prints the answer below, the module contract is real rather than a path that
//! works only inside the fork.
//!
//! ## The task, and the answer it is checked against
//!
//! The program does the one thing most callers of a projection library do: turn a
//! longitude and a latitude into projected metres. It uses Philadelphia, and the
//! expected value is **not** read back out of the library. It is
//!
//!     x = R * lambda,   y = R * ln(tan(pi/4 + phi/2)),   R = 6378137 m
//!
//! from the EPSG Guidance Note 7-2 description of EPSG:3857's "Popular
//! Visualisation Pseudo Mercator" method, transcribed into
//! `../testdata/webmercator-known-answers.md` with its exact decimal expansion and
//! its derivation. PROJ computes the same function as `k0 * asinh(tan(phi))`
//! (`../src/projections/merc.cpp:24-29`), which is the same function written
//! through a different identity, so agreement is evidence and not restatement.
//!
//! **The axis order matters and is the authority's.** `EPSG:4326` declares
//! GeodeticLatitude first, so `coord(40.0, -75.0, 0, 0)` is *latitude* 40 and
//! *longitude* −75. Upstream's own example does the same
//! (`../examples/EPSG_4326_to_32631.cpp:74-79`). The tolerance is 1e-6 m and the
//! argument for it is in `../tests.zig` and in the audit record.
//!
//! ## Runtime-loaded builds
//!
//! `zig build run -Druntime=true` links nothing native into the module, so the
//! provider has to be named before this program can ask the library anything:
//!
//!     zig build run -Druntime=true -- --provider /path/to/libproj.so.25
//!
//! or the same path in `PROJ_TEST_PROVIDER`. With neither, it says so and exits
//! non-zero rather than running against nothing. There is no fallback from one
//! channel to the other and no silent default. The default linked build needs
//! neither and reads neither, so the program below is the same program in both
//! configurations.
//!
//! The provider must be named **before any native call**, and it is: the only thing
//! this program does before `load` is read its arguments and its environment.

const std = @import("std");
const proj = @import("proj");

/// A shared object exporting the 292 `proj_*` entry points `src/proj.h` declares.
const provider_variable = "PROJ_TEST_PROVIDER";

/// Where the build installed `proj.db`. Read rather than guessed: upstream resolves
/// this variable itself (`../src/filemanager.cpp:1113-1132`), and this package never
/// embeds a build-host path.
const data_variable = "PROJ_DATA";

/// EPSG:3857's spherical Mercator radius, in metres.
const mercator_radius_m: f64 = 6378137.0;

const radians_per_degree: f64 = std.math.pi / 180.0;

/// The tolerance the comparison uses, in metres.
///
/// Half of nothing: 1e-6 m against numbers near 8.3e6, where one ulp of a double is
/// about 9.3e-10 m. The two computations differ only in the transcendental used
/// (`asinh` versus `ln` of a `tan`) and in the order of the multiplications, so a
/// few of those roundings accumulate to a few times 1e-9 m and the 1e-6 has three
/// orders of magnitude of headroom. It is also four orders of magnitude finer than
/// the 1 m precision the EPSG method itself publishes. The full argument is in
/// `../testdata/webmercator-known-answers.md` and in `../tests.zig`.
const tolerance_m: f64 = 1e-6;

/// Philadelphia, in degrees. Latitude first, because that is what `EPSG:4326`
/// declares and therefore what the operation built from it takes.
const latitude_deg: f64 = 40.0;
const longitude_deg: f64 = -75.0;

/// The published answer, in metres. Computed here from the closed form so that the
/// program checks its own arithmetic as well as PROJ's.
fn closedForm(lon_deg: f64, lat_deg: f64) [2]f64 {
    const lam = lon_deg * radians_per_degree;
    const phi = lat_deg * radians_per_degree;
    return .{
        mercator_radius_m * lam,
        // `@as(f64, 4)`: `std.math.pi / 4` alone is a comptime_float divided by
        // a comptime_int, which Zig 0.16.0 rejects as an ambiguous coercion.
        mercator_radius_m * @log(std.math.tan(std.math.pi / @as(f64, 4) + phi / 2)),
    };
}

/// Assert that `got` is within `tolerance` of `want`, naming both when it is not.
fn expectNear(want: f64, got: f64, tolerance: f64, what: []const u8) !void {
    if (std.math.approxEqAbs(f64, want, got, tolerance)) return;
    // `{e:.3}`, not C's `{d:.3e}`: Zig 0.16.0 names the scientific mode `e`
    // (`lib/std/fmt.zig:63`), and `{d:.3e}` parses the `e` as an extraneous
    // trailing character (`lib/std/fmt.zig:138`).
    std.debug.print(
        "consumer: {s}: expected {d:.6}, got {d:.6}, difference {e:.3} m, tolerance {e:.3} m\n",
        .{ what, want, got, @abs(got - want), tolerance },
    );
    return error.UnexpectedResult;
}

/// Which native library to open, or null in a linked build.
///
/// An explicit `--provider` wins over the environment variable, so a caller can
/// point this program at a different provider without changing the environment of
/// the whole run. Neither channel falls back to the other: an explicit path is used
/// or the run fails.
fn resolveProvider(
    args: []const [:0]const u8,
    environ: *const std.process.Environ.Map,
) !?[]const u8 {
    if (!proj.runtime_loaded) return null;

    var named: ?[]const u8 = null;
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        if (std.mem.eql(u8, args[index], "--provider")) {
            if (index + 1 >= args.len) {
                std.debug.print("consumer: --provider needs a path\n", .{});
                return error.MissingProvider;
            }
            index += 1;
            named = args[index];
        } else if (std.mem.startsWith(u8, args[index], "--provider=")) {
            named = args[index]["--provider=".len..];
        } else {
            std.debug.print("consumer: unknown argument '{s}'\n", .{args[index]});
            return error.UnknownArgument;
        }
    }
    if (named == null) named = environ.get(provider_variable);
    const path = named orelse {
        std.debug.print(
            "consumer: this is a runtime-loading build, so nothing native is " ++
                "linked into the module. Pass --provider /path/to/libproj.so.25, " ++
                "or set {s}. There is no fallback and no default.\n",
            .{provider_variable},
        );
        return error.MissingProvider;
    };
    if (path.len == 0) {
        std.debug.print("consumer: the provider path is empty\n", .{});
        return error.MissingProvider;
    }
    return path;
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);

    // Before any native call. Nothing below this line has touched PROJ.
    const provider = try resolveProvider(args, init.environ_map);
    if (provider) |path| try proj.load(.{ .path = path });

    var threaded: std.Io.Threaded = .init(std.heap.page_allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();
    var out_buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(io, &out_buffer);
    const w = &stdout.interface;

    if (proj.runtime_loaded) {
        try w.print("runtime-loaded: {s}\n", .{proj.loadedSource().?.path});
    } else {
        try w.writeAll("linked: proj_* resolved at link time\n");
    }

    const reported = proj.version();
    try w.print(
        "library: PROJ {d}.{d}.{d}\n",
        .{ reported.major, reported.minor, reported.patch },
    );

    const ctx = try proj.Context.create();
    defer ctx.destroy();

    // No network, so nothing below can be satisfied by fetching a grid. That is what
    // makes a datum shift's refusal a data statement rather than a network one.
    //
    // **The return value is the previous setting, not an acceptance flag.**
    // `proj_context_set_enable_network` answers what the network was *before* it
    // changed anything (`src/proj.h:555`), so when this run already has the
    // network off the answer is false and says nothing about the request. The
    // read-back is the check; `../smoke.zig` and `../tests.zig` do the same.
    const network_was = ctx.setNetworkEnabled(false);
    _ = network_was;
    if (ctx.networkEnabled()) {
        std.debug.print("consumer: the network is still enabled after it was turned off\n", .{});
        return error.UnexpectedResult;
    }

    if (init.environ_map.get(data_variable)) |data| {
        if (data.len != 0) {
            // `proj_context_set_database_path` takes the path to the database
            // *file*: `DatabaseContext::Private::open` hands `databasePath`
            // straight to `sqlite3_open_v2` (`src/iso19111/factory.cpp:1243-1270`)
            // and appends nothing. `PROJ_DATA` names the directory, so the file
            // name is joined onto it here.
            const database = try std.fs.path.joinZ(arena, &.{ data, "proj.db" });
            if (!ctx.setDatabasePath(database, null, null)) {
                std.debug.print("consumer: proj_context_set_database_path refused {s}\n", .{data});
                return error.DatabaseRefused;
            }
        }
    }
    const resolved = (try ctx.databasePath(arena)) orelse {
        std.debug.print("consumer: PROJ resolved no database path\n", .{});
        return error.NoDatabase;
    };
    try w.print("database: {s}\n", .{resolved});

    // ---- The check ---------------------------------------------------------
    const operation = try ctx.crsToCrs("EPSG:4326", "EPSG:3857", null);
    defer operation.destroy();

    const oracle = closedForm(longitude_deg, latitude_deg);
    const out = operation.trans(.fwd, proj.coord(latitude_deg, longitude_deg, 0.0, 0.0));

    if (proj.isErrorCoordinate(out)) {
        std.debug.print(
            "consumer: the transform returned the error coordinate, errno {d}\n",
            .{operation.errno()},
        );
        return error.TransformationFailed;
    }

    try w.print(
        "comparing EPSG:4326 -> EPSG:3857 at {d} deg N, {d} deg E\n",
        .{ latitude_deg, longitude_deg },
    );
    try w.print(
        "  closed form (EPSG Guidance Note 7-2): x = {d:.6} m, y = {d:.6} m\n",
        .{ oracle[0], oracle[1] },
    );
    try w.print(
        "  through dep.module(\"proj\")        : x = {d:.6} m, y = {d:.6} m\n",
        .{ out.v[0], out.v[1] },
    );
    try expectNear(oracle[0], out.v[0], tolerance_m, "easting");
    try expectNear(oracle[1], out.v[1], tolerance_m, "northing");

    // The published decimal expansion of the same number, so the comparison above
    // can be audited against `../testdata/webmercator-known-answers.md` by hand.
    try expectNear(-8348961.809495518, out.v[0], tolerance_m, "published easting");
    try expectNear(4865942.279503176, out.v[1], tolerance_m, "published northing");
    // `{e}`, not C's `{d:.3e}`: Zig 0.16.0 names the scientific mode `e`, and
    // `lib/std/fmt.zig:982` shows its precision spelled `{e:.5}`.
    try w.print("  difference: {e:.3} m easting, {e:.3} m northing\n", .{
        @abs(out.v[0] - oracle[0]),
        @abs(out.v[1] - oracle[1]),
    });
    try w.print("  tolerance:  {e:.3} m\n", .{tolerance_m});

    // The same operation, run backwards, is a round trip and proves nothing about
    // correctness. It is here only to show the inverse route reaches a caller through
    // the same module, and it is labelled as what it is.
    const back = operation.trans(.inv, proj.coord(out.v[0], out.v[1], 0.0, 0.0));
    if (proj.isErrorCoordinate(back)) return error.TransformationFailed;
    try expectNear(latitude_deg, back.v[0], 1e-11, "round-trip latitude");
    try expectNear(longitude_deg, back.v[1], 1e-11, "round-trip longitude");
    try w.print(
        "  (round trip, self-agreement only: {d:.12} deg N, {d:.12} deg E)\n",
        .{ back.v[0], back.v[1] },
    );

    // A CRS the caller can name, read back out of the registry the build installed.
    const geographic = try ctx.createFromDatabase("EPSG", "4326", .crs, false, null);
    defer geographic.destroy();
    try w.print(
        "registry: {s}:{s} is {s}\n",
        .{ geographic.idAuthName(0).?, geographic.idCode(0).?, geographic.name().? },
    );

    try w.flush();
    proj.cleanup();
}