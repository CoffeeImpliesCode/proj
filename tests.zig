// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md for what that identifier covers.

//! Behavioural tests for the PROJ facade.
//!
//! ## What is proved here, and what is not
//!
//! The primary evidence is **Fixture A**, an independent known answer: the
//! spherical Mercator closed form from the EPSG Guidance Note, re-derived here
//! from the published formulas and compared against what PROJ computes. It does
//! not come from PROJ, from a previous run of this library, or from a round trip.
//!
//! **Fixture B** is a registry read: the values EPSG itself defines, fetched back
//! out of `proj.db` through the facade. A facade that returns them is reading the
//! registry, not agreeing with itself.
//!
// **Fixture C** is a behavioural boundary: `ONLY_BEST=YES` must make a datum
// shift fail, with the code upstream sets when a grid is missing, and the
// default route must either refuse the same way or run an operation whose every
// grid this build can actually reach. The network is off, so "no network" is a
// property of this test and not an accident.
//!
//! Everything else in this file is a **supplement**, and says so: a malformed-input
//! error path, a metadata read, and a WKT round trip that is explicitly labelled
//! self-agreement — the two directions of one code agreeing with each other, which
//! is not evidence that either is correct.
//!
//! ## What each case needs
//!
//! Every case needs the linked archive, or under `-Druntime` a provider named by
//! `PROJ_TEST_PROVIDER`; `openDatabase` says so and fails loudly rather than
//! skipping. Every fixture also needs `proj.db`: `PROJ_DATA` must point at the
//! directory the build installed it into. PROJ resolves that variable itself
//! (`src/filemanager.cpp:1113-1132`), which is why the tests read it and hand it
//! to `setDatabasePath` rather than re-deriving a path of their own.
//!
//! Nothing here is skipped when something is missing. A case that quietly passed
//! without a database or a provider would say nothing at all.
//!
//! ## A leak oracle is not available, and this file does not pretend otherwise
//!
//! PROJ allocates everything with C `new`/`malloc` and frees it inside the library
//! (`src/ctx.cpp:305-306`, `src/malloc.cpp:100-110`). `std.testing`'s allocator
//! only sees what *it* allocated, so `std.testing.allocator` cannot be given a leak
//! oracle for PROJ's memory. The two strings this file asks the facade to copy are
//! the exception, and they are freed. A green run of this file is a statement about
//! the answers, not about PROJ's allocations.
//!
//! ## The provider, in a runtime-loading build
//!
//! `zig build test` runs this root through `addRunArtifact`, which hands the child
//! the environment it inherited rather than the arguments after `--`, so the
//! environment variable is the channel here by construction.

const std = @import("std");
const proj = @import("proj");

// ---- The provider ------------------------------------------------------------

/// A shared object exporting the 292 `proj_*` entry points `src/proj.h` declares.
const provider_variable = "PROJ_TEST_PROVIDER";

/// Where the build installed `proj.db` and the rest of the datum data.
const data_variable = "PROJ_DATA";

/// What can be wrong with this file's own setup rather than with the library,
/// plus whatever the loader itself refuses with.
const Setup = proj.LoadError || proj.Error || error{
    /// A `std.testing` expectation of this file's own did not hold. Carried here
    /// so that a fixture helper may use `std.testing.expect` under `try`.
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

/// Load the configured provider, once, if this build needs one at all.
///
/// A linked build links `proj_*` and has nothing to load, so this returns
/// immediately there and every case below is an ordinary direct call. A
/// runtime-loading build has to be told, and the only two outcomes that mean
/// anything are "a provider is in use" and "there is none"; the middle state is not
/// a third thing a caller has to handle, so it reports the error instead.
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

/// A context with this build's database opened, and the network off.
///
/// `PROJ_DATA` is read here and handed to `setDatabasePath`, which is the route
/// the facade offers: upstream resolves that variable itself
/// (`src/filemanager.cpp:1113-1132`) and a facade that re-derived a path of its own
/// would be a second place for that decision to live.
fn openDatabase() Setup!proj.Context {
    try loadProvider();
    const ctx = try proj.Context.create();
    errdefer ctx.destroy();

    // The network is off for every case, and each one says so rather than
    // inheriting it. With the network on, a missing grid could be fetched and
    // Fixture C would stop being a boundary.
    // `proj_context_set_enable_network` answers the *previous* setting
    // (`src/proj.h:555`), not whether it accepted the request, so its return
    // value is not an acceptance flag and asserting on it would assert the wrong
    // thing. The read-back on the next line is what says the network is off.
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
    // `setDatabasePath` wants the C spelling, a sentinel-terminated string, and
    // `getAlloc` hands back a length-only slice -- the environment value carries
    // no NUL in the returned range, so asserting one by slicing past the end
    // would read out of bounds. The terminator is added here, once, by copy.
    const data: [:0]const u8 = try std.testing.allocator.dupeZ(u8, raw_data);
    defer std.testing.allocator.free(data);
    if (data.len == 0) {
        std.debug.print("\n{s} is empty; there is no database directory to open.\n", .{data_variable});
        return error.MissingDataPath;
    }

    // `proj_context_set_database_path` takes the path to the database *file*:
    // `DatabaseContext::Private::open` hands `databasePath` straight to
    // `sqlite3_open_v2` (`src/iso19111/factory.cpp:1243-1270`) and appends
    // nothing, so a bare directory is not a database. `PROJ_DATA` names the
    // directory, so the file name is joined onto it here.
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

// ---- Harness -----------------------------------------------------------------

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

/// Two answers that must differ, and why the tolerance cannot say so.
///
/// `expectNumberNear` asserts the **opposite**. `std.math.approxEqAbs(x, y, 0.0)`
/// is exact equality — its fast path is `x == y` and its body is
/// `abs(x - y) <= tolerance` (`lib/std/math.zig:76-88`) — so asking it with a
/// tolerance of zero would assert that two coordinates are the same. That is a
/// separate function, not a tolerance of zero, so a reader cannot mistake one
/// claim for the other.
fn expectNumberDifferent(unwanted: f64, got: f64, what: []const u8) !void {
    if (unwanted != got) return;
    std.debug.print("{s}: both answers are {d:.17}\n", .{ what, got });
    return error.TestUnexpectedResult;
}

// ---- Fixture A: the independent known answer ----------------------------------

/// EPSG:3857's sphere radius, in metres.
///
/// The "Popular Visualisation Pseudo-Mercator" method is defined on a sphere of
/// this radius and on no ellipsoid, so `b = a` and the eccentricity is zero. That is
/// what makes `src/projections/merc.cpp:24-29` the *spheroidal* branch:
/// `xy.y = k0 * asinh(tan(lp.phi))`, with `k0 = 1`.
const mercator_radius_m: f64 = 6378137.0;

const radians_per_degree: f64 = std.math.pi / 180.0;

/// One published answer and the input it answers for.
///
/// The `x_m` and `y_m` values are the shortest decimal strings that round-trip to
/// the doubles the closed form produces, transcribed from
/// `testdata/webmercator-known-answers.md`. Nothing in this file reads that file;
/// the literals below ARE the transcription, and the test that compares them is the
/// tie between the two.
const KnownPoint = struct {
    name: []const u8,
    lon_deg: f64,
    lat_deg: f64,
    x_m: f64,
    y_m: f64,
};

const known_points = [_]KnownPoint{
    // -8348961.809495518 = 6378137 * (-75 * pi / 180)
    //  4865942.279503176 = 6378137 * ln(tan(pi/4 + 40 * pi / 360))
    .{
        .name = "P1 Philadelphia",
        .lon_deg = -75.0,
        .lat_deg = 40.0,
        .x_m = -8348961.809495518,
        .y_m = 4865942.279503176,
    },
    // 255420.45655484113 = 6378137 * (2.294481 * pi / 180)
    // 6250863.825524256 = 6378137 * ln(tan(pi/4 + 48.85837 * pi / 360))
    .{
        .name = "P2 Eiffel Tower",
        .lon_deg = 2.294481,
        .lat_deg = 48.858370,
        .x_m = 255420.45655484113,
        .y_m = 6250863.825524256,
    },
    // x is exactly zero: the central meridian of EPSG:3857 is Greenwich.
    // 5621521.486192066 = 6378137 * ln(1 + sqrt(2)), and ln(1 + sqrt 2) =
    // 0.8813735870195429, which is also asinh(1) — the 45-degree case in closed
    // form, since tan(3*pi/8) = 1 + sqrt(2).
    .{
        .name = "P3",
        .lon_deg = 0.0,
        .lat_deg = 45.0,
        .x_m = 0.0,
        .y_m = 5621521.486192066,
    },
    // 15550410.136561133 = 6378137 * (139.691711 * pi / 180)
    // 4257978.9503935715 = 6378137 * ln(tan(pi/4 + 35.689487 * pi / 360))
    .{
        .name = "P4 Tokyo",
        .lon_deg = 139.691711,
        .lat_deg = 35.689487,
        .x_m = 15550410.136561133,
        .y_m = 4257978.9503935715,
    },
};

/// The published spherical Mercator forward closed form, from the EPSG Guidance
/// Note 7-2 method formulas:
///
///     x = R * lambda
///     y = R * ln(tan(pi/4 + phi/2))
///
/// with `lambda` and `phi` in radians. This is deliberately **not** written the way
/// upstream writes it. `src/projections/merc.cpp:24-29` computes
/// `k0 * asinh(tan(phi))`, and `asinh(t) = ln(t + sqrt(1 + t^2))` is the same
/// function as `ln(tan(pi/4 + phi/2))` by the half-angle identity
/// `tan(pi/4 + phi/2) = (1 + sin phi) / cos phi = t + sqrt(1 + t^2)` for
/// `t = tan(phi)`. Same answer, different arithmetic, so agreement is expected and
/// is not agreement with itself.
///
/// The degree→radian multiply is done here rather than through `proj.toRad`, so the
/// oracle does not depend on the library it is checking.
fn closedFormForward(lon_deg: f64, lat_deg: f64) [2]f64 {
    const lam = lon_deg * radians_per_degree;
    const phi = lat_deg * radians_per_degree;
    return .{
        mercator_radius_m * lam,
        mercator_radius_m * @log(std.math.tan(std.math.pi / @as(f64, 4) + phi / 2)),
    };
}

/// The published inverse closed form: `lambda = x/R`,
/// `phi = 2 * atan(exp(y/R)) - pi/2`, in degrees.
fn closedFormInverse(x_m: f64, y_m: f64) [2]f64 {
    return .{
        (x_m / mercator_radius_m) / radians_per_degree,
        (2 * std.math.atan(@exp(y_m / mercator_radius_m)) - std.math.pi / @as(f64, 2)) / radians_per_degree,
    };
}

/// The tolerance every comparison in this fixture uses, in metres.
///
/// **Why 1e-6 m is the right number here, and not 1e-9.** The two computations
/// differ in three places and nothing else: PROJ multiplies by `k0` after `asinh`,
/// the closed form multiplies by `R` after `ln` (and `k0 = 1` exactly for
/// EPSG:3857, so those two are the same number); the degree→radian conversion is
/// one multiply by `pi/180` either way; and `asinh` and `ln(tan(.))` differ by the
/// half-angle identity above, which is exact in real arithmetic but not in floating
/// point. A double has a 53-bit significand, so one ulp of a number near 6.3e6 is
/// about 8.9e-10 m. Three or four roundings of that size — the `tan`, the `ln` or
/// `asinh`, the `pi/4 +` and the final scale — accumulate to a few times 1e-9 m.
/// 1e-6 m leaves three orders of magnitude of headroom over that and is still four
/// orders of magnitude finer than the 1 m precision the EPSG method itself
/// publishes. A tighter tolerance would be testing the two libm implementations
/// against each other rather than the projection.
const tolerance_m: f64 = 1e-6;

test "fixture A: EPSG:4326 to EPSG:3857 reproduces the published spherical Mercator closed form" {
    const ctx = try openDatabase();
    defer ctx.destroy();

    // **The axis order this test passes is latitude-then-longitude, because
    // EPSG:4326 declares GeodeticLatitude as its first axis and
    // `proj_create_crs_to_crs` honours the authority order.** Upstream's own example
    // is the evidence: `examples/EPSG_4326_to_32631.cpp:74-85` puts `49.0` in
    // `v[0]` labelled "latitude in degree" and `2.0` in `v[1]` labelled "longitude
    // in degree", and reads `v[0]` back as easting. `test/unit/test_c_api.cpp:4374`
    // builds the same pair and shows that `proj_normalize_for_visualization` is what
    // removes the swap — its expected pipeline at `:4382-4384` has no `axisswap`
    // step — which is the other route and is exercised separately below.
    //
    // So: latitude goes in `v[0]`, longitude in `v[1]`, and the result comes back as
    // easting in `v[0]` and northing in `v[1]`.
    const operation = try ctx.crsToCrs("EPSG:4326", "EPSG:3857", null);
    defer operation.destroy();

    for (known_points) |point| {
        const oracle = closedFormForward(point.lon_deg, point.lat_deg);

        // The tie between this file and testdata/: the literal the audit record
        // carries is the closed form's own value.
        try expectNear(oracle[0], point.x_m, tolerance_m, "recorded x");
        try expectNear(oracle[1], point.y_m, tolerance_m, "recorded y");

        // -- forward: PROJ against the closed form ---------------------------
        const out = operation.trans(.fwd, proj.coord(point.lat_deg, point.lon_deg, 0.0, 0.0));
        if (proj.isErrorCoordinate(out)) {
            std.debug.print("{s}: forward transform returned the error coordinate, errno {d}\n", .{ point.name, operation.errno() });
            return error.TestUnexpectedResult;
        }
        try expectNear(oracle[0], out.v[0], tolerance_m, point.name);
        try expectNear(oracle[1], out.v[1], tolerance_m, point.name);

        // -- inverse: PROJ's answer pushed back through the closed form -------
        const back = operation.trans(.inv, proj.coord(point.x_m, point.y_m, 0.0, 0.0));
        if (proj.isErrorCoordinate(back)) {
            std.debug.print("{s}: inverse transform returned the error coordinate, errno {d}\n", .{ point.name, operation.errno() });
            return error.TestUnexpectedResult;
        }
        // Latitude is `v[0]` and longitude is `v[1]` again, because the inverse
        // operation's input is the authority's axis order too.
        const recovered = closedFormForward(back.v[1], back.v[0]);
        try expectNear(oracle[0], recovered[0], tolerance_m, point.name);
        try expectNear(oracle[1], recovered[1], tolerance_m, point.name);

        // The inverse closed form is the same function as the forward one, and
        // saying so here is a check on the *fixture*, not on the library: if the two
        // halves of the published method disagreed, no transform could pass.
        const inverted = closedFormInverse(point.x_m, point.y_m);
        try expectNumberNear(point.lon_deg, inverted[0], 1e-11, "closed-form inverse lon");
        try expectNumberNear(point.lat_deg, inverted[1], 1e-11, "closed-form inverse lat");
    }
}

// ---- Fixture A, second leg: the two axis-order routes ------------------------

test "fixture A, second leg: the authority order and the visualisation order are different objects with different inputs" {
    const ctx = try openDatabase();
    defer ctx.destroy();

    // EPSG:4326 to EPSG:32631, whose answer upstream publishes in its own example
    // (`examples/EPSG_4326_to_32631.cpp:84-85`): "should be 426857.988" and
    // "should be 5427937.523", printed to three decimals. That is an independent
    // known answer from upstream's documentation, not a value this run produced.
    //
    // The 5e-4 tolerance is the rounding of those two published figures to three
    // decimal places (half of the last printed digit), and nothing more: the UTM
    // forward is a series in closed form with no grid and no iterative step, so
    // PROJ's own arithmetic error is a few ulp of 5.4e6 m, about 1e-9 m.
    const utm_published_easting: f64 = 426857.988;
    const utm_published_northing: f64 = 5427937.523;

    const authority_order = try ctx.crsToCrs("EPSG:4326", "EPSG:32631", null);
    defer authority_order.destroy();

    // Latitude first, because that is what the authority says.
    const by_authority = authority_order.trans(.fwd, proj.coord(49.0, 2.0, 0.0, 0.0));
    if (proj.isErrorCoordinate(by_authority)) return error.TestUnexpectedResult;
    try expectNear(utm_published_easting, by_authority.v[0], 5e-4, "authority-order easting");
    try expectNear(utm_published_northing, by_authority.v[1], 5e-4, "authority-order northing");

    // Now the other route, on its own object, with its own input order. Upstream's
    // summary of `proj_normalize_for_visualization` is "Returns a PJ* object whose
    // axis order is the one expected for visualization purposes"
    // (`src/iso19111/c_api.cpp:2205`), and `test/unit/test_c_api.cpp:4377-4387`
    // shows the resulting pipeline dropping the axis swap.
    const visual_order = try authority_order.normalizeForVisualization();
    defer visual_order.destroy();

    // Longitude first now.
    const by_visualization = visual_order.trans(.fwd, proj.coord(2.0, 49.0, 0.0, 0.0));
    if (proj.isErrorCoordinate(by_visualization)) return error.TestUnexpectedResult;
    try expectNear(utm_published_easting, by_visualization.v[0], 5e-4, "visualisation-order easting");
    try expectNear(utm_published_northing, by_visualization.v[1], 5e-4, "visualisation-order northing");

    // And the two orders are genuinely different: feeding the visualisation object
    // the authority's input must not reproduce the answer. It is 47 degrees away in
    // latitude, which no rounding could explain.
    const mixed = visual_order.trans(.fwd, proj.coord(49.0, 2.0, 0.0, 0.0));
    if (proj.isErrorCoordinate(mixed)) return error.TestUnexpectedResult;
    try expectNumberDifferent(by_authority.v[0], mixed.v[0], "swapped input is not the same answer");
}

// ---- Fixture B: the EPSG registry, read back out of proj.db -------------------

test "fixture B: the EPSG registry constants come back out of proj.db through the facade" {
    const ctx = try openDatabase();
    defer ctx.destroy();

    // -- EPSG:4326 ----------------------------------------------------------
    const geographic = try ctx.createFromDatabase("EPSG", "4326", .crs, false, null);
    defer geographic.destroy();

    try expectExactString("EPSG", geographic.idAuthName(0), "EPSG:4326 authority");
    try expectExactString("4326", geographic.idCode(0), "EPSG:4326 code");
    try expectExactString("WGS 84", geographic.name(), "EPSG:4326 name");
    try std.testing.expectEqual(proj.Type.geographic_2d_crs, geographic.getType());
    try std.testing.expect(geographic.isCrs());
    try std.testing.expect(!geographic.isDeprecated());

    // **`EPSG:4326` is bound to a datum *ensemble*, not to a datum, and that is
    // what the registry in this package's own `proj.db` says.** Its `geodetic_crs`
    // row names `EPSG:6326` (`data/sql/geodetic_crs.sql:523`), and that row is
    // named "World Geodetic System 1984 ensemble", carries a non-null
    // `ensemble_accuracy` and has eight rows in `geodetic_datum_ensemble_member`
    // — so upstream's factory takes the ensemble branch
    // (`src/iso19111/factory.cpp:4960-4977`) with `turnEnsembleAsDatum = false`
    // (`:5538-5541`) and leaves the datum pointer null. Upstream's own test
    // asserts exactly that shape for `EPSG:4326`
    // (`test/unit/test_factory.cpp:568-571`).
    //
    // So `datum()` is null here, and that null is upstream's own answer rather
    // than a gap: it returns NULL as soon as `SingleCRS::datum()` is
    // (`src/iso19111/c_api.cpp:8808-8811`), documents itself "NULL in case of
    // error (or if there is no datum)" (`:8793-8794`), and points the reader at
    // `proj_crs_get_datum_ensemble` (`:8784-8785`). Both halves are checked, so a
    // facade that answered null for everything would fail on the second.
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

    // `datumForced` is the route upstream provides for exactly this CRS, in its
    // own words: "If the SingleCRS has a datum, then this datum is returned.
    // Otherwise, the SingleCRS has a datum ensemble, and this datum ensemble is
    // returned as a regular datum instead of a datum ensemble"
    // (`src/iso19111/c_api.cpp:8951-8956`).
    //
    // Its ellipsoid's semi-major axis and inverse flattening are numbers the
    // EPSG dataset defines; PROJ does not compute either of them from the other.
    const datum = (try geographic.datumForced()) orelse return error.TestUnexpectedResult;
    defer datum.destroy();
    const shape = (try datum.ellipsoid()) orelse return error.TestUnexpectedResult;
    defer shape.destroy();
    const ellipsoid = try shape.ellipsoidParameters();

    // Both are exact to a double: 6378137 is an integer, and
    // 298.257223563 is stored in proj.db as decimal text and read back as the
    // nearest double, whose error is at most half an ulp — 1.4e-14 here. The 1e-9
    // is four orders of magnitude above that and six orders below anything that
    // could be a wrong number.
    try expectNumberNear(6378137.0, ellipsoid.semi_major_metre, 1e-9, "WGS 84 semi-major axis");
    try expectNumberNear(298.257223563, ellipsoid.inv_flattening, 1e-9, "WGS 84 inverse flattening");

    // The registry gives WGS 84 as an inverse flattening, so PROJ derived the
    // semi-minor axis rather than reading it. That flag is how a caller knows which
    // of the two numbers is the dataset's (`src/proj.h:1483`).
    try std.testing.expect(ellipsoid.semi_minor_computed);

    // -- EPSG:32631 ---------------------------------------------------------
    const projected = try ctx.createFromDatabase("EPSG", "32631", .crs, false, null);
    defer projected.destroy();

    try expectExactString("WGS 84 / UTM zone 31N", projected.name(), "EPSG:32631 name");
    try std.testing.expectEqual(proj.Type.projected_crs, projected.getType());

    // The method is read out of the same registry the CRS came from. Both the name
    // and the code are upstream's own constants:
    // `EPSG_NAME_METHOD_TRANSVERSE_MERCATOR` is "Transverse Mercator" and
    // `EPSG_CODE_METHOD_TRANSVERSE_MERCATOR` is 9807, both at
    // `src/proj_constants.h:34-35`.
    const conversion = (try projected.crsGetCoordoperation()) orelse return error.TestUnexpectedResult;
    defer conversion.destroy();
    const method = try conversion.coordoperationMethodInfo();
    try expectExactString("Transverse Mercator", method.name, "EPSG:32631 method name");
    try expectExactString("EPSG", method.auth_name, "EPSG:32631 method authority");
    try expectExactString("9807", method.code, "EPSG:32631 method code");

    // The four parameters the contract names, matched by their EPSG **codes** rather
    // than by their order, because the codes are the registry's own identifiers and
    // the order is an implementation detail. The codes are
    // `src/proj_constants.h:299-311`:
    //
    //     8802  Longitude of natural origin
    //     8805  Scale factor at natural origin
    //     8806  False easting
    //     8807  False northing
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
            // The largest value here is 500000 m, whose ulp is 5.8e-11 m, so 1e-9
            // covers the decimal-to-binary rounding of the stored value with five
            // orders of magnitude to spare.
            try expectNumberNear(want.value, param.value, 1e-9, want.name);
        }
        if (!found) {
            std.debug.print("EPSG:32631 has no parameter with EPSG code {s}\n", .{want.code});
            return error.TestUnexpectedResult;
        }
    }
}

// ---- Fixture C: the datum shift this package cannot do -----------------------

test "fixture C: a datum shift with no grid reports the failure and never claims a coordinate" {
    const ctx = try openDatabase();
    defer ctx.destroy();

    const source = try ctx.createFromDatabase("EPSG", "4326", .crs, false, null);
    defer source.destroy();
    const target = try ctx.createFromDatabase("EPSG", "4277", .crs, false, null);
    defer target.destroy();

    // -- part one: PROJ reports that no operation exists ---------------------
    //
    // A factory that discards an operation needing a missing grid
    // (`src/proj.h:977-978`) and refuses a ballpark fallback
    // (`src/proj.h:1409-1410`) leaves nothing for 4326 to 4277 **under the
    // spatial criterion such a factory has by default**,
    // `PROJ_SPATIAL_CRITERION_STRICT_CONTAINMENT` (`src/proj.h:1003`): the
    // accurate transformations between these two datums are NTv2 and NADCON
    // shifts, this package ships no such grid, and the gridless Helmert route
    // does not satisfy strict containment. A length of zero is upstream's own
    // answer, through `proj_list_get_count`, and it is a stronger statement than
    // an error: there is no object to transform with, so no finite coordinate can
    // be claimed at all.
    //
    // The criterion is stated because parts two and three *do* find operations,
    // and that is not a contradiction: `proj_create_crs_to_crs_from_pj` asks the
    // factory for `PROJ_SPATIAL_CRITERION_PARTIAL_INTERSECTION`
    // (`src/crs_to_crs.cpp:568-569`), and the same factory answers that with a
    // non-empty list for this pair.
    const strict = try proj.OperationFactory.create(ctx, null);
    defer strict.destroy();
    strict.setGridAvailabilityUse(.discard_operation_if_missing_grid);
    strict.setAllowBallparkTransformations(false);

    const unavailable = (try strict.createOperations(source, target)) orelse return error.TestUnexpectedResult;
    defer unavailable.destroy();
    try std.testing.expectEqual(@as(c_int, 0), unavailable.len());

    // The positive control, so that zero above means "for this pair" and not "this
    // factory finds nothing anywhere": 4326 to 3857 needs no grid, and the same
    // settings must still produce it.
    const mercator = try ctx.createFromDatabase("EPSG", "3857", .crs, false, null);
    defer mercator.destroy();
    const available = (try strict.createOperations(source, mercator)) orelse return error.TestUnexpectedResult;
    defer available.destroy();
    try std.testing.expect(available.len() >= 1);

    // -- part two: asking for the best, and being told there is none ----------
    //
    // `ONLY_BEST=YES` is upstream's switch for "tell me if there is no real
    // transformation": it sets `errorIfBestTransformationNotAvailable`
    // (`src/crs_to_crs.cpp:521-526`). Upstream states what that does in its own
    // release notes — "With ONLY_BEST=YES a transformation will fail if a needed
    // grid is unavailable" (`NEWS.md:751`) — and the word there is *fail*, not
    // *refuse to build*.
    //
    // **For this pair the constructor is not where the refusal happens, and the
    // source says why.** `proj_create_crs_to_crs_from_pj` answers NULL only when
    // the factory handed it exactly one candidate and that candidate is not
    // instantiable (`src/crs_to_crs.cpp:617-641`, and again at `:758-769`). Here
    // the factory leaves several, so an object is built — as the "Set of
    // coordinate operations" shell (`src/crs_to_crs.cpp:783-795`) — and
    // `proj_trans` does the refusing: it warns about the missing grid and sets
    // `PROJ_ERR_COORD_TRANSFM_NO_OPERATION` (`src/trans.cpp:289-294`).
    //
    // So what is asserted is the refusal itself: the error coordinate, and the
    // code upstream sets for it. Upstream's `options` is a NULL-terminated
    // `const char **`, and it walks it with `getOptionValue`/`ci_starts_with`
    // (`src/crs_to_crs.cpp:471-477,505`), which calls `strlen` on each element.
    // The terminator is therefore part of the value: without it upstream reads
    // past the end.
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
        // The other route upstream has for this pair. `src/crs_to_crs.cpp:637-640`
        // destroys the candidate and returns without writing any code, so no code
        // is demanded here: a test that wanted one would be wanting something the
        // C does not do.
        error.OutOfMemory => return error.TestUnexpectedResult,
        error.NullReturn => {},
        else => return err,
    }

    // -- part three: the default route, and why a finite answer is not a shift --
    //
    // With the ballpark fallback left on, PROJ builds something, and it is right
    // to: `EPSG:4326` to `EPSG:4277` has a seven-parameter Helmert route in
    // `proj.db` that needs no grid at all. A finite coordinate here is therefore
    // not by itself a fault, and demanding a ballpark declaration would be
    // demanding something upstream does not owe — a Helmert shift is a real datum
    // shift, not a substitution.
    //
    // What must hold is the thing this case exists to catch: whatever PROJ ran
    // must be something it can run. Two facts prove that, and both are asked of
    // the operation PROJ names as the one it used —
    // `proj_trans_get_last_used_operation` (`src/proj.h:630`,
    // `src/trans.cpp:363-377`). Asking the object `crsToCrsFromPj` returned would
    // be asking about the "Set of coordinate operations" shell, which is not a
    // coordinate operation at all (`src/crs_to_crs.cpp:783-795`):
    //
    //   * every grid that operation lists must be one this build can reach, which
    //     is upstream's own `out_available` answer (`src/proj.h:1533`). The
    //     network is off and this package ships no grid, so an unavailable grid
    //     means the coordinate came out of a step that never ran;
    //   * and it must be instantiable as it reports itself
    //     (`src/proj.h:1503-1504`).
    if (ctx.crsToCrsFromPj(source, target, null, null)) |built| {
        const operation = built;
        defer operation.destroy();

        const result = operation.trans(.fwd, proj.coord(50.0, -2.0, 0.0, 0.0));
        if (proj.isErrorCoordinate(result)) {
            // A real refusal. Name the code, and accept only the ones upstream
            // documents for a transformation that could not be performed:
            // `src/trans.cpp:344` for "no operation", `src/trans.cpp:410` for
            // failures that do not share a code, and `src/grids.cpp:3235-3236` /
            // `:3561-3562` for a grid file that is not there.
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
            // No object at all is also a clean refusal, and the factory above already
            // proved there is nothing to build one from.
        },
        else => return err,
    }
}

// ---- Supplement: a malformed definition ---------------------------------------

test "supplement: a malformed definition is refused with the code upstream sets for it" {
    const ctx = try openDatabase();
    defer ctx.destroy();

    // An unknown `+proj=` name. Upstream's own path: the projection lookup fails and
    // `free_params` records `PROJ_ERR_INVALID_OP_ILLEGAL_ARG_VALUE`
    // (`src/init.cpp:536-539`), which is 1027. The facade maps the NULL to
    // `error.NullReturn`; the code is on the context and is read here rather than
    // folded into the error, because `src/crs_to_crs.cpp:589-591` shows upstream has
    // at least one NULL path that sets no code at all.
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

    // A `+proj=` name shorter than the six characters upstream requires, which is
    // the neighbouring refusal at `src/init.cpp:528-531` and the same code.
    try std.testing.expectError(error.NullReturn, ctx.createFromProjString("+proj=ab"));
    try std.testing.expectEqual(
        proj.ErrorCode.invalid_op_illegal_arg_value,
        ctx.errno(),
    );

    // Text that is not WKT at all. **There is no error code to check here, and
    // that is a fact about upstream rather than a gap in the test.** The WKT route
    // catches the parse exception, logs it and returns NULL without touching the
    // context slot (`src/iso19111/c_api.cpp:762-773`) — it reports the reason
    // through the `out_grammar_errors` out-parameter instead, which this facade
    // passes as null and does not expose. So `errno` still holds whatever the
    // previous call left there, and asserting a code here would be asserting a
    // number this call never wrote. The two cases above are the ones that do set
    // one, and they set it on the line `src/init.cpp` names.
    try std.testing.expectError(
        error.NullReturn,
        ctx.createFromWkt("THIS IS NOT A WKT STRING", null),
    );
    try std.testing.expectError(
        error.NullReturn,
        ctx.createFromWkt("GEOGCRS[\"unterminated\"", null),
    );
}

// ---- Supplement: the database this build opened ------------------------------

test "supplement: the database this build opened can be read for its own metadata" {
    const ctx = try openDatabase();
    defer ctx.destroy();

    // `DATABASE.LAYOUT.VERSION.MAJOR` is one of the keys upstream documents at
    // `src/iso19111/c_api.cpp:425-426`. Reading it proves the query reached SQLite
    // and not a cached answer, and that the copy this facade hands back is the
    // value the database holds rather than a pointer into a slot the next call
    // overwrites.
    const major_text = (try ctx.databaseMetadata(std.testing.allocator, "DATABASE.LAYOUT.VERSION.MAJOR")) orelse {
        std.debug.print("proj.db has no DATABASE.LAYOUT.VERSION.MAJOR\n", .{});
        return error.TestUnexpectedResult;
    };
    defer std.testing.allocator.free(major_text);

    try std.testing.expect(major_text.len > 0);
    for (major_text) |byte| {
        try std.testing.expect(byte >= '0' and byte <= '9');
    }

    // `proj.db` is the file name the package installs (contract §4), so a database
    // path that does not end in it means the build wired the wrong directory.
    const path = (try ctx.databasePath(std.testing.allocator)) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(path);
    try std.testing.expect(std.mem.endsWith(u8, path, "proj.db"));

    // Two metadata reads at once must not collide: upstream keeps one slot per
    // context for this (`src/iso19111/c_api.cpp:445-466`), which is exactly why the
    // facade copies. Two copies of two different keys are two different strings.
    const first = (try ctx.databaseMetadata(std.testing.allocator, "DATABASE.LAYOUT.VERSION.MINOR")) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(first);
    const second = (try ctx.databaseMetadata(std.testing.allocator, "EPSG.VERSION")) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(second);
    try std.testing.expect(!std.mem.eql(u8, first, second));
    try std.testing.expect(first.len > 0);
    try std.testing.expect(second.len > 0);
}

// ---- Supplement: WKT self-agreement -------------------------------------------

test "supplement: WKT export and re-import agree with each other, which is self-agreement and nothing more" {
    const ctx = try openDatabase();
    defer ctx.destroy();

    var original = try ctx.createFromDatabase("EPSG", "4326", .crs, false, null);
    defer original.destroy();

    const wkt = original.asWkt(.wkt2_2019, null) orelse return error.TestUnexpectedResult;

    var reimported = try ctx.createFromWkt(wkt, null);
    defer reimported.destroy();

    // **This proves that one direction of the same code agrees with the other. It
    // does not prove that either is right.** A facade that wrote the same wrong
    // string twice would pass it. The independent evidence about EPSG:4326 is
    // Fixture B, which reads its name, code and type out of `proj.db`; the
    // independent evidence about the projection is Fixture A, which compares a
    // transformed coordinate against a published formula. This case earns its place
    // only by covering a path neither of those does: text that survives a full
    // parse and re-export.
    try expectExactString(
        original.name().?,
        reimported.name(),
        "WKT round trip name",
    );
    try std.testing.expectEqual(original.getType(), reimported.getType());
    try std.testing.expect(reimported.isEquivalentTo(original, .equivalent));
    try std.testing.expectEqualStrings("EPSG", reimported.idAuthName(0).?);
    try std.testing.expectEqualStrings("4326", reimported.idCode(0).?);

    // The dialect guesser agrees with the exporter about the text it was handed.
    try std.testing.expectEqual(.wkt2_2019, ctx.guessWktDialect(wkt));
}