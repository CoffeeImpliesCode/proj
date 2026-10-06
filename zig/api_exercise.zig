// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md for what that identifier covers.

//! Compile-only exercise of every public method of the facade.
//!
//! **This file is compiled and is never run.** It exists for exactly one reason:
//! Zig analyses a function body when something calls it, so a compile that never
//! reaches a facade method proves nothing about that method. The `test` block at
//! the foot of the file calls `exercise`, which is what instantiates every body
//! below and turns "the declaration exists" into "the body type-checks"; the
//! build graph compiles that test artifact and attaches **no run step** to it.
//! There is deliberately **no `main`**, so nothing here can be run as a program
//! even by accident.
//!
//! `zig build check` compiles this file as the root of a module for all six cross
//! targets, and `zig build test` compiles it for the requested target. Neither
//! runs it.
//!
//! The behavioural proof lives elsewhere and is not duplicated here: `tests.zig`
//! checks a coordinate transformation against an independent known answer and a
//! datum shift against the reported failure, `smoke.zig` runs one transformation
//! natively, and `consumer/src/main.zig` repeats the check as a dependent.
//!
//! ## What the checks inside are
//!
//! Most of them are about *calling* the method, not about its answer. Where a
//! check is cheap and true of every build that reaches it — that a coordinate's
//! union arms alias, that a degree→radian→degree round trip comes back, that
//! `proj_errno_set(P, 0)` is not a clear — it is an ordinary comparison, so the
//! compile also proves the return type is what the doc comment says. Where a check
//! would depend on `proj.db`, on a grid file or on a network it is deliberately
//! **absent**, and the doc comment says which. A check that passed only because the
//! data was missing would be worth nothing here.
//!
//! Every constructor that needs a database is called through a small
//! `refusalOrSuccess` helper rather than a bare `try`, so a build with no
//! `proj.db` still reaches every *other* method instead of stopping at the first
//! `EPSG:` lookup.
//!
//! ## The module this file is compiled in must carry `c` and the archive
//!
//! This file never names `c` as an import of its own beyond `proj.c`, and that is
//! not evidence that `c` is unnecessary: `root.zig` resolves its own
//! `@import("c")` in the import table of whichever module it is being analysed as
//! part of. Under `zig build check` this file is the root of a fresh module, so
//! that module — not the facade's — has to supply `c`, the `rt` loader core in a
//! linked build, and the linked archive. Dropping them fails with a missing-import
//! error naming this file rather than the build line that omitted them.
//!
//! ## The provider, in a runtime-loading build
//!
//! Under `-Druntime=true` nothing native is linked into the module, so a real run
//! would have to name a provider before anything else. This file is never run, and
//! the guard below is a runtime `if` rather than a `comptime` one precisely so that
//! `proj.load`'s body is instantiated and type-checked in **both** configurations:
//! the linked build type-checks the panic path, the runtime build type-checks the
//! dispatch call.

const std = @import("std");

// The facade, reached by file path rather than by module name. Whichever module
// this file is analysed as part of still has to supply `c`; see above.
const proj = @import("root.zig");

/// The raw translated route, reached the way `zig/root.zig` itself reaches it.
/// Under `-Druntime=true` this is the generated dispatch, so every call through
/// `proj.c` here is a call through the resolved table.
const c = proj.c;

/// Everything this file can fail with.
///
/// `UnexpectedResult` is its own verdict: a public call answered something that
/// contradicts an expectation this file states. The facade's own `Error` is carried
/// through unchanged rather than flattened into that single name, so a refusal that
/// reaches the caller still says which refusal it was.
pub const Failure = proj.Error || proj.LoadError || error{
    /// A call answered something this file expected not to happen.
    UnexpectedResult,
};

/// A path no machine has, so that a load attempt would fail for a real reason
/// rather than by guesswork. Never opened: this file is compiled, not run.
const absent_provider = "/proj-no-such-directory/libproj.so.25";

/// A `+proj=` definition that needs nothing but the numbers in it.
///
/// No `+init=epsg:`, no `+datum=` lookup and no grid, so the only thing it asks of
/// this build is that the C parser and the compiled core are present.
const plain_geographic = "+proj=longlat +a=6378137 +b=6378137 +no_defs";
const plain_mercator =
    "+proj=merc +a=6378137 +b=6378137 +lat_ts=0 +lon_0=0 +x_0=0 +y_0=0 +k=1 +units=m +no_defs";

fn expect(condition: bool) Failure!void {
    if (!condition) return error.UnexpectedResult;
}

/// Assert that `got` is within `tolerance` of `want`. Two NaNs count as equal,
/// because upstream answers NaN for out-of-range input and a check that could not
/// say so would be checking the wrong thing.
fn expectNear(want: f64, got: f64, tolerance: f64) Failure!void {
    if (std.math.isNan(want) or std.math.isNan(got)) {
        if (std.math.isNan(want) and std.math.isNan(got)) return;
        return error.UnexpectedResult;
    }
    if (!std.math.approxEqAbs(f64, want, got, tolerance)) return error.UnexpectedResult;
}

/// The result type `refusalOrSuccess` hands back for `call`.
///
/// One optional level deeper than the call's own payload when that payload is not
/// already optional, so null means "upstream refused" and non-null is the value it
/// returned. A call that already answers an optional — `ObjectList.get` — keeps its
/// own type: there is no second meaning to add, and `??T` would make every caller
/// unwrap twice for no extra information.
fn refusalResult(comptime call: type) type {
    const payload = @typeInfo(call).error_union.payload;
    return switch (@typeInfo(payload)) {
        .optional => payload,
        else => ?payload,
    };
}

/// Call a fallible facade method, treating upstream's own refusals as "not this
/// build's problem" and only a mistake on our side as a failure.
///
/// The point is reach, not verdict: a constructor that needs `proj.db` must not
/// stop the exercise before the methods after it are instantiated. The caller
/// captures one optional level, which for the common `Error!T` case is the one
/// this function adds.
fn refusalOrSuccess(call: anytype) Failure!refusalResult(@TypeOf(call)) {
    return call catch |err| switch (err) {
        error.OutOfMemory => error.UnexpectedResult,
        error.NullReturn, error.UpstreamRefused => null,
        else => return err,
    };
}

/// The loader route, in whichever configuration this build is.
///
/// Compiled, never run: reaching the line below would attempt to open a path that
/// does not exist and fail. What is proved here is that the call type-checks
/// against the dispatch in a runtime-loading build and against the panic path in a
/// linked one.
fn loadProvider() Failure!void {
    if (!proj.runtime_loaded) return;
    try proj.load(.{ .path = absent_provider });
    _ = proj.loadedSource();
}

/// Call every public method of the facade once.
///
/// Nothing here asserts a number that depends on `proj.db`, on a grid file or on a
/// network. The data-dependent proofs are in `tests.zig`; this file is about
/// reachability and about the handful of invariants that hold without any data.
pub fn exercise() Failure!void {
    try loadProvider();

    try moduleLevel();
    try contextAndObjects();
    try databaseQueries();
    try transformationAndOperations();

    // Every handle created above was destroyed on its own path. `cleanup` is last
    // because it is upstream's process-wide teardown (`src/proj.h:816`) and nothing
    // may use PROJ afterwards.
    proj.cleanup();
}

// The reference that makes this file more than a pile of declarations.
//
// A `test` block's body is semantically analysed when the test artifact is
// **compiled**, which is what `addExercise` in `build.zig` asks for, and this build
// graph never runs that artifact. Calling `exercise` from here is therefore what
// instantiates every body below — Zig analyses a function body when something
// calls it, not when it is declared — while no call in this file is ever
// executed. Running it would open `absent_provider` under `-Druntime=true` and
// would tear down PROJ's process-wide caches, which is upstream's one-way
// `cleanup` (`:144-148`).
test "facade API exercise: every public method is instantiated" {
    try exercise();
}

// ---- Module level ------------------------------------------------------------

fn moduleLevel() Failure!void {
    const reported = proj.version();
    // The only thing asserted is the shape: a version is three numbers and three
    // possibly-absent strings. What the numbers are belongs to the provenance and
    // licence gates, not here.
    try expect(reported.major >= 0);
    try expect(reported.minor >= 0);
    try expect(reported.patch >= 0);
    _ = reported.release;
    _ = reported.version;
    _ = reported.searchpath;

    const point = proj.coord(1.0, 2.0, 3.0, 4.0);
    try expect(point.v[0] == 1.0 and point.v[1] == 2.0 and point.v[2] == 3.0 and point.v[3] == 4.0);

    // The union arms are the same four words read differently, which is what
    // `src/proj.h:313-314` says the union exists for. Reading them through `lp` and
    // `xyzt` turns that claim into a comparison.
    try expect(point.lp.lam == 1.0 and point.lp.phi == 2.0);
    try expect(point.xyzt.x == 1.0 and point.xyzt.y == 2.0);
    try expect(@sizeOf(proj.Coord) == 4 * @sizeOf(f64));

    // A degree→radian→degree round trip is one multiplication by a constant each
    // way, so for these values it is exact to a double.
    try expectNear(137.0, proj.toDeg(proj.toRad(137.0)), 1e-12);

    try expect(!proj.isErrorCoordinate(point));
    try expect(proj.isErrorCoordinate(proj.coord(
        std.math.inf(f64),
        std.math.inf(f64),
        std.math.inf(f64),
        std.math.inf(f64),
    )));

    try expectNear(5.0, proj.xyDistance(proj.coord(0, 0, 0, 0), proj.coord(3, 4, 0, 0)), 0.0);
    try expectNear(13.0, proj.xyzDistance(proj.coord(0, 0, 0, 0), proj.coord(3, 4, 12, 0)), 0.0);

    // Both releases are called with null, which is the one argument that is
    // unconditionally safe for them: `free(NULL)` is defined to do nothing
    // (`src/iso19111/c_api.cpp:9557`) and `proj_int_list_destroy` guards on the
    // pointer the same way (`src/proj.h:1300`). Anything else here would be a
    // pointer this file does not own.
    proj.freeString(null);
    proj.freeIntList(null);

    // The struct aliases are the translated types themselves, so a literal with
    // upstream's field names type-checking at all is the layout claim.
    const xyzt: proj.Xyzt = .{ .x = 1, .y = 2, .z = 3, .t = 4 };
    try expect(xyzt.t == 4.0);
    const lpzt: proj.Lpzt = .{ .lam = 1, .phi = 2, .z = 3, .t = 4 };
    try expect(lpzt.phi == 2.0);

    // `PJ_FACTORS` and `PJ_PROJ_INFO` carry upstream's own field names; reading
    // them here is what instantiates the aliases.
    const scaling: proj.Factors = undefined;
    _ = scaling.meridional_scale;
    _ = scaling.parallel_scale;
    _ = scaling.areal_scale;
    _ = scaling.angular_distortion;
    _ = scaling.meridian_parallel_angle;
    _ = scaling.meridian_convergence;
    _ = scaling.tissot_semimajor;
    _ = scaling.tissot_semiminor;
    _ = scaling.dx_dlam;
    _ = scaling.dx_dphi;
    _ = scaling.dy_dlam;
    _ = scaling.dy_dphi;

    const about: proj.ProjInfo = undefined;
    _ = about.id;
    _ = about.description;
    _ = about.definition;
    _ = about.has_inverse;
    _ = about.accuracy;

    // The raw route, called exactly as a C consumer calls it, so the translated
    // declarations behind the facade are instantiated too.
    const raw_info: proj.Info = c.proj_info();
    try expect(raw_info.major == reported.major);
    _ = raw_info.minor;
    _ = raw_info.patch;
    _ = raw_info.paths;
    _ = raw_info.path_count;
}

// ---- Context, objects and their identity -------------------------------------

fn contextAndObjects() Failure!void {
    const ctx = try proj.Context.create();
    defer ctx.destroy();

    const second = try ctx.clone();
    defer second.destroy();
    try expect(second.ptr != ctx.ptr);

    // Autoclose is on upstream; asking for it is a request. Which default the
    // process has is not asserted, because `src/proj.h:1189-1190` declares none.
    ctx.setAutocloseDatabase(true);
    ctx.useProj4InitRules(false);
    try expect(!ctx.getUseProj4InitRules(false));
    try expect(!ctx.getUseProj4InitRules(true));

    // The log level call returns the previous one, so setting and reading it back
    // is one round trip rather than two independent statements.
    const previous = ctx.logLevel(.none);
    try expect(@intFromEnum(ctx.logLevel(previous)) == @intFromEnum(previous));
    ctx.logFunc(null, null);

    if (try refusalOrSuccess(ctx.createFromProjString(plain_mercator))) |object| {
        const op = object;
        defer op.destroy();
        try objectIdentity(ctx, op);
        try errnoQuartet(op);
    }

    const argv = [_][*:0]const u8{ "+proj=utm", "+zone=31", "+ellps=WGS84" };
    if (try refusalOrSuccess(ctx.createArgv(&argv))) |object| {
        const op = object;
        defer op.destroy();
        try objectIdentity(ctx, op);
    }

    if (try refusalOrSuccess(ctx.createFromWkt(
        "GEOGCS[\"WGS 84\",DATUM[\"WGS_1984\",SPHEROID[\"WGS 84\",6378137,298.257223563]],"
            ++ "PRIMEM[\"Greenwich\",0],UNIT[\"degree\",0.0174532925199433],"
            ++ "AUTHORITY[\"EPSG\",\"4326\"]]",
        null,
    ))) |object| {
        const crs = object;
        defer crs.destroy();
        try objectIdentity(ctx, crs);
        // `not_wkt` is a normal answer, not a failure: this is a guess about text
        // and it builds nothing (`src/proj.h:1204-1205`).
        try expect(ctx.guessWktDialect("not wkt at all") == .not_wkt);
    }

    if (try refusalOrSuccess(ctx.createFromDatabase("EPSG", "4326", .crs, false, null))) |object| {
        const crs = object;
        defer crs.destroy();
        // The one registry fact that needs no projection: an EPSG CRS reports its
        // own authority and code, which come out of `proj.db`.
        if (crs.idAuthName(0)) |authority| {
            try expect(std.mem.eql(u8, authority, "EPSG"));
        }
        if (crs.idCode(0)) |code| {
            try expect(std.mem.eql(u8, code, "4326"));
        }
    }

    _ = ctx.errno();
    _ = ctx.errnoString(0);
    _ = ctx.errnoString(proj.ErrorCode.coord_transfm_no_operation);
}

/// `proj_errno_set`, `proj_errno_reset` and `proj_errno_restore` read as one
/// contract, which is exactly what upstream's own doc comment at
/// `src/ctx.cpp:275-294` describes.
///
/// Two facts make this worth a comparison rather than three calls: a zero argument
/// is *ignored* rather than treated as a clear (`:242-243` and `:261-262`), and
/// `proj_errno_restore` returns zero whatever it does (`:264`). Both would pass a
/// "it did not crash" test and fail here.
fn errnoQuartet(op: proj.Object) Failure!void {
    try expect(op.errno() == proj.ErrorCode.other_api_misuse or op.errno() == 0);

    try expect(op.errnoSet(0) == 0);
    try expect(op.errnoSet(proj.ErrorCode.coord_transfm_no_operation) ==
        proj.ErrorCode.coord_transfm_no_operation);
    try expect(op.errno() == proj.ErrorCode.coord_transfm_no_operation);

    // Zero does not clear: the code set a moment ago is still there.
    try expect(op.errnoSet(0) == 0);
    try expect(op.errno() == proj.ErrorCode.coord_transfm_no_operation);

    const saved = op.errnoReset();
    try expect(saved == proj.ErrorCode.coord_transfm_no_operation);
    try expect(op.errno() == 0);

    // Restore returns zero whatever it does, and puts the saved code back.
    try expect(op.errnoRestore(saved) == 0);
    try expect(op.errno() == proj.ErrorCode.coord_transfm_no_operation);

    try expect(op.errnoRestore(0) == 0);
    try expect(op.errno() == proj.ErrorCode.coord_transfm_no_operation);

    _ = op.errnoReset();
    try expect(op.errno() == 0);
}

/// The whole identity and export surface of one object.
fn objectIdentity(ctx: proj.Context, object: proj.Object) Failure!void {
    const kind = object.getType();
    try expect(@intFromEnum(kind) >= 0);
    _ = object.isCrs();
    _ = object.isDeprecated();
    _ = object.isEquivalentTo(object, .strict);
    _ = object.isEquivalentTo(object, .equivalent);
    _ = object.isEquivalentTo(object, .equivalent_except_axis_order_geogcrs);
    _ = object.name();
    _ = object.idAuthName(0);
    _ = object.idCode(0);
    _ = object.scope();
    _ = object.remarks();

    if (try refusalOrSuccess(object.areaOfUse())) |area| {
        try expect(area.west_lon_degree <= area.east_lon_degree);
        _ = area.south_lat_degree;
        _ = area.north_lat_degree;
        _ = area.name;
    }

    // Exports are borrows, not copies, and one object holds one string per form,
    // so the next call of the same form replaces the last: reading all of them here
    // is a reminder that they are different slots, not different allocations.
    _ = object.asWkt(.wkt2_2015, null);
    _ = object.asWkt(.wkt2_2015_simplified, null);
    _ = object.asWkt(.wkt2_2019, null);
    _ = object.asWkt(.wkt2_2019_simplified, null);
    _ = object.asWkt(.wkt2_2018, null);
    _ = object.asWkt(.wkt2_2018_simplified, null);
    _ = object.asWkt(.wkt1_gdal, null);
    _ = object.asWkt(.wkt1_esri, null);
    _ = object.asProjString(.proj5, null);
    _ = object.asProjString(.proj4, null);
    _ = object.asProjJson(null);

    const about = object.pjInfo();
    _ = about.accuracy;

    if (try refusalOrSuccess(object.nonDeprecated())) |replacements| {
        const list = replacements;
        defer list.destroy();
        try expect(list.len() >= 0);
    }

    // `assignContext` rebinds the borrowed pointer; this file puts it straight back
    // to the context it already had, so the pairing the handle documents is the
    // pairing that survives.
    object.assignContext(ctx);
}

// ---- Database queries --------------------------------------------------------

fn databaseQueries() Failure!void {
    const ctx = try proj.Context.create();
    defer ctx.destroy();
    const gpa = std.heap.page_allocator;

    // These two are the copying methods, because upstream keeps one slot per
    // context for each and the next call overwrites it. The copies are released
    // here so the exercise leaves nothing behind.
    if (try ctx.databasePath(gpa)) |path| {
        defer gpa.free(path);
        try expect(path.len > 0);
    }
    if (try ctx.databaseMetadata(gpa, "PROJ.VERSION")) |value| {
        defer gpa.free(value);
        try expect(value.len > 0);
    }
    // A key with no value is null and that is not an error
    // (`src/iso19111/c_api.cpp:457-459`).
    if (try ctx.databaseMetadata(gpa, "NO.SUCH.KEY")) |value| {
        gpa.free(value);
        return error.UnexpectedResult;
    }

    const paths = [_][*:0]const u8{ "/nonexistent/proj-data" };
    ctx.setSearchPaths(@intCast(paths.len), &paths);
    ctx.setSqlite3VfsName("unix");
    _ = ctx.setDatabasePath(null, null, null);

    // The network is the switch Fixture C depends on; this file only asks for the
    // state it asked for.
    _ = ctx.setNetworkEnabled(false);
    try expect(!ctx.networkEnabled());
    _ = ctx.setNetworkEnabled(true);
    try expect(ctx.networkEnabled());
    _ = ctx.setNetworkEnabled(false);

    ctx.setUserWritableDirectory("/nonexistent/proj-user-writable", false);
    _ = ctx.userWritableDirectory(false);

    if (try refusalOrSuccess(ctx.authoritiesFromDatabase())) |authorities| {
        const list = authorities;
        defer list.destroy();
        try expect(list.len() > 0);
        try expect(list.at(0) != null);
        try expect(list.at(list.len()) == null);
    }

    if (try refusalOrSuccess(ctx.codesFromDatabase("EPSG", .geographic_2d_crs, false))) |codes| {
        const list = codes;
        defer list.destroy();
        try expect(list.len() > 0);
    }

    try parametersAndLists(ctx);

    // Celestial bodies are a separate array with its own release, which is why it
    // is a second type and not another field of the unit list.
    if (try refusalOrSuccess(proj.celestialBodyListFromDatabase(ctx, null))) |bodies| {
        const list = bodies;
        defer list.destroy();
        try expect(list.len() > 0);
        if (list.at(0)) |body| {
            _ = body.auth_name;
            _ = body.name;
        }
    }
}

fn parametersAndLists(ctx: proj.Context) Failure!void {
    const parameters = try proj.crsListParametersCreate();
    defer parameters.destroy();

    if (try refusalOrSuccess(proj.crsInfoListFromDatabase(ctx, "EPSG", parameters.ptr))) |list| {
        const records = list;
        defer records.destroy();
        try expect(records.len() > 0);
        if (records.at(0)) |record| {
            _ = record.auth_name;
            _ = record.code;
            _ = record.name;
            _ = record.type;
            _ = record.deprecated;
            _ = record.bbox_valid;
            _ = record.west_lon_degree;
            _ = record.south_lat_degree;
            _ = record.east_lon_degree;
            _ = record.north_lat_degree;
            _ = record.area_name;
            _ = record.projection_method_name;
            _ = record.celestial_body_name;
        }
        try expect(records.at(records.len()) == null);
    }

    if (try refusalOrSuccess(proj.unitsFromDatabase(ctx, null, "linear", false))) |list| {
        const records = list;
        defer records.destroy();
        try expect(records.len() > 0);
        if (records.at(0)) |record| {
            _ = record.auth_name;
            _ = record.code;
            _ = record.name;
            _ = record.category;
            _ = record.conv_factor;
            _ = record.proj_short_name;
            _ = record.deprecated;
        }
    }
}

// ---- Transformation and operations -------------------------------------------

fn transformationAndOperations() Failure!void {
    const ctx = try proj.Context.create();
    defer ctx.destroy();

    var area = try proj.Area.create();
    defer area.destroy();
    area.setBbox(-10.0, -10.0, 10.0, 10.0);
    area.setName("ten by ten");

    const source = try ctx.createFromProjString(plain_geographic);
    defer source.destroy();
    const target = try ctx.createFromProjString(plain_mercator);
    defer target.destroy();

    // This one needs `proj.db`: building an operation between two CRS objects goes
    // through the factory, which reads the registry. A build without a database
    // skips the surface below it rather than stopping.
    if (try refusalOrSuccess(ctx.crsToCrsFromPj(source, target, &area, null))) |built| {
        const operation = built;
        defer operation.destroy();
        try transformSurface(operation);

        if (try refusalOrSuccess(operation.coordoperationCreateInverse())) |reverse| {
            const backwards = reverse;
            defer backwards.destroy();
            try transformSurface(backwards);
        }

        try operationFactory(ctx, source, target);
    }

    try crsSurface(source, target);

    // The `crsToCrs` form takes no options, so the two forms are told apart by
    // their own signatures rather than by a shared parameter list.
    if (try refusalOrSuccess(ctx.crsToCrs("EPSG:4326", "EPSG:3857", &area))) |built| {
        const other = built;
        defer other.destroy();
        try transformSurface(other);
    }
}

/// Everything a coordinate operation can be asked to do with a coordinate.
fn transformSurface(operation: proj.Object) Failure!void {
    // `Direction.ident` is documented to return the coordinate untouched
    // (`src/trans.cpp:222-223`), which is a fact about the direction value and
    // needs no CRS to check.
    const identity = operation.trans(.ident, proj.coord(1.0, 2.0, 3.0, 4.0));
    try expect(identity.v[0] == 1.0 and identity.v[1] == 2.0);

    const forward = operation.trans(.fwd, proj.coord(0.0, 0.0, 0.0, 0.0));
    // A result is either a coordinate or upstream's refusal, and upstream says which
    // by recording an error when it refuses (`src/internal.cpp:65-68`).
    try expect(!proj.isErrorCoordinate(forward) or operation.errno() != 0);

    _ = operation.angularInput(.fwd);
    _ = operation.angularOutput(.fwd);
    _ = operation.degreeInput(.fwd);
    _ = operation.degreeOutput(.fwd);

    var batch = [_]proj.Coord{
        proj.coord(0.0, 0.0, 0.0, 0.0),
        proj.coord(1.0, 1.0, 0.0, 0.0),
        proj.coord(2.0, 2.0, 0.0, 0.0),
    };
    _ = operation.transArray(.fwd, &batch);

    // `transGeneric` is the stride-based form: each column is its own array with
    // its own stride in bytes and its own count, and a count of one means a
    // broadcast constant (`src/trans.cpp:427-436`). A null column means "not
    // supplied", which is how `z` and `t` are left out of a 2D transform.
    var xs = [_]f64{ 0.0, 1.0, 2.0 };
    var ys = [_]f64{ 0.0, 1.0, 2.0 };
    const completed = operation.transGeneric(
        .fwd,
        &xs,
        @sizeOf(f64),
        xs.len,
        &ys,
        @sizeOf(f64),
        ys.len,
        null,
        0,
        0,
        null,
        0,
        0,
    );
    try expect(completed <= 3);

    if (try refusalOrSuccess(operation.transBounds(
        .fwd,
        .{ .xmin = -1, .ymin = -1, .xmax = 1, .ymax = 1 },
        21,
    ))) |box| {
        try expect(box.xmin <= box.xmax and box.ymin <= box.ymax);
    }

    if (try refusalOrSuccess(operation.lastUsedOperation())) |last| {
        const chosen = last;
        defer chosen.destroy();
        _ = chosen.name();
    }

    _ = operation.roundtrip(.fwd, 1, &batch);

    // The angular distance needs a geodesic on the object, which only an operation
    // carrying one has; `HUGE_VAL` is upstream's answer when it does not
    // (`src/dist.cpp:43-45`), so only the call is made here.
    _ = operation.lpDist(proj.coord(0, 0, 0, 0), proj.coord(1, 1, 0, 0));

    const scaling = operation.factors(proj.coord(0.0, 0.0, 0.0, 0.0));
    _ = scaling.meridional_scale;
    _ = scaling.parallel_scale;

    try coordoperationSurface(operation);
}

/// Everything that can be asked about a coordinate operation's own description.
fn coordoperationSurface(operation: proj.Object) Failure!void {
    if (try refusalOrSuccess(operation.coordoperationMethodInfo())) |method| {
        _ = method.name;
        _ = method.auth_name;
        _ = method.code;
    }

    _ = operation.coordoperationAccuracy();
    const parameter_count = operation.coordoperationParamCount();
    try expect(parameter_count >= 0);

    var index: c_int = 0;
    while (index < parameter_count) : (index += 1) {
        if (operation.coordoperationParam(index)) |param| {
            _ = param.name;
            _ = param.auth_name;
            _ = param.code;
            _ = param.value;
            _ = param.value_string;
            _ = param.unit_conv_factor;
            _ = param.unit_name;
            _ = param.unit_auth_name;
            _ = param.unit_code;
            _ = param.unit_category;
        } else |err| switch (err) {
            error.OutOfMemory => return error.UnexpectedResult,
            error.UpstreamRefused => break,
            else => |other| return other,
        }
    }

    const grids = operation.coordoperationGridUsedCount();
    try expect(grids >= 0);
    var grid_index: c_int = 0;
    while (grid_index < grids) : (grid_index += 1) {
        if (operation.coordoperationGridUsed(grid_index)) |grid| {
            _ = grid.short_name;
            _ = grid.full_name;
            _ = grid.package_name;
            _ = grid.url;
            _ = grid.direct_download;
            _ = grid.open_license;
            _ = grid.available;
        } else |err| switch (err) {
            error.OutOfMemory => return error.UnexpectedResult,
            error.UpstreamRefused => break,
            else => |other| return other,
        }
    }

    // The pair of questions that separates a real transformation from a fallback.
    _ = operation.coordoperationHasBallparkTransformation();
    _ = operation.coordoperationIsInstantiable();

    const steps = operation.concatoperationStepCount();
    try expect(steps >= 0);
    if (steps > 0) {
        if (try refusalOrSuccess(operation.concatoperationStep(0))) |step| {
            const first = step;
            defer first.destroy();
            _ = first.name();
        }
    }
}

fn operationFactory(ctx: proj.Context, source: proj.Object, target: proj.Object) Failure!void {
    const factory = try proj.OperationFactory.create(ctx, null);
    defer factory.destroy();

    factory.setDesiredAccuracy(1.0);
    factory.setAreaOfInterest(-180.0, -90.0, 180.0, 90.0);
    factory.setSpatialCriterion(.partial_intersection);
    factory.setDiscardSuperseded(true);
    factory.setAllowUseIntermediateCrs(.never);

    // The two settings Fixture C depends on, asked here so every enum value is
    // instantiated even in a build that never reaches a database.
    factory.setGridAvailabilityUse(.discard_operation_if_missing_grid);
    factory.setGridAvailabilityUse(.used_for_sorting);
    factory.setGridAvailabilityUse(.ignored);
    factory.setGridAvailabilityUse(.known_available);
    factory.setAllowBallparkTransformations(false);

    if (try refusalOrSuccess(factory.createOperations(source, target))) |candidates| {
        const list = candidates;
        defer list.destroy();
        try expect(list.len() >= 0);

        const suggested = list.suggestedOperation(.fwd, proj.coord(0.0, 0.0, 0.0, 0.0));
        try expect(suggested >= -1 or suggested < list.len());

        if (list.len() > 0) {
            if (try refusalOrSuccess(list.get(0))) |best| {
                var chosen = best;
                defer chosen.destroy();
                try coordoperationSurface(chosen);
            }
        }
        try expect((try refusalOrSuccess(list.get(list.len()))) == null);
    }
}

fn crsSurface(source: proj.Object, target: proj.Object) Failure!void {
    _ = source.isDerived();
    _ = source.isDynamic();
    _ = source.celestialBodyName();
    _ = try source.sourceCrs();
    _ = try source.targetCrs();
    _ = try source.crsGetCoordoperation();

    if (try refusalOrSuccess(source.normalizeForVisualization())) |normalized| {
        const visual = normalized;
        defer visual.destroy();
        // The point of the call: the visual route and the authority route are two
        // different objects, and this is where the axis order differs.
        try expect(visual.ptr != source.ptr);
    }

    for ([_]proj.Object{ source, target }) |each| {
        if (try refusalOrSuccess(each.geodeticCrs())) |geodetic| {
            const g = geodetic;
            defer g.destroy();
            try ellipsoidAndMeridian(g);
        }
        if (try refusalOrSuccess(each.datum())) |datum| {
            const d = datum;
            defer d.destroy();
            _ = d.name();
        }
        if (try refusalOrSuccess(each.datumEnsemble())) |ensemble| {
            const e = ensemble;
            defer e.destroy();
            _ = e.name();
        }
        if (try refusalOrSuccess(each.datumForced())) |forced| {
            const f = forced;
            defer f.destroy();
            _ = f.name();
        }
        if (try refusalOrSuccess(each.horizontalDatum())) |horizontal| {
            const h = horizontal;
            defer h.destroy();
            _ = h.name();
        }
        if (try refusalOrSuccess(each.subCrs(0))) |component| {
            const part = component;
            defer part.destroy();
            _ = part.name();
        }
        if (try refusalOrSuccess(each.createBoundCrs(null, null))) |bound| {
            const b = bound;
            defer b.destroy();
            _ = b.getType();
        }
        try coordinateSystemSurface(each);
    }
}

fn coordinateSystemSurface(crs: proj.Object) Failure!void {
    if (try refusalOrSuccess(crs.coordinateSystem())) |built| {
        const cs = built;
        defer cs.destroy();
        _ = cs.csType();
        const axes = cs.csAxisCount();
        try expect(axes >= 0);

        var axis: c_int = 0;
        while (axis < axes) : (axis += 1) {
            if (cs.csAxisInfo(axis)) |info| {
                _ = info.name;
                _ = info.abbrev;
                _ = info.direction;
                _ = info.unit_conv_factor;
                _ = info.unit_name;
                _ = info.unit_auth_name;
                _ = info.unit_code;
            } else |err| switch (err) {
                error.OutOfMemory => return error.UnexpectedResult,
                error.UpstreamRefused => break,
                else => |other| return other,
            }
        }

        // An index past the end is upstream's own refusal
        // (`src/iso19111/c_api.cpp:9174-9177`), and it writes nothing.
        if (cs.csAxisInfo(axes)) |_| {
            return error.UnexpectedResult;
        } else |err| switch (err) {
            error.OutOfMemory => return error.UnexpectedResult,
            error.UpstreamRefused => {},
            else => |other| return other,
        }
    }
}

fn ellipsoidAndMeridian(geodetic: proj.Object) Failure!void {
    if (try refusalOrSuccess(geodetic.ellipsoid())) |built| {
        const shape = built;
        defer shape.destroy();
        if (try refusalOrSuccess(shape.ellipsoidParameters())) |parameters| {
            // A semi-major axis is positive for every ellipsoid the registry
            // defines, and upstream reports one number or the other: with
            // `semi_minor_computed` set, `inv_flattening` is zero, and without it
            // the flattening was computed from a semi-minor axis.
            try expect(parameters.semi_major_metre > 0.0);
            try expect(parameters.semi_minor_computed or parameters.inv_flattening != 0.0);
            _ = parameters.semi_minor_metre;
        }
    }

    if (try refusalOrSuccess(geodetic.primeMeridian())) |built| {
        const origin = built;
        defer origin.destroy();
        if (try refusalOrSuccess(origin.primeMeridianParameters())) |parameters| {
            try expect(parameters.unit_conv_factor > 0.0);
            _ = parameters.longitude;
            _ = parameters.unit_name;
        }
    }
}