// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md for what that identifier covers.

//! End-to-end smoke run for the PROJ facade.

const std = @import("std");
const proj = @import("proj");

const provider_variable = "PROJ_TEST_PROVIDER";
const data_variable = "PROJ_DATA";

/// EPSG:3857's spherical Mercator radius in metres.
const mercator_radius_m: f64 = 6378137.0;

/// Maximum easting of spherical Mercator: half the circumference.
const mercator_limit_m: f64 = std.math.pi * mercator_radius_m;

/// Fail with a message rather than a bare error, so the run says what went wrong.
fn require(condition: bool, comptime message: []const u8) !void {
    if (condition) return;
    std.debug.print("smoke: " ++ message ++ "\n", .{});
    return error.UnexpectedResult;
}

/// Resolve `--provider` before `PROJ_TEST_PROVIDER`; never fall back.
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

    // Report whether calls use linked symbols or the loaded provider.
    if (proj.runtime_loaded) {
        try w.print(
            "runtime-loaded: provider {s}, loadedSource reports the same path\n",
            .{proj.loadedSource().?.path},
        );
    } else {
        try w.writeAll("linked: proj_* resolved at link time\n");
    }

    // Print the version; do not assert it.
    const reported = proj.version();
    try w.print(
        "PROJ {d}.{d}.{d}\n",
        .{ reported.major, reported.minor, reported.patch },
    );
    if (reported.release) |release| try w.print("  release:   {s}\n", .{release});
    if (reported.version) |version| try w.print("  version:   {s}\n", .{version});

    const ctx = try proj.Context.create();
    defer ctx.destroy();

    // Verify networking is off; setNetworkEnabled returns the previous state.
    const network_was = ctx.setNetworkEnabled(false);
    _ = network_was;
    try require(!ctx.networkEnabled(), "the network is still enabled after it was turned off");

    if (init.environ_map.get(data_variable)) |data| {
        if (data.len != 0) {
            // PROJ expects a database-file path, so append `proj.db` to `PROJ_DATA`.
            const database = try std.fs.path.joinZ(arena, &.{ data, "proj.db" });
            if (!ctx.setDatabasePath(database, null, null)) {
                std.debug.print("smoke: proj_context_set_database_path refused {s}\n", .{data});
                return error.DatabaseRefused;
            }
        }
    }
    // Copy the path before another database query overwrites the context slot.
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

    // EPSG:4326 uses latitude-first authority order.
    const operation = try ctx.crsToCrs("EPSG:4326", "EPSG:3857", null);
    defer operation.destroy();

    const out = operation.trans(.fwd, proj.coord(40.0, -75.0, 0.0, 0.0));
    // Reject PROJ's error coordinate before printing it.
    if (proj.isErrorCoordinate(out)) {
        std.debug.print(
            "smoke: the transform returned the error coordinate, errno {d}\n",
            .{operation.errno()},
        );
        return error.TransformationFailed;
    }
    // Fixture A checks numerical correctness independently.
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

    // Print registry values; Fixture B verifies them.
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
        // A CRS may have no declared area of use.
        error.UpstreamRefused => try w.writeAll("  area of use: none declared\n"),
        else => return err,
    }

    // Report the operation used, not only the candidate list.
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

    // Clean up after all PROJ handles have been destroyed.
    proj.cleanup();
}
