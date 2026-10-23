// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md in the parent directory for what that identifier covers.

//! Consumer example using the published module to transform EPSG:4326 to EPSG:3857.
//! It checks an independent Mercator reference; EPSG:4326 input order is latitude, longitude.
//! Runtime mode requires `--provider` or `PROJ_TEST_PROVIDER`.

const std = @import("std");
const proj = @import("proj");

/// Environment variable naming a runtime provider.
const provider_variable = "PROJ_TEST_PROVIDER";

/// `PROJ_DATA` names the directory containing the installed `proj.db`.
const data_variable = "PROJ_DATA";

/// Spherical Mercator radius, in metres.
const mercator_radius_m: f64 = 6378137.0;

const radians_per_degree: f64 = std.math.pi / 180.0;

/// Absolute tolerance for metre comparisons.
const tolerance_m: f64 = 1e-6;

/// Philadelphia latitude, in degrees; EPSG:4326 uses latitude first.
const latitude_deg: f64 = 40.0;
const longitude_deg: f64 = -75.0;

/// Computes the independent spherical-Mercator reference.
fn closedForm(lon_deg: f64, lat_deg: f64) [2]f64 {
    const lam = lon_deg * radians_per_degree;
    const phi = lat_deg * radians_per_degree;
    return .{
        mercator_radius_m * lam,
        // Observed with Zig 0.16: this division requires an explicit float type.
        // Not rechecked with Zig 0.17.0.
        mercator_radius_m * @log(std.math.tan(std.math.pi / @as(f64, 4) + phi / 2)),
    };
}

/// Fails with both values when `got` differs from `want` beyond `tolerance`.
fn expectNear(want: f64, got: f64, tolerance: f64, what: []const u8) !void {
    if (std.math.approxEqAbs(f64, want, got, tolerance)) return;
    // Zig uses `{e:.3}` for scientific notation.
    std.debug.print(
        "consumer: {s}: expected {d:.6}, got {d:.6}, difference {e:.3} m, tolerance {e:.3} m\n",
        .{ what, want, got, @abs(got - want), tolerance },
    );
    return error.UnexpectedResult;
}

/// Resolves `--provider` before `PROJ_TEST_PROVIDER`; linked builds need neither.
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

    // Resolve the provider before the first native call.
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

    // The setter returns the previous state; read back to confirm networking is disabled.
    const network_was = ctx.setNetworkEnabled(false);
    _ = network_was;
    if (ctx.networkEnabled()) {
        std.debug.print("consumer: the network is still enabled after it was turned off\n", .{});
        return error.UnexpectedResult;
    }

    if (init.environ_map.get(data_variable)) |data| {
        if (data.len != 0) {
            // `PROJ_DATA` is a directory; this setter takes the `proj.db` file path.
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

    // Published values are recorded in `../testdata/webmercator-known-answers.md`.
    try expectNear(-8348961.809495518, out.v[0], tolerance_m, "published easting");
    try expectNear(4865942.279503176, out.v[1], tolerance_m, "published northing");
    // Zig uses `{e:.3}` for scientific notation.
    try w.print("  difference: {e:.3} m easting, {e:.3} m northing\n", .{
        @abs(out.v[0] - oracle[0]),
        @abs(out.v[1] - oracle[1]),
    });
    try w.print("  tolerance:  {e:.3} m\n", .{tolerance_m});

    // The inverse round trip demonstrates the reverse path, not correctness.
    const back = operation.trans(.inv, proj.coord(out.v[0], out.v[1], 0.0, 0.0));
    if (proj.isErrorCoordinate(back)) return error.TransformationFailed;
    try expectNear(latitude_deg, back.v[0], 1e-11, "round-trip latitude");
    try expectNear(longitude_deg, back.v[1], 1e-11, "round-trip longitude");
    try w.print(
        "  (round trip, self-agreement only: {d:.12} deg N, {d:.12} deg E)\n",
        .{ back.v[0], back.v[1] },
    );

    // Read EPSG:4326 from the installed database.
    const geographic = try ctx.createFromDatabase("EPSG", "4326", .crs, false, null);
    defer geographic.destroy();
    try w.print(
        "registry: {s}:{s} is {s}\n",
        .{ geographic.idAuthName(0).?, geographic.idCode(0).?, geographic.name().? },
    );

    try w.flush();
    proj.cleanup();
}
