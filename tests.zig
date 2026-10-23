// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md for what that identifier covers.

//! Behavior tests for independent Mercator, EPSG registry and missing-grid results.
//! Require a provider and proj.db; supplementary WKT checks prove self-agreement only.
const std = @import("std");
const proj = @import("proj");

// Setup.

/// A shared object exporting the 292 `proj_*` entry points `src/proj.h` declares.
const provider_variable = "PROJ_TEST_PROVIDER";

/// Where the build installed `proj.db` and the rest of the datum data.
const data_variable = "PROJ_DATA";

/// Setup errors include loader refusals and missing required environment values.
const Setup = proj.LoadError || proj.Error || error{
    /// A test expectation failed.
    TestUnexpectedResult,
    /// No provider was named and this is a runtime-loading build.
    MissingProvider,
    /// No `PROJ_DATA` was named, so no test below can find a database.
    MissingDataPath,
};

/// The provider this process is using, or null when none has loaded yet.
fn inUse() ?[]const u8 {
    const source = proj.loadedSource() orelse return null;
    return switch (source) {
        .path => |p| p,
        .system => |s| s,
    };
}

/// Load the configured provider when this build uses runtime loading.
fn loadProvider() Setup!void {
    if (!proj.runtime_loaded) return;
    if (inUse() != null) return;
    const value = std.testing.environ.getAlloc(std.testing.allocator, provider_variable) catch |err| switch (err) {
        error.EnvironmentVariableMissing, error.InvalidWtf8 => {
            std.debug.print(
                "\n{s}: not set. This is a runtime-loading build, so nothing native " ++
                    "is linked into the module and there is no provider to call.\n" ++
                    "Build one with `zig build -Dlinkage=dynamic --prefix <dir>` and " ++
                    "point {s} at <dir>/lib/libproj.so.25.\n",
                .{ @errorName(err), provider_variable },
            );
            return error.MissingProvider;
        },
        error.OutOfMemory => return error.MissingProvider,
    };
    defer std.testing.allocator.free(value);
    if (value.len == 0) {
        std.debug.print("\n{s} is empty; there is no provider to name.\n", .{provider_variable});
        return error.MissingProvider;
    }
    try proj.load(.{ .path = value });
}

/// Open proj.db from PROJ_DATA and disable network access.
fn openDatabase() Setup!proj.Context {
    try loadProvider();
    const ctx = try proj.Context.create();
    errdefer ctx.destroy();

    // Disable and verify network access so missing grids remain missing.
    const network_was = ctx.setNetworkEnabled(false);
    _ = network_was;
    try std.testing.expect(!ctx.networkEnabled());

    const raw_data = std.testing.environ.getAlloc(std.testing.allocator, data_variable) catch |err| switch (err) {
        error.EnvironmentVariableMissing, error.InvalidWtf8 => {
            std.debug.print(
                "\n{s}: not set. Every fixture here reads the EPSG registry out of " ++
                    "proj.db, so a test that ran without it would prove nothing.\n",
                .{@errorName(err)},
            );
            return error.MissingDataPath;
        },
        error.OutOfMemory => return error.MissingDataPath,
    };
    defer std.testing.allocator.free(raw_data);
    // Convert the environment slice to the sentinel-terminated C string required by PROJ.
    const data: [:0]const u8 = try std.testing.allocator.dupeZ(u8, raw_data);
    defer std.testing.allocator.free(data);
    if (data.len == 0) {
        std.debug.print("\n{s} is empty; there is no database directory to open.\n", .{data_variable});
        return error.MissingDataPath;
    }

    // PROJ expects a database file path; join proj.db to the PROJ_DATA directory.
    const database = try std.fs.path.joinZ(
        std.testing.allocator,
        &.{ data, "proj.db" },
    );
    defer std.testing.allocator.free(database);

    if (!ctx.setDatabasePath(database, null, null)) {
        std.debug.print("\nproj_context_set_database_path refused {s}\n", .{database});
        return error.MissingDataPath;
    }

    // Prove a database is really open, rather than trusting the setter.
    const opened = (try ctx.databasePath(std.testing.allocator)) orelse {
        std.debug.print("\nno database path after setDatabasePath({s})\n", .{data});
        return error.MissingDataPath;
    };
    defer std.testing.allocator.free(opened);

    return ctx;
}

// Harness.

fn expectNear(want: f64, got: f64, tolerance: f64, what: []const u8) !void {
    if (std.math.approxEqAbs(f64, want, got, tolerance)) return;
    std.debug.print(
        "{s}: expected {d:.12}, got {d:.12}, difference {e:.3} m, tolerance {e:.3} m\n",
        .{ what, want, got, @abs(got - want), tolerance },
    );
    return error.TestUnexpectedResult;
}

fn expectExactString(want: []const u8, got: ?[]const u8, what: []const u8) !void {
    const actual = got orelse {
        std.debug.print("{s}: upstream returned null\n", .{what});
        return error.TestUnexpectedResult;
    };
    try std.testing.expectEqualStrings(want, actual);
}

fn expectNumberNear(want: f64, got: f64, tolerance: f64, what: []const u8) !void {
    if (std.math.approxEqAbs(f64, want, got, tolerance)) return;
    std.debug.print(
        "{s}: expected {d:.17}, got {d:.17}, tolerance {d}\n",
        .{ what, want, got, tolerance },
    );
    return error.TestUnexpectedResult;
}

/// Assert two answers differ; zero-tolerance equality is a separate claim.
fn expectNumberDifferent(unwanted: f64, got: f64, what: []const u8) !void {
    if (unwanted != got) return;
    std.debug.print("{s}: both answers are {d:.17}\n", .{ what, got });
    return error.TestUnexpectedResult;
}

// Fixture A: independent Mercator answer.

/// EPSG:3857's spherical radius, in metres.
const mercator_radius_m: f64 = 6378137.0;

const radians_per_degree: f64 = std.math.pi / 180.0;

/// Reference inputs and independent EPSG:3857 answers.
const KnownPoint = struct {
    name: []const u8,
    lon_deg: f64,
    lat_deg: f64,
    x_m: f64,
    y_m: f64,
};

const known_points = [_]KnownPoint{
    .{
        .name = "P1 Philadelphia",
        .lon_deg = -75.0,
        .lat_deg = 40.0,
        .x_m = -8348961.809495518,
        .y_m = 4865942.279503176,
    },
    .{
        .name = "P2 Eiffel Tower",
        .lon_deg = 2.294481,
        .lat_deg = 48.858370,
        .x_m = 255420.45655484113,
        .y_m = 6250863.825524256,
    },
    .{
        .name = "P3",
        .lon_deg = 0.0,
        .lat_deg = 45.0,
        .x_m = 0.0,
        .y_m = 5621521.486192066,
    },
    .{
        .name = "P4 Tokyo",
        .lon_deg = 139.691711,
        .lat_deg = 35.689487,
        .x_m = 15550410.136561133,
        .y_m = 4257978.9503935715,
    },
};

/// Independent EPSG spherical Mercator formula; convert degrees without the facade.
fn closedFormForward(lon_deg: f64, lat_deg: f64) [2]f64 {
    const lam = lon_deg * radians_per_degree;
    const phi = lat_deg * radians_per_degree;
    return .{
        mercator_radius_m * lam,
        mercator_radius_m * @log(std.math.tan(std.math.pi / @as(f64, 4) + phi / 2)),
    };
}

/// Inverse Mercator formula, returning longitude and latitude in degrees.
fn closedFormInverse(x_m: f64, y_m: f64) [2]f64 {
    return .{
        (x_m / mercator_radius_m) / radians_per_degree,
        (2 * std.math.atan(@exp(y_m / mercator_radius_m)) - std.math.pi / @as(f64, 2)) / radians_per_degree,
    };
}

/// Metre tolerance: allows libm rounding but remains well below EPSG's 1 m precision.
const tolerance_m: f64 = 1e-6;

test "fixture A: EPSG:4326 to EPSG:3857 reproduces the published spherical Mercator closed form" {
    const ctx = try openDatabase();
    defer ctx.destroy();

    // EPSG:4326 authority order is latitude, longitude; projected output is easting, northing.
    const operation = try ctx.crsToCrs("EPSG:4326", "EPSG:3857", null);
    defer operation.destroy();

    for (known_points) |point| {
        const oracle = closedFormForward(point.lon_deg, point.lat_deg);

        // Ensure the recorded answers match the independent formula.
        try expectNear(oracle[0], point.x_m, tolerance_m, "recorded x");
        try expectNear(oracle[1], point.y_m, tolerance_m, "recorded y");

        // Forward transform: compare PROJ with the closed-form result.
        const out = operation.trans(.fwd, proj.coord(point.lat_deg, point.lon_deg, 0.0, 0.0));
        if (proj.isErrorCoordinate(out)) {
            std.debug.print("{s}: forward transform returned the error coordinate, errno {d}\n", .{ point.name, operation.errno() });
            return error.TestUnexpectedResult;
        }
        try expectNear(oracle[0], out.v[0], tolerance_m, point.name);
        try expectNear(oracle[1], out.v[1], tolerance_m, point.name);

        // Inverse transform.
        const back = operation.trans(.inv, proj.coord(point.x_m, point.y_m, 0.0, 0.0));
        if (proj.isErrorCoordinate(back)) {
            std.debug.print("{s}: inverse transform returned the error coordinate, errno {d}\n", .{ point.name, operation.errno() });
            return error.TestUnexpectedResult;
        }
        // Inverse input also follows EPSG:4326's latitude-longitude order.
        const recovered = closedFormForward(back.v[1], back.v[0]);
        try expectNear(oracle[0], recovered[0], tolerance_m, point.name);
        try expectNear(oracle[1], recovered[1], tolerance_m, point.name);

        // Check the fixture's inverse formula independently of the library.
        const inverted = closedFormInverse(point.x_m, point.y_m);
        try expectNumberNear(point.lon_deg, inverted[0], 1e-11, "closed-form inverse lon");
        try expectNumberNear(point.lat_deg, inverted[1], 1e-11, "closed-form inverse lat");
    }
}

// Fixture A: authority and visualization axis orders.

test "fixture A, second leg: the authority order and the visualisation order are different objects with different inputs" {
    const ctx = try openDatabase();
    defer ctx.destroy();

    // Compare against the UTM values published in upstream's example.
    // The 5e-4 m tolerance is half the final printed decimal place.
    const utm_published_easting: f64 = 426857.988;
    const utm_published_northing: f64 = 5427937.523;

    const authority_order = try ctx.crsToCrs("EPSG:4326", "EPSG:32631", null);
    defer authority_order.destroy();

    // Authority order is latitude first.
    const by_authority = authority_order.trans(.fwd, proj.coord(49.0, 2.0, 0.0, 0.0));
    if (proj.isErrorCoordinate(by_authority)) return error.TestUnexpectedResult;
    try expectNear(utm_published_easting, by_authority.v[0], 5e-4, "authority-order easting");
    try expectNear(utm_published_northing, by_authority.v[1], 5e-4, "authority-order northing");

    // Visualization normalization returns a separate, longitude-first operation.
    const visual_order = try authority_order.normalizeForVisualization();
    defer visual_order.destroy();

    const by_visualization = visual_order.trans(.fwd, proj.coord(2.0, 49.0, 0.0, 0.0));
    if (proj.isErrorCoordinate(by_visualization)) return error.TestUnexpectedResult;
    try expectNear(utm_published_easting, by_visualization.v[0], 5e-4, "visualisation-order easting");
    try expectNear(utm_published_northing, by_visualization.v[1], 5e-4, "visualisation-order northing");

    // Swapped input must not reproduce the authority-order answer.
    const mixed = visual_order.trans(.fwd, proj.coord(49.0, 2.0, 0.0, 0.0));
    if (proj.isErrorCoordinate(mixed)) return error.TestUnexpectedResult;
    try expectNumberDifferent(by_authority.v[0], mixed.v[0], "swapped input is not the same answer");
}

// Fixture B: EPSG registry values.

test "fixture B: the EPSG registry constants come back out of proj.db through the facade" {
    const ctx = try openDatabase();
    defer ctx.destroy();

    // EPSG:4326.
    const geographic = try ctx.createFromDatabase("EPSG", "4326", .crs, false, null);
    defer geographic.destroy();

    try expectExactString("EPSG", geographic.idAuthName(0), "EPSG:4326 authority");
    try expectExactString("4326", geographic.idCode(0), "EPSG:4326 code");
    try expectExactString("WGS 84", geographic.name(), "EPSG:4326 name");
    try std.testing.expectEqual(proj.Type.geographic_2d_crs, geographic.getType());
    try std.testing.expect(geographic.isCrs());
    try std.testing.expect(!geographic.isDeprecated());

    // EPSG:4326 binds to datum ensemble EPSG:6326, so datum() is null.
    // Check both accessors to distinguish the ensemble from a missing result.
    if (try geographic.datum()) |plain| {
        plain.destroy();
        std.debug.print("EPSG:4326 returned a plain datum; the registry binds it to ensemble EPSG:6326\n", .{});
        return error.TestUnexpectedResult;
    }
    const ensemble = (try geographic.datumEnsemble()) orelse {
        std.debug.print("EPSG:4326 returned neither a datum nor a datum ensemble\n", .{});
        return error.TestUnexpectedResult;
    };
    ensemble.destroy();

    // datumForced exposes the ensemble as a regular datum; ellipsoid values come from EPSG.
    const datum = (try geographic.datumForced()) orelse return error.TestUnexpectedResult;
    defer datum.destroy();
    const shape = (try datum.ellipsoid()) orelse return error.TestUnexpectedResult;
    defer shape.destroy();
    const ellipsoid = try shape.ellipsoidParameters();

    // Tolerance covers decimal-to-double rounding of stored ellipsoid values.
    try expectNumberNear(6378137.0, ellipsoid.semi_major_metre, 1e-9, "WGS 84 semi-major axis");
    try expectNumberNear(298.257223563, ellipsoid.inv_flattening, 1e-9, "WGS 84 inverse flattening");

    // The registry stores inverse flattening, so PROJ computes the semi-minor axis.
    try std.testing.expect(ellipsoid.semi_minor_computed);

    // EPSG:32631.
    const projected = try ctx.createFromDatabase("EPSG", "32631", .crs, false, null);
    defer projected.destroy();

    try expectExactString("WGS 84 / UTM zone 31N", projected.name(), "EPSG:32631 name");
    try std.testing.expectEqual(proj.Type.projected_crs, projected.getType());

    // Check the registry's Transverse Mercator method name and code.
    const conversion = (try projected.crsGetCoordoperation()) orelse return error.TestUnexpectedResult;
    defer conversion.destroy();
    const method = try conversion.coordoperationMethodInfo();
    try expectExactString("Transverse Mercator", method.name, "EPSG:32631 method name");
    try expectExactString("EPSG", method.auth_name, "EPSG:32631 method authority");
    try expectExactString("9807", method.code, "EPSG:32631 method code");

    // Match the four parameters by EPSG code, not implementation-dependent order.
    const expected = [_]struct { code: []const u8, name: []const u8, value: f64 }{
        .{ .code = "8802", .name = "Longitude of natural origin", .value = 3.0 },
        .{ .code = "8805", .name = "Scale factor at natural origin", .value = 0.9996 },
        .{ .code = "8806", .name = "False easting", .value = 500000.0 },
        .{ .code = "8807", .name = "False northing", .value = 0.0 },
    };

    const parameter_count = conversion.coordoperationParamCount();
    try std.testing.expect(parameter_count >= @as(c_int, @intCast(expected.len)));

    for (expected) |want| {
        var found = false;
        var index: c_int = 0;
        while (index < parameter_count) : (index += 1) {
            const param = try conversion.coordoperationParam(index);
            const code = param.code orelse continue;
            if (!std.mem.eql(u8, code, want.code)) continue;
            found = true;
            try expectExactString("EPSG", param.auth_name, want.name);
            try expectExactString(want.name, param.name, want.name);
            // Tolerance covers decimal-to-double rounding of the largest value.
            try expectNumberNear(want.value, param.value, 1e-9, want.name);
        }
        if (!found) {
            std.debug.print("EPSG:32631 has no parameter with EPSG code {s}\n", .{want.code});
            return error.TestUnexpectedResult;
        }
    }
}

// Fixture C: datum shift and grid availability.

test "fixture C: a datum shift with no grid reports the failure and never claims a coordinate" {
    const ctx = try openDatabase();
    defer ctx.destroy();

    const source = try ctx.createFromDatabase("EPSG", "4326", .crs, false, null);
    defer source.destroy();
    const target = try ctx.createFromDatabase("EPSG", "4277", .crs, false, null);
    defer target.destroy();

    // Strict containment excludes this pair: its accurate datum shifts need grids absent from this package.
    // Partial-intersection factories later in the test can still return candidates.
    const strict = try proj.OperationFactory.create(ctx, null);
    defer strict.destroy();
    strict.setGridAvailabilityUse(.discard_operation_if_missing_grid);
    strict.setAllowBallparkTransformations(false);

    const unavailable = (try strict.createOperations(source, target)) orelse return error.TestUnexpectedResult;
    defer unavailable.destroy();
    try std.testing.expectEqual(@as(c_int, 0), unavailable.len());

    // Positive control: the same settings must still find the grid-free EPSG:4326 to EPSG:3857 operation.
    const mercator = try ctx.createFromDatabase("EPSG", "3857", .crs, false, null);
    defer mercator.destroy();
    const available = (try strict.createOperations(source, mercator)) orelse return error.TestUnexpectedResult;
    defer available.destroy();
    try std.testing.expect(available.len() >= 1);

    // ONLY_BEST=YES builds an operation shell here; the transform refuses when the required grid is missing.
    // Its options array must be null-terminated; assert the error coordinate and errno.
    const only_best = [_]?[*:0]const u8{ "ONLY_BEST=YES", null };
    if (ctx.crsToCrsFromPj(source, target, null, &only_best)) |best| {
        var best_operation = best;
        defer best_operation.destroy();

        const refused = best_operation.trans(.fwd, proj.coord(50.0, -2.0, 0.0, 0.0));
        if (!proj.isErrorCoordinate(refused)) {
            std.debug.print(
                "ONLY_BEST=YES turned EPSG:4326 -> EPSG:4277 into {d} {d}\n",
                .{ refused.v[0], refused.v[1] },
            );
            return error.TestUnexpectedResult;
        }
        try std.testing.expectEqual(
            proj.ErrorCode.coord_transfm_no_operation,
            best_operation.errno(),
        );
    } else |err| switch (err) {
        // A null constructor result is another upstream refusal and may not set errno.
        error.OutOfMemory => return error.TestUnexpectedResult,
        error.NullReturn => {},
        else => return err,
    }

    // A finite result may use the grid-free Helmert route, so inspect the operation PROJ actually ran.
    // Every listed grid must be available and the operation must be instantiable.
    if (ctx.crsToCrsFromPj(source, target, null, null)) |built| {
        const operation = built;
        defer operation.destroy();

        const result = operation.trans(.fwd, proj.coord(50.0, -2.0, 0.0, 0.0));
        if (proj.isErrorCoordinate(result)) {
            // Accept only documented transformation and missing-grid refusal codes.
            const reported = operation.errno();
            const documented = reported == proj.ErrorCode.coord_transfm_no_operation or
                reported == proj.ErrorCode.coord_transfm or
                reported == proj.ErrorCode.invalid_op_file_not_found_or_invalid or
                reported == proj.ErrorCode.coord_transfm_outside_grid;
            if (!documented) {
                std.debug.print(
                    "EPSG:4326 -> EPSG:4277 refused with an undocumented code: {d}\n",
                    .{reported},
                );
                return error.TestUnexpectedResult;
            }
        } else {
            const used = (try operation.lastUsedOperation()) orelse {
                std.debug.print(
                    "EPSG:4326 -> EPSG:4277 returned {d} {d} and names no operation\n",
                    .{ result.v[0], result.v[1] },
                );
                return error.TestUnexpectedResult;
            };
            defer used.destroy();

            const grids = used.coordoperationGridUsedCount();
            var index: c_int = 0;
            while (index < grids) : (index += 1) {
                const grid = try used.coordoperationGridUsed(index);
                if (grid.available != 0) continue;
                std.debug.print(
                    "EPSG:4326 -> EPSG:4277 returned {d} {d} through an operation " ++
                        "needing grid {?s}; this build has no network and ships no " ++
                        "such file, so that step never ran\n",
                    .{ result.v[0], result.v[1], grid.short_name },
                );
                return error.TestUnexpectedResult;
            }
            if (grids != 0) try std.testing.expect(used.coordoperationIsInstantiable());
        }
    } else |err| switch (err) {
        error.OutOfMemory => return error.TestUnexpectedResult,
        error.NullReturn => {
            // A null constructor result is also a clean refusal.
        },
        else => return err,
    }
}

// Supplement: malformed definitions.

test "supplement: a malformed definition is refused with the code upstream sets for it" {
    const ctx = try openDatabase();
    defer ctx.destroy();

    // Unknown projection names return NullReturn and set INVALID_OP_ILLEGAL_ARG_VALUE.
    try std.testing.expectError(
        error.NullReturn,
        ctx.createFromProjString("+proj=no_such_projection_here +a=6378137 +b=6378137"),
    );
    try std.testing.expectEqual(
        proj.ErrorCode.invalid_op_illegal_arg_value,
        ctx.errno(),
    );
    try std.testing.expectEqualStrings(
        "Invalid value for an argument",
        ctx.errnoString(ctx.errno()).?,
    );

    // Names shorter than PROJ's minimum length set the same error.
    try std.testing.expectError(error.NullReturn, ctx.createFromProjString("+proj=ab"));
    try std.testing.expectEqual(
        proj.ErrorCode.invalid_op_illegal_arg_value,
        ctx.errno(),
    );

    // WKT parse failures return NullReturn without changing context errno.
    // The facade does not expose the parser's out_grammar_errors result.
    try std.testing.expectError(
        error.NullReturn,
        ctx.createFromWkt("THIS IS NOT A WKT STRING", null),
    );
    try std.testing.expectError(
        error.NullReturn,
        ctx.createFromWkt("GEOGCRS[\"unterminated\"", null),
    );
}

// Supplement: database metadata.

test "supplement: the database this build opened can be read for its own metadata" {
    const ctx = try openDatabase();
    defer ctx.destroy();

    // Check a documented proj.db key and verify the facade returns a copied value.
    const major_text = (try ctx.databaseMetadata(std.testing.allocator, "DATABASE.LAYOUT.VERSION.MAJOR")) orelse {
        std.debug.print("proj.db has no DATABASE.LAYOUT.VERSION.MAJOR\n", .{});
        return error.TestUnexpectedResult;
    };
    defer std.testing.allocator.free(major_text);

    try std.testing.expect(major_text.len > 0);
    for (major_text) |byte| {
        try std.testing.expect(byte >= '0' and byte <= '9');
    }

    // Confirm the opened database path ends in proj.db.
    const path = (try ctx.databasePath(std.testing.allocator)) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(path);
    try std.testing.expect(std.mem.endsWith(u8, path, "proj.db"));

    // Distinct metadata keys return separate copies despite upstream's shared context slot.
    const first = (try ctx.databaseMetadata(std.testing.allocator, "DATABASE.LAYOUT.VERSION.MINOR")) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(first);
    const second = (try ctx.databaseMetadata(std.testing.allocator, "EPSG.VERSION")) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(second);
    try std.testing.expect(!std.mem.eql(u8, first, second));
    try std.testing.expect(first.len > 0);
    try std.testing.expect(second.len > 0);
}

// Supplement: WKT self-agreement.

test "supplement: WKT export and re-import agree with each other, which is self-agreement and nothing more" {
    const ctx = try openDatabase();
    defer ctx.destroy();

    var original = try ctx.createFromDatabase("EPSG", "4326", .crs, false, null);
    defer original.destroy();

    const wkt = original.asWkt(.wkt2_2019, null) orelse return error.TestUnexpectedResult;

    var reimported = try ctx.createFromWkt(wkt, null);
    defer reimported.destroy();

    // Export/re-import agreement is not proof of correctness; fixtures A and B provide independent checks.
    // This supplement covers parsing and re-export of the text.
    try expectExactString(
        original.name().?,
        reimported.name(),
        "WKT round trip name",
    );
    try std.testing.expectEqual(original.getType(), reimported.getType());
    try std.testing.expect(reimported.isEquivalentTo(original, .equivalent));
    try std.testing.expectEqualStrings("EPSG", reimported.idAuthName(0).?);
    try std.testing.expectEqualStrings("4326", reimported.idCode(0).?);

    // The dialect guesser should identify the exported WKT version.
    try std.testing.expectEqual(.wkt2_2019, ctx.guessWktDialect(wkt));
}
