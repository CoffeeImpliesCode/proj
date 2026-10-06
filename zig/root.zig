// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md for what that identifier covers.

//! Public Zig surface of the PROJ 9.9.0 fork: the typed facade over the
//! compiled C library in `src/`.
//!
//! ## What is reached, and how
//!
//!   * `pub const c` — the translation of `zig/translate.h`, which is upstream's
//!     `src/proj.h` and `src/proj_constants.h` byte for byte. All 292 `proj_*`
//!     function declarations, the `PJ_COORD` union and every structure upstream
//!     publishes are there. Reach for it when a declaration below is not the shape
//!     you want.
//!   * the typed surface below — `Context`, `Object`, `OperationFactory`,
//!     `ObjectList`, `StringList`, `Area`, `CrsInfoList`, `UnitInfoList`,
//!     `CelestialBodyList` and the records around them.
//!   * the by-value ABI bridge below — ten upstream entry points move `PJ_COORD`
//!     by value and this compiler and the one that built the archive disagree
//!     about where it goes, so those calls are made in C. `zig/proj_abi.h` is
//!     the contract and `FORK-NOTES.md` § 12 is the evidence.
//!
//! ## Types are aliases, not copies
//!
//! Every structure below is `pub const X = c.Y;`. That is deliberate and it is
//! the point of a binding: `Coord` here **is** the translated `PJ_COORD`, the
//! `extern union` `src/proj.h:315-330` declares, so its twelve arms have exactly
//! the layout upstream's C++ core writes through (`src/fwd.cpp:47-56`,
//! `src/inv.cpp:41-42`). Re-typing it would create a second, hand-maintained copy
//! of an ABI the shipped header already states exactly, the two could drift while
//! both compiled, and the facade's `Coord` would stop being the type the library
//! actually exchanges. The doc comment on `Coord` writes out every arm and its
//! source line, so the layout is auditable without a second declaration.
//!
//! ## Pointers are upstream's, not optional ones
//!
//! A translated C pointer keeps its C spelling: `const char *` arrives as
//! `[*:0]const u8` and `PJ *` as `*c.PJ`, and both can be null. This file does not
//! widen them to `?` and does not narrow them either, because either would be a
//! second ABI. So a parameter that upstream documents as "may be null" takes a
//! plain pointer here and the caller passes `null`, and a return that upstream
//! documents as "null in case of error" comes back as a plain pointer that
//! `maybeSpan` or `require` turns into an optional slice or an error. `void *` is
//! the one exception the translation makes, arriving as `?*anyopaque`, and it is
//! used only where upstream itself says "optional".
//!
//! ## Units are never converted, and never guessed
//!
//! `Coord` fields are whatever the CRS being used says they are: degrees for a
//! geographic CRS, metres or feet for a projected one, metres for a geocentric
//! one. Nothing here inspects a CRS to decide, because upstream does not:
//! `proj_trans` hands the coordinate to the operation and returns what comes out
//! (`src/trans.cpp:355-359`). `toRad` and `toDeg` exist because upstream exposes
//! them (`src/proj.h:807-808`); they convert a number, not a coordinate.
//!
//! ## Axis order is the authority's, not the caller's
//!
//! `EPSG:4326` is **latitude-then-longitude**. `src/proj.h` documents a CRS's
//! axes as the CRS declares them, and the EPSG registry declares 4326 with
//! GeodeticLatitude first. An operation built by `Context.crsToCrs` respects that,
//! so `Object.trans` on a 4326 → 3857 operation takes latitude in `v[0]` and
//! longitude in `v[1]`.
//!
//! `Object.normalizeForVisualization` is the documented other route
//! (`src/proj.h:602`; upstream's own summary is "Returns a PJ* object whose axis
//! order is the one expected for visualization purposes",
//! `src/iso19111/c_api.cpp:2205`). For `EPSG:4326` it inserts an axis-order
//! reversal so longitude comes first. The two routes are not interchangeable and
//! this facade does not blur them.
//!
//! ## Failure is reported out of band, so it is read explicitly
//!
//! PROJ rarely returns an error from a fallible call. It returns `NULL`, or the
//! upstream error coordinate, and records the reason on the object or the context:
//! `proj_coord_error()` is four `HUGE_VAL`s (`src/internal.cpp:65-68`) and
//! `src/trans.cpp:344` sets `PROJ_ERR_COORD_TRANSFM_NO_OPERATION`. So:
//!
//!   * a call that promised an object and got `NULL` is `error.NullReturn`, and
//!     the code PROJ set is read with `errno`. There is one such code per context
//!     plus the thread-local C `errno`, not one per object: `proj_errno(P)` is
//!     literally `proj_context_errno(pj_get_ctx(P))` (`src/ctx.cpp:217-223`), so
//!     `Object.errno` and `Context.errno` answer the same question and a second
//!     failing call overwrites what the first recorded.
//!   * `Object.trans` returns whatever upstream returned, including the error
//!     coordinate. `isErrorCoordinate` is how a caller asks; reading `v[0]`
//!     without asking would be reading `HUGE_VAL` as a coordinate.
//!   * an `int`-returning query that answers false is `error.UpstreamRefused`.
//!     Upstream uses false both for an error and for "there is no such answer",
//!     and does not always separate them: `proj_get_area_of_use` returns false
//!     "in case of error or if the area of use is unknown"
//!     (`src/iso19111/c_api.cpp:1971-1972`).
//!
//! ## Ownership
//!
//! Three families, and they are not interchangeable.
//!
//!   * **Objects and handles.** `Context`, `Object`, `OperationFactory`,
//!     `ObjectList`, `StringList`, `Area`, `CrsInfoList`, `UnitInfoList`,
//!     `CelestialBodyList` and `CrsListParametersHandle` each own exactly what
//!     upstream allocated, and each has a `destroy` that calls upstream's matching
//!     release exactly once. Upstream's own releases carry no information:
//!     `proj_context_destroy` returns `nullptr` on every path including success
//!     (`src/ctx.cpp:309-320`) and `proj_destroy` does the same
//!     (`src/malloc.cpp:100-110`), so `destroy` returns nothing rather than
//!     inventing a success value upstream never produces.
//!   * **Borrows that die with their owner.** `name`, `remarks`, `idAuthName`,
//!     `idCode`, `scope`, `celestialBodyName`, `areaOfUse().name`,
//!     `csAxisInfo`, `coordoperationMethodInfo`, `coordoperationParam` and
//!     `coordoperationGridUsed` all return slices into storage the `PJ` or the
//!     context owns. Upstream states the lifetime for each; the doc comment on
//!     each repeats the line.
//!   * **Copies the caller owns.** `Context.databasePath` and
//!     `Context.databaseMetadata` are the two that copy, and they have to:
//!     upstream keeps one slot per context for each and the *next* call overwrites
//!     it. `src/iso19111/c_api.cpp:394-397` says the database path "remains valid
//!     while ctx is valid, and until proj_context_set_database_path() is called";
//!     `:418-421` says the same of a metadata item. A caller holding two of them
//!     at once would be holding one string and two pointers to it. Those two
//!     return `!` because the copy can fail. Everything else borrows.
//!
//! ## PROJ allocates with the C allocator
//!
//! Every `PJ`, every context, every WKT string and every SQLite connection in this
//! library is allocated with C `new`/`malloc` and released with `delete`/`free`
//! inside the library (`src/ctx.cpp:305-306`, `src/malloc.cpp:100-110`,
//! `src/iso19111/c_api.cpp:9557`). This facade allocates exactly one kind of
//! thing — the two copies named above, with the caller's allocator — and hands
//! every other pointer straight back.
//!
//! **A Zig test allocator cannot be given a leak oracle for that.**
//! `std.testing` checks what *it* allocated; PROJ's memory is behind `malloc`
//! inside the library and is not reachable from a `std.mem.Allocator`. The tests
//! therefore say nothing about PROJ's leaks, and a green test here is not a
//! statement about them. What *is* checkable, and is what this file does, is that
//! every handle handed out has a `destroy` and that each is released on every
//! path.
//!
//! ## Two configurations: linked and runtime-loaded
//!
//! This module is built in one of two shapes, and `runtime_loaded` says which at
//! comptime.
//!
//! *Linked* is the default. `libproj` is linked, `c` is the translated header,
//! and every call below is a direct call with no table and no readiness check.
//!
//! *Runtime-loaded* is opt-in (`-Druntime`). Nothing native is linked into the
//! module; `c` is a dispatch generated from the same translation, resolving all
//! 292 `proj_*` entry points through the platform loader once the caller has
//!
//! ```zig
//! try proj.load(.{ .path = "/usr/lib/libproj.so.25" });
//! ```
//!
//! before anything else. A call into a module that has not loaded stops the
//! program with a message naming the function, in every optimization mode: the
//! table does not exist yet and there is no partial state to fall back on. The
//! load itself reports a missing file, a provider that does not export the names
//! `src/proj.h` declares, a request that cannot be honoured because a different
//! provider already won, or a reentrant call, as errors.
//!
//! `runtime/library.zig` states the whole provider boundary. The part that
//! matters most here: PROJ has no external ABI family of its own, but a provider
//! compiled with `PROJ_RENAME_SYMBOLS` exports `internal_proj_*` instead of
//! `proj_*` (`src/proj.h:127-129`, `src/proj_symbol_rename.h:32-36`) and is
//! refused. SQLite3's and libc's are real and belong to that file.
//!
//! That rename is not perfectly uniform, and the exception is worth knowing
//! before someone reasons from it. `src/proj_symbol_rename.h` holds 314 renames
//! — 291 `proj_*`, 21 `geod_*`, and `projinfo` and `pj_release` — and one public
//! `proj_*` entry point is missing from it: `proj_crs_is_dynamic`
//! (`src/proj.h:1435`), whose immediate neighbour `proj_crs_is_derived`
//! (`src/proj.h:1433`) *is* renamed. So a renamed provider exports
//! `internal_proj_crs_is_derived` next to a plain `proj_crs_is_dynamic`, and a
//! loader that demanded every declaration be renamed under its `internal_` name
//! would refuse it over one function. `Object.isDynamic` below binds the plain
//! spelling, which is the spelling this build's own library exports.
//!
//! The provider is reached, never guessed: `.path` names a file and `.system`
//! names a library for the platform loader, neither falls back to the other,
//! there is no unload and no reset, and the handle and its own copy of the
//! request live to the end of the process.
//!
//! ## The shortest sequence that uses it
//!
//! **This snippet is documentation, not a compiled artefact.** Zig has no
//! doc-test mechanism: nothing in `zig build check`, `zig build test` or
//! `zig build smoke` extracts code from a comment, so nothing below is evidence
//! and no gate in this fork will tell anyone whether it still compiles. What is
//! evidence is the same work as real code: `tests.zig` checks it against an
//! independent known answer, `smoke.zig` runs it natively,
//! `consumer/src/main.zig` repeats it as a dependent, and
//! `zig/api_exercise.zig` calls every method below so `check` proves the bodies
//! instantiate. Keep them in step when a signature changes.
//!
//! ```zig
//! const std = @import("std");
//! const proj = @import("proj");
//!
//! pub fn main() !void {
//!     var ctx = try proj.Context.create();
//!     defer ctx.destroy();
//!     try ctx.setDatabasePath(null, null, null);
//!
//!     // EPSG:4326 is latitude-then-longitude, so latitude goes in v[0].
//!     var op = try ctx.crsToCrs("EPSG:4326", "EPSG:3857", null);
//!     defer op.destroy();
//!     const out = op.trans(.fwd, proj.coord(40.0, -75.0, 0.0, 0.0));
//!     std.debug.print("{d:.3} {d:.3}\n", .{ out.v[0], out.v[1] });
//! }
//! ```

const std = @import("std");

// ---- The translated header --------------------------------------------------

/// The translation of `zig/translate.h`: upstream's `src/proj.h` and
/// `src/proj_constants.h`.
///
/// The contract for every declaration here is the text of those files at the
/// pinned revision, and that is the documentation. Nothing in this file restates
/// a declaration's meaning; it states the lifetime, the ownership and the NULL
/// convention, which the C header does not always say in one place.
pub const c = @import("c");

/// The loader core, which is where a *linked* build's `LoadSource` and
/// `LoadError` come from.
///
/// Referenced only from the comptime branches below, so in a runtime-loading build
/// — where this import is not bound, because the generated dispatch carries the
/// same two declarations itself — it is never resolved.
const rt = @import("rt");

/// Whether this module was configured to resolve PROJ's symbols at run time.
///
/// False for the ordinary build, where `proj_*` is linked and `c` is the
/// translated header itself. True when the build generated a dispatch that
/// resolves the same 292 entry points through the platform loader, in which case
/// `load` is the call that makes the library usable and nothing may be called
/// before it.
///
/// A comptime constant, so a consumer can write two code paths and have only the
/// one it chose analyzed.
pub const runtime_loaded: bool = if (@hasDecl(c, "rt_runtime_loaded")) c.rt_runtime_loaded else false;

/// Which native library `load` should open.
///
/// `.path` is an explicit absolute file path and `.system` an explicit basename
/// for the platform loader. There is no path-to-system fallback and no implicit
/// fallback of any kind; a request that cannot be honoured is an error, not a
/// different library.
pub const LoadSource = if (runtime_loaded) c.LoadSource else rt.LoadSource;

/// Every way `load` can decline.
///
/// Declared here, in the module a consumer imports, rather than only inside the
/// loader: the caller names the failure it is handling.
pub const LoadError = if (runtime_loaded) c.LoadError else rt.LoadError;

/// Load the native library this module dispatches to.
///
/// In a runtime-loading build this is the whole contract: call it once, then use
/// this module exactly as a linked build would. Calling it again with the same
/// request succeeds and changes nothing; calling it with a different request
/// after a success is `ProviderMismatch`, and the library already in use stays in
/// use. A failed attempt publishes nothing and is retried only by calling this
/// again — there is no automatic retry and no implicit second source.
///
/// Safe to call from any thread. A thread that arrives while an attempt for the
/// same request is in flight waits for it and gets its result, whatever it was.
/// A call from the thread running the attempt is `ReentrantLoad` rather than a
/// deadlock.
///
/// In a linked build there is no provider, no table and nothing to resolve, so
/// this stops the program with a message saying so instead of quietly succeeding.
/// `runtime_loaded` is false there, so a consumer that supports both
/// configurations can tell them apart at comptime instead of meeting this at run
/// time.
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

/// The request that succeeded, or null when nothing has loaded yet.
///
/// The loader's own retained copy, valid for the life of the process. Null in a
/// linked build, which has no request.
pub fn loadedSource() ?LoadSource {
    if (runtime_loaded) return c.loadedSource();
    return null;
}

// ---- Errors -----------------------------------------------------------------

/// Everything this module can refuse.
///
/// Each is raised by an ordinary comparison in this file, in every optimize mode,
/// on a condition the documentation above promises to check. None is a
/// `std.debug.assert`: a check that disappears in ReleaseSafe would mean the
/// contract it guards is enforced nowhere.
pub const Error = error{
    /// Upstream returned `NULL` where this facade had promised an object.
    ///
    /// Deliberately one error for every NULL return. PROJ reports *why* out of
    /// band rather than in the return value — it writes one code into the context
    /// slot (`proj_context_errno`, `src/proj.h:769`) — and different constructors
    /// set different codes.
    /// `proj_create_argv` sets `PROJ_ERR_INVALID_OP_MISSING_ARG` for a null argv
    /// and `PROJ_ERR_INVALID_OP` for the allocation it then fails
    /// (`src/create.cpp:266-279`), while `proj_create_crs_to_crs` returns NULL
    /// for "no operation found matching criteria" and sets no code at all
    /// (`src/crs_to_crs.cpp:589-591`). A second error per constructor would claim
    /// a distinction the C does not make. Read the code instead.
    NullReturn,

    /// The allocator the caller handed this module refused to copy a string.
    ///
    /// Only the two copying methods below can produce it.
    OutOfMemory,

    /// An upstream query that returns an `int` answered false.
    ///
    /// Upstream uses false both for an error and for "there is no such answer".
    /// `proj_get_area_of_use` is explicit: "TRUE in case of success, FALSE in
    /// case of error or if the area of use is unknown"
    /// (`src/iso19111/c_api.cpp:1971-1972`). `proj_trans_bounds` also pre-fills
    /// all four outputs with `HUGE_VAL` before it starts
    /// (`src/trans_bounds.cpp:413-416`), so handing the box back would be handing
    /// back four infinities as an answer.
    UpstreamRefused,

    /// A length did not fit the C `int` that carries it.
    ///
    /// Reached only by `Context.createArgv`, whose count upstream takes as
    /// `int argc` (`src/proj.h:594`).
    TooManyItems,
};

/// Upstream's C string as a borrowed span, or null when upstream had none.
///
/// The parameter keeps the **translated** C pointer type `[*c]const u8`, and
/// that is the whole point. Declaring it `[*:0]const u8` instead makes the
/// compiler insert a non-null check **at every call site**, before this body
/// runs, so the `@intFromPtr` test below would be dead code and a documented
/// NULL would abort the process instead of becoming `null`. An optional pointer
/// parameter does not help either: `?[*c]const u8` holding address zero is a
/// present value wrapping a null pointer, `orelse` does not fire, and
/// `std.mem.span` asserts on it.
///
/// This is not hypothetical. `proj_get_name` answers NULL for the "Set of
/// coordinate operations" object `proj_create_crs_to_crs_from_pj` builds when it
/// leaves alternatives behind and nulls `iso_obj`
/// (`src/crs_to_crs.cpp:783-795`), and upstream documents that NULL as an answer
/// for any object that is not an identified object
/// (`src/iso19111/c_api.cpp:1516-1519`).
inline fn maybeSpan(ptr: [*c]const u8) ?[:0]const u8 {
    if (@intFromPtr(ptr) == 0) return null;
    return std.mem.span(ptr);
}

/// Copy an upstream string into the caller's allocator, or null when upstream had
/// none. Used only where upstream's own borrow is shorter-lived than the caller
/// needs; see the module doc. The pointer type is `maybeSpan`'s, for the same
/// reason.
fn copyString(gpa: std.mem.Allocator, ptr: [*c]const u8) Error!?[]const u8 {
    const borrowed = maybeSpan(ptr) orelse return null;
    return try gpa.dupe(u8, borrowed);
}

/// Upstream's own pointer, or `error.NullReturn` when upstream returned `NULL`.
///
/// PROJ's fallible constructors promise an object and report failure by handing
/// back `NULL`, never by returning a value a caller could mistake for one:
/// `proj_context_create` constructs with `new (std::nothrow)`
/// (`src/ctx.cpp:305-306`), so its NULL is that allocation failing, and
/// `proj_create_crs_to_crs` returns NULL for "no operation found matching
/// criteria" and sets no code at all (`src/crs_to_crs.cpp:589-591`). Both are
/// this one error, because the reason is out of band in the context's `errno`
/// slot and is read with it (see the module doc): one error for every NULL, and
/// a second one per constructor would claim a distinction the C does not make.
///
/// The test is an ordinary comparison, in every optimize mode, and the pointer
/// handed back is upstream's own: same address, same ownership, same lifetime.
/// Nothing stands in for the NULL — there is no default object and no
/// placeholder for a value upstream did not produce.
fn require(comptime T: type, ptr: ?T) Error!T {
    return ptr orelse error.NullReturn;
}

/// `bool` from a C `int` upstream documents as a truth value.
fn isSet(v: c_int) bool {
    return v != 0;
}

// ---- Enumerations -----------------------------------------------------------

/// Which way to run a transformation — `enum PJ_DIRECTION` (`src/proj.h:616-621`).
///
/// Upstream's values are 1, 0 and -1 and the negative is load-bearing:
/// `PJ_IDENT` is not "no direction", it is the direction that means "do nothing"
/// (`src/proj.h:618`), and `proj_trans` returns the coordinate untouched for it
/// (`src/trans.cpp:222-223`).
pub const Direction = enum(c_int) {
    /// `PJ_FWD` — `src/proj.h:617`.
    fwd = 1,
    /// `PJ_IDENT` — `src/proj.h:618`.
    ident = 0,
    /// `PJ_INV` — `src/proj.h:619`.
    inv = -1,
};

/// What an ISO19111 object is — `PJ_TYPE` (`src/proj.h:865-910`).
///
/// `PJ_TYPE_CRS` (8) is documented as abstract and never returned by
/// `proj_get_type` (`src/proj.h:878-879`), and `PJ_TYPE_GEOGRAPHIC_CRS` (11) the
/// same (`:884-886`). Both are here because upstream's own switches handle them,
/// and a binding that dropped them would not have a total mapping from the C's
/// tag set to the Zig one.
pub const Type = enum(c_uint) {
    /// `PJ_TYPE_UNKNOWN` — `src/proj.h:866`.
    unknown = 0,
    /// `PJ_TYPE_ELLIPSOID` — `:868`.
    ellipsoid = 1,
    /// `PJ_TYPE_PRIME_MERIDIAN` — `:870`.
    prime_meridian = 2,
    /// `PJ_TYPE_GEODETIC_REFERENCE_FRAME` — `:872`.
    geodetic_reference_frame = 3,
    /// `PJ_TYPE_DYNAMIC_GEODETIC_REFERENCE_FRAME` — `:873`.
    dynamic_geodetic_reference_frame = 4,
    /// `PJ_TYPE_VERTICAL_REFERENCE_FRAME` — `:874`.
    vertical_reference_frame = 5,
    /// `PJ_TYPE_DYNAMIC_VERTICAL_REFERENCE_FRAME` — `:875`.
    dynamic_vertical_reference_frame = 6,
    /// `PJ_TYPE_DATUM_ENSEMBLE` — `:876`.
    datum_ensemble = 7,
    /// `PJ_TYPE_CRS` — `:879`. Abstract; `proj_get_type` never returns it.
    crs = 8,
    /// `PJ_TYPE_GEODETIC_CRS` — `:881`.
    geodetic_crs = 9,
    /// `PJ_TYPE_GEOCENTRIC_CRS` — `:882`.
    geocentric_crs = 10,
    /// `PJ_TYPE_GEOGRAPHIC_CRS` — `:886`. Abstract; never returned.
    geographic_crs = 11,
    /// `PJ_TYPE_GEOGRAPHIC_2D_CRS` — `:887`.
    geographic_2d_crs = 12,
    /// `PJ_TYPE_GEOGRAPHIC_3D_CRS` — `:888`.
    geographic_3d_crs = 13,
    /// `PJ_TYPE_VERTICAL_CRS` — `:889`.
    vertical_crs = 14,
    /// `PJ_TYPE_PROJECTED_CRS` — `:890`.
    projected_crs = 15,
    /// `PJ_TYPE_COMPOUND_CRS` — `:891`.
    compound_crs = 16,
    /// `PJ_TYPE_TEMPORAL_CRS` — `:892`.
    temporal_crs = 17,
    /// `PJ_TYPE_ENGINEERING_CRS` — `:893`.
    engineering_crs = 18,
    /// `PJ_TYPE_BOUND_CRS` — `:894`.
    bound_crs = 19,
    /// `PJ_TYPE_OTHER_CRS` — `:895`.
    other_crs = 20,
    /// `PJ_TYPE_CONVERSION` — `:897`.
    conversion = 21,
    /// `PJ_TYPE_TRANSFORMATION` — `:898`.
    transformation = 22,
    /// `PJ_TYPE_CONCATENATED_OPERATION` — `:899`.
    concatenated_operation = 23,
    /// `PJ_TYPE_OTHER_COORDINATE_OPERATION` — `:900`.
    other_coordinate_operation = 24,
    /// `PJ_TYPE_TEMPORAL_DATUM` — `:902`.
    temporal_datum = 25,
    /// `PJ_TYPE_ENGINEERING_DATUM` — `:903`.
    engineering_datum = 26,
    /// `PJ_TYPE_PARAMETRIC_DATUM` — `:904`.
    parametric_datum = 27,
    /// `PJ_TYPE_DERIVED_PROJECTED_CRS` — `:906`.
    derived_projected_crs = 28,
    /// `PJ_TYPE_COORDINATE_METADATA` — `:909`.
    coordinate_metadata = 29,
};

/// Which registry family an object belongs to — `PJ_CATEGORY`
/// (`src/proj.h:855-862`).
pub const Category = enum(c_uint) {
    /// `PJ_CATEGORY_ELLIPSOID` — `src/proj.h:856`.
    ellipsoid = 0,
    /// `PJ_CATEGORY_PRIME_MERIDIAN` — `:857`.
    prime_meridian = 1,
    /// `PJ_CATEGORY_DATUM` — `:858`.
    datum = 2,
    /// `PJ_CATEGORY_CRS` — `:859`.
    crs = 3,
    /// `PJ_CATEGORY_COORDINATE_OPERATION` — `:860`.
    coordinate_operation = 4,
    /// `PJ_CATEGORY_DATUM_ENSEMBLE` — `:861`.
    datum_ensemble = 5,
};

/// What kind of coordinate system a `PJ` is — `PJ_COORDINATE_SYSTEM_TYPE`
/// (`src/proj.h:1024-1036`).
pub const CoordinateSystemType = enum(c_uint) {
    /// `PJ_CS_TYPE_UNKNOWN` — `src/proj.h:1025`.
    unknown = 0,
    /// `PJ_CS_TYPE_CARTESIAN` — `:1027`.
    cartesian = 1,
    /// `PJ_CS_TYPE_ELLIPSOIDAL` — `:1028`.
    ellipsoidal = 2,
    /// `PJ_CS_TYPE_VERTICAL` — `:1029`.
    vertical = 3,
    /// `PJ_CS_TYPE_SPHERICAL` — `:1030`.
    spherical = 4,
    /// `PJ_CS_TYPE_ORDINAL` — `:1031`.
    ordinal = 5,
    /// `PJ_CS_TYPE_PARAMETRIC` — `:1032`.
    parametric = 6,
    /// `PJ_CS_TYPE_DATETIMETEMPORAL` — `:1033`.
    datetime_temporal = 7,
    /// `PJ_CS_TYPE_TEMPORALCOUNT` — `:1034`.
    temporal_count = 8,
    /// `PJ_CS_TYPE_TEMPORALMEASURE` — `:1035`.
    temporal_measure = 9,
};

/// Which WKT flavour to export — `PJ_WKT_TYPE` (`src/proj.h:934-951`).
///
/// The C enum's two deprecated aliases are not fields here. `PJ_WKT2_2018` is
/// `PJ_WKT2_2019` (`src/proj.h:942`) and `PJ_WKT2_2018_SIMPLIFIED` is
/// `PJ_WKT2_2019_SIMPLIFIED` (`:946`); they are the same numbers with a second
/// spelling, and a Zig enum with two fields of one value would give a caller two
/// names for one answer. They are constants on the enum below.
pub const WktType = enum(c_uint) {
    /// `PJ_WKT2_2015` — `src/proj.h:936`.
    wkt2_2015 = 0,
    /// `PJ_WKT2_2015_SIMPLIFIED` — `:937`.
    wkt2_2015_simplified = 1,
    /// `PJ_WKT2_2019` — `:938`.
    wkt2_2019 = 2,
    /// `PJ_WKT2_2019_SIMPLIFIED` — `:944`.
    wkt2_2019_simplified = 3,
    /// `PJ_WKT1_GDAL` — `:947`.
    wkt1_gdal = 4,
    /// `PJ_WKT1_ESRI` — `:949`.
    wkt1_esri = 5,

    /// `PJ_WKT2_2018`, the deprecated alias of `wkt2_2019` — `src/proj.h:942`.
    pub const wkt2_2018: WktType = .wkt2_2019;
    /// `PJ_WKT2_2018_SIMPLIFIED`, the deprecated alias of
    /// `wkt2_2019_simplified` — `src/proj.h:946`.
    pub const wkt2_2018_simplified: WktType = .wkt2_2019_simplified;
};

/// What dialect a WKT string is in — `PJ_GUESSED_WKT_DIALECT`
/// (`src/proj.h:834-852`).
pub const GuessedDialect = enum(c_uint) {
    /// `PJ_GUESSED_WKT2_2019` — `src/proj.h:836`.
    wkt2_2019 = 0,
    /// `PJ_GUESSED_WKT2_2015` — `:842`.
    wkt2_2015 = 1,
    /// `PJ_GUESSED_WKT1_GDAL` — `:844`.
    wkt1_gdal = 2,
    /// `PJ_GUESSED_WKT1_ESRI` — `:847`.
    wkt1_esri = 3,
    /// `PJ_GUESSED_NOT_WKT` — `:850`.
    not_wkt = 4,

    /// `PJ_GUESSED_WKT2_2018`, the deprecated alias of `wkt2_2019` —
    /// `src/proj.h:839`.
    pub const wkt2_2018: GuessedDialect = .wkt2_2019;
};

/// Which PROJ-string syntax to export — `PJ_PROJ_STRING_TYPE`
/// (`src/proj.h:992-997`).
pub const ProjStringType = enum(c_uint) {
    /// `PJ_PROJ_5` — `src/proj.h:994`.
    proj5 = 0,
    /// `PJ_PROJ_4` — `:996`.
    proj4 = 1,
};
/// How missing grids affect the candidate list — `PROJ_GRID_AVAILABILITY_USE`
/// (`src/proj.h:972-989`).
///
/// This is what makes Fixture C in `tests.zig` a boundary rather than a
/// preference: `discard_operation_if_missing_grid` removes an operation outright
/// instead of merely sorting it last (`:977-978`), and
/// `proj_create_crs_to_crs` picks exactly that when the network is off and nothing
/// else asks otherwise (`src/crs_to_crs.cpp:571-576`).
pub const GridAvailabilityUse = enum(c_uint) {
    /// `PROJ_GRID_AVAILABILITY_USED_FOR_SORTING` — `src/proj.h:975`.
    used_for_sorting = 0,
    /// `PROJ_GRID_AVAILABILITY_DISCARD_OPERATION_IF_MISSING_GRID` — `:978`.
    discard_operation_if_missing_grid = 1,
    /// `PROJ_GRID_AVAILABILITY_IGNORED` — `:982`.
    ignored = 2,
    /// `PROJ_GRID_AVAILABILITY_KNOWN_AVAILABLE` — `:988`.
    known_available = 3,
};

/// How strictly an operation's area of validity must contain the area of interest
/// — `PROJ_SPATIAL_CRITERION` (`src/proj.h:1000-1008`).
pub const SpatialCriterion = enum(c_uint) {
    /// `PROJ_SPATIAL_CRITERION_STRICT_CONTAINMENT` — `src/proj.h:1003`.
    strict_containment = 0,
    /// `PROJ_SPATIAL_CRITERION_PARTIAL_INTERSECTION` — `:1007`.
    partial_intersection = 1,
};

/// Whether intermediate CRS may be searched for — `PROJ_INTERMEDIATE_CRS_USE`
/// (`src/proj.h:1011-1021`).
pub const IntermediateCrsUse = enum(c_uint) {
    /// `PROJ_INTERMEDIATE_CRS_USE_ALWAYS` — `src/proj.h:1013`.
    always = 0,
    /// `PROJ_INTERMEDIATE_CRS_USE_IF_NO_DIRECT_TRANSFORMATION` — `:1017`.
    if_no_direct_transformation = 1,
    /// `PROJ_INTERMEDIATE_CRS_USE_NEVER` — `:1020`.
    never = 2,
};

/// How strict a CRS comparison should be — `PJ_COMPARISON_CRITERION`
/// (`src/proj.h:913-931`).
pub const ComparisonCriterion = enum(c_uint) {
    /// `PJ_COMP_STRICT` — `src/proj.h:915`.
    strict = 0,
    /// `PJ_COMP_EQUIVALENT` — `:924`.
    equivalent = 1,
    /// `PJ_COMP_EQUIVALENT_EXCEPT_AXIS_ORDER_GEOGCRS` — `:930`.
    equivalent_except_axis_order_geogcrs = 2,
};

/// How much PROJ should say — `PJ_LOG_LEVEL` (`src/proj.h:373-381`).
///
/// `PJ_LOG_DEBUG_MAJOR` (2) and `PJ_LOG_DEBUG_MINOR` (3) are the same two numbers
/// as `debug` and `trace`, kept for `proj_api.h` compatibility
/// (`src/proj.h:379-380`); they are constants below for the same reason `WktType`
/// carries its aliases that way.
pub const LogLevel = enum(c_uint) {
    /// `PJ_LOG_NONE` — `src/proj.h:374`.
    none = 0,
    /// `PJ_LOG_ERROR` — `:375`.
    err = 1,
    /// `PJ_LOG_DEBUG` — `:376`.
    debug = 2,
    /// `PJ_LOG_TRACE` — `:377`.
    trace = 3,
    /// `PJ_LOG_TELL` — `:378`.
    tell = 4,

    /// `PJ_LOG_DEBUG_MAJOR`, compatibility alias of `debug` — `src/proj.h:379`.
    pub const debug_major: LogLevel = .debug;
    /// `PJ_LOG_DEBUG_MINOR`, compatibility alias of `trace` — `src/proj.h:380`.
    pub const debug_minor: LogLevel = .trace;
};

// ---- Error codes ------------------------------------------------------------

/// PROJ's `PJ_ERR_*` codes, as upstream computes them.
///
/// Every value below is the arithmetic of `src/proj.h:715-766`, written out
/// rather than left to a macro expansion so a reader can check the number against
/// the line. **Nothing in this facade branches on these codes**: PROJ carries them
/// on the context or the object rather than in a return value
/// (`src/proj.h:769-770`), so a caller reads them with `Context.errno` or
/// `Object.errno` and decides. They are named here because the tests compare them
/// and because naming a number upstream computed is not the same as re-deriving
/// it.
///
/// Two paths in `src/crs_to_crs.cpp` set **no** code: "No operation found
/// matching criteria" (`:589-591`) and the early `proj_destroy(P); return
/// nullptr` after a non-instantiable single candidate (`:637-640`). A binding that
/// reported a code there would be inventing one, and `tests.zig` does not.
pub const ErrorCode = struct {
    /// `PROJ_ERR_INVALID_OP` — `src/proj.h:715-717`, value 1024.
    pub const invalid_op: c_int = 1024;
    /// `PROJ_ERR_INVALID_OP_WRONG_SYNTAX` — `:718-720`, 1025.
    pub const invalid_op_wrong_syntax: c_int = 1024 + 1;
    /// `PROJ_ERR_INVALID_OP_MISSING_ARG` — `:721-722`, 1026.
    pub const invalid_op_missing_arg: c_int = 1024 + 2;
    /// `PROJ_ERR_INVALID_OP_ILLEGAL_ARG_VALUE` — `:723-725`, 1027.
    pub const invalid_op_illegal_arg_value: c_int = 1024 + 3;
    /// `PROJ_ERR_INVALID_OP_MUTUALLY_EXCLUSIVE_ARGS` — `:726-727`, 1028.
    pub const invalid_op_mutually_exclusive_args: c_int = 1024 + 4;
    /// `PROJ_ERR_INVALID_OP_FILE_NOT_FOUND_OR_INVALID` — `:728-730`, 1029.
    ///
    /// The code a missing datum grid reports on the grid-loading path
    /// (`src/grids.cpp:3235-3236`, `:3561-3562`), which is why Fixture C looks
    /// for it as well as for the transformation-time codes.
    pub const invalid_op_file_not_found_or_invalid: c_int = 1024 + 5;

    /// `PROJ_ERR_COORD_TRANSFM` — `src/proj.h:733-734`, value 2048.
    pub const coord_transfm: c_int = 2048;
    /// `PROJ_ERR_COORD_TRANSFM_INVALID_COORD` — `:735-736`, 2049.
    pub const coord_transfm_invalid_coord: c_int = 2048 + 1;
    /// `PROJ_ERR_COORD_TRANSFM_OUTSIDE_PROJECTION_DOMAIN` — `:737-741`, 2050.
    pub const coord_transfm_outside_projection_domain: c_int = 2048 + 2;
    /// `PROJ_ERR_COORD_TRANSFM_NO_OPERATION` — `:742-746`, 2051.
    ///
    /// What `proj_trans` sets when a `PJ` carrying alternative operations found
    /// none that would work (`src/trans.cpp:344`), and what `proj_trans_array`
    /// falls back to when its failures do not share one code (`src/trans.cpp:410`).
    pub const coord_transfm_no_operation: c_int = 2048 + 3;
    /// `PROJ_ERR_COORD_TRANSFM_OUTSIDE_GRID` — `:747-749`, 2052.
    pub const coord_transfm_outside_grid: c_int = 2048 + 4;
    /// `PROJ_ERR_COORD_TRANSFM_GRID_AT_NODATA` — `:750-752`, 2053.
    pub const coord_transfm_grid_at_nodata: c_int = 2048 + 5;
    /// `PROJ_ERR_COORD_TRANSFM_NO_CONVERGENCE` — `:753-754`, 2054.
    pub const coord_transfm_no_convergence: c_int = 2048 + 6;
    /// `PROJ_ERR_COORD_TRANSFM_MISSING_TIME` — `:755-757`, 2055.
    pub const coord_transfm_missing_time: c_int = 2048 + 7;

    /// `PROJ_ERR_OTHER` — `src/proj.h:760`, value 4096.
    pub const other: c_int = 4096;
    /// `PROJ_ERR_OTHER_API_MISUSE` — `:761-762`, 4097.
    pub const other_api_misuse: c_int = 4096 + 1;
    /// `PROJ_ERR_OTHER_NO_INVERSE_OP` — `:763-764`, 4098.
    pub const other_no_inverse_op: c_int = 4096 + 2;
    /// `PROJ_ERR_OTHER_NETWORK_ERROR` — `:765-766`, 4099.
    ///
    /// Only reachable with networking enabled, which this package's gates turn
    /// off. `src/grids.cpp:3233-3237` shows it taking precedence over the "file
    /// not found" code, so a network failure is not misreported as a missing file.
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
/// `PJ_GRID_INFO` — `src/proj.h:355-363`.
///
/// Exposed for completeness of the type surface. The accessor that fills it,
/// `proj_grid_info` (`src/proj.h:788`), is deliberately not bound: it describes an
/// on-disk grid file and this fork ships none. Reach it through
/// `c.proj_grid_info` if you need it.
pub const GridInfo = c.PJ_GRID_INFO;
/// `PROJ_CRS_INFO` — `src/proj.h:1043-1075`.
///
/// `PJ_CRS_INFO` is not a name at this pin: upstream spells this and the two
/// records below with a `PROJ_` prefix, and a binding that spelled it `PJ_CRS_INFO`
/// would be inventing a type name.
pub const CrsInfo = c.PROJ_CRS_INFO;
/// `PROJ_UNIT_INFO` — `src/proj.h:1122-1146`.
pub const UnitInfo = c.PROJ_UNIT_INFO;
/// `PROJ_CRS_LIST_PARAMETERS` — `src/proj.h:1082-1114`.
pub const CrsListParameters = c.PROJ_CRS_LIST_PARAMETERS;
/// `PJ_OBJ_LIST` — `src/proj.h:1184`. Opaque upstream and opaque here.
pub const ObjectListHandle = c.PJ_OBJ_LIST;
/// `PJ_LOG_FUNCTION` — `src/proj.h:383`: `void (*)(void *, int, const char *)`.
pub const LogFunction = c.PJ_LOG_FUNCTION;

/// `PJ_COORD` — `src/proj.h:315-330`, the union `proj_trans` takes and returns.
///
/// This is the translated type, not a copy, and every arm is upstream's under
/// upstream's name:
///
///     union PJ_COORD {
///         double v[4];   // :316-317  "First and foremost, it really is
///                         //            just 4 numbers in a vector"
///         PJ_XYZT xyzt;   // :318      double x, y, z, t      (:273-275)
///         PJ_UVWT uvwt;   // :319      double u, v, w, t      (:277-278)
///         PJ_LPZT lpzt;   // :320      double lam, phi, z, t  (:280-281)
///         PJ_GEOD geod;   // :321      double s, a1, a2       (:289-290)
///         PJ_OPK  opk;    // :322      double o, p, k        (:283-284)
///         PJ_ENU  enu;    // :323      double e, n, u        (:286-287)
///         PJ_XYZ  xyz;    // :324      double x, y, z        (:304-305)
///         PJ_UVW  uvw;    // :325      double u, v, w        (:309-310)
///         PJ_LPZ  lpz;    // :326      double lam, phi, z    (:311-312)
///         PJ_XY   xy;     // :327      double x, y           (:298-299)
///         PJ_UV   uv;     // :328      double u, v           (:294-295)
///         PJ_LP   lp;     // :329      double lam, phi       (:300-301)
///     };
///
/// The arms are not decoration. `src/proj.h:313-314` says the union exists to
/// "Avoid preprocessor renaming and implicit type-punning", and the core relies on
/// the layout: `pj_fwd4d` and the projection functions read and write through the
/// arms directly (`src/fwd.cpp:47-56`, `src/inv.cpp:41-42`), so `xy` and `lp` are
/// the same four words read two ways and `v` is the array they alias.
pub const Coord = c.PJ_COORD;

// ---- The by-value ABI bridge ------------------------------------------------

/// The pointer-shaped route into the compiled library, one declaration for
/// every entry point whose upstream signature moves a `PJ_COORD` by value.
///
/// **Why a Zig declaration is not enough.** Upstream passes and returns
/// `PJ_COORD` by value on purpose - `src/proj.h:65-71` calls that out - and ten
/// entry points are written that way: `src/proj.h:629` `proj_trans`, `:656`
/// `proj_coord`, `:663` `proj_lp_dist`, `:666` `proj_lpz_dist`, `:669`
/// `proj_xy_dist`, `:672` `proj_xyz_dist`, `:676` `proj_geod`, `:705`
/// `proj_geod_direct`, `:783` `proj_factors` and `:1426-1429`
/// `proj_get_suggested_operation`. The C compiler that builds this package's
/// archive classifies that 32-byte union as a four-element floating-point
/// aggregate and moves it in four consecutive SIMD registers; Zig 0.16.0's own
/// lowering of a call to the same function moves it in memory and reads the
/// result from a slot the callee never wrote. On `aarch64-linux`,
/// `powerpc64le-linux` and thirteen other matrix targets that disagreement
/// turned every transform into zeros; `src/proj.h:65-71` is upstream's design,
/// so the call is not negotiable and the two halves of it have to be made by one
/// compiler.
///
/// `zig/proj_abi.h` is the C contract for these declarations and is compiled
/// into the same archive. Nothing but a pointer, a `double` and an `int` crosses
/// back out of it.
///
/// The declarations are written here rather than translated from that header
/// because `runtime/generate.zig` builds the runtime route's symbol table out of
/// the one translation `zig/translate.h` names, and it is checked against the
/// 292 entry points `src/proj.h` declares; a second translated header would
/// either miss that check or put ten fork names in a table that is supposed to
/// hold exactly PROJ's. `Coord`, `Factors`, `c.PJ` and `c.PJ_CONTEXT` below are
/// the translated types, so the two spellings cannot drift apart in their types -
/// only in a signature, which is why every declaration here names its upstream
/// line and the header names the same line.
const c_abi = struct {
    extern fn proj_abi_coord(x: f64, y: f64, z: f64, t: f64, out: *Coord) void;
    extern fn proj_abi_trans(P: ?*c.PJ, direction: c.PJ_DIRECTION, in: *const Coord, out: *Coord) void;
    extern fn proj_abi_lp_dist(P: ?*const c.PJ, a: *const Coord, b: *const Coord) f64;
    extern fn proj_abi_xy_dist(a: *const Coord, b: *const Coord) f64;
    extern fn proj_abi_xyz_dist(a: *const Coord, b: *const Coord) f64;
    extern fn proj_abi_factors(P: ?*c.PJ, lp: *const Coord, out: *Factors) void;
    extern fn proj_abi_get_suggested_operation(ctx: ?*c.PJ_CONTEXT, operations: ?*c.PJ_OBJ_LIST, direction: c.PJ_DIRECTION, coord: *const Coord) c_int;
};

/// Upstream's initializer, reached the way this build can vouch for.
fn makeCoord(x: f64, y: f64, z: f64, t: f64) Coord {
    if (comptime runtime_loaded) return c.proj_coord(x, y, z, t);
    var out: Coord = undefined;
    c_abi.proj_abi_coord(x, y, z, t, &out);
    return out;
}

/// `proj_trans`, reached the way this build can vouch for.
fn transformCoord(P: ?*c.PJ, direction: Direction, point: Coord) Coord {
    if (comptime runtime_loaded) return c.proj_trans(P, @intFromEnum(direction), point);
    var out: Coord = undefined;
    c_abi.proj_abi_trans(P, @intFromEnum(direction), &point, &out);
    return out;
}

/// `proj_lp_dist`, reached the way this build can vouch for.
fn lpDistance(P: ?*const c.PJ, a: Coord, b: Coord) f64 {
    if (comptime runtime_loaded) return c.proj_lp_dist(P, a, b);
    return c_abi.proj_abi_lp_dist(P, &a, &b);
}

/// `proj_xy_dist`, reached the way this build can vouch for.
fn xyDistanceBetween(a: Coord, b: Coord) f64 {
    if (comptime runtime_loaded) return c.proj_xy_dist(a, b);
    return c_abi.proj_abi_xy_dist(&a, &b);
}

/// `proj_xyz_dist`, reached the way this build can vouch for.
fn xyzDistanceBetween(a: Coord, b: Coord) f64 {
    if (comptime runtime_loaded) return c.proj_xyz_dist(a, b);
    return c_abi.proj_abi_xyz_dist(&a, &b);
}

/// `proj_factors`, reached the way this build can vouch for.
fn pointFactors(P: ?*c.PJ, lp: Coord) Factors {
    if (comptime runtime_loaded) return c.proj_factors(P, lp);
    var out: Factors = undefined;
    c_abi.proj_abi_factors(P, &lp, &out);
    return out;
}

/// `proj_get_suggested_operation`, reached the way this build can vouch for.
fn suggestionIndex(ctx: ?*c.PJ_CONTEXT, operations: ?*c.PJ_OBJ_LIST, direction: Direction, point: Coord) c_int {
    if (comptime runtime_loaded) return c.proj_get_suggested_operation(ctx, operations, @intFromEnum(direction), point);
    return c_abi.proj_abi_get_suggested_operation(ctx, operations, @intFromEnum(direction), &point);
}

/// What PROJ reports about itself — `proj_info()` (`src/proj.h:786`).
///
/// The strings borrow out of the static `PJ_INFO` upstream fills, so they live as
/// long as the process and need no release. Each is optional because the C type is
/// `const char *` and a binding promising a string where the C allows null would
/// promise more than upstream does.
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
    /// `PJ_INFO.searchpath` — `:338-341`, where init and grid files were looked
    /// for.
    searchpath: ?[:0]const u8,
};

/// The bounding box of an area of use, in degrees.
///
/// Every field is what the CRS declares. A CRS with no area of use does not
/// produce one: upstream answers false, which is `error.UpstreamRefused`.
pub const AreaOfUse = struct {
    /// Western-most longitude, degrees. `src/proj.h:1263`.
    west_lon_degree: f64,
    /// Southern-most latitude, degrees.
    south_lat_degree: f64,
    /// Eastern-most longitude, degrees.
    east_lon_degree: f64,
    /// Northern-most latitude, degrees.
    north_lat_degree: f64,
    /// Name of the area, a borrow from the `PJ` that produced it and valid while
    /// that `PJ` is (`src/iso19111/c_api.cpp:1969-1970`).
    name: ?[:0]const u8,
};

/// One axis of a coordinate system — the seven out-parameters of
/// `proj_cs_get_axis_info` (`src/proj.h:1472-1476`) gathered into one record.
///
/// Upstream has no struct for this: it passes seven pointers and fills each with a
/// `const char *` pointing into the coordinate system's own storage
/// (`src/iso19111/c_api.cpp:9178-9199`). Every string below is a borrow that dies
/// with the `PJ` you asked, so this record owns nothing and has no `destroy`.
///
/// There is no upstream type named `PJ_COORDINATE_SYSTEM_INFO` at this pin. This
/// is the shape a caller wants, over the shape the C has, and the doc comment
/// says so rather than pretending a type exists.
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

/// The shape parameters of an ellipsoid — the four out-parameters of
/// `proj_ellipsoid_get_parameters` (`src/proj.h:1480-1484`).
pub const EllipsoidParameters = struct {
    /// Semi-major axis, metres.
    semi_major_metre: f64,
    /// Semi-minor axis, metres. Zero when `semi_minor_computed` is false.
    semi_minor_metre: f64,
    /// Whether upstream computed the semi-minor axis rather than reading it. An
    /// ellipsoid the registry gave as an inverse flattening has one.
    semi_minor_computed: bool,
    /// Inverse flattening. Zero when the ellipsoid was given a semi-minor axis
    /// instead.
    inv_flattening: f64,
};

/// The longitude and unit of a prime meridian — the three out-parameters of
/// `proj_prime_meridian_get_parameters` (`src/proj.h:1491-1495`).
pub const PrimeMeridianParameters = struct {
    /// Longitude from Greenwich, in `unit_name`. For Greenwich itself, zero.
    longitude: f64,
    /// Factor to multiply `longitude` by to get radians.
    unit_conv_factor: f64,
    /// Unit `longitude` is expressed in, a borrow from the `PJ`.
    unit_name: ?[:0]const u8,
};

/// One parameter of a coordinate operation — the eleven out-parameters of
/// `proj_coordoperation_get_param` (`src/proj.h:1519-1524`).
///
/// Every string is a borrow from the operation `PJ`. `value_string` is null unless
/// upstream can only express the value in text.
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
    /// Unit category: "linear", "angular", "scale", "time" and so on.
    /// `src/proj.h:1522`.
    unit_category: ?[:0]const u8,
};

/// One grid a coordinate operation needs — the six out-parameters of
/// `proj_coordoperation_get_grid_used` (`src/proj.h:1529-1533`).
///
/// Every string is a borrow from the operation `PJ`. `available` is upstream's own
/// answer to "can this build reach that file", which is the question Fixture C
/// turns on.
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

/// The method a coordinate operation uses — the three out-parameters of
/// `proj_coordoperation_get_method_info` (`src/proj.h:1499-1501`).
///
/// Every string is a borrow from the operation `PJ`. This is the registry read
/// Fixture B checks: `name` and `code` for `EPSG:32631` are the `proj.db` values,
/// not something this facade computed.
pub const MethodInfo = struct {
    /// Method name, e.g. "Transverse Mercator". `src/proj.h:1500`.
    name: ?[:0]const u8,
    /// Method authority, normally "EPSG". `src/proj.h:1500`.
    auth_name: ?[:0]const u8,
    /// Method code, e.g. "9807". `src/proj.h:1501`.
    code: ?[:0]const u8,
};

/// What a transformed bounding box came to — the four outputs of
/// `proj_trans_bounds` (`src/proj.h:638-642`), in the target CRS's own units.
pub const Bounds = struct {
    xmin: f64,
    ymin: f64,
    xmax: f64,
    ymax: f64,
};

// ---- Module-level functions -------------------------------------------------

/// What PROJ reports about itself — `proj_info` (`src/proj.h:786`).
///
/// Takes no arguments and touches no context, which is why it is here and not a
/// method: `PJ_INFO` describes the *library*, and its `searchpath` field is
/// whatever the process environment resolved, not whatever a particular context
/// was told to look in.
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

/// Release everything PROJ holds in process-wide caches — `proj_cleanup`
/// (`src/proj.h:816`).
///
/// Upstream's global teardown for caches that are not attached to a context. It
/// is not a substitute for destroying a `Context`: it drops the shared database
/// cache and the grid cache, so calling it while a context is live leaves that
/// context's answers depending on what re-initialises afterwards. Destroy your
/// handles first. There is no way back — nothing in PROJ re-creates what this
/// dropped — so this is for a program that is finished with PROJ, not for a
/// pause.
pub fn cleanup() void {
    c.proj_cleanup();
}

/// Build a coordinate from four numbers — `proj_coord` (`src/proj.h:656`).
///
/// Upstream's initializer and nothing more: it writes the four words and returns
/// the union. It does not validate, convert or check a unit.
pub fn coord(x: f64, y: f64, z: f64, t: f64) Coord {
    return makeCoord(x, y, z, t);
}

/// Degrees to radians — `proj_torad` (`src/proj.h:807`).
///
/// A multiplication by a constant (`src/proj.h:801-806` places it in the "trivial"
/// group). It converts the number and nothing else: it does not touch a coordinate
/// and it does not know what CRS you are working in.
pub fn toRad(angle_in_degrees: f64) f64 {
    return c.proj_torad(angle_in_degrees);
}

/// Radians to degrees — `proj_todeg` (`src/proj.h:808`).
pub fn toDeg(angle_in_radians: f64) f64 {
    return c.proj_todeg(angle_in_radians);
}

/// Whether a coordinate is the one upstream returns when it could not transform.
///
/// `proj_coord_error()` writes `HUGE_VAL` into all four words
/// (`src/internal.cpp:65-68`), so this is that test. A caller reading `v[0]`
/// without asking would be reading `HUGE_VAL` as a distance.
///
/// A NaN is not this. `proj_trans` propagates NaN into every component when handed
/// one (`src/trans.cpp:352-354`), which is a different answer with a different
/// cause.
pub fn isErrorCoordinate(point: Coord) bool {
    const huge = std.math.inf(f64);
    return point.v[0] == huge and
        point.v[1] == huge and
        point.v[2] == huge and
        point.v[3] == huge;
}

/// Euclidean distance between two linear 2D points — `proj_xy_dist`
/// (`src/proj.h:669`).
///
/// Takes no `PJ`: upstream's own signature does not have one.
pub fn xyDistance(a: Coord, b: Coord) f64 {
    return xyDistanceBetween(a, b);
}

/// Euclidean distance between two linear 3D points — `proj_xyz_dist`
/// (`src/proj.h:672`).
pub fn xyzDistance(a: Coord, b: Coord) f64 {
    return xyzDistanceBetween(a, b);
}

/// Release a string PROJ allocated for the caller to free — `proj_string_destroy`
/// (`src/proj.h:1355`; the body is `void proj_string_destroy(char *str) { free(str); }`
/// at `src/iso19111/c_api.cpp:9557`).
///
/// **Do not call this on the result of `Object.asWkt`, `Object.asProjString` or
/// `Object.asProjJson`.** Those three return a borrow from a slot inside the
/// object — `obj->lastWKT` at `src/iso19111/c_api.cpp:1708`, with the lifetime
/// stated at `:1611-1612` — not a `malloc`ed string, and freeing one would corrupt
/// the object. Upstream's own unit test never frees them
/// (`test/unit/test_c_api.cpp:496-541`).
///
/// What *is* caller-freed at this pin is `proj_suggests_code_for`, whose own
/// documentation says "to be freed with proj_string_destroy"
/// (`src/iso19111/c_api.cpp:9509-9511`). This facade does not bind that function,
/// so a caller who reached it through `pub const c` uses this to release what it
/// returned; nothing in the typed surface below produces such a string.
pub fn freeString(str: [*c]u8) void {
    c.proj_string_destroy(str);
}

/// Release an `int` list — `proj_int_list_destroy` (`src/proj.h:1300`).
///
/// Upstream's only producer for this shape is the confidence array
/// `proj_identify` writes through `int **out_confidence` (`src/proj.h:1291-1294`).
/// This facade does not bind `proj_identify`, so nothing in the typed surface
/// produces such a list and no caller of this goes through it. It is exposed
/// because upstream declares it and because a caller who obtained such a list
/// through `pub const c` needs exactly this call and not an allocator's. Passing
/// anything other than what `proj_identify` returned is undefined.
pub fn freeIntList(list: [*c]c_int) void {
    c.proj_int_list_destroy(list);
}

// ---- Context ----------------------------------------------------------------

/// A `PJ_CONTEXT`: the handle every thread-affecting part of PROJ hangs off.
///
/// `proj_context_create` (`src/proj.h:404`) makes one and `proj_context_destroy`
/// (`:405`) frees it.
///
/// **Never the default context.** Upstream has a process-wide default that
/// `PJ_DEFAULT_CTX` (`src/proj.h:400-403`) names and that many entry points
/// substitute for a null pointer; nothing here passes one, so every call below has
/// a context the caller owns and every answer belongs to it. Two contexts are
/// independent: separate database caches, separate log levels, separate error
/// codes.
pub const Context = struct {
    ptr: *c.PJ_CONTEXT,

    /// A new context — `proj_context_create` (`src/proj.h:404`).
    ///
    /// Upstream constructs with `new (std::nothrow)`
    /// (`src/ctx.cpp:305-306`), so it can return NULL on allocation failure and
    /// that is `error.NullReturn`.
    pub fn create() Error!Context {
        return .{ .ptr = try require(*c.PJ_CONTEXT, c.proj_context_create()) };
    }

    /// Release this context — `proj_context_destroy` (`src/proj.h:405`).
    ///
    /// Releases everything the context allocated, including its database
    /// connection and its grid cache. Every `Object` created from this context must
    /// be destroyed first: an `Object` holds a borrowed pointer to its context, and
    /// using one after this is a use-after-free this facade cannot detect.
    ///
    /// Returns nothing, because upstream's own release carries no information:
    /// `src/ctx.cpp:309-320` returns `nullptr` on every path, including the path
    /// where it frees.
    pub fn destroy(self: Context) void {
        _ = c.proj_context_destroy(self.ptr);
    }

    /// An independent copy — `proj_context_clone` (`src/proj.h:406`).
    ///
    /// The clone starts from the parent's settings and then diverges. Destroy both.
    pub fn clone(self: Context) Error!Context {
        return .{ .ptr = try require(*c.PJ_CONTEXT, c.proj_context_clone(self.ptr)) };
    }

    // -- Objects -------------------------------------------------------------

    /// Build an object from a PROJ string — `proj_create` (`src/proj.h:593`).
    ///
    /// Named `createFromProjString`, not `create`, because Zig has no
    /// overloading and `Context.create()` above is already the context
    /// constructor. It sits with `createArgv`, `createFromWkt` and
    /// `createFromDatabase` as the source the object is built from.
    ///
    /// `definition` is the whole `+proj=...` pipeline text.
    /// `init=epsg:XXXX` needs the legacy rules turned on first
    /// (`Context.useProj4InitRules`); upstream rejects it otherwise
    /// (`src/create.cpp:301-303`).
    pub fn createFromProjString(self: Context, definition: [*:0]const u8) Error!Object {
        return self.adopt(c.proj_create(self.ptr, definition));
    }

    /// Build an object from separate arguments — `proj_create_argv`
    /// (`src/proj.h:594`).
    ///
    /// `argv` is a slice of *sentinel-terminated* strings, and each element stays
    /// the caller's: upstream concatenates the elements into one string and frees
    /// that (`src/create.cpp:275-283`), writing nothing back through `argv`.
    /// Elements may carry the `+` or leave it off (`src/create.cpp:262-263`).
    ///
    /// `argv` elements are `[*:0]const u8`, so the caller's own storage and
    /// spelling stay as they are and upstream receives a pointer array it may
    /// only read.
    pub fn createArgv(self: Context, argv: []const [*:0]const u8) Error!Object {
        if (argv.len > @as(usize, @intCast(std.math.maxInt(c_int)))) {
            return error.TooManyItems;
        }
        // Upstream's parameter is `char *const *`, not `const char *const *`
        // (`src/proj.h:594`), which translate-c spells `[*c][*c]u8`. Upstream
        // reads the elements and frees only the concatenation it builds from them
        // (`src/create.cpp:275-283`), so this casts the pointer array's
        // constness and not any string's: the caller's bytes are never written,
        // and the array stays the caller's own.
        return self.adopt(c.proj_create_argv(
            self.ptr,
            @intCast(argv.len),
            @ptrCast(@constCast(argv.ptr)),
        ));
    }

    /// Build an object from WKT — `proj_create_from_wkt` (`src/proj.h:1207-1210`).
    ///
    /// `options` is a null-terminated string list; pass null for none. Upstream can
    /// report parse warnings and grammar errors through its two extra
    /// out-parameters, both caller-freed string lists. This facade passes null for
    /// both and does not expose them, so a WKT string that parses with warnings
    /// parses quietly here. That is a stated gap, not a claim that there were none.
    pub fn createFromWkt(
        self: Context,
        wkt: [*:0]const u8,
        options: [*c]const ?[*:0]const u8,
    ) Error!Object {
        return self.adopt(c.proj_create_from_wkt(self.ptr, wkt, options, null, null));
    }

    /// Read one object out of the database — `proj_create_from_database`
    /// (`src/proj.h:1212-1215`).
    ///
    /// `auth_name` and `code` are what the registry calls the object, e.g.
    /// `"EPSG"` and `"4326"`. `use_proj_alternative_grid_names` asks upstream to
    /// use PROJ's own grid names rather than the registry's; it is an
    /// introspection question, not an ownership one.
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

    /// A transformation between two CRS descriptions — `proj_create_crs_to_crs`
    /// (`src/proj.h:595-596`).
    ///
    /// `area` restricts the search to one part of the world; pass null for none.
    ///
    /// This entry point takes no options — upstream's signature has no such
    /// parameter. The options (`ONLY_BEST`, `ALLOW_BALLPARK`) belong to
    /// `crsToCrsFromPj` below.
    ///
    /// **`error.NullReturn` here is a real answer, not a bug.** With no grid
    /// present and the network off, upstream finds no operation and returns NULL
    /// (`src/crs_to_crs.cpp:582-591`) — and on that path it sets *no* error code,
    /// only a debug-level log line (`:590`). A test demanding a code there would
    /// demand something the C does not do. See Fixture C in `tests.zig`.
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

    /// A transformation between two objects already in memory —
    /// `proj_create_crs_to_crs_from_pj` (`src/proj.h:597-600`).
    ///
    /// This is the form that takes options. `options` is a null-terminated string
    /// list; pass null for none. Upstream walks it with
    /// `getOptionValue`/`ci_starts_with` (`src/crs_to_crs.cpp:471-477,505`), which
    /// calls `strlen` on each element, so **the terminator is part of the value**:
    /// a list without one makes upstream read past the end.
    ///
    /// **`"ONLY_BEST=YES"` does not make this call fail; it makes the transform
    /// fail.** It sets upstream's `errorIfBestTransformationNotAvailable` flag
    /// (`src/crs_to_crs.cpp:521-526`), and upstream's own description is "With
    /// ONLY_BEST=YES a transformation will fail if a needed grid is unavailable"
    /// (`NEWS.md:751`). The constructor answers NULL only when the factory left a
    /// single candidate and that candidate is not instantiable
    /// (`src/crs_to_crs.cpp:617-641`, `:758-769`); with several candidates it
    /// builds an object and `proj_trans` does the refusing, by warning about the
    /// missing grid and setting `PROJ_ERR_COORD_TRANSFM_NO_OPERATION`
    /// (`src/trans.cpp:289-294`).
    ///
    /// **What comes back is not always one coordinate operation.** When a single
    /// candidate survives, upstream returns it directly
    /// (`src/crs_to_crs.cpp:776-781`); when several do, it returns the "Set of
    /// coordinate operations" shell with `iso_obj` nulled
    /// (`src/crs_to_crs.cpp:783-795`). That shell has no name of its own —
    /// `name` answers null — and is not a coordinate operation, so
    /// `coordoperationHasBallparkTransformation` and friends refuse it. `lastUsedOperation`
    /// is how a caller names the operation a given point actually used
    /// (`src/proj.h:630`, `src/trans.cpp:363-377`).
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

    /// Point this context at a `proj.db` — `proj_context_set_database_path`
    /// (`src/proj.h:1192-1194`).
    ///
    /// Pass null for `db_path` to take upstream's default resolution, which is
    /// `PROJ_DATA` first and the deprecated `PROJ_LIB` second
    /// (`src/filemanager.cpp:1119-1127`). This facade does not read those variables
    /// itself, because upstream defines them.
    ///
    /// Returns false — not an error — when upstream refused the request and
    /// restored the previous path (`src/iso19111/c_api.cpp:377-389`). There is no
    /// other way for this call to fail: it either took the path or did not.
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

    /// Where this context found its database — `proj_context_get_database_path`
    /// (`src/proj.h:1196`).
    ///
    /// **This one is copied, and that is not optional.** Upstream keeps a single
    /// `std::string` slot per context and hands back its `c_str()`
    /// (`src/iso19111/c_api.cpp:402-414`), with the lifetime stated as "remains
    /// valid while ctx is valid, and until proj_context_set_database_path() is
    /// called" (`:394-397`). A caller holding two of these at once would hold one
    /// string and two pointers to it, and the first would already have changed. The
    /// copy is in `gpa` and the caller frees it.
    ///
    /// Null when upstream had no path to report or could not reach a database.
    pub fn databasePath(self: Context, gpa: std.mem.Allocator) Error!?[]const u8 {
        return copyString(gpa, c.proj_context_get_database_path(self.ptr));
    }

    /// Read one metadata key — `proj_context_get_database_metadata`
    /// (`src/proj.h:1198-1199`).
    ///
    /// **Also copied**, for the same reason as `databasePath`: upstream has one
    /// slot per context for this too (`src/iso19111/c_api.cpp:445-466`), valid
    /// "while ctx is valid, and until proj_context_get_database_metadata() is
    /// called" (`:418-421`).
    ///
    /// Keys upstream documents are `DATABASE.LAYOUT.VERSION.MAJOR`,
    /// `DATABASE.LAYOUT.VERSION.MINOR`, `EPSG.VERSION`, `EPSG.DATE`,
    /// `ESRI.VERSION`, `ESRI.DATE`, `IGNF.SOURCE`, `IGNF.VERSION`, `IGNF.DATE`,
    /// `NKG.SOURCE`, `NKG.VERSION`, `NKG.DATE`, `PROJ.VERSION` and
    /// `PROJ_DATA.VERSION` (`src/iso19111/c_api.cpp:423-439`). A key with no value
    /// is null and that is not an error: upstream returns null for "no such key"
    /// without setting a code (`:457-459`).
    pub fn databaseMetadata(
        self: Context,
        gpa: std.mem.Allocator,
        key: [:0]const u8,
    ) Error!?[]const u8 {
        return copyString(gpa, c.proj_context_get_database_metadata(self.ptr, key.ptr));
    }

    /// Replace the search path — `proj_context_set_search_paths`
    /// (`src/proj.h:416-417`).
    ///
    /// `paths` is a C array of exactly `count_paths` NUL-terminated strings, not a
    /// null-terminated list, so upstream gets an explicit length. This replaces
    /// whatever `PROJ_DATA`/`PROJ_LIB` resolution found; it does not add to it.
    pub fn setSearchPaths(
        self: Context,
        count_paths: c_int,
        paths: [*c]const [*:0]const u8,
    ) void {
        c.proj_context_set_search_paths(self.ptr, count_paths, paths);
    }

    /// Whether the database closes itself between operations —
    /// `proj_context_set_autoclose_database` (`src/proj.h:1189-1190`).
    ///
    /// Upstream's own default is on; that is a fact about the default and not a
    /// promise this module makes. True here closes the connection after each
    /// operation, false keeps it open.
    pub fn setAutocloseDatabase(self: Context, autoclose: bool) void {
        c.proj_context_set_autoclose_database(self.ptr, if (autoclose) 1 else 0);
    }

    /// Name the SQLite3 VFS to open `proj.db` through —
    /// `proj_context_set_sqlite3_vfs_name` (`src/proj.h:494-495`).
    ///
    /// The name must be one the vendored SQLite3 knows
    /// (`vendor/sqlite3/sqlite3.c`). This facade does not check that; an unknown
    /// name fails where the database is opened rather than here.
    pub fn setSqlite3VfsName(self: Context, name: [:0]const u8) void {
        c.proj_context_set_sqlite3_vfs_name(self.ptr, name.ptr);
    }

    /// Turn network access on or off — `proj_context_set_enable_network`
    /// (`src/proj.h:555`).
    ///
    /// This is the switch Fixture C depends on. With the network off, a grid that
    /// is not on disk is simply not there: `proj_create_crs_to_crs` then chooses
    /// `PROJ_GRID_AVAILABILITY_DISCARD_OPERATION_IF_MISSING_GRID` rather than
    /// assuming the grid could be fetched (`src/crs_to_crs.cpp:571-576`). Upstream
    /// also reads `PROJ_NETWORK` from the environment; this sets the same flag
    /// directly, which is what a test does.
    pub fn setNetworkEnabled(self: Context, enabled: bool) bool {
        return isSet(c.proj_context_set_enable_network(self.ptr, if (enabled) 1 else 0));
    }

    /// Whether the network is on — `proj_context_is_network_enabled`
    /// (`src/proj.h:557`).
    pub fn networkEnabled(self: Context) bool {
        return isSet(c.proj_context_is_network_enabled(self.ptr));
    }

    /// Where PROJ may write user data —
    /// `proj_context_set_user_writable_directory` (`src/proj.h:566-568`).
    ///
    /// `create_dir` asks upstream to create the directory if it is not there.
    /// This facade does not create it and does not report whether upstream did.
    /// The parameter is not named `create` because that would shadow
    /// `Context.create` above.
    pub fn setUserWritableDirectory(
        self: Context,
        path: [:0]const u8,
        create_dir: bool,
    ) void {
        c.proj_context_set_user_writable_directory(self.ptr, path.ptr, if (create_dir) 1 else 0);
    }

    /// The user-writable directory upstream would use —
    /// `proj_context_get_user_writable_directory` (`src/proj.h:563-564`).
    ///
    /// A borrow into the context, valid until the context is destroyed or the
    /// directory is set again. `create_dir` asks upstream to create it.
    pub fn userWritableDirectory(self: Context, create_dir: bool) ?[:0]const u8 {
        return maybeSpan(c.proj_context_get_user_writable_directory(self.ptr, if (create_dir) 1 else 0));
    }

    /// Every authority the database knows —
    /// `proj_get_authorities_from_database` (`src/proj.h:1304`).
    ///
    /// Needs an open database. The result is a caller-freed `StringList`.
    pub fn authoritiesFromDatabase(self: Context) Error!?StringList {
        return StringList.create(c.proj_get_authorities_from_database(self.ptr));
    }

    /// The codes of one kind in one authority — `proj_get_codes_from_database`
    /// (`src/proj.h:1306-1309`).
    ///
    /// Pass null for `auth_name` to search every authority. `allow_deprecated`
    /// false hides deprecated objects, which is upstream's default. The result is
    /// a caller-freed `StringList`.
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

    /// Which WKT dialect a string is in — `proj_context_guess_wkt_dialect`
    /// (`src/proj.h:1204-1205`).
    ///
    /// A guess about text, not a parse: it builds nothing, and `not_wkt` is a normal
    /// answer rather than a failure.
    pub fn guessWktDialect(self: Context, wkt: [*:0]const u8) GuessedDialect {
        return @enumFromInt(c.proj_context_guess_wkt_dialect(self.ptr, wkt));
    }

    /// The error code recorded on this context — `proj_context_errno`
    /// (`src/proj.h:769`).
    ///
    /// This is where PROJ puts the reason for a NULL return from any ISO19111
    /// entry point, and for a failed coordinate transformation. Zero means no
    /// error, which is a value and not a promise that nothing has ever gone wrong.
    pub fn errno(self: Context) c_int {
        return c.proj_context_errno(self.ptr);
    }

    /// PROJ's own text for an error code — `proj_context_errno_string`
    /// (`src/proj.h:774-776`).
    ///
    /// A borrow into a static table upstream keeps, so it lives as long as the
    /// process. Pass a code from `errno`, or one of `ErrorCode`'s constants.
    pub fn errnoString(self: Context, err: c_int) ?[:0]const u8 {
        return maybeSpan(c.proj_context_errno_string(self.ptr, err));
    }

    /// Set the log level and read back the old one — `proj_log_level`
    /// (`src/proj.h:778`).
    ///
    /// Returns the previous level, which is what makes restoring it possible.
    pub fn logLevel(self: Context, log_level: LogLevel) LogLevel {
        return @enumFromInt(c.proj_log_level(self.ptr, @intFromEnum(log_level)));
    }

    /// Replace the log callback — `proj_log_func` (`src/proj.h:779-780`).
    ///
    /// The function pointer is upstream's own type
    /// (`PJ_LOG_FUNCTION`, `src/proj.h:383`). Pass null to remove the callback and
    /// return to upstream's own logging. `app_data` is handed back to the callback
    /// untouched.
    pub fn logFunc(self: Context, app_data: ?*anyopaque, logf: LogFunction) void {
        c.proj_log_func(self.ptr, app_data, logf);
    }

    /// Apply the `+init=epsg:XXXX` compatibility rules —
    /// `proj_context_use_proj4_init_rules` (`src/proj.h:421`).
    ///
    /// Older PROJ documentation calls this `proj_use_proj4_init_rules`. At this pin
    /// the only declaration is the `proj_context_` one above, and a binding that
    /// spelled the short name would be inventing a symbol.
    pub fn useProj4InitRules(self: Context, enable: bool) void {
        c.proj_context_use_proj4_init_rules(self.ptr, if (enable) 1 else 0);
    }

    /// Whether those rules are on — `proj_context_get_use_proj4_init_rules`
    /// (`src/proj.h:422-423`).
    ///
    /// `from_legacy_code_path` asks on behalf of a caller that is itself legacy,
    /// which upstream distinguishes; this passes it through rather than deciding
    /// which caller it is.
    pub fn getUseProj4InitRules(self: Context, from_legacy_code_path: bool) bool {
        return isSet(c.proj_context_get_use_proj4_init_rules(
            self.ptr,
            if (from_legacy_code_path) 1 else 0,
        ));
    }
};

// ---- Object (PJ) ------------------------------------------------------------

/// A `PJ`: a CRS, a datum, an ellipsoid, a conversion, a transformation or a
/// ready-to-use coordinate operation, depending on what was created.
///
/// **An `Object` borrows its context.** Upstream stores the pointer
/// (`src/proj.h:36-49` on why the type is not a `void *`), so destroying the
/// `Context` first leaves every method here a use-after-free. Keep the context
/// alive.
pub const Object = struct {
    ptr: *c.PJ,
    ctx: *c.PJ_CONTEXT,

    /// An independent copy — `proj_clone` (`src/proj.h:1226`).
    pub fn clone(self: Object) Error!Object {
        return .{ .ptr = try require(*c.PJ, c.proj_clone(self.ctx, self.ptr)), .ctx = self.ctx };
    }

    /// Release this object — `proj_destroy` (`src/proj.h:605`).
    ///
    /// Upstream returns `nullptr` on every path (`src/malloc.cpp:100-110`), so
    /// this returns nothing. One upstream case does not free: an object with no
    /// destructor, which `src/malloc.cpp:101-102` returns early for. Nothing this
    /// facade constructs is in that state.
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

    /// Whether the registry marks it deprecated — `proj_is_deprecated`
    /// (`src/proj.h:1236`).
    pub fn isDeprecated(self: Object) bool {
        return isSet(c.proj_is_deprecated(self.ptr));
    }

    /// Whether two objects mean the same thing — `proj_is_equivalent_to`
    /// (`src/proj.h:1240-1241`).
    pub fn isEquivalentTo(self: Object, other: Object, criterion: ComparisonCriterion) bool {
        return isSet(c.proj_is_equivalent_to(self.ptr, other.ptr, @intFromEnum(criterion)));
    }

    /// Its name — `proj_get_name` (`src/proj.h:1249`).
    ///
    /// A borrow from this object: upstream says "The lifetime of the returned
    /// string is the same as the input obj parameter"
    /// (`src/iso19111/c_api.cpp:1505-1507`). Null when the object is not an
    /// identified object or has no name at all (`:1516-1519`) — one null for two
    /// cases, because upstream has one null for two cases.
    pub fn name(self: Object) ?[:0]const u8 {
        return maybeSpan(c.proj_get_name(self.ptr));
    }

    /// The authority of its `index`-th identifier — `proj_get_id_auth_name`
    /// (`src/proj.h:1251`).
    ///
    /// A borrow from this object, on the same terms as `name`.
    pub fn idAuthName(self: Object, index: c_int) ?[:0]const u8 {
        return maybeSpan(c.proj_get_id_auth_name(self.ptr, index));
    }

    /// The code of its `index`-th identifier — `proj_get_id_code`
    /// (`src/proj.h:1253`).
    ///
    /// A borrow from this object. `EPSG:4326` reports `"EPSG"` and `"4326"`.
    pub fn idCode(self: Object, index: c_int) ?[:0]const u8 {
        return maybeSpan(c.proj_get_id_code(self.ptr, index));
    }

    /// Its scope — `proj_get_scope` (`src/proj.h:1259`).
    ///
    /// A borrow from this object.
    pub fn scope(self: Object) ?[:0]const u8 {
        return maybeSpan(c.proj_get_scope(self.ptr));
    }

    /// Its remarks — `proj_get_remarks` (`src/proj.h:1255`).
    ///
    /// A borrow from this object.
    pub fn remarks(self: Object) ?[:0]const u8 {
        return maybeSpan(c.proj_get_remarks(self.ptr));
    }

    /// Where it is meant to be used — `proj_get_area_of_use`
    /// (`src/proj.h:1263-1268`).
    ///
    /// `error.UpstreamRefused` when upstream answers false, which is both an error
    /// and "this object has no area of use"
    /// (`src/iso19111/c_api.cpp:1971-1972`). `name` is a borrow from this object
    /// (`src/iso19111/c_api.cpp:1969-1970`).
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

    /// This object as WKT — `proj_as_wkt` (`src/proj.h:1277-1278`).
    ///
    /// **A borrow, and a short-lived one.** Upstream stores the text in
    /// `obj->lastWKT` (`src/iso19111/c_api.cpp:1708`) and states the lifetime as
    /// "valid while the input obj parameter is valid, and until a next call to
    /// proj_as_wkt() with the same input object" (`:1611-1612`). One object holds
    /// one WKT string, so a second call replaces the first. Do not `freeString` it.
    ///
    /// An unknown option makes upstream refuse outright and return null
    /// (`src/iso19111/c_api.cpp:1702-1706`); null here is "no answer", not an
    /// empty answer.
    pub fn asWkt(
        self: Object,
        kind: WktType,
        options: [*c]const ?[*:0]const u8,
    ) ?[:0]const u8 {
        return maybeSpan(c.proj_as_wkt(self.ctx, self.ptr, @intFromEnum(kind), options));
    }

    /// This object as a PROJ string — `proj_as_proj_string`
    /// (`src/proj.h:1280-1282`).
    ///
    /// A borrow from a one-slot-per-object member, on the same terms as `asWkt`
    /// (`src/iso19111/c_api.cpp:1720-1722`). Do not `freeString` it.
    ///
    /// Upstream warns that a CRS not created from a PROJ string may not export to
    /// one (`src/iso19111/c_api.cpp:1724`), which arrives here as null.
    pub fn asProjString(
        self: Object,
        kind: ProjStringType,
        options: [*c]const ?[*:0]const u8,
    ) ?[:0]const u8 {
        return maybeSpan(c.proj_as_proj_string(self.ctx, self.ptr, @intFromEnum(kind), options));
    }

    /// This object as PROJJSON — `proj_as_projjson` (`src/proj.h:1284-1285`).
    ///
    /// A borrow from a one-slot-per-object member
    /// (`src/iso19111/c_api.cpp:1815-1817`). Do not `freeString` it.
    pub fn asProjJson(self: Object, options: [*c]const [*:0]const u8) ?[:0]const u8 {
        return maybeSpan(c.proj_as_projjson(self.ctx, self.ptr, options));
    }

    /// What upstream says about the operation — `proj_pj_info` (`src/proj.h:787`).
    ///
    /// Three strings borrowed from the object and one number: `accuracy` is -1
    /// when upstream does not know (`src/proj.h:351-352`), which is a value to
    /// test rather than an absence.
    pub fn pjInfo(self: Object) ProjInfo {
        return c.proj_pj_info(self.ptr);
    }

    /// The non-deprecated form of a deprecated object —
    /// `proj_get_non_deprecated` (`src/proj.h:1238`).
    ///
    /// A caller-freed list, or null. Upstream uses null both for "not deprecated"
    /// and for "no replacement exists", so this does too rather than inventing a
    /// distinction.
    pub fn nonDeprecated(self: Object) Error!?ObjectList {
        return ObjectList.create(self.ctx, c.proj_get_non_deprecated(self.ctx, self.ptr));
    }

    /// Move this object to another context — `proj_assign_context` (`src/proj.h:604`).
    ///
    /// Upstream rebinds the pointer and nothing else; the object itself is not
    /// copied, and this facade has no mutable `ctx` field, so the pairing stays as
    /// built unless this is called.
    pub fn assignContext(self: Object, ctx: Context) void {
        c.proj_assign_context(self.ptr, ctx.ptr);
    }

    // -- Errors --------------------------------------------------------------

    /// The error code recorded for this object — `proj_errno` (`src/proj.h:770`).
    ///
    /// **This is the context's code, not a per-object one.** Upstream's body is
    /// `return proj_context_errno(pj_get_ctx((PJ *)P));`
    /// (`src/ctx.cpp:217-223`), so the answer is identical to `ctx.errno` for the
    /// context this object was built from. Two objects sharing a context share
    /// one slot, and a second failing call overwrites what the first recorded.
    pub fn errno(self: Object) c_int {
        return c.proj_errno(self.ptr);
    }

    /// Record a code and read it back — `proj_errno_set` (`src/proj.h:771`).
    ///
    /// **A code of zero is not a clear.** Upstream returns early for `err == 0`
    /// without touching anything (`src/ctx.cpp:242-243`), so this is how to *write*
    /// an error and `errnoReset` is how to clear one. Writes the context slot and
    /// the thread-local C `errno` (`:246-249`) and returns `err`.
    pub fn errnoSet(self: Object, err: c_int) c_int {
        return c.proj_errno_set(self.ptr, err);
    }

    /// Clear the code and read the previous one — `proj_errno_reset`
    /// (`src/proj.h:772`).
    ///
    /// Clears both the context's slot and the thread-local C `errno` and returns
    /// what was there (`src/ctx.cpp:296-301`). Upstream's own doc comment at
    /// `:275-294` gives the bracket-and-restore pattern this exists for.
    pub fn errnoReset(self: Object) c_int {
        return c.proj_errno_reset(self.ptr);
    }

    /// Put a previously saved code back — `proj_errno_restore`
    /// (`src/proj.h:773`).
    ///
    /// The success half of the bracket above: restore what `errnoReset` returned
    /// once the call being measured has finished without setting an error.
    /// **Returns zero whatever it does** (`src/ctx.cpp:253-265`), and a zero
    /// argument is again ignored rather than treated as a clear.
    pub fn errnoRestore(self: Object, err: c_int) c_int {
        return c.proj_errno_restore(self.ptr, err);
    }

    // -- CRS -----------------------------------------------------------------

    /// The same object with visualization-friendly axis order —
    /// `proj_normalize_for_visualization` (`src/proj.h:602`).
    ///
    /// Upstream's own summary: "Returns a PJ* object whose axis order is the one
    /// expected for visualization purposes" (`src/iso19111/c_api.cpp:2205`). For
    /// `EPSG:4326` that means longitude in `v[0]` and latitude in `v[1]`, the
    /// reverse of the CRS's own order, which is why the two routes are not
    /// interchangeable. A new object; destroy it.
    pub fn normalizeForVisualization(self: Object) Error!Object {
        return .{
            .ptr = try require(*c.PJ, c.proj_normalize_for_visualization(self.ctx, self.ptr)),
            .ctx = self.ctx,
        };
    }

    /// The geodetic CRS underneath this one — `proj_crs_get_geodetic_crs`
    /// (`src/proj.h:1437`).
    ///
    /// A new object; destroy it. Null when this is not a CRS.
    pub fn geodeticCrs(self: Object) Error!?Object {
        return self.optional(c.proj_crs_get_geodetic_crs(self.ctx, self.ptr));
    }

    /// Its datum — `proj_crs_get_datum` (`src/proj.h:1443`).
    ///
    /// A new object; destroy it.
    ///
    /// **Null when the CRS is bound to a datum ensemble rather than to a datum.**
    /// That is upstream's own null, not a gap in this facade and not an error:
    /// `proj_crs_get_datum` returns NULL the moment `SingleCRS::datum()` is
    /// null (`src/iso19111/c_api.cpp:8808-8811`) and its summary says so —
    /// "NULL in case of error (or if there is no datum)" (`:8793-8794`) — while
    /// pointing the reader at `proj_crs_get_datum_ensemble` (`:8784-8785`).
    /// `EPSG:4326` is exactly such a CRS in this package's own `proj.db`: its
    /// datum row `EPSG:6326` carries a non-null `ensemble_accuracy` and eight
    /// members, so upstream's factory takes the ensemble branch
    /// (`src/iso19111/factory.cpp:4960-4977`) with `turnEnsembleAsDatum = false`
    /// (`:5538-5541`) and leaves the datum null. Upstream's own test asserts that
    /// shape for `EPSG:4326` (`test/unit/test_factory.cpp:568-571`). For that CRS,
    /// ask `datumEnsemble` or `datumForced`.
    pub fn datum(self: Object) Error!?Object {
        return self.optional(c.proj_crs_get_datum(self.ctx, self.ptr));
    }

    /// Its datum ensemble — `proj_crs_get_datum_ensemble` (`src/proj.h:1445`).
    ///
    /// A new object; destroy it. Null when the CRS has a single datum rather than
    /// an ensemble, which is a fact about the CRS and not a failure.
    pub fn datumEnsemble(self: Object) Error!?Object {
        return self.optional(c.proj_crs_get_datum_ensemble(self.ctx, self.ptr));
    }

    /// A datum for this CRS whether it has one or only an ensemble —
    /// `proj_crs_get_datum_forced` (`src/proj.h:1447`).
    ///
    /// Upstream's own summary: "If the SingleCRS has a datum, then this datum is
    /// returned. Otherwise, the SingleCRS has a datum ensemble, and this datum
    /// ensemble is returned as a regular datum instead of a datum ensemble"
    /// (`src/iso19111/c_api.cpp:8951-8956`), which is the route that reaches the
    /// ensemble's ellipsoid for a CRS such as `EPSG:4326`, where `datum` is null.
    /// A new object; destroy it. Null only when upstream could not build it at
    /// all, which it reports as a debug log line and a NULL return
    /// (`src/iso19111/c_api.cpp:8986-8991`).
    pub fn datumForced(self: Object) Error!?Object {
        return self.optional(c.proj_crs_get_datum_forced(self.ctx, self.ptr));
    }

    /// Its horizontal datum — `proj_crs_get_horizontal_datum`
    /// (`src/proj.h:1439`).
    ///
    /// A new object; destroy it.
    pub fn horizontalDatum(self: Object) Error!?Object {
        return self.optional(c.proj_crs_get_horizontal_datum(self.ctx, self.ptr));
    }

    /// Its coordinate system — `proj_crs_get_coordinate_system`
    /// (`src/proj.h:1465`).
    ///
    /// A new object; destroy it. Every axis question below is asked of what this
    /// returns.
    pub fn coordinateSystem(self: Object) Error!?Object {
        return self.optional(c.proj_crs_get_coordinate_system(self.ctx, self.ptr));
    }

    /// The `index`-th component of a compound CRS — `proj_crs_get_sub_crs`
    /// (`src/proj.h:1441`).
    ///
    /// A new object; destroy it. Null for an index the CRS does not have.
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

    /// The source CRS of a coordinate operation — `proj_get_source_crs`
    /// (`src/proj.h:1287`).
    ///
    /// A new object; destroy it. Null when the object is not an operation with a
    /// source.
    pub fn sourceCrs(self: Object) Error!?Object {
        return self.optional(c.proj_get_source_crs(self.ctx, self.ptr));
    }

    /// The target CRS of a coordinate operation — `proj_get_target_crs`
    /// (`src/proj.h:1289`).
    ///
    /// A new object; destroy it.
    pub fn targetCrs(self: Object) Error!?Object {
        return self.optional(c.proj_get_target_crs(self.ctx, self.ptr));
    }

    /// Bind a CRS to a hub through a transformation —
    /// `proj_crs_create_bound_crs` (`src/proj.h:1848-1850`).
    ///
    /// `self` is the base CRS. `hub_crs` and `transformation` may be null when
    /// there is nothing to bind through. A new object; destroy it.
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

    /// Its ellipsoid — `proj_get_ellipsoid` (`src/proj.h:1478`).
    ///
    /// A new object; destroy it. Null when the object is neither a CRS nor a
    /// geodetic reference frame (`src/iso19111/c_api.cpp:2397-2399`).
    pub fn ellipsoid(self: Object) Error!?Object {
        return self.optional(c.proj_get_ellipsoid(self.ctx, self.ptr));
    }

    /// The shape parameters of an ellipsoid —
    /// `proj_ellipsoid_get_parameters` (`src/proj.h:1480-1484`).
    ///
    /// Ask this of what `ellipsoid` returned. `semi_minor_computed` says which of
    /// the two numbers is derived: the EPSG registry gives an inverse flattening,
    /// so `inv_flattening` is the registry's number and `semi_minor_metre` is
    /// upstream's arithmetic. Fixture B checks the former and says so.
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

    /// Its prime meridian — `proj_get_prime_meridian` (`src/proj.h:1489`).
    ///
    /// A new object; destroy it.
    pub fn primeMeridian(self: Object) Error!?Object {
        return self.optional(c.proj_get_prime_meridian(self.ctx, self.ptr));
    }

    /// The longitude and unit of a prime meridian —
    /// `proj_prime_meridian_get_parameters` (`src/proj.h:1491-1495`).
    ///
    /// Ask this of what `primeMeridian` returned.
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

    /// Which body this object describes — `proj_get_celestial_body_name`
    /// (`src/proj.h:1486-1487`).
    ///
    /// A borrow into the object's own storage
    /// (`src/iso19111/c_api.cpp:2422`, `:2432`), so it dies with the object.
    pub fn celestialBodyName(self: Object) ?[:0]const u8 {
        return maybeSpan(c.proj_get_celestial_body_name(self.ctx, self.ptr));
    }

    /// What kind of coordinate system this is — `proj_cs_get_type`
    /// (`src/proj.h:1467-1468`).
    ///
    /// Ask this of what `coordinateSystem` returned.
    pub fn csType(self: Object) CoordinateSystemType {
        return @enumFromInt(c.proj_cs_get_type(self.ctx, self.ptr));
    }

    /// How many axes it has — `proj_cs_get_axis_count` (`src/proj.h:1470`).
    pub fn csAxisCount(self: Object) c_int {
        return c.proj_cs_get_axis_count(self.ctx, self.ptr);
    }

    /// Everything about one axis — `proj_cs_get_axis_info`
    /// (`src/proj.h:1472-1476`).
    ///
    /// Every string is a borrow from this coordinate-system object
    /// (`src/iso19111/c_api.cpp:9178-9199`), so `AxisInfo` owns nothing and has no
    /// `destroy`; the owner is the `Object` you asked and must outlive it.
    ///
    /// `error.UpstreamRefused` for an index outside `0..csAxisCount`, which
    /// upstream checks before writing anything
    /// (`src/iso19111/c_api.cpp:9174-9177`).
    pub fn csAxisInfo(self: Object, index: c_int) Error!AxisInfo {
        // Named `axis_name`, not `name`: a local may not shadow `Object.name`
        // (root.zig:1535), and the returned field keeps upstream's own spelling.
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

    /// Wrap a `PJ *` upstream returned from a getter that legitimately answers
    /// null, or report the NULL that is a failure. Used by the getters below that
    /// return null for "this object does not have that part".
    fn optional(self: Object, raw: ?*c.PJ) Error!?Object {
        if (raw) |p| return Object{ .ptr = p, .ctx = self.ctx };
        return null;
    }

    // -- Transformation ------------------------------------------------------

    /// Apply this operation — `proj_trans` (`src/proj.h:629`).
    ///
    /// The coordinate is by value, which is upstream's convention
    /// (`src/proj.h:65-71`), and so is the result. **The result is not a result
    /// until `isErrorCoordinate` says it is not upstream's error coordinate**: on
    /// failure upstream returns four `HUGE_VAL`s (`src/internal.cpp:65-68`) and
    /// records the reason where `errno` reads it.
    ///
    /// `Direction.ident` returns the coordinate untouched by design
    /// (`src/trans.cpp:222-223`), and a NaN in the input makes all four outputs NaN
    /// (`src/trans.cpp:352-354`).
    ///
    /// **Upstream takes the coordinate by value; the call itself does not.** The
    /// by-value call is made by `zig/proj_abi.c`, because Zig 0.16.0 and the
    /// compiler that built this package's archive put a 32-byte `PJ_COORD` in
    /// different places and the two halves of the call have to come from one
    /// compiler. See `transformCoord` above and `zig/proj_abi.h` for the
    /// disassembly. The value on the Zig side of that boundary is the same
    /// coordinate upstream passes, and the result is upstream's own.
    pub fn trans(self: Object, direction: Direction, point: Coord) Coord {
        return transformCoord(self.ptr, direction, point);
    }

    /// Transform an array in place — `proj_trans_array` (`src/proj.h:631-632`).
    ///
    /// Every element is transformed even if some fail, and the failed ones become
    /// the error coordinate (`src/trans.cpp:386-393`). Returns 0 when all
    /// succeeded and otherwise the code the failures share, or
    /// `PROJ_ERR_COORD_TRANSFM` when they do not share one
    /// (`src/trans.cpp:400-417`). That return value is one of `ErrorCode`'s
    /// constants, and upstream has set it on the context as well
    /// (`src/trans.cpp:415`).
    pub fn transArray(self: Object, direction: Direction, coords: []Coord) c_int {
        return c.proj_trans_array(self.ptr, @intFromEnum(direction), coords.len, coords.ptr);
    }

    /// Transform strided columns — `proj_trans_generic` (`src/proj.h:633-636`).
    ///
    /// The strides are in **bytes**. A null array or a zero length means "not
    /// supplied"; a length of one means "a constant, broadcast"
    /// (`src/trans.cpp:427-436`). Work is in place, so even the constants come back
    /// changed and must be reinitialised between calls
    /// (`src/trans.cpp:466-470`). Returns the number of transformations completed.
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

    /// Transform a bounding box — `proj_trans_bounds` (`src/proj.h:638-642`).
    ///
    /// `densify_pts` is how many points upstream adds along each edge; upstream
    /// suggests 21 and rejects anything outside `0..10000`
    /// (`src/trans_bounds.cpp:402-403`, `:423`). Returns true on success. On
    /// failure upstream has already written `HUGE_VAL` into all four outputs
    /// (`src/trans_bounds.cpp:413-416`), which is why this is
    /// `error.UpstreamRefused` and not a box of infinities handed back as an
    /// answer.
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

    /// Which operation the last `trans` actually used —
    /// `proj_trans_get_last_used_operation` (`src/proj.h:630`).
    ///
    /// Upstream's own comment: "The returned object must be freed with
    /// proj_destroy()" (`src/trans.cpp:363-369`). A new object; destroy it. Null
    /// when there is no last operation to name.
    pub fn lastUsedOperation(self: Object) Error!?Object {
        return self.optional(c.proj_trans_get_last_used_operation(self.ptr));
    }

    /// Whether the input is angular in this direction —
    /// `proj_angular_input` (`src/proj.h:623`).
    pub fn angularInput(self: Object, direction: Direction) bool {
        return isSet(c.proj_angular_input(self.ptr, @intFromEnum(direction)));
    }

    /// Whether the output is angular in this direction —
    /// `proj_angular_output` (`src/proj.h:624`).
    pub fn angularOutput(self: Object, direction: Direction) bool {
        return isSet(c.proj_angular_output(self.ptr, @intFromEnum(direction)));
    }

    /// Whether the input is in degrees specifically — `proj_degree_input`
    /// (`src/proj.h:626`).
    pub fn degreeInput(self: Object, direction: Direction) bool {
        return isSet(c.proj_degree_input(self.ptr, @intFromEnum(direction)));
    }

    /// Whether the output is in degrees specifically — `proj_degree_output`
    /// (`src/proj.h:627`).
    pub fn degreeOutput(self: Object, direction: Direction) bool {
        return isSet(c.proj_degree_output(self.ptr, @intFromEnum(direction)));
    }

    /// How far a forward and an inverse disagree — `proj_roundtrip`
    /// (`src/proj.h:659-660`).
    ///
    /// Upstream calls this "Measure internal consistency"; it is a diagnostic and
    /// not an accuracy statement. The unit is whatever the coordinates are in.
    pub fn roundtrip(self: Object, direction: Direction, n: c_int, coords: []Coord) f64 {
        return c.proj_roundtrip(self.ptr, @intFromEnum(direction), n, coords.ptr);
    }

    /// Geodesic distance between two angular points on this operation's ellipsoid
    /// — `proj_lp_dist` (`src/proj.h:663`).
    ///
    /// `HUGE_VAL` when the operation has no ellipsoid to measure on
    /// (`src/dist.cpp:43-45`), which is a value to test and not an error.
    pub fn lpDist(self: Object, a: Coord, b: Coord) f64 {
        return lpDistance(self.ptr, a, b);
    }

    /// Cartographic characteristics at a point — `proj_factors` (`src/proj.h:783`).
    ///
    /// Every field is documented at `src/proj.h:206-220`: `meridional_scale` (h),
    /// `parallel_scale` (k), `areal_scale` (s), `angular_distortion` (omega),
    /// `meridian_parallel_angle` (theta-prime), `meridian_convergence` (alpha),
    /// the Tissot indicatrix axes, and the four partial derivatives. This returns
    /// upstream's own struct rather than a re-spelling of it, so a field added
    /// upstream arrives here.
    pub fn factors(self: Object, lp: Coord) Factors {
        return pointFactors(self.ptr, lp);
    }

    // -- Coordinate operations ------------------------------------------------

    /// Which method this operation uses —
    /// `proj_coordoperation_get_method_info` (`src/proj.h:1499-1501`).
    ///
    /// Every string is a borrow from this operation. This is a registry read: the
    /// method name and code come out of `proj.db`, so an operation reporting
    /// "Transverse Mercator" / "9807" is reporting what the EPSG dataset says and
    /// not what this library computed. Fixture B checks exactly that.
    pub fn coordoperationMethodInfo(self: Object) Error!MethodInfo {
        // Named `method_name`, not `name`: a local may not shadow `Object.name`
        // (root.zig:1535), and `MethodInfo.name` keeps upstream's own spelling.
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

    /// How accurate upstream believes this operation is —
    /// `proj_coordoperation_get_accuracy` (`src/proj.h:1535-1536`).
    ///
    /// Metres. A negative value means upstream does not know, which for an
    /// operation this library built itself is the normal answer.
    pub fn coordoperationAccuracy(self: Object) f64 {
        return c.proj_coordoperation_get_accuracy(self.ctx, self.ptr);
    }

    /// How many parameters it has — `proj_coordoperation_get_param_count`
    /// (`src/proj.h:1512-1513`).
    pub fn coordoperationParamCount(self: Object) c_int {
        return c.proj_coordoperation_get_param_count(self.ctx, self.ptr);
    }

    /// One parameter — `proj_coordoperation_get_param` (`src/proj.h:1519-1524`).
    ///
    /// Every string is a borrow from this operation. The parameter names are the
    /// registry's own: `proj_constants.h:307-308` gives
    /// `EPSG_NAME_PARAMETER_FALSE_EASTING` as "False easting", and this is where a
    /// caller reads that back out of the database instead of comparing strings of
    /// its own.
    pub fn coordoperationParam(self: Object, index: c_int) Error!Param {
        // Named `param_name`, not `name`: a local may not shadow `Object.name`
        // (root.zig:1535), and `Param.name` keeps upstream's own spelling.
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

    /// How many grids it needs — `proj_coordoperation_get_grid_used_count`
    /// (`src/proj.h:1526-1527`).
    pub fn coordoperationGridUsedCount(self: Object) c_int {
        return c.proj_coordoperation_get_grid_used_count(self.ctx, self.ptr);
    }

    /// One grid it needs — `proj_coordoperation_get_grid_used`
    /// (`src/proj.h:1529-1533`).
    ///
    /// Every string is a borrow from this operation. `available` is upstream's
    /// answer to "can this build read that file", which is the field Fixture C
    /// reads to show that a datum shift is present in the registry and absent from
    /// the disk.
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

    /// Whether any step is a ballpark substitution —
    /// `proj_coordoperation_has_ballpark_transformation` (`src/proj.h:1506-1507`).
    ///
    /// The question "is this a real transformation, or did upstream fall back to
    /// something that does not move the point?", and what makes a finite answer
    /// from an operation with a missing grid interpretable.
    pub fn coordoperationHasBallparkTransformation(self: Object) bool {
        return isSet(c.proj_coordoperation_has_ballpark_transformation(self.ctx, self.ptr));
    }

    /// Whether every step can actually run here —
    /// `proj_coordoperation_is_instantiable` (`src/proj.h:1503-1504`).
    ///
    /// False means a grid this operation needs is not reachable from this build,
    /// which with the network off and no grid installed is exactly the case.
    pub fn coordoperationIsInstantiable(self: Object) bool {
        return isSet(c.proj_coordoperation_is_instantiable(self.ctx, self.ptr));
    }

    /// The reverse operation — `proj_coordoperation_create_inverse`
    /// (`src/proj.h:1542`).
    ///
    /// A new object; destroy it. Null when the operation cannot be reversed, which
    /// is `error.NullReturn`.
    pub fn coordoperationCreateInverse(self: Object) Error!Object {
        return .{
            .ptr = try require(*c.PJ, c.proj_coordoperation_create_inverse(self.ctx, self.ptr)),
            .ctx = self.ctx,
        };
    }

    /// How many steps a concatenated operation has —
    /// `proj_concatoperation_get_step_count` (`src/proj.h:1544-1545`).
    pub fn concatoperationStepCount(self: Object) c_int {
        return c.proj_concatoperation_get_step_count(self.ctx, self.ptr);
    }

    /// One step of a concatenated operation —
    /// `proj_concatoperation_get_step` (`src/proj.h:1547-1549`).
    ///
    /// A new object; destroy it. Null for an index outside the count.
    pub fn concatoperationStep(self: Object, i_step: c_int) Error!?Object {
        return self.optional(c.proj_concatoperation_get_step(self.ctx, self.ptr, i_step));
    }

    /// The coordinate operation a BoundCRS wraps —
    /// `proj_crs_get_coordoperation` (`src/proj.h:1497`).
    ///
    /// A new object; destroy it. Null when this is not a BoundCRS.
    pub fn crsGetCoordoperation(self: Object) Error!?Object {
        return self.optional(c.proj_crs_get_coordoperation(self.ctx, self.ptr));
    }
};

// ---- Area of use ------------------------------------------------------------

/// A `PJ_AREA`: the rectangle that restricts which operations upstream considers.
///
/// `proj_area_create` (`src/proj.h:607`) allocates it and `proj_area_destroy`
/// (`:613`) frees it; upstream's destroy is `delete area` (`src/area.cpp:51-52`)
/// and returns nothing.
///
/// The mutating methods take `*Area` so the change is visible, which is upstream's
/// own shape: those functions write through the pointer rather than returning a new
/// object (`src/proj.h:608-612`).
pub const Area = struct {
    ptr: *c.PJ_AREA,

    /// A new, empty area — `proj_area_create` (`src/proj.h:607`).
    pub fn create() Error!Area {
        return .{ .ptr = try require(*c.PJ_AREA, c.proj_area_create()) };
    }

    /// Restrict to a bounding box in degrees — `proj_area_set_bbox`
    /// (`src/proj.h:608-611`).
    ///
    /// The order is west, south, east, north, all degrees.
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

    /// Name this area — `proj_area_set_name` (`src/proj.h:612`).
    pub fn setName(self: *Area, name: [*:0]const u8) void {
        c.proj_area_set_name(self.ptr, name);
    }

    /// Release it — `proj_area_destroy` (`src/proj.h:613`).
    pub fn destroy(self: Area) void {
        c.proj_area_destroy(self.ptr);
    }
};

// ---- Operation factory ------------------------------------------------------

/// A `PJ_OPERATION_FACTORY_CONTEXT`: the settings that decide which candidate
/// operations upstream searches for.
///
/// `proj_create_operation_factory_context` (`src/proj.h:1362-1363`) allocates it
/// and `proj_operation_factory_context_destroy` (`:1365-1366`) frees it. Every
/// setter takes the `PJ_CONTEXT` explicitly (`src/proj.h:1368-1410`), which is why
/// this handle carries both pointers.
///
/// Unlike `Object`, this is a query builder: nothing it produces is a
/// transformation you can run. What it produces is a list.
pub const OperationFactory = struct {
    ctx: *c.PJ_CONTEXT,
    ptr: *c.PJ_OPERATION_FACTORY_CONTEXT,

    /// A new factory — `proj_create_operation_factory_context`
    /// (`src/proj.h:1362-1363`).
    ///
    /// `authority` restricts the registry search, e.g. `"EPSG"`; pass null to
    /// search every authority.
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

    /// Release it — `proj_operation_factory_context_destroy`
    /// (`src/proj.h:1365-1366`).
    pub fn destroy(self: OperationFactory) void {
        c.proj_operation_factory_context_destroy(self.ptr);
    }

    /// The accuracy to aim for, metres — `..._set_desired_accuracy`
    /// (`src/proj.h:1368-1370`).
    pub fn setDesiredAccuracy(self: OperationFactory, accuracy: f64) void {
        c.proj_operation_factory_context_set_desired_accuracy(self.ctx, self.ptr, accuracy);
    }

    /// Where to look — `..._set_area_of_interest` (`src/proj.h:1372-1375`).
    ///
    /// West, south, east, north, all degrees. This is what the spatial criterion is
    /// then applied to.
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

    /// How strictly the area of validity must contain the area of interest —
    /// `..._set_spatial_criterion` (`src/proj.h:1385-1387`).
    pub fn setSpatialCriterion(self: OperationFactory, criterion: SpatialCriterion) void {
        c.proj_operation_factory_context_set_spatial_criterion(
            self.ctx,
            self.ptr,
            @intFromEnum(criterion),
        );
    }

    /// What to do about a grid that is not here —
    /// `..._set_grid_availability_use` (`src/proj.h:1389-1391`).
    ///
    /// `discard_operation_if_missing_grid` is the setting that makes a missing
    /// datum shift visible instead of merely uninteresting: it removes such an
    /// operation from the candidate list rather than sorting it last
    /// (`src/proj.h:977-978`).
    pub fn setGridAvailabilityUse(self: OperationFactory, use: GridAvailabilityUse) void {
        c.proj_operation_factory_context_set_grid_availability_use(
            self.ctx,
            self.ptr,
            @intFromEnum(use),
        );
    }

    /// Whether a route through a third CRS may be searched for —
    /// `..._set_allow_use_intermediate_crs` (`src/proj.h:1398-1400`).
    pub fn setAllowUseIntermediateCrs(self: OperationFactory, use: IntermediateCrsUse) void {
        c.proj_operation_factory_context_set_allow_use_intermediate_crs(
            self.ctx,
            self.ptr,
            @intFromEnum(use),
        );
    }

    /// Whether superseded operations are removed — `..._set_discard_superseded`
    /// (`src/proj.h:1406-1407`).
    pub fn setDiscardSuperseded(self: OperationFactory, discard: bool) void {
        c.proj_operation_factory_context_set_discard_superseded(
            self.ctx,
            self.ptr,
            if (discard) 1 else 0,
        );
    }

    /// Whether an operation may be a ballpark substitution —
    /// `..._set_allow_ballpark_transformations` (`src/proj.h:1409-1410`).
    ///
    /// False is how a caller says "tell me about real transformations only", and
    /// with no grid on disk that is what turns `EPSG:4326 → EPSG:4277` into an
    /// empty candidate list rather than a no-op that returns its input.
    pub fn setAllowBallparkTransformations(self: OperationFactory, allow: bool) void {
        c.proj_operation_factory_context_set_allow_ballpark_transformations(
            self.ctx,
            self.ptr,
            if (allow) 1 else 0,
        );
    }

    /// Every candidate operation between two CRS — `proj_create_operations`
    /// (`src/proj.h:1414-1417`).
    ///
    /// A caller-freed list. **A list of length zero is the interesting answer**,
    /// not an empty one: it is how upstream says no transformation exists under
    /// these constraints. `ObjectList.len` is where to read that.
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

// ---- Lists ------------------------------------------------------------------

/// A `PJ_OBJ_LIST`: candidate operations, or the non-deprecated forms of an
/// object.
///
/// Created by `OperationFactory.createOperations` and `Object.nonDeprecated`;
/// freed by `proj_list_destroy` (`src/proj.h:1424`). Each element is an `Object`
/// the caller destroys separately.
pub const ObjectList = struct {
    ptr: *c.PJ_OBJ_LIST,
    ctx: *c.PJ_CONTEXT,

    /// Wrap an upstream list, or note that there was none.
    fn create(ctx: *c.PJ_CONTEXT, raw: ?*c.PJ_OBJ_LIST) Error!?ObjectList {
        if (raw) |list| return .{ .ptr = list, .ctx = ctx };
        return null;
    }

    /// Release the list — `proj_list_destroy` (`src/proj.h:1424`).
    ///
    /// Releases the container only. Every `Object` this list handed out is still
    /// the caller's to destroy.
    pub fn destroy(self: ObjectList) void {
        c.proj_list_destroy(self.ptr);
    }

    /// How many operations are in it — `proj_list_get_count` (`src/proj.h:1419`).
    ///
    /// Upstream answers zero for a null list as well as for an empty one
    /// (`src/iso19111/c_api.cpp:8699-8702`), so a zero here means "none" and the
    /// facade's own null is what distinguishes "no list at all".
    pub fn len(self: ObjectList) c_int {
        return c.proj_list_get_count(self.ptr);
    }

    /// One of them — `proj_list_get` (`src/proj.h:1421-1422`).
    ///
    /// A new object the caller destroys. Null for an index outside `0..len`.
    pub fn get(self: ObjectList, index: c_int) Error!?Object {
        const raw = c.proj_list_get(self.ctx, self.ptr, index);
        if (raw == null) return null;
        return Object{ .ptr = try require(*c.PJ, raw), .ctx = self.ctx };
    }

    /// Which of these operations suits this point —
    /// `proj_get_suggested_operation` (`src/proj.h:1426-1429`).
    ///
    /// Returns the index into this list, or a negative value when none of them
    /// covers the coordinate. It does not transform anything.
    pub fn suggestedOperation(self: ObjectList, direction: Direction, point: Coord) c_int {
        return suggestionIndex(self.ctx, self.ptr, direction, point);
    }
};

/// A null-terminated list of strings PROJ allocated: `PROJ_STRING_LIST`
/// (`src/proj.h:831`).
///
/// Produced by `Context.authoritiesFromDatabase` and
/// `Context.codesFromDatabase`; released by `proj_string_list_destroy`
/// (`src/proj.h:1187`). **Every element is memory the C allocator owns** — see the
/// module doc on why a Zig test allocator cannot watch it — so this list is the
/// caller's to release and only through `destroy`.
pub const StringList = struct {
    /// Upstream's `const char **`, which is a `[*c][*c]u8`: the C header cannot
    /// say "this element may be NULL", and it must, because the terminator is one.
    ptr: [*c][*c]u8,

    /// Wrap an upstream list, or note that there was none.
    fn create(raw: [*c][*c]u8) Error!?StringList {
        if (@intFromPtr(raw) == 0) return null;
        return .{ .ptr = raw };
    }

    /// Release it and every string in it — `proj_string_list_destroy`
    /// (`src/proj.h:1187`).
    pub fn destroy(self: StringList) void {
        c.proj_string_list_destroy(self.ptr);
    }

    /// How many strings there are, counted by walking to the terminator, which is
    /// the shape upstream documents (`src/proj.h:829`).
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

/// `PROJ_CRS_INFO **` — the result of `proj_get_crs_info_list_from_database`
/// (`src/proj.h:1321-1324`), released by `proj_crs_info_list_destroy`
/// (`src/proj.h:1326`).
///
/// Upstream states the shape precisely: "an array of PROJ_CRS_INFO* pointers,
/// whose last entry is NULL" (`src/iso19111/c_api.cpp:2998-2999`). Each record and
/// every string in it belongs to the array and dies with it
/// (`src/iso19111/c_api.cpp:3176-3179`), which is why `at` returns a pointer and not
/// a copy.
pub const CrsInfoList = struct {
    ptr: [*c][*c]CrsInfo,
    count: c_int,

    /// Wrap an upstream array and its count.
    fn create(raw: [*c][*c]CrsInfo, count: c_int) Error!?CrsInfoList {
        if (@intFromPtr(raw) == 0) return null;
        return .{ .ptr = raw, .count = count };
    }

    /// Release the array and everything in it — `proj_crs_info_list_destroy`
    /// (`src/proj.h:1326`).
    pub fn destroy(self: CrsInfoList) void {
        c.proj_crs_info_list_destroy(self.ptr);
    }

    /// How many records upstream reported.
    pub fn len(self: CrsInfoList) usize {
        if (self.count <= 0) return 0;
        return @intCast(self.count);
    }

    /// One record, borrowed. Dead after `destroy`.
    pub fn at(self: CrsInfoList, index: usize) ?*CrsInfo {
        if (index >= self.len()) return null;
        return self.ptr[index];
    }
};

/// `PROJ_UNIT_INFO **` — the result of `proj_get_units_from_database`
/// (`src/proj.h:1328-1332`), released by `proj_unit_list_destroy`
/// (`src/proj.h:1334`).
pub const UnitInfoList = struct {
    ptr: [*c][*c]UnitInfo,
    count: c_int,

    /// Wrap an upstream array and its count.
    fn create(raw: [*c][*c]UnitInfo, count: c_int) Error!?UnitInfoList {
        if (@intFromPtr(raw) == 0) return null;
        return .{ .ptr = raw, .count = count };
    }

    /// Release it and every record in it — `proj_unit_list_destroy`
    /// (`src/proj.h:1334`).
    pub fn destroy(self: UnitInfoList) void {
        c.proj_unit_list_destroy(self.ptr);
    }

    /// How many records upstream reported.
    pub fn len(self: UnitInfoList) usize {
        if (self.count <= 0) return 0;
        return @intCast(self.count);
    }

    /// One record, borrowed. Dead after `destroy`.
    pub fn at(self: UnitInfoList, index: usize) ?*UnitInfo {
        if (index >= self.len()) return null;
        return self.ptr[index];
    }
};

/// `PROJ_CELESTIAL_BODY_INFO **` — the result of
/// `proj_get_celestial_body_list_from_database` (`src/proj.h:1311-1312`), released
/// by `proj_celestial_body_list_destroy` (`src/proj.h:1314`).
///
/// Each record is `PROJ_CELESTIAL_BODY_INFO` (`src/proj.h:1154-1161`): an
/// authority name and an object name, both owned by the array.
pub const CelestialBodyList = struct {
    ptr: [*c][*c]c.PROJ_CELESTIAL_BODY_INFO,
    count: c_int,

    /// Release it and every record in it — `proj_celestial_body_list_destroy`
    /// (`src/proj.h:1314`).
    pub fn destroy(self: CelestialBodyList) void {
        c.proj_celestial_body_list_destroy(self.ptr);
    }

    /// How many records upstream reported.
    pub fn len(self: CelestialBodyList) usize {
        if (self.count <= 0) return 0;
        return @intCast(self.count);
    }

    /// One record, borrowed. Dead after `destroy`.
    pub fn at(self: CelestialBodyList, index: usize) ?*c.PROJ_CELESTIAL_BODY_INFO {
        if (index >= self.len()) return null;
        return self.ptr[index];
    }
};

/// The `PROJ_CRS_LIST_PARAMETERS *` that
/// `proj_get_crs_list_parameters_create` (`src/proj.h:1316`) hands out, released
/// by `proj_get_crs_list_parameters_destroy` (`src/proj.h:1318-1319`).
///
/// Upstream warns that this structure may grow, so a caller should always use the
/// create function's allocation rather than its own
/// (`src/iso19111/c_api.cpp:3009-3011`). Every field starts at zero, which is
/// upstream's "no restriction": no type filter, no bounding box, no deprecated
/// objects, no celestial-body restriction (`src/proj.h:1084-1113`).
pub fn crsListParametersCreate() Error!CrsListParametersHandle {
    return .{
        .ptr = try require(
            *c.PROJ_CRS_LIST_PARAMETERS,
            c.proj_get_crs_list_parameters_create(),
        ),
    };
}

/// The handle `crsListParametersCreate` returns.
pub const CrsListParametersHandle = struct {
    ptr: *c.PROJ_CRS_LIST_PARAMETERS,

    /// Release it — `proj_get_crs_list_parameters_destroy`
    /// (`src/proj.h:1318-1319`).
    pub fn destroy(self: CrsListParametersHandle) void {
        c.proj_get_crs_list_parameters_destroy(self.ptr);
    }
};

/// CRS records out of the database —
/// `proj_get_crs_info_list_from_database` (`src/proj.h:1321-1324`).
///
/// Pass null for `auth_name` to search every authority, and null for `parameters`
/// to apply no filter, which upstream reads as "everything".
/// (`src/iso19111/c_api.cpp:3006-3011`). Needs an open `proj.db`.
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

/// Unit records out of the database — `proj_get_units_from_database`
/// (`src/proj.h:1328-1332`).
///
/// `category` is one of the words upstream documents at `src/proj.h:1132-1134` —
/// "linear", "linear_per_time", "angular", "angular_per_time", "scale",
/// "scale_per_time", "time" — and null means every category. `allow_deprecated`
/// false hides deprecated records.
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

/// Celestial body records out of the database —
/// `proj_get_celestial_body_list_from_database` (`src/proj.h:1311-1312`).
///
/// Pass null for `auth_name` to search every authority.
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
    // Upstream's return type here is a non-optional `[*c]`, because a C header
    // cannot say "this may be NULL"; the NULL is a real answer for an empty
    // list, so it is compared on the address.
    if (@intFromPtr(raw) == 0) return null;
    return .{
        .ptr = raw,
        .count = count,
    };
}