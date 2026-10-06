// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md for what that identifier covers.

//! A runnable tour of the PROJ facade.
//!
//! `zig build smoke` runs this; `zig build check` compiles it for every cross
//! target without running it. It reaches the library only through
//! `@import("proj")`, the same name a dependent gets from `dep.module("proj")`, so
//! what it proves is about the published module and nothing else.
//!
//! **It is not a test.** It asserts no version, pins no default and compares no
//! corpus: the pinned version is *printed*, which is a fact about the build rather
//! than a check. What it does refuse is a non-finite answer and a missing database,
//! because either means the numbers below would be wrong, and a wrong number printed
//! with a zero exit is worse than no number at all.
//!
//! The coordinate it prints is checked against the independent closed form in
//! `tests.zig` (Fixture A), not here: this file's job is to show the route working
//! end to end, and duplicating the oracle would make two places to keep in step
//! without making the answer any more correct.
//!
//! ## The provider, in a runtime-loading build
//!
//! A build with `-Druntime=true` links nothing native into the module, so this
//! program has to be told which provider to open before it can ask the library
//! anything: `--provider /path/to/libproj.so.25`, or the same path in
//! `PROJ_TEST_PROVIDER`. With neither, it says so and exits non-zero rather than
//! running against nothing. In the default linked build neither is needed and
//! neither is read: `runtime_loaded` is false, so `proj_*` is a direct call and
//! `load` is never called.

const std = @import("std");
const proj = @import("proj");

const provider_variable = "PROJ_TEST_PROVIDER";
const data_variable = "PROJ_DATA";

/// EPSG:3857's spherical Mercator radius, in metres.
///
/// Printed so a reader can see that the easting below is a distance from the
/// central meridian rather than a longitude, and so the two printed degree figures
/// can be recomputed by hand.
const mercator_radius_m: f64 = 6378137.0;

/// The widest easting a spherical Mercator of this radius can produce: half the
/// circumference, `pi * R`. A value beyond that is not a coordinate.
const mercator_limit_m: f64 = std.math.pi * mercator_radius_m;

/// Fail with a message rather than a bare error, so the run says what went wrong.
fn require(condition: bool, comptime message: []const u8) !void {
    if (condition) return;
    std.debug.print("smoke: " ++ message ++ "\n", .{});
    return error.UnexpectedResult;
}

/// Which native library to open, or null in a linked build.
///
/// `--provider` wins over the environment variable, so a caller can point this
/// program at a different provider without changing the environment of the whole
/// run. Neither channel falls back to the other: an explicit path is used or the
/// run fails.
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
                std.debug.print("smoke: --provider needs a path\n", .{});
                return error.MissingProvider;
            }
            index += 1;
            named = args[index];
        } else if (std.mem.startsWith(u8, args[index], "--provider=")) {
            named = args[index]["--provider=".len..];
        } else {
            std.debug.print("smoke: unknown argument '{s}'\n", .{args[index]});
            return error.UnknownArgument;
        }
    }
    if (named == null) named = environ.get(provider_variable);
    const path = named orelse {
        std.debug.print(
            "smoke: this is a runtime-loading build, so nothing native is linked " ++
                "into the module. Pass --provider /path/to/libproj.so.25, or set " ++
                "{s}. Build one with `zig build -Dlinkage=dynamic --prefix <dir>`.\n",
            .{provider_variable},
        );
        return error.MissingProvider;
    };
    if (path.len == 0) {
        std.debug.print("smoke: the provider path is empty\n", .{});
        return error.MissingProvider;
    }
    return path;
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);

    const provider = try resolveProvider(args, init.environ_map);
    if (provider) |path| try proj.load(.{ .path = path });

    var threaded: std.Io.Threaded = .init(std.heap.page_allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();
    var out_buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(io, &out_buffer);
    const w = &stdout.interface;

    // Which route produced everything below is part of the answer: in a linked build
    // every `proj_*` call was a direct call resolved by the linker, and in a
    // runtime-loading one every one went through the table this provider filled.
    if (proj.runtime_loaded) {
        try w.print(
            "runtime-loaded: provider {s}, loadedSource reports the same path\n",
            .{proj.loadedSource().?.path},
        );
    } else {
        try w.writeAll("linked: proj_* resolved at link time\n");
    }

    // -- The version, printed and not checked -------------------------------
    const reported = proj.version();
    try w.print(
        "PROJ {d}.{d}.{d}\n",
        .{ reported.major, reported.minor, reported.patch },
    );
    if (reported.release) |release| try w.print("  release:   {s}\n", .{release});
    if (reported.version) |version| try w.print("  version:   {s}\n", .{version});

    const ctx = try proj.Context.create();
    defer ctx.destroy();

    // The network is off, so "no network" is a property of this run rather than an
    // accident. A grid that is not on disk is then simply not available, and a datum
    // shift that needs one would report that rather than pass the input through.
    //
    // **The return value is the previous setting, not an acceptance flag.**
    // `proj_context_set_enable_network` answers "the network was …" before it
    // changed anything (`src/proj.h:555`), and this build already runs with
    // `PROJ_NETWORK=OFF`, so the answer here is false and would say nothing about
    // whether the request took. The read-back on the next line is the check, and
    // `tests.zig:135-137` says the same thing for the same reason.
    const network_was = ctx.setNetworkEnabled(false);
    _ = network_was;
    try require(!ctx.networkEnabled(), "the network is still enabled after it was turned off");

    // -- The data this build resolved ---------------------------------------
    if (init.environ_map.get(data_variable)) |data| {
        if (data.len != 0) {
            // `proj_context_set_database_path` takes the path to the database
            // *file*: `DatabaseContext::Private::open` hands `databasePath`
            // straight to `sqlite3_open_v2` (`src/iso19111/factory.cpp:1243-1270`)
            // and appends nothing. `PROJ_DATA` names the directory, so the file
            // name is joined onto it here.
            const database = try std.fs.path.joinZ(arena, &.{ data, "proj.db" });
            if (!ctx.setDatabasePath(database, null, null)) {
                std.debug.print("smoke: proj_context_set_database_path refused {s}\n", .{data});
                return error.DatabaseRefused;
            }
        }
    }
    // The path is *copied* rather than borrowed: upstream keeps one slot per context
    // for it and the next call overwrites that slot, so a borrow would be a pointer
    // the next database query invalidates.
    const resolved = (try ctx.databasePath(arena)) orelse {
        std.debug.print("smoke: PROJ resolved no database path\n", .{});
        return error.NoDatabase;
    };
    try w.print("database:   {s}\n", .{resolved});

    if (try ctx.databaseMetadata(arena, "PROJ.VERSION")) |database_version| {
        try w.print("  registry: {s}\n", .{database_version});
    }
    if (try ctx.databaseMetadata(arena, "DATABASE.LAYOUT.VERSION.MAJOR")) |layout_major| {
        try w.print("  layout:   {s}\n", .{layout_major});
    }

    // -- One coordinate ------------------------------------------------------
    //
    // EPSG:4326 is latitude-then-longitude, which is the order the authority
    // declares and therefore the order this operation takes. Philadelphia.
    const operation = try ctx.crsToCrs("EPSG:4326", "EPSG:3857", null);
    defer operation.destroy();

    const out = operation.trans(.fwd, proj.coord(40.0, -75.0, 0.0, 0.0));
    // Upstream's own refusal is four `HUGE_VAL`s (`src/internal.cpp:65-68`), and a
    // coordinate is not one. This is the check that has to be here: everything else
    // below prints, so without it a refusal would be printed as a number.
    if (proj.isErrorCoordinate(out)) {
        std.debug.print(
            "smoke: the transform returned the error coordinate, errno {d}\n",
            .{operation.errno()},
        );
        return error.TransformationFailed;
    }
    // Beyond half the circumference is not a Mercator easting. This is a sanity
    // bound rather than a check of the answer: the answer's correctness is Fixture
    // A's business, and this file deliberately does not restate the oracle.
    try require(
        std.math.isFinite(out.v[0]) and std.math.isFinite(out.v[1]),
        "the transform produced a non-finite coordinate",
    );
    try require(
        @abs(out.v[0]) <= mercator_limit_m,
        "the easting is outside the spherical Mercator domain",
    );

    try w.print(
        "40N 75W  ->  {d:.3} E, {d:.3} N  (EPSG:4326 -> EPSG:3857)\n",
        .{ out.v[0], out.v[1] },
    );
    try w.print(
        "  which is {d:.9} and {d:.9} degrees of arc on a {d:.0} m sphere\n",
        .{
            proj.toDeg(out.v[0] / mercator_radius_m),
            proj.toDeg(out.v[1] / mercator_radius_m),
            mercator_radius_m,
        },
    );

    // -- The registry, read back --------------------------------------------
    //
    // Not compared against anything hard-coded: this prints what the database says,
    // so a reader sees the registry PROJ actually opened. `tests.zig` Fixture B is
    // where these values are checked.
    const geographic = try ctx.createFromDatabase("EPSG", "4326", .crs, false, null);
    defer geographic.destroy();
    try w.print(
        "{s}:{s}  {s}  ({s})\n",
        .{
            geographic.idAuthName(0).?,
            geographic.idCode(0).?,
            geographic.name().?,
            @tagName(geographic.getType()),
        },
    );

    if (geographic.areaOfUse()) |area| {
        try w.print(
            "  area of use: {d} {d} {d} {d}\n",
            .{
                area.west_lon_degree,
                area.south_lat_degree,
                area.east_lon_degree,
                area.north_lat_degree,
            },
        );
    } else |err| switch (err) {
        error.OutOfMemory => return error.UnexpectedResult,
        // A CRS with no area of use answers false, and that is not a failure of this
        // program (`src/iso19111/c_api.cpp:1971-1972`).
        error.UpstreamRefused => try w.writeAll("  area of use: none declared\n"),
        else => return err,
    }

    // -- The operation PROJ actually picked ---------------------------------
    //
    // `proj_trans_get_last_used_operation` is upstream's own answer to "which of
    // the alternatives did this point use" (`src/proj.h:630`,
    // `src/trans.cpp:363-377`), so what is printed is the operation that ran and
    // not merely one of the candidates. Null is a real answer here, not a failure
    // of this program.
    if (try operation.lastUsedOperation()) |chosen| {
        defer chosen.destroy();
        const method = try chosen.coordoperationMethodInfo();
        if (method.name) |name| {
            try w.print("  method:    {s}", .{name});
            if (method.code) |code| try w.print(" (EPSG:{s})", .{code});
            try w.writeAll("\n");
        }
    } else {
        try w.writeAll("  method:    none recorded\n");
    }

    try w.flush();

    // Upstream's process-wide teardown, last: it drops caches nothing above is using
    // any more.
    proj.cleanup();
}