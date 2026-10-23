// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md for what that identifier covers.

//! Typed Zig facade over PROJ's translated C API.
//! Public records alias translated types; PJ_COORD by-value calls use the C bridge in zig/proj_abi.h.
//! Destroy owned handles. Borrowed strings live with their owner; databasePath and databaseMetadata return copies.
//! Null object results become NullReturn; inspect errno for the upstream cause. Use isErrorCoordinate for transforms.
//! Coordinates use CRS axis order (EPSG:4326 is latitude, longitude); visualization normalization reverses it.
//! Linked builds call libproj directly. Runtime builds require an explicit proj.load before any calls.
//! PROJ allocations use C allocators, so Zig test allocators cannot track them.

const std = @import("std");

// Translated declarations.

/// Translated declarations from PROJ's public headers.
pub const c = @import("c");

/// Loader core used by linked builds.
const rt = @import("rt");

/// Whether calls use runtime dispatch rather than linked libproj.
/// Runtime builds require load before calling the API.
pub const runtime_loaded: bool = if (@hasDecl(c, "rt_runtime_loaded")) c.rt_runtime_loaded else false;

/// Explicit provider path or system-library name; no fallback is attempted.
pub const LoadSource = if (runtime_loaded) c.LoadSource else rt.LoadSource;

/// Errors returned when a provider request cannot be honored.
pub const LoadError = if (runtime_loaded) c.LoadError else rt.LoadError;

/// Load an explicit provider; same requests are idempotent, mismatches and reentrant calls fail.
/// Concurrent identical calls wait; failures can be retried. Linked builds panic because they have no loader.
pub fn load(source: LoadSource) LoadError!void {
    if (comptime !runtime_loaded) {
        std.debug.panic(
            "proj: load was called on a linked build; this module is not " ++
                "runtime-loaded, so there is no library to load. Build with " ++
                "runtime loading configured, or do not call load.",
            .{},
        );
    }
    return c.load(source);
}

/// Return the successful provider request, or null before load and in linked builds.
pub fn loadedSource() ?LoadSource {
    if (runtime_loaded) return c.loadedSource();
    return null;
}

// Errors.

/// Errors returned when upstream refuses a result or a local boundary is exceeded.
pub const Error = error{
    /// Upstream returned null; inspect context errno for the cause, which may be unset.
    NullReturn,

    /// The caller's allocator could not copy a string.
    OutOfMemory,

    /// An upstream integer query returned false for failure or for no available answer.
    UpstreamRefused,

    /// An item count does not fit the C int accepted by createArgv.
    TooManyItems,
};

/// Convert a nullable translated C string pointer to a borrowed span.
inline fn maybeSpan(ptr: [*c]const u8) ?[:0]const u8 {
    if (@intFromPtr(ptr) == 0) return null;
    return std.mem.span(ptr);
}

/// Copy an upstream string when the caller needs it beyond the borrow's lifetime.
fn copyString(gpa: std.mem.Allocator, ptr: [*c]const u8) Error!?[]const u8 {
    const borrowed = maybeSpan(ptr) orelse return null;
    return try gpa.dupe(u8, borrowed);
}

/// Return an upstream pointer or NullReturn when it is null.
fn require(comptime T: type, ptr: ?T) Error!T {
    return ptr orelse error.NullReturn;
}

/// Convert a documented C integer truth value to bool.
fn isSet(v: c_int) bool {
    return v != 0;
}

// Enum types.

/// PROJ transformation direction; ident leaves the coordinate unchanged.
pub const Direction = enum(c_int) {
    fwd = 1,
    ident = 0,
    inv = -1,
};

/// PROJ ISO 19111 object type; abstract CRS tags are included but not returned.
pub const Type = enum(c_uint) {
    unknown = 0,
    ellipsoid = 1,
    prime_meridian = 2,
    geodetic_reference_frame = 3,
    dynamic_geodetic_reference_frame = 4,
    vertical_reference_frame = 5,
    dynamic_vertical_reference_frame = 6,
    datum_ensemble = 7,
    /// `PJ_TYPE_CRS` — `:879`. Abstract; `proj_get_type` never returns it.
    crs = 8,
    geodetic_crs = 9,
    geocentric_crs = 10,
    /// `PJ_TYPE_GEOGRAPHIC_CRS` — `:886`. Abstract; never returned.
    geographic_crs = 11,
    geographic_2d_crs = 12,
    geographic_3d_crs = 13,
    vertical_crs = 14,
    projected_crs = 15,
    compound_crs = 16,
    temporal_crs = 17,
    engineering_crs = 18,
    bound_crs = 19,
    other_crs = 20,
    conversion = 21,
    transformation = 22,
    concatenated_operation = 23,
    other_coordinate_operation = 24,
    temporal_datum = 25,
    engineering_datum = 26,
    parametric_datum = 27,
    derived_projected_crs = 28,
    coordinate_metadata = 29,
};

/// PROJ registry category.
pub const Category = enum(c_uint) {
    ellipsoid = 0,
    prime_meridian = 1,
    datum = 2,
    crs = 3,
    coordinate_operation = 4,
    datum_ensemble = 5,
};

/// Coordinate-system kind reported by PROJ.
pub const CoordinateSystemType = enum(c_uint) {
    unknown = 0,
    cartesian = 1,
    ellipsoidal = 2,
    vertical = 3,
    spherical = 4,
    ordinal = 5,
    parametric = 6,
    datetime_temporal = 7,
    temporal_count = 8,
    temporal_measure = 9,
};

/// WKT export format; deprecated 2018 spellings are aliases below.
pub const WktType = enum(c_uint) {
    wkt2_2015 = 0,
    wkt2_2015_simplified = 1,
    wkt2_2019 = 2,
    wkt2_2019_simplified = 3,
    wkt1_gdal = 4,
    wkt1_esri = 5,

    /// `PJ_WKT2_2018`, the deprecated alias of `wkt2_2019` — `src/proj.h:942`.
    pub const wkt2_2018: WktType = .wkt2_2019;
    /// Deprecated spelling of `wkt2_2019_simplified`.
    pub const wkt2_2018_simplified: WktType = .wkt2_2019_simplified;
};

/// WKT dialect inferred from an input string.
pub const GuessedDialect = enum(c_uint) {
    wkt2_2019 = 0,
    wkt2_2015 = 1,
    wkt1_gdal = 2,
    wkt1_esri = 3,
    not_wkt = 4,

    /// Deprecated spelling of `wkt2_2019`.
    pub const wkt2_2018: GuessedDialect = .wkt2_2019;
};

/// PROJ string export syntax.
pub const ProjStringType = enum(c_uint) {
    proj5 = 0,
    proj4 = 1,
};
/// How missing grids affect candidate operations.
pub const GridAvailabilityUse = enum(c_uint) {
    used_for_sorting = 0,
    discard_operation_if_missing_grid = 1,
    ignored = 2,
    known_available = 3,
};

/// Area-of-interest rule for operation selection.
pub const SpatialCriterion = enum(c_uint) {
    strict_containment = 0,
    partial_intersection = 1,
};

/// Whether PROJ may search for an intermediate CRS.
pub const IntermediateCrsUse = enum(c_uint) {
    always = 0,
    if_no_direct_transformation = 1,
    never = 2,
};

/// How strictly PROJ compares two coordinate reference systems.
pub const ComparisonCriterion = enum(c_uint) {
    strict = 0,
    equivalent = 1,
    equivalent_except_axis_order_geogcrs = 2,
};

/// PROJ logging levels; legacy debug-major and debug-minor names are aliases below.
pub const LogLevel = enum(c_uint) {
    none = 0,
    err = 1,
    debug = 2,
    trace = 3,
    tell = 4,

    /// `PJ_LOG_DEBUG_MAJOR`, compatibility alias of `debug` — `src/proj.h:379`.
    pub const debug_major: LogLevel = .debug;
    /// `PJ_LOG_DEBUG_MINOR`, compatibility alias of `trace` — `src/proj.h:380`.
    pub const debug_minor: LogLevel = .trace;
};

/// PROJ error codes; read them from Context.errno or Object.errno, not facade returns.
pub const ErrorCode = struct {
    pub const invalid_op: c_int = 1024;
    pub const invalid_op_wrong_syntax: c_int = 1024 + 1;
    pub const invalid_op_missing_arg: c_int = 1024 + 2;
    pub const invalid_op_illegal_arg_value: c_int = 1024 + 3;
    pub const invalid_op_mutually_exclusive_args: c_int = 1024 + 4;
    pub const invalid_op_file_not_found_or_invalid: c_int = 1024 + 5;

    pub const coord_transfm: c_int = 2048;
    pub const coord_transfm_invalid_coord: c_int = 2048 + 1;
    pub const coord_transfm_outside_projection_domain: c_int = 2048 + 2;
    pub const coord_transfm_no_operation: c_int = 2048 + 3;
    pub const coord_transfm_outside_grid: c_int = 2048 + 4;
    pub const coord_transfm_grid_at_nodata: c_int = 2048 + 5;
    pub const coord_transfm_no_convergence: c_int = 2048 + 6;
    pub const coord_transfm_missing_time: c_int = 2048 + 7;

    pub const other: c_int = 4096;
    pub const other_api_misuse: c_int = 4096 + 1;
    pub const other_no_inverse_op: c_int = 4096 + 2;
    pub const other_network_error: c_int = 4096 + 3;
};

// ---- Translated value types, named ------------------------------------------

/// `PJ_XYZT` — `src/proj.h:273-275`: `double x, y, z, t`.
pub const Xyzt = c.PJ_XYZT;
/// `PJ_LPZT` — `src/proj.h:280-281`: `double lam, phi, z, t`.
pub const Lpzt = c.PJ_LPZT;
/// `PJ_FACTORS` — `src/proj.h:206-221`, the struct `proj_factors` fills.
pub const Factors = c.PJ_FACTORS;
/// `PJ_PROJ_INFO` — `src/proj.h:346-353`, the struct `proj_pj_info` fills.
pub const ProjInfo = c.PJ_PROJ_INFO;
/// `PJ_INFO` — `src/proj.h:332-344`, the struct `proj_info` returns.
pub const Info = c.PJ_INFO;
/// Translated grid metadata. The grid-file accessor is available through `c.proj_grid_info`.
pub const GridInfo = c.PJ_GRID_INFO;
/// Translated CRS metadata record.
pub const CrsInfo = c.PROJ_CRS_INFO;
/// `PROJ_UNIT_INFO` — `src/proj.h:1122-1146`.
pub const UnitInfo = c.PROJ_UNIT_INFO;
/// `PROJ_CRS_LIST_PARAMETERS` — `src/proj.h:1082-1114`.
pub const CrsListParameters = c.PROJ_CRS_LIST_PARAMETERS;
/// `PJ_OBJ_LIST` — `src/proj.h:1184`. Opaque upstream and opaque here.
pub const ObjectListHandle = c.PJ_OBJ_LIST;
/// `PJ_LOG_FUNCTION` — `src/proj.h:383`: `void (*)(void *, int, const char *)`.
pub const LogFunction = c.PJ_LOG_FUNCTION;

/// The translated `PJ_COORD` union used by transformations.
/// Every arm aliases the same four-double storage.
pub const Coord = c.PJ_COORD;

// ---- The by-value ABI bridge ------------------------------------------------

/// Linked builds route by-value `PJ_COORD` calls through the C bridge because Zig's ABI lowering differs.
/// `zig/proj_abi.h` declares pointer-shaped wrappers, compiled into the same archive.
const c_abi = struct {
    extern fn proj_abi_coord(x: f64, y: f64, z: f64, t: f64, out: *Coord) void;
    extern fn proj_abi_trans(P: ?*c.PJ, direction: c.PJ_DIRECTION, in: *const Coord, out: *Coord) void;
    extern fn proj_abi_lp_dist(P: ?*const c.PJ, a: *const Coord, b: *const Coord) f64;
    extern fn proj_abi_xy_dist(a: *const Coord, b: *const Coord) f64;
    extern fn proj_abi_xyz_dist(a: *const Coord, b: *const Coord) f64;
    extern fn proj_abi_factors(P: ?*c.PJ, lp: *const Coord, out: *Factors) void;
    extern fn proj_abi_get_suggested_operation(ctx: ?*c.PJ_CONTEXT, operations: ?*c.PJ_OBJ_LIST, direction: c.PJ_DIRECTION, coord: *const Coord) c_int;
};

fn makeCoord(x: f64, y: f64, z: f64, t: f64) Coord {
    if (comptime runtime_loaded) return c.proj_coord(x, y, z, t);
    var out: Coord = undefined;
    c_abi.proj_abi_coord(x, y, z, t, &out);
    return out;
}

fn transformCoord(P: ?*c.PJ, direction: Direction, point: Coord) Coord {
    if (comptime runtime_loaded) return c.proj_trans(P, @intFromEnum(direction), point);
    var out: Coord = undefined;
    c_abi.proj_abi_trans(P, @intFromEnum(direction), &point, &out);
    return out;
}

fn lpDistance(P: ?*const c.PJ, a: Coord, b: Coord) f64 {
    if (comptime runtime_loaded) return c.proj_lp_dist(P, a, b);
    return c_abi.proj_abi_lp_dist(P, &a, &b);
}

fn xyDistanceBetween(a: Coord, b: Coord) f64 {
    if (comptime runtime_loaded) return c.proj_xy_dist(a, b);
    return c_abi.proj_abi_xy_dist(&a, &b);
}

fn xyzDistanceBetween(a: Coord, b: Coord) f64 {
    if (comptime runtime_loaded) return c.proj_xyz_dist(a, b);
    return c_abi.proj_abi_xyz_dist(&a, &b);
}

fn pointFactors(P: ?*c.PJ, lp: Coord) Factors {
    if (comptime runtime_loaded) return c.proj_factors(P, lp);
    var out: Factors = undefined;
    c_abi.proj_abi_factors(P, &lp, &out);
    return out;
}

fn suggestionIndex(ctx: ?*c.PJ_CONTEXT, operations: ?*c.PJ_OBJ_LIST, direction: Direction, point: Coord) c_int {
    if (comptime runtime_loaded) return c.proj_get_suggested_operation(ctx, operations, @intFromEnum(direction), point);
    return c_abi.proj_abi_get_suggested_operation(ctx, operations, @intFromEnum(direction), &point);
}

/// Library version and search paths; strings borrow from process-lifetime storage and may be null.
pub const Version = struct {
    /// `PJ_INFO.major` — `src/proj.h:333`.
    major: c_int,
    /// `PJ_INFO.minor` — `:334`.
    minor: c_int,
    /// `PJ_INFO.patch` — `:335`.
    patch: c_int,
    /// `PJ_INFO.release` — `:336`, "Release info. Version + date".
    release: ?[:0]const u8,
    /// `PJ_INFO.version` — `:337`, "Full version number".
    version: ?[:0]const u8,
    /// Search paths used to find initialization and grid files; may be null.
    searchpath: ?[:0]const u8,
};

/// Bounds of an object's area of use in degrees.
/// No record is returned when PROJ has no area.
pub const AreaOfUse = struct {
    /// Western-most longitude, degrees. `src/proj.h:1263`.
    west_lon_degree: f64,
    /// Southern-most latitude, degrees.
    south_lat_degree: f64,
    /// Eastern-most longitude, degrees.
    east_lon_degree: f64,
    /// Northern-most latitude, degrees.
    north_lat_degree: f64,
    /// Borrowed from the PJ that produced this record.
    name: ?[:0]const u8,
};

/// Facade record for the seven outputs of `proj_cs_get_axis_info`.
/// Strings borrow from the coordinate-system object; the record owns nothing.
pub const AxisInfo = struct {
    /// Axis name. `src/proj.h:1473`.
    name: ?[:0]const u8,
    /// Axis abbreviation. `src/proj.h:1474`.
    abbrev: ?[:0]const u8,
    /// Axis direction, a word such as "north". `src/proj.h:1475`.
    direction: ?[:0]const u8,
    /// Factor to multiply this axis by to get the SI unit. `src/proj.h:1475`.
    unit_conv_factor: f64,
    /// Unit name. `src/proj.h:1476`.
    unit_name: ?[:0]const u8,
    /// Unit authority. `src/proj.h:1476`.
    unit_auth_name: ?[:0]const u8,
    /// Unit code. `src/proj.h:1476`.
    unit_code: ?[:0]const u8,
};

/// The four values returned by `proj_ellipsoid_get_parameters`.
pub const EllipsoidParameters = struct {
    /// Semi-major axis, metres.
    semi_major_metre: f64,
    /// Semi-minor axis, metres. Zero when `semi_minor_computed` is false.
    semi_minor_metre: f64,
    /// Whether PROJ computed the semi-minor axis from inverse flattening.
    semi_minor_computed: bool,
    /// Inverse flattening; zero when the ellipsoid specifies a semi-minor axis.
    inv_flattening: f64,
};

/// Longitude and unit returned for a prime meridian.
pub const PrimeMeridianParameters = struct {
    /// Longitude from Greenwich, in `unit_name`. For Greenwich itself, zero.
    longitude: f64,
    /// Factor to multiply `longitude` by to get radians.
    unit_conv_factor: f64,
    /// Unit `longitude` is expressed in, a borrow from the `PJ`.
    unit_name: ?[:0]const u8,
};

/// One coordinate-operation parameter; its strings borrow from the operation.
/// `value_string` is null when PROJ represents the value numerically.
pub const Param = struct {
    /// Parameter name. `src/proj.h:1520`.
    name: ?[:0]const u8,
    /// Parameter authority. `src/proj.h:1520`.
    auth_name: ?[:0]const u8,
    /// Parameter code. `src/proj.h:1520`.
    code: ?[:0]const u8,
    /// Parameter value, in `unit_name`.
    value: f64,
    /// The value as text, when upstream has one. `src/proj.h:1521`.
    value_string: ?[:0]const u8,
    /// Factor to multiply `value` by to get the SI unit. `src/proj.h:1521`.
    unit_conv_factor: f64,
    /// Unit name. `src/proj.h:1521`.
    unit_name: ?[:0]const u8,
    /// Unit authority. `src/proj.h:1521`.
    unit_auth_name: ?[:0]const u8,
    /// Unit code. `src/proj.h:1521`.
    unit_code: ?[:0]const u8,
    /// Unit category, such as linear, angular, scale, or time.
    unit_category: ?[:0]const u8,
};

/// Metadata for a required grid; strings borrow from the operation.
/// `available` reports whether this build can reach the file.
pub const GridUsed = struct {
    /// Short name of the grid. `src/proj.h:1531`.
    short_name: ?[:0]const u8,
    /// Full name. `src/proj.h:1531`.
    full_name: ?[:0]const u8,
    /// Package the grid ships in. `src/proj.h:1531`.
    package_name: ?[:0]const u8,
    /// Where it can be fetched from, when networking is on. `src/proj.h:1532`.
    url: ?[:0]const u8,
    /// Whether PROJ may fetch it directly. `src/proj.h:1532`.
    direct_download: c_int,
    /// Whether its licence allows redistribution. `src/proj.h:1532`.
    open_license: c_int,
    /// Whether this build can actually read it. `src/proj.h:1533`.
    available: c_int,
};

/// Coordinate-operation method details; strings borrow from the operation.
pub const MethodInfo = struct {
    /// Method name.
    name: ?[:0]const u8,
    /// Authority name.
    auth_name: ?[:0]const u8,
    /// Registry code.
    code: ?[:0]const u8,
};

/// Transformed bounding box in the target CRS's units.
pub const Bounds = struct {
    xmin: f64,
    ymin: f64,
    xmax: f64,
    ymax: f64,
};

// Module-level functions.

/// Return library version and search-path information without a context.
pub fn version() Version {
    const raw = c.proj_info();
    return .{
        .major = raw.major,
        .minor = raw.minor,
        .patch = raw.patch,
        .release = maybeSpan(raw.release),
        .version = maybeSpan(raw.version),
        .searchpath = maybeSpan(raw.searchpath),
    };
}

/// Clear process-wide PROJ caches; destroy all handles first.
/// Use only when finished with PROJ; upstream does not restore dropped state.
pub fn cleanup() void {
    c.proj_cleanup();
}

/// Construct a coordinate without validation, conversion, or unit checks.
pub fn coord(x: f64, y: f64, z: f64, t: f64) Coord {
    return makeCoord(x, y, z, t);
}

/// Convert degrees to radians without inspecting a coordinate or CRS.
pub fn toRad(angle_in_degrees: f64) f64 {
    return c.proj_torad(angle_in_degrees);
}

/// Convert radians to degrees.
pub fn toDeg(angle_in_radians: f64) f64 {
    return c.proj_todeg(angle_in_radians);
}

/// True when all four words are HUGE_VAL, PROJ's transform-failure marker.
pub fn isErrorCoordinate(point: Coord) bool {
    const huge = std.math.inf(f64);
    return point.v[0] == huge and
        point.v[1] == huge and
        point.v[2] == huge and
        point.v[3] == huge;
}

/// Euclidean distance between linear 2D coordinates; no operation is needed.
pub fn xyDistance(a: Coord, b: Coord) f64 {
    return xyDistanceBetween(a, b);
}

/// Euclidean distance between linear 3D coordinates.
pub fn xyzDistance(a: Coord, b: Coord) f64 {
    return xyzDistanceBetween(a, b);
}

/// Free a caller-owned PROJ string, such as one returned by `c.proj_suggests_code_for`.
/// Never free `asWkt`, `asProjString`, or `asProjJson` results; those borrow from the object.
pub fn freeString(str: [*c]u8) void {
    c.proj_string_destroy(str);
}

/// Free a PROJ-owned integer list, such as `proj_identify` confidence output.
/// This facade does not bind `proj_identify`; do not pass memory from another allocator.
pub fn freeIntList(list: [*c]c_int) void {
    c.proj_int_list_destroy(list);
}

// ---- Context ----------------------------------------------------------------

/// A PROJ context that owns database, cache, logging, and error state.
/// Destroy its Objects before destroying the context.
pub const Context = struct {
    ptr: *c.PJ_CONTEXT,

    /// Create a context, or return NullReturn if allocation fails.
    pub fn create() Error!Context {
        return .{ .ptr = try require(*c.PJ_CONTEXT, c.proj_context_create()) };
    }

    /// Destroy the context and its resources; destroy its Objects first.
    pub fn destroy(self: Context) void {
        _ = c.proj_context_destroy(self.ptr);
    }

    /// Clone context settings into a separately owned context.
    pub fn clone(self: Context) Error!Context {
        return .{ .ptr = try require(*c.PJ_CONTEXT, c.proj_context_clone(self.ptr)) };
    }

    // -- Objects -------------------------------------------------------------

    /// Create an object from a PROJ string.
    /// `init=epsg:XXXX` requires `useProj4InitRules` first.
    pub fn createFromProjString(self: Context, definition: [*:0]const u8) Error!Object {
        return self.adopt(c.proj_create(self.ptr, definition));
    }

    /// Create an object from sentinel-terminated argument strings.
    /// Upstream reads the caller-owned array and strings without modifying them.
    pub fn createArgv(self: Context, argv: []const [*:0]const u8) Error!Object {
        if (argv.len > @as(usize, @intCast(std.math.maxInt(c_int)))) {
            return error.TooManyItems;
        }
        // Translate-C's pointer array is mutable, but upstream only reads its caller-owned strings.
        return self.adopt(c.proj_create_argv(
            self.ptr,
            @intCast(argv.len),
            @ptrCast(@constCast(argv.ptr)),
        ));
    }

    /// Parse WKT with an optional null-terminated option list.
    /// Parse warning and grammar-error lists are not exposed.
    pub fn createFromWkt(
        self: Context,
        wkt: [*:0]const u8,
        options: [*c]const ?[*:0]const u8,
    ) Error!Object {
        return self.adopt(c.proj_create_from_wkt(self.ptr, wkt, options, null, null));
    }

    /// Create an object from a database authority, code, and category.
    /// Alternative grid names select PROJ names rather than registry names.
    pub fn createFromDatabase(
        self: Context,
        auth_name: [*:0]const u8,
        code: [*:0]const u8,
        category: Category,
        use_proj_alternative_grid_names: bool,
        options: [*c]const ?[*:0]const u8,
    ) Error!Object {
        return self.adopt(c.proj_create_from_database(
            self.ptr,
            auth_name,
            code,
            @intFromEnum(category),
            if (use_proj_alternative_grid_names) 1 else 0,
            options,
        ));
    }

    /// Create a CRS transformation, optionally restricted to an area.
    /// With networking off, a missing grid can yield NullReturn without setting errno.
    pub fn crsToCrs(
        self: Context,
        source_crs: [*:0]const u8,
        target_crs: [*:0]const u8,
        area: ?*Area,
    ) Error!Object {
        return self.adopt(c.proj_create_crs_to_crs(
            self.ptr,
            source_crs,
            target_crs,
            if (area) |a| a.ptr else null,
        ));
    }

    /// Create a transformation from in-memory CRS objects with optional settings.
    /// Option strings must be sentinel-terminated; ONLY_BEST can defer failure to `trans`, and `lastUsedOperation` identifies the selected alternative.
    pub fn crsToCrsFromPj(
        self: Context,
        source_crs: Object,
        target_crs: Object,
        area: ?*Area,
        options: [*c]const ?[*:0]const u8,
    ) Error!Object {
        return self.adopt(c.proj_create_crs_to_crs_from_pj(
            self.ptr,
            source_crs.ptr,
            target_crs.ptr,
            if (area) |a| a.ptr else null,
            options,
        ));
    }

    /// Adopt a raw `PJ *` this context produced, or report upstream's NULL.
    fn adopt(self: Context, raw: ?*c.PJ) Error!Object {
        return .{ .ptr = try require(*c.PJ, raw), .ctx = self.ptr };
    }

    // -- Database ------------------------------------------------------------

    /// Set the database path; null uses PROJ_DATA, then the deprecated PROJ_LIB.
    /// Returns false when PROJ refuses the path and restores the previous one.
    pub fn setDatabasePath(
        self: Context,
        db_path: ?[*:0]const u8,
        aux_db_paths: [*c]const [*:0]const u8,
        options: [*c]const ?[*:0]const u8,
    ) bool {
        return isSet(c.proj_context_set_database_path(
            self.ptr,
            if (db_path) |path| path else null,
            aux_db_paths,
            options,
        ));
    }

    /// Return the database path as a caller-owned copy, or null when unavailable.
    /// Free the returned slice with the allocator passed as `gpa`.
    pub fn databasePath(self: Context, gpa: std.mem.Allocator) Error!?[]const u8 {
        return copyString(gpa, c.proj_context_get_database_path(self.ptr));
    }

    /// Return a copied metadata value, or null when the key has no value.
    /// Keys include DATABASE.LAYOUT.VERSION.{MAJOR,MINOR}, EPSG/ESRI/IGNF/NKG metadata, PROJ.VERSION, and PROJ_DATA.VERSION.
    pub fn databaseMetadata(
        self: Context,
        gpa: std.mem.Allocator,
        key: [:0]const u8,
    ) Error!?[]const u8 {
        return copyString(gpa, c.proj_context_get_database_metadata(self.ptr, key.ptr));
    }

    /// Replace search paths with `count_paths` entries; this overrides PROJ_DATA/PROJ_LIB resolution.
    pub fn setSearchPaths(
        self: Context,
        count_paths: c_int,
        paths: [*c]const [*:0]const u8,
    ) void {
        c.proj_context_set_search_paths(self.ptr, count_paths, paths);
    }

    /// Set whether the database connection closes between operations.
    pub fn setAutocloseDatabase(self: Context, autoclose: bool) void {
        c.proj_context_set_autoclose_database(self.ptr, if (autoclose) 1 else 0);
    }

    /// Set the SQLite VFS used to open `proj.db`; an unknown name fails when opened.
    pub fn setSqlite3VfsName(self: Context, name: [:0]const u8) void {
        c.proj_context_set_sqlite3_vfs_name(self.ptr, name.ptr);
    }

    /// Enable or disable network access; offline mode excludes grids not on disk.
    pub fn setNetworkEnabled(self: Context, enabled: bool) bool {
        return isSet(c.proj_context_set_enable_network(self.ptr, if (enabled) 1 else 0));
    }

    /// Return whether network access is enabled.
    pub fn networkEnabled(self: Context) bool {
        return isSet(c.proj_context_is_network_enabled(self.ptr));
    }

    /// Set PROJ's user-writable directory; `create_dir` asks PROJ to create it.
    pub fn setUserWritableDirectory(
        self: Context,
        path: [:0]const u8,
        create_dir: bool,
    ) void {
        c.proj_context_set_user_writable_directory(self.ptr, path.ptr, if (create_dir) 1 else 0);
    }

    /// Return the context's user-writable directory as a borrow.
    /// The borrow ends when the context is destroyed or the directory changes.
    pub fn userWritableDirectory(self: Context, create_dir: bool) ?[:0]const u8 {
        return maybeSpan(c.proj_context_get_user_writable_directory(self.ptr, if (create_dir) 1 else 0));
    }

    /// Return all database authorities in a caller-freed StringList.
    pub fn authoritiesFromDatabase(self: Context) Error!?StringList {
        return StringList.create(c.proj_get_authorities_from_database(self.ptr));
    }

    /// Return codes for a type; null authority searches all, and false excludes deprecated entries.
    pub fn codesFromDatabase(
        self: Context,
        auth_name: ?[*:0]const u8,
        kind: Type,
        allow_deprecated: bool,
    ) Error!?StringList {
        return StringList.create(c.proj_get_codes_from_database(
            self.ptr,
            if (auth_name) |name| name else null,
            @intFromEnum(kind),
            if (allow_deprecated) 1 else 0,
        ));
    }

    /// Guess a WKT dialect without parsing; `not_wkt` is a normal result.
    pub fn guessWktDialect(self: Context, wkt: [*:0]const u8) GuessedDialect {
        return @enumFromInt(c.proj_context_guess_wkt_dialect(self.ptr, wkt));
    }

    /// Return the context error code; zero means no current error, not no past errors.
    pub fn errno(self: Context) c_int {
        return c.proj_context_errno(self.ptr);
    }

    /// Return PROJ's error text as a process-lifetime borrow.
    pub fn errnoString(self: Context, err: c_int) ?[:0]const u8 {
        return maybeSpan(c.proj_context_errno_string(self.ptr, err));
    }

    /// Set the log level and return its previous value.
    pub fn logLevel(self: Context, log_level: LogLevel) LogLevel {
        return @enumFromInt(c.proj_log_level(self.ptr, @intFromEnum(log_level)));
    }

    /// Set the logging callback; null restores PROJ logging, and `app_data` is passed through.
    pub fn logFunc(self: Context, app_data: ?*anyopaque, logf: LogFunction) void {
        c.proj_log_func(self.ptr, app_data, logf);
    }

    /// Enable or disable legacy `+init=epsg:XXXX` rules.
    pub fn useProj4InitRules(self: Context, enable: bool) void {
        c.proj_context_use_proj4_init_rules(self.ptr, if (enable) 1 else 0);
    }

    /// Return whether the legacy rules are enabled for this caller category.
    pub fn getUseProj4InitRules(self: Context, from_legacy_code_path: bool) bool {
        return isSet(c.proj_context_get_use_proj4_init_rules(
            self.ptr,
            if (from_legacy_code_path) 1 else 0,
        ));
    }
};

// Objects.

/// A PROJ object that borrows its Context; destroy the object before its context.
pub const Object = struct {
    ptr: *c.PJ,
    ctx: *c.PJ_CONTEXT,

    /// Clone this object; caller owns and must destroy the copy.
    pub fn clone(self: Object) Error!Object {
        return .{ .ptr = try require(*c.PJ, c.proj_clone(self.ctx, self.ptr)), .ctx = self.ctx };
    }

    /// Destroy this object before its borrowed Context.
    pub fn destroy(self: Object) void {
        _ = c.proj_destroy(self.ptr);
    }

    // -- Identity ------------------------------------------------------------

    /// What kind of object this is — `proj_get_type` (`src/proj.h:1234`).
    pub fn getType(self: Object) Type {
        return @enumFromInt(c.proj_get_type(self.ptr));
    }

    /// Whether it is a CRS — `proj_is_crs` (`src/proj.h:1247`).
    pub fn isCrs(self: Object) bool {
        return isSet(c.proj_is_crs(self.ptr));
    }

    /// Whether the registry marks it deprecated.
    pub fn isDeprecated(self: Object) bool {
        return isSet(c.proj_is_deprecated(self.ptr));
    }

    /// Whether two objects are equivalent under the selected criterion.
    pub fn isEquivalentTo(self: Object, other: Object, criterion: ComparisonCriterion) bool {
        return isSet(c.proj_is_equivalent_to(self.ptr, other.ptr, @intFromEnum(criterion)));
    }

    /// Return the object name as a borrow, or null when unavailable.
    pub fn name(self: Object) ?[:0]const u8 {
        return maybeSpan(c.proj_get_name(self.ptr));
    }

    /// Return an identifier's authority as a borrow.
    pub fn idAuthName(self: Object, index: c_int) ?[:0]const u8 {
        return maybeSpan(c.proj_get_id_auth_name(self.ptr, index));
    }

    /// Return an identifier's code as a borrow.
    pub fn idCode(self: Object, index: c_int) ?[:0]const u8 {
        return maybeSpan(c.proj_get_id_code(self.ptr, index));
    }

    /// Return the object's scope as a borrow.
    pub fn scope(self: Object) ?[:0]const u8 {
        return maybeSpan(c.proj_get_scope(self.ptr));
    }

    /// Return the object's remarks as a borrow.
    pub fn remarks(self: Object) ?[:0]const u8 {
        return maybeSpan(c.proj_get_remarks(self.ptr));
    }

    /// Return area bounds in degrees; the name borrows from the object.
    /// Returns UpstreamRefused when no area is available or upstream fails.
    pub fn areaOfUse(self: Object) Error!AreaOfUse {
        var west: f64 = undefined;
        var south: f64 = undefined;
        var east: f64 = undefined;
        var north: f64 = undefined;
        var area_name: [*c]const u8 = undefined;
        if (!isSet(c.proj_get_area_of_use(
            self.ctx,
            self.ptr,
            &west,
            &south,
            &east,
            &north,
            &area_name,
        ))) return error.UpstreamRefused;
        return .{
            .west_lon_degree = west,
            .south_lat_degree = south,
            .east_lon_degree = east,
            .north_lat_degree = north,
            .name = maybeSpan(area_name),
        };
    }

    // -- Export --------------------------------------------------------------

    /// Export WKT as a short-lived borrow; do not free it.
    /// Unknown options return null.
    pub fn asWkt(
        self: Object,
        kind: WktType,
        options: [*c]const ?[*:0]const u8,
    ) ?[:0]const u8 {
        return maybeSpan(c.proj_as_wkt(self.ctx, self.ptr, @intFromEnum(kind), options));
    }

    /// Export a PROJ string as a short-lived borrow; do not free it.
    /// Objects not created from a PROJ string may return null.
    pub fn asProjString(
        self: Object,
        kind: ProjStringType,
        options: [*c]const ?[*:0]const u8,
    ) ?[:0]const u8 {
        return maybeSpan(c.proj_as_proj_string(self.ctx, self.ptr, @intFromEnum(kind), options));
    }

    /// Export PROJJSON as a short-lived borrow; do not free it.
    pub fn asProjJson(self: Object, options: [*c]const [*:0]const u8) ?[:0]const u8 {
        return maybeSpan(c.proj_as_projjson(self.ctx, self.ptr, options));
    }

    /// Return operation info; strings borrow from the object and accuracy -1 means unknown.
    pub fn pjInfo(self: Object) ProjInfo {
        return c.proj_pj_info(self.ptr);
    }

    /// Return a caller-owned list of replacements, or null if none applies.
    pub fn nonDeprecated(self: Object) Error!?ObjectList {
        return ObjectList.create(self.ctx, c.proj_get_non_deprecated(self.ctx, self.ptr));
    }

    /// Rebind this upstream object to `ctx`; the object is not copied.
    pub fn assignContext(self: Object, ctx: Context) void {
        c.proj_assign_context(self.ptr, ctx.ptr);
    }

    // -- Errors --------------------------------------------------------------

    /// Read this object's context error code; objects in one context share the slot.
    /// Later failures overwrite it.
    pub fn errno(self: Object) c_int {
        return c.proj_errno(self.ptr);
    }

    /// Set and return a nonzero code in the context slot and thread-local errno.
    /// Setting zero does nothing; use `errnoReset` to clear.
    pub fn errnoSet(self: Object, err: c_int) c_int {
        return c.proj_errno_set(self.ptr, err);
    }

    /// Clear context and thread-local errno, returning the previous code.
    pub fn errnoReset(self: Object) c_int {
        return c.proj_errno_reset(self.ptr);
    }

    /// Restore a saved nonzero code; upstream returns zero and ignores zero input.
    pub fn errnoRestore(self: Object, err: c_int) c_int {
        return c.proj_errno_restore(self.ptr, err);
    }

    // -- CRS -----------------------------------------------------------------

    /// Create a visualization-order object (longitude, latitude for EPSG:4326).
    /// The caller owns the new object.
    pub fn normalizeForVisualization(self: Object) Error!Object {
        return .{
            .ptr = try require(*c.PJ, c.proj_normalize_for_visualization(self.ctx, self.ptr)),
            .ctx = self.ctx,
        };
    }

    /// Return a new geodetic CRS object, or null when this object is not a CRS.
    pub fn geodeticCrs(self: Object) Error!?Object {
        return self.optional(c.proj_crs_get_geodetic_crs(self.ctx, self.ptr));
    }

    /// Return a new datum object; null when the CRS uses an ensemble.
    /// Use `datumEnsemble` or `datumForced` for ensemble-based CRSs.
    pub fn datum(self: Object) Error!?Object {
        return self.optional(c.proj_crs_get_datum(self.ctx, self.ptr));
    }

    /// Return a new datum ensemble, or null when the CRS has a single datum.
    pub fn datumEnsemble(self: Object) Error!?Object {
        return self.optional(c.proj_crs_get_datum_ensemble(self.ctx, self.ptr));
    }

    /// Return a new datum or ensemble-as-datum object, or null if PROJ cannot build it.
    pub fn datumForced(self: Object) Error!?Object {
        return self.optional(c.proj_crs_get_datum_forced(self.ctx, self.ptr));
    }

    /// Return a new horizontal datum object, or null when unavailable.
    pub fn horizontalDatum(self: Object) Error!?Object {
        return self.optional(c.proj_crs_get_horizontal_datum(self.ctx, self.ptr));
    }

    /// Return the coordinate-system object; the caller owns it.
    pub fn coordinateSystem(self: Object) Error!?Object {
        return self.optional(c.proj_crs_get_coordinate_system(self.ctx, self.ptr));
    }

    /// Return a new component of a compound CRS, or null for an absent index.
    pub fn subCrs(self: Object, index: c_int) Error!?Object {
        return self.optional(c.proj_crs_get_sub_crs(self.ctx, self.ptr, index));
    }

    /// Whether the CRS is derived — `proj_crs_is_derived` (`src/proj.h:1433`).
    pub fn isDerived(self: Object) bool {
        return isSet(c.proj_crs_is_derived(self.ctx, self.ptr));
    }

    /// Whether the CRS is dynamic — `proj_crs_is_dynamic` (`src/proj.h:1435`).
    pub fn isDynamic(self: Object) bool {
        return isSet(c.proj_crs_is_dynamic(self.ctx, self.ptr));
    }

    /// Return the source CRS as a new object, or null when absent.
    pub fn sourceCrs(self: Object) Error!?Object {
        return self.optional(c.proj_get_source_crs(self.ctx, self.ptr));
    }

    /// Return the target CRS as a new object, or null when unavailable.
    pub fn targetCrs(self: Object) Error!?Object {
        return self.optional(c.proj_get_target_crs(self.ctx, self.ptr));
    }

    /// Create a bound CRS from this base CRS and optional hub and transformation.
    /// The caller owns the new object.
    pub fn createBoundCrs(
        self: Object,
        hub_crs: ?Object,
        transformation: ?Object,
    ) Error!Object {
        return .{
            .ptr = try require(*c.PJ, c.proj_crs_create_bound_crs(
                self.ctx,
                self.ptr,
                if (hub_crs) |h| h.ptr else null,
                if (transformation) |t| t.ptr else null,
            )),
            .ctx = self.ctx,
        };
    }

    /// Return a new ellipsoid object, or null for non-CRS/non-frame objects.
    pub fn ellipsoid(self: Object) Error!?Object {
        return self.optional(c.proj_get_ellipsoid(self.ctx, self.ptr));
    }

    /// Return ellipsoid dimensions; `semi_minor_computed` marks the derived value.
    pub fn ellipsoidParameters(self: Object) Error!EllipsoidParameters {
        var semi_major: f64 = undefined;
        var semi_minor: f64 = undefined;
        var semi_minor_computed: c_int = 0;
        var inv_flattening: f64 = undefined;
        if (!isSet(c.proj_ellipsoid_get_parameters(
            self.ctx,
            self.ptr,
            &semi_major,
            &semi_minor,
            &semi_minor_computed,
            &inv_flattening,
        ))) return error.UpstreamRefused;
        return .{
            .semi_major_metre = semi_major,
            .semi_minor_metre = semi_minor,
            .semi_minor_computed = isSet(semi_minor_computed),
            .inv_flattening = inv_flattening,
        };
    }

    /// Return the prime meridian as a new object.
    pub fn primeMeridian(self: Object) Error!?Object {
        return self.optional(c.proj_get_prime_meridian(self.ctx, self.ptr));
    }

    /// Return prime-meridian longitude and unit details.
    pub fn primeMeridianParameters(self: Object) Error!PrimeMeridianParameters {
        var longitude: f64 = undefined;
        var conv: f64 = undefined;
        var unit_name: [*c]const u8 = undefined;
        if (!isSet(c.proj_prime_meridian_get_parameters(
            self.ctx,
            self.ptr,
            &longitude,
            &conv,
            &unit_name,
        ))) return error.UpstreamRefused;
        return .{
            .longitude = longitude,
            .unit_conv_factor = conv,
            .unit_name = maybeSpan(unit_name),
        };
    }

    /// Return the celestial-body name as an object-lifetime borrow.
    pub fn celestialBodyName(self: Object) ?[:0]const u8 {
        return maybeSpan(c.proj_get_celestial_body_name(self.ctx, self.ptr));
    }

    /// Return the coordinate-system type.
    pub fn csType(self: Object) CoordinateSystemType {
        return @enumFromInt(c.proj_cs_get_type(self.ctx, self.ptr));
    }

    /// Return the number of coordinate-system axes.
    pub fn csAxisCount(self: Object) c_int {
        return c.proj_cs_get_axis_count(self.ctx, self.ptr);
    }

    /// Return one axis's metadata; its strings borrow from the coordinate-system object.
    /// Returns UpstreamRefused when `index` is outside `0..csAxisCount`.
    pub fn csAxisInfo(self: Object, index: c_int) Error!AxisInfo {
        var axis_name: [*c]const u8 = undefined;
        var abbrev: [*c]const u8 = undefined;
        var direction: [*c]const u8 = undefined;
        var conv: f64 = undefined;
        var unit_name: [*c]const u8 = undefined;
        var unit_auth: [*c]const u8 = undefined;
        var unit_code: [*c]const u8 = undefined;
        if (!isSet(c.proj_cs_get_axis_info(
            self.ctx,
            self.ptr,
            index,
            &axis_name,
            &abbrev,
            &direction,
            &conv,
            &unit_name,
            &unit_auth,
            &unit_code,
        ))) return error.UpstreamRefused;
        return .{
            .name = maybeSpan(axis_name),
            .abbrev = maybeSpan(abbrev),
            .direction = maybeSpan(direction),
            .unit_conv_factor = conv,
            .unit_name = maybeSpan(unit_name),
            .unit_auth_name = maybeSpan(unit_auth),
            .unit_code = maybeSpan(unit_code),
        };
    }

    /// Wrap a present getter result; preserve null for absent object parts.
    fn optional(self: Object, raw: ?*c.PJ) Error!?Object {
        if (raw) |p| return Object{ .ptr = p, .ctx = self.ctx };
        return null;
    }

    // -- Transformation ------------------------------------------------------

    /// Transform one coordinate; failures return four HUGE_VAL values and record errno.
    /// ident passes through, NaN propagates, and linked builds use the C ABI bridge.
    pub fn trans(self: Object, direction: Direction, point: Coord) Coord {
        return transformCoord(self.ptr, direction, point);
    }

    /// Transform coordinates in place; failed points become error coordinates.
    /// Return zero or a shared ErrorCode, using the generic transform code when needed.
    pub fn transArray(self: Object, direction: Direction, coords: []Coord) c_int {
        return c.proj_trans_array(self.ptr, @intFromEnum(direction), coords.len, coords.ptr);
    }

    /// Transform strided columns in place; strides are bytes, and length one broadcasts.
    /// Null/zero omits a column; return the number of transformations completed.
    pub fn transGeneric(
        self: Object,
        direction: Direction,
        x: [*c]f64,
        sx: usize,
        nx: usize,
        y: [*c]f64,
        sy: usize,
        ny: usize,
        z: [*c]f64,
        sz: usize,
        nz: usize,
        t: [*c]f64,
        st: usize,
        nt: usize,
    ) usize {
        return c.proj_trans_generic(
            self.ptr,
            @intFromEnum(direction),
            x,
            sx,
            nx,
            y,
            sy,
            ny,
            z,
            sz,
            nz,
            t,
            st,
            nt,
        );
    }

    /// Transform a bounding box; upstream recommends densify_pts 21 and accepts 0..10000.
    /// Return UpstreamRefused on failure rather than output infinities.
    pub fn transBounds(
        self: Object,
        direction: Direction,
        input: Bounds,
        densify_pts: c_int,
    ) Error!Bounds {
        var out_xmin: f64 = undefined;
        var out_ymin: f64 = undefined;
        var out_xmax: f64 = undefined;
        var out_ymax: f64 = undefined;
        if (!isSet(c.proj_trans_bounds(
            self.ctx,
            self.ptr,
            @intFromEnum(direction),
            input.xmin,
            input.ymin,
            input.xmax,
            input.ymax,
            &out_xmin,
            &out_ymin,
            &out_xmax,
            &out_ymax,
            densify_pts,
        ))) return error.UpstreamRefused;
        return .{ .xmin = out_xmin, .ymin = out_ymin, .xmax = out_xmax, .ymax = out_ymax };
    }

    /// Return the operation used by the last transform as a new object, or null if none.
    pub fn lastUsedOperation(self: Object) Error!?Object {
        return self.optional(c.proj_trans_get_last_used_operation(self.ptr));
    }

    /// Whether the input is angular in this direction.
    pub fn angularInput(self: Object, direction: Direction) bool {
        return isSet(c.proj_angular_input(self.ptr, @intFromEnum(direction)));
    }

    /// Whether the output is angular in this direction.
    pub fn angularOutput(self: Object, direction: Direction) bool {
        return isSet(c.proj_angular_output(self.ptr, @intFromEnum(direction)));
    }

    /// Whether the input is in degrees.
    pub fn degreeInput(self: Object, direction: Direction) bool {
        return isSet(c.proj_degree_input(self.ptr, @intFromEnum(direction)));
    }

    /// Whether the output is in degrees.
    pub fn degreeOutput(self: Object, direction: Direction) bool {
        return isSet(c.proj_degree_output(self.ptr, @intFromEnum(direction)));
    }

    /// Measure forward/inverse consistency, not accuracy; units follow the coordinates.
    pub fn roundtrip(self: Object, direction: Direction, n: c_int, coords: []Coord) f64 {
        return c.proj_roundtrip(self.ptr, @intFromEnum(direction), n, coords.ptr);
    }

    /// Return geodesic distance; HUGE_VAL means the operation has no ellipsoid.
    pub fn lpDist(self: Object, a: Coord, b: Coord) f64 {
        return lpDistance(self.ptr, a, b);
    }

    /// Return PROJ cartographic factors in the translated PJ_FACTORS record.
    pub fn factors(self: Object, lp: Coord) Factors {
        return pointFactors(self.ptr, lp);
    }

    // -- Coordinate operations ------------------------------------------------

    /// Return operation method name, authority, and code.
    /// Strings borrow from the operation and reflect registry metadata.
    pub fn coordoperationMethodInfo(self: Object) Error!MethodInfo {
        var method_name: [*c]const u8 = undefined;
        var auth: [*c]const u8 = undefined;
        var code: [*c]const u8 = undefined;
        if (!isSet(c.proj_coordoperation_get_method_info(
            self.ctx,
            self.ptr,
            &method_name,
            &auth,
            &code,
        ))) return error.UpstreamRefused;
        return .{
            .name = maybeSpan(method_name),
            .auth_name = maybeSpan(auth),
            .code = maybeSpan(code),
        };
    }

    /// Return expected operation accuracy in metres; negative means unknown.
    pub fn coordoperationAccuracy(self: Object) f64 {
        return c.proj_coordoperation_get_accuracy(self.ctx, self.ptr);
    }

    /// Return the operation's parameter count.
    pub fn coordoperationParamCount(self: Object) c_int {
        return c.proj_coordoperation_get_param_count(self.ctx, self.ptr);
    }

    /// Return one operation parameter and its unit data; strings borrow from the operation.
    pub fn coordoperationParam(self: Object, index: c_int) Error!Param {
        var param_name: [*c]const u8 = undefined;
        var auth: [*c]const u8 = undefined;
        var code: [*c]const u8 = undefined;
        var value: f64 = undefined;
        var value_string: [*c]const u8 = undefined;
        var conv: f64 = undefined;
        var unit_name: [*c]const u8 = undefined;
        var unit_auth: [*c]const u8 = undefined;
        var unit_code: [*c]const u8 = undefined;
        var unit_category: [*c]const u8 = undefined;
        if (!isSet(c.proj_coordoperation_get_param(
            self.ctx,
            self.ptr,
            index,
            &param_name,
            &auth,
            &code,
            &value,
            &value_string,
            &conv,
            &unit_name,
            &unit_auth,
            &unit_code,
            &unit_category,
        ))) return error.UpstreamRefused;
        return .{
            .name = maybeSpan(param_name),
            .auth_name = maybeSpan(auth),
            .code = maybeSpan(code),
            .value = value,
            .value_string = maybeSpan(value_string),
            .unit_conv_factor = conv,
            .unit_name = maybeSpan(unit_name),
            .unit_auth_name = maybeSpan(unit_auth),
            .unit_code = maybeSpan(unit_code),
            .unit_category = maybeSpan(unit_category),
        };
    }

    /// Return the number of grids required by the operation.
    pub fn coordoperationGridUsedCount(self: Object) c_int {
        return c.proj_coordoperation_get_grid_used_count(self.ctx, self.ptr);
    }

    /// Return grid metadata; strings borrow from the operation, and `available` reports local reachability.
    pub fn coordoperationGridUsed(self: Object, index: c_int) Error!GridUsed {
        var short_name: [*c]const u8 = undefined;
        var full_name: [*c]const u8 = undefined;
        var package_name: [*c]const u8 = undefined;
        var url: [*c]const u8 = undefined;
        var direct_download: c_int = 0;
        var open_license: c_int = 0;
        var available: c_int = 0;
        if (!isSet(c.proj_coordoperation_get_grid_used(
            self.ctx,
            self.ptr,
            index,
            &short_name,
            &full_name,
            &package_name,
            &url,
            &direct_download,
            &open_license,
            &available,
        ))) return error.UpstreamRefused;
        return .{
            .short_name = maybeSpan(short_name),
            .full_name = maybeSpan(full_name),
            .package_name = maybeSpan(package_name),
            .url = maybeSpan(url),
            .direct_download = direct_download,
            .open_license = open_license,
            .available = available,
        };
    }

    /// Whether any step uses a ballpark transformation.
    pub fn coordoperationHasBallparkTransformation(self: Object) bool {
        return isSet(c.proj_coordoperation_has_ballpark_transformation(self.ctx, self.ptr));
    }

    /// Whether every step can run with the currently reachable grids.
    pub fn coordoperationIsInstantiable(self: Object) bool {
        return isSet(c.proj_coordoperation_is_instantiable(self.ctx, self.ptr));
    }

    /// Create the inverse operation as a new object, or return NullReturn if unavailable.
    pub fn coordoperationCreateInverse(self: Object) Error!Object {
        return .{
            .ptr = try require(*c.PJ, c.proj_coordoperation_create_inverse(self.ctx, self.ptr)),
            .ctx = self.ctx,
        };
    }

    /// Return the step count of a concatenated operation.
    pub fn concatoperationStepCount(self: Object) c_int {
        return c.proj_concatoperation_get_step_count(self.ctx, self.ptr);
    }

    /// Return one concatenated-operation step as a new object, or null for an invalid index.
    pub fn concatoperationStep(self: Object, i_step: c_int) Error!?Object {
        return self.optional(c.proj_concatoperation_get_step(self.ctx, self.ptr, i_step));
    }

    /// Return the coordinate operation wrapped by a BoundCRS, or null otherwise.
    pub fn crsGetCoordoperation(self: Object) Error!?Object {
        return self.optional(c.proj_crs_get_coordoperation(self.ctx, self.ptr));
    }
};

// ---- Area of use ------------------------------------------------------------

/// An owned, mutable area-of-interest rectangle.
/// Create and destroy it with the methods below.
pub const Area = struct {
    ptr: *c.PJ_AREA,

    /// Create an empty area.
    pub fn create() Error!Area {
        return .{ .ptr = try require(*c.PJ_AREA, c.proj_area_create()) };
    }

    /// Set a bounding box in west, south, east, north order, in degrees.
    pub fn setBbox(
        self: *Area,
        west_lon_degree: f64,
        south_lat_degree: f64,
        east_lon_degree: f64,
        north_lat_degree: f64,
    ) void {
        c.proj_area_set_bbox(
            self.ptr,
            west_lon_degree,
            south_lat_degree,
            east_lon_degree,
            north_lat_degree,
        );
    }

    /// Set the area's name.
    pub fn setName(self: *Area, name: [*:0]const u8) void {
        c.proj_area_set_name(self.ptr, name);
    }

    /// Destroy this area.
    pub fn destroy(self: Area) void {
        c.proj_area_destroy(self.ptr);
    }
};

// Operation factory.

/// Own query settings that select candidate operations, not a runnable transform.
/// The factory borrows its Context; destroy it before the Context.
pub const OperationFactory = struct {
    ctx: *c.PJ_CONTEXT,
    ptr: *c.PJ_OPERATION_FACTORY_CONTEXT,

    /// Create a factory; null authority searches all authorities.
    pub fn create(ctx: Context, authority: ?[*:0]const u8) Error!OperationFactory {
        return .{
            .ctx = ctx.ptr,
            .ptr = try require(
                *c.PJ_OPERATION_FACTORY_CONTEXT,
                c.proj_create_operation_factory_context(
                    ctx.ptr,
                    if (authority) |name| name else null,
                ),
            ),
        };
    }

    /// Destroy this factory.
    pub fn destroy(self: OperationFactory) void {
        c.proj_operation_factory_context_destroy(self.ptr);
    }

    /// Set the desired operation accuracy in metres.
    pub fn setDesiredAccuracy(self: OperationFactory, accuracy: f64) void {
        c.proj_operation_factory_context_set_desired_accuracy(self.ctx, self.ptr, accuracy);
    }

    /// Set the area of interest in west, south, east, north order, in degrees.
    pub fn setAreaOfInterest(
        self: OperationFactory,
        west_lon_degree: f64,
        south_lat_degree: f64,
        east_lon_degree: f64,
        north_lat_degree: f64,
    ) void {
        c.proj_operation_factory_context_set_area_of_interest(
            self.ctx,
            self.ptr,
            west_lon_degree,
            south_lat_degree,
            east_lon_degree,
            north_lat_degree,
        );
    }

    /// Set how strictly candidate validity areas must contain the area of interest.
    pub fn setSpatialCriterion(self: OperationFactory, criterion: SpatialCriterion) void {
        c.proj_operation_factory_context_set_spatial_criterion(
            self.ctx,
            self.ptr,
            @intFromEnum(criterion),
        );
    }

    /// Choose how missing grids affect candidates; discard removes unavailable-grid operations.
    pub fn setGridAvailabilityUse(self: OperationFactory, use: GridAvailabilityUse) void {
        c.proj_operation_factory_context_set_grid_availability_use(
            self.ctx,
            self.ptr,
            @intFromEnum(use),
        );
    }

    /// Set whether PROJ may search through an intermediate CRS.
    pub fn setAllowUseIntermediateCrs(self: OperationFactory, use: IntermediateCrsUse) void {
        c.proj_operation_factory_context_set_allow_use_intermediate_crs(
            self.ctx,
            self.ptr,
            @intFromEnum(use),
        );
    }

    /// Set whether superseded operations are discarded.
    pub fn setDiscardSuperseded(self: OperationFactory, discard: bool) void {
        c.proj_operation_factory_context_set_discard_superseded(
            self.ctx,
            self.ptr,
            if (discard) 1 else 0,
        );
    }

    /// Permit approximate ballpark substitutions; false may leave no candidates.
    pub fn setAllowBallparkTransformations(self: OperationFactory, allow: bool) void {
        c.proj_operation_factory_context_set_allow_ballpark_transformations(
            self.ctx,
            self.ptr,
            if (allow) 1 else 0,
        );
    }

    /// Return the caller-owned candidate list; destroy the list and each returned object.
    /// An empty list means no operation satisfies the selected constraints.
    pub fn createOperations(
        self: OperationFactory,
        source_crs: Object,
        target_crs: Object,
    ) Error!?ObjectList {
        return ObjectList.create(
            self.ctx,
            c.proj_create_operations(self.ctx, source_crs.ptr, target_crs.ptr, self.ptr),
        );
    }
};

// Lists.

/// Caller-owned list of candidate or replacement objects.
/// Destroy the list and each object returned by `get`.
pub const ObjectList = struct {
    ptr: *c.PJ_OBJ_LIST,
    ctx: *c.PJ_CONTEXT,

    /// Wrap a non-null upstream list.
    fn create(ctx: *c.PJ_CONTEXT, raw: ?*c.PJ_OBJ_LIST) Error!?ObjectList {
        if (raw) |list| return .{ .ptr = list, .ctx = ctx };
        return null;
    }

    /// Destroy the list container; returned Objects remain caller-owned.
    pub fn destroy(self: ObjectList) void {
        c.proj_list_destroy(self.ptr);
    }

    /// Return the operation count; a zero-length list differs from a null result.
    pub fn len(self: ObjectList) c_int {
        return c.proj_list_get_count(self.ptr);
    }

    /// Return a new object at `index`, or null when the index is invalid.
    pub fn get(self: ObjectList, index: c_int) Error!?Object {
        const raw = c.proj_list_get(self.ctx, self.ptr, index);
        if (raw == null) return null;
        return Object{ .ptr = try require(*c.PJ, raw), .ctx = self.ctx };
    }

    /// Return the matching operation's list index, or a negative value; no transform is run.
    pub fn suggestedOperation(self: ObjectList, direction: Direction, point: Coord) c_int {
        return suggestionIndex(self.ctx, self.ptr, direction, point);
    }
};

/// PROJ-owned null-terminated string list; destroy it to release all elements.
/// Database list methods return this caller-owned wrapper.
pub const StringList = struct {
    /// C string-pointer array terminated by a null element.
    ptr: [*c][*c]u8,

    /// Wrap a non-null upstream string list.
    fn create(raw: [*c][*c]u8) Error!?StringList {
        if (@intFromPtr(raw) == 0) return null;
        return .{ .ptr = raw };
    }

    /// Destroy the list and all its strings.
    pub fn destroy(self: StringList) void {
        c.proj_string_list_destroy(self.ptr);
    }

    /// Count strings by scanning to the null terminator.
    pub fn len(self: StringList) usize {
        var count: usize = 0;
        var i: usize = 0;
        while (@intFromPtr(self.ptr[i]) != 0) : (i += 1) count += 1;
        return count;
    }

    /// One string, borrowed from the list. Dead after `destroy`.
    pub fn at(self: StringList, index: usize) ?[:0]const u8 {
        var i: usize = 0;
        var count: usize = 0;
        while (@intFromPtr(self.ptr[i]) != 0) : (i += 1) {
            if (count == index) return std.mem.span(self.ptr[i]);
            count += 1;
        }
        return null;
    }
};

/// Caller-owned array of database CRS records; each record and string borrows from it.
/// Destroy the list to release them; element borrows expire then.
pub const CrsInfoList = struct {
    ptr: [*c][*c]CrsInfo,
    count: c_int,

    /// Wrap an upstream array and its record count.
    fn create(raw: [*c][*c]CrsInfo, count: c_int) Error!?CrsInfoList {
        if (@intFromPtr(raw) == 0) return null;
        return .{ .ptr = raw, .count = count };
    }

    /// Destroy the array and its records.
    pub fn destroy(self: CrsInfoList) void {
        c.proj_crs_info_list_destroy(self.ptr);
    }

    /// Return the reported count, clamped at zero.
    pub fn len(self: CrsInfoList) usize {
        if (self.count <= 0) return 0;
        return @intCast(self.count);
    }

    /// Return a record borrowed from this list.
    pub fn at(self: CrsInfoList, index: usize) ?*CrsInfo {
        if (index >= self.len()) return null;
        return self.ptr[index];
    }
};

/// Caller-owned array of unit-info records from the database.
pub const UnitInfoList = struct {
    ptr: [*c][*c]UnitInfo,
    count: c_int,

    /// Wrap an upstream array and its record count.
    fn create(raw: [*c][*c]UnitInfo, count: c_int) Error!?UnitInfoList {
        if (@intFromPtr(raw) == 0) return null;
        return .{ .ptr = raw, .count = count };
    }

    /// Destroy the array and its records.
    pub fn destroy(self: UnitInfoList) void {
        c.proj_unit_list_destroy(self.ptr);
    }

    /// Return the reported count, clamped at zero.
    pub fn len(self: UnitInfoList) usize {
        if (self.count <= 0) return 0;
        return @intCast(self.count);
    }

    /// Return a record borrowed from this list.
    pub fn at(self: UnitInfoList, index: usize) ?*UnitInfo {
        if (index >= self.len()) return null;
        return self.ptr[index];
    }
};

/// Caller-owned array of PROJ celestial-body records.
/// Record names borrow from the array and expire after `destroy`.
pub const CelestialBodyList = struct {
    ptr: [*c][*c]c.PROJ_CELESTIAL_BODY_INFO,
    count: c_int,

    /// Destroy the array and its records.
    pub fn destroy(self: CelestialBodyList) void {
        c.proj_celestial_body_list_destroy(self.ptr);
    }

    /// Return the reported count, clamped at zero.
    pub fn len(self: CelestialBodyList) usize {
        if (self.count <= 0) return 0;
        return @intCast(self.count);
    }

    /// Return a record borrowed from this list.
    pub fn at(self: CelestialBodyList, index: usize) ?*c.PROJ_CELESTIAL_BODY_INFO {
        if (index >= self.len()) return null;
        return self.ptr[index];
    }
};

/// Allocate CRS-query parameters; release them with `CrsListParametersHandle.destroy`.
/// Defaults impose no type, bounds, deprecation, or celestial-body restrictions.
pub fn crsListParametersCreate() Error!CrsListParametersHandle {
    return .{
        .ptr = try require(
            *c.PROJ_CRS_LIST_PARAMETERS,
            c.proj_get_crs_list_parameters_create(),
        ),
    };
}

/// Owned handle returned by `crsListParametersCreate`.
pub const CrsListParametersHandle = struct {
    ptr: *c.PROJ_CRS_LIST_PARAMETERS,

    /// Destroy this handle.
    pub fn destroy(self: CrsListParametersHandle) void {
        c.proj_get_crs_list_parameters_destroy(self.ptr);
    }
};

/// Query CRS records from an open database; null authority searches all.
/// Null parameters apply no filter.
pub fn crsInfoListFromDatabase(
    ctx: Context,
    auth_name: ?[*:0]const u8,
    parameters: ?*const c.PROJ_CRS_LIST_PARAMETERS,
) Error!?CrsInfoList {
    var count: c_int = 0;
    const raw = c.proj_get_crs_info_list_from_database(
        ctx.ptr,
        if (auth_name) |name| name else null,
        if (parameters) |p| p else null,
        &count,
    );
    return CrsInfoList.create(raw, count);
}

/// Query units from an open database; null authority or category searches all.
/// Categories: linear, linear_per_time, angular, angular_per_time, scale, scale_per_time, time; false excludes deprecated records.
pub fn unitsFromDatabase(
    ctx: Context,
    auth_name: ?[*:0]const u8,
    category: ?[*:0]const u8,
    allow_deprecated: bool,
) Error!?UnitInfoList {
    var count: c_int = 0;
    const raw = c.proj_get_units_from_database(
        ctx.ptr,
        if (auth_name) |name| name else null,
        if (category) |cat| cat else null,
        if (allow_deprecated) 1 else 0,
        &count,
    );
    return UnitInfoList.create(raw, count);
}

/// Query celestial-body records from an open database; null authority searches all.
pub fn celestialBodyListFromDatabase(
    ctx: Context,
    auth_name: ?[*:0]const u8,
) Error!?CelestialBodyList {
    var count: c_int = 0;
    const raw = c.proj_get_celestial_body_list_from_database(
        ctx.ptr,
        if (auth_name) |name| name else null,
        &count,
    );
    // Compare the address because the translated C pointer type cannot express nullability.
    if (@intFromPtr(raw) == 0) return null;
    return .{
        .ptr = raw,
        .count = count,
    };
}
