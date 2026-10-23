// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md for what that identifier covers.

//! Compile-only calls that instantiate every public PROJ facade method.
//! Data-dependent behavior is covered by tests.zig and smoke.zig.
const std = @import("std");

// Import the facade by path; the containing module still supplies `c`.
const proj = @import("root.zig");

const c = proj.c;

/// Facade, loader and expectation errors returned by this exercise.
pub const Failure = proj.Error || proj.LoadError || error{
    /// A call answered something this file expected not to happen.
    UnexpectedResult,
};

const absent_provider = "/proj-no-such-directory/libproj.so.25";

const plain_geographic = "+proj=longlat +a=6378137 +b=6378137 +no_defs";
const plain_mercator =
    "+proj=merc +a=6378137 +b=6378137 +lat_ts=0 +lon_0=0 +x_0=0 +y_0=0 +k=1 +units=m +no_defs";

fn expect(condition: bool) Failure!void {
    if (!condition) return error.UnexpectedResult;
}

fn expectNear(want: f64, got: f64, tolerance: f64) Failure!void {
    if (std.math.isNan(want) or std.math.isNan(got)) {
        if (std.math.isNan(want) and std.math.isNan(got)) return;
        return error.UnexpectedResult;
    }
    if (!std.math.approxEqAbs(f64, want, got, tolerance)) return error.UnexpectedResult;
}

fn refusalResult(comptime call: type) type {
    const payload = @typeInfo(call).error_union.payload;
    return switch (@typeInfo(payload)) {
        .optional => payload,
        else => ?payload,
    };
}

fn refusalOrSuccess(call: anytype) Failure!refusalResult(@TypeOf(call)) {
    return call catch |err| switch (err) {
        error.OutOfMemory => error.UnexpectedResult,
        error.NullReturn, error.UpstreamRefused => null,
        else => return err,
    };
}

fn loadProvider() Failure!void {
    if (!proj.runtime_loaded) return;
    try proj.load(.{ .path = absent_provider });
    _ = proj.loadedSource();
}

/// Instantiate every facade method; return facade, loader or expectation errors.
pub fn exercise() Failure!void {
    try loadProvider();

    try moduleLevel();
    try contextAndObjects();
    try databaseQueries();
    try transformationAndOperations();

    // Destroy every handle before process-wide cleanup, which must be last.
    proj.cleanup();
}

// Compile-only: execution would open the absent provider and call process-wide cleanup.
test "facade API exercise: every public method is instantiated" {
    try exercise();
}

fn moduleLevel() Failure!void {
    const reported = proj.version();
    // Check the version result's shape, not its release-specific values.
    try expect(reported.major >= 0);
    try expect(reported.minor >= 0);
    try expect(reported.patch >= 0);
    _ = reported.release;
    _ = reported.version;
    _ = reported.searchpath;

    const point = proj.coord(1.0, 2.0, 3.0, 4.0);
    try expect(point.v[0] == 1.0 and point.v[1] == 2.0 and point.v[2] == 3.0 and point.v[3] == 4.0);

    // Compare union views to check that the coordinate arms alias the same values.
    try expect(point.lp.lam == 1.0 and point.lp.phi == 2.0);
    try expect(point.xyzt.x == 1.0 and point.xyzt.y == 2.0);
    try expect(@sizeOf(proj.Coord) == 4 * @sizeOf(f64));

    // Check a degree-to-radian-to-degree round trip.
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

    // Only free null; this file owns no strings or lists.
    proj.freeString(null);
    proj.freeIntList(null);

    // Verify that the public aliases accept upstream field names.
    const xyzt: proj.Xyzt = .{ .x = 1, .y = 2, .z = 3, .t = 4 };
    try expect(xyzt.t == 4.0);
    const lpzt: proj.Lpzt = .{ .lam = 1, .phi = 2, .z = 3, .t = 4 };
    try expect(lpzt.phi == 2.0);

    // Verify the translated aliases expose upstream fields.
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

    // Exercise the raw translated C declaration too.
    const raw_info: proj.Info = c.proj_info();
    try expect(raw_info.major == reported.major);
    _ = raw_info.minor;
    _ = raw_info.patch;
    _ = raw_info.paths;
    _ = raw_info.path_count;
}

// Context and objects.

fn contextAndObjects() Failure!void {
    const ctx = try proj.Context.create();
    defer ctx.destroy();

    const second = try ctx.clone();
    defer second.destroy();
    try expect(second.ptr != ctx.ptr);

    // Enable autoclose explicitly; no default is assumed.
    ctx.setAutocloseDatabase(true);
    ctx.useProj4InitRules(false);
    try expect(!ctx.getUseProj4InitRules(false));
    try expect(!ctx.getUseProj4InitRules(true));

    // Setting the log level returns the previous value.
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
        // Invalid WKT is a normal dialect-guess result.
        try expect(ctx.guessWktDialect("not wkt at all") == .not_wkt);
    }

    if (try refusalOrSuccess(ctx.createFromDatabase("EPSG", "4326", .crs, false, null))) |object| {
        const crs = object;
        defer crs.destroy();
        // Verify the EPSG authority and code reported from proj.db.
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

fn errnoQuartet(op: proj.Object) Failure!void {
    try expect(op.errno() == proj.ErrorCode.other_api_misuse or op.errno() == 0);

    try expect(op.errnoSet(0) == 0);
    try expect(op.errnoSet(proj.ErrorCode.coord_transfm_no_operation) ==
        proj.ErrorCode.coord_transfm_no_operation);
    try expect(op.errno() == proj.ErrorCode.coord_transfm_no_operation);

    // Zero does not clear the current error.
    try expect(op.errnoSet(0) == 0);
    try expect(op.errno() == proj.ErrorCode.coord_transfm_no_operation);

    const saved = op.errnoReset();
    try expect(saved == proj.ErrorCode.coord_transfm_no_operation);
    try expect(op.errno() == 0);

    // Restore returns zero and reinstates the saved error.
    try expect(op.errnoRestore(saved) == 0);
    try expect(op.errno() == proj.ErrorCode.coord_transfm_no_operation);

    try expect(op.errnoRestore(0) == 0);
    try expect(op.errno() == proj.ErrorCode.coord_transfm_no_operation);

    _ = op.errnoReset();
    try expect(op.errno() == 0);
}

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

    // Exports are borrowed; each format keeps one replaceable result slot.
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

    // Restore the object's original context after rebinding the borrowed pointer.
    object.assignContext(ctx);
}

// Database queries.

fn databaseQueries() Failure!void {
    const ctx = try proj.Context.create();
    defer ctx.destroy();
    const gpa = std.heap.page_allocator;

    // Copy returned context-owned values before the next call can replace them.
    if (try ctx.databasePath(gpa)) |path| {
        defer gpa.free(path);
        try expect(path.len > 0);
    }
    if (try ctx.databaseMetadata(gpa, "PROJ.VERSION")) |value| {
        defer gpa.free(value);
        try expect(value.len > 0);
    }
    // A missing metadata value is null, not an error.
    if (try ctx.databaseMetadata(gpa, "NO.SUCH.KEY")) |value| {
        gpa.free(value);
        return error.UnexpectedResult;
    }

    const paths = [_][*:0]const u8{ "/nonexistent/proj-data" };
    ctx.setSearchPaths(@intCast(paths.len), &paths);
    ctx.setSqlite3VfsName("unix");
    _ = ctx.setDatabasePath(null, null, null);

    // Exercise both network states without depending on Fixture C.
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

    // Celestial bodies use a separate list type and destructor.
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

// Transformations and operations.

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

    // CRS-to-CRS construction needs proj.db; skip if upstream refuses.
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

    // Exercise the no-options crsToCrs overload.
    if (try refusalOrSuccess(ctx.crsToCrs("EPSG:4326", "EPSG:3857", &area))) |built| {
        const other = built;
        defer other.destroy();
        try transformSurface(other);
    }
}

fn transformSurface(operation: proj.Object) Failure!void {
    // Identity direction returns the input unchanged.
    const identity = operation.trans(.ident, proj.coord(1.0, 2.0, 3.0, 4.0));
    try expect(identity.v[0] == 1.0 and identity.v[1] == 2.0);

    const forward = operation.trans(.fwd, proj.coord(0.0, 0.0, 0.0, 0.0));
    // A refused transform returns an error coordinate and sets errno.
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

    // transGeneric accepts strided coordinate columns; null columns omit ordinates.
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

    // lpDist needs an operation with a geodesic; exercise the call only.
    _ = operation.lpDist(proj.coord(0, 0, 0, 0), proj.coord(1, 1, 0, 0));

    const scaling = operation.factors(proj.coord(0.0, 0.0, 0.0, 0.0));
    _ = scaling.meridional_scale;
    _ = scaling.parallel_scale;

    try coordoperationSurface(operation);
}

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

    // Distinguish real transformations from fallback operations.
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

    // Instantiate every grid-availability option without requiring a database.
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
        // Visual and authority CRS creation return distinct objects.
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

        // An index past the end is an upstream refusal with no output.
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
            // The registry reports either a computed semi-minor axis or flattening.
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
