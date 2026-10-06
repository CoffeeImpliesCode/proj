# The Zig interface

How the PROJ 9.9.0 SDK is consumed from Zig: the typed surface published by
`zig/root.zig`, the raw translated C route, the runtime-loading route, the
ownership rules and the ABI a loaded provider has to satisfy.

`zig/root.zig` is the authority on this page. Where the two differ, the file is
right and this document is out of date.

The pin is the `proj-9.9.0.tar.gz` release, published 2026-09-15T12:21:00Z, and
its 664 recorded digests live in [`UPSTREAM.sha256`](UPSTREAM.sha256). For
provenance, licensing and the build matrix see [`README.md`](README.md); for the
source-level evidence behind every statement here see
[`FORK-NOTES.md`](FORK-NOTES.md).

**Status: nothing here has been run.** No build, test, smoke run, cross-target
check, format run or provenance script has been executed for this tree. What
follows describes `zig/root.zig` as it stands; it is not a receipt, and there is
no test count to quote. The per-gate table is at the end of this page, and every
row in it is `PENDING-VERIFICATION`.

## The routes

```zig
const proj = @import("proj");   // dep.module("proj")
const c = proj.c;               // pub const c = @import("c")
```

| Route | How you get it | What you get |
|---|---|---|
| Linked, static (default) | `zig build`, then `dep.module("proj")` | the typed facade over the linked `libproj.a`; every call is a direct call |
| Linked, shared | `zig build -Dlinkage=dynamic` | the same facade over `libproj.so.25.9.0`, soname `libproj.so.25` |
| Runtime-loaded | `zig build -Druntime=true` | the same types and the same public surface, resolved through the platform loader by an explicit `load(source)`; the facade module links no archive |
| Native artifact | `dep.artifact("proj")` | the compiled library on its own, for a dependent that links it into its own C or Zig build |
| Installed C | `zig build install`, then `-I<prefix>/include -lproj` | upstream's installed headers, the library and `lib/pkgconfig/proj.pc` |
| System | not offered | recorded below as *vacuous, not satisfied* |

The first five are this package's own routes. A dependent forwards exactly two
options, `linkage` (`std.builtin.LinkMode`) and `runtime` (`bool`).

System mode is a different thing: it binds to whatever `libproj` is already on
the machine. This package has **no** `-Dsystem` option, so the rule this
workspace requires is recorded as vacuous rather than satisfied. It is not
"verified", not "refused", and no system result of any kind is claimed here.

`c` is re-exported **on the `proj` module**, not published as a module of its
own: registering it separately would make `dep.module("c")` resolve and hand a
dependent the declarations without the library that satisfies them, which is a
reachability a dependent cannot tell from support.

### `pub const c` is the escape hatch

**Say it plainly: `pub const c` is the escape hatch for everything this facade
does not name.** It is the translation of `zig/translate.h`, which is two
includes and nothing else — upstream's `src/proj.h` and `src/proj_constants.h`,
byte for byte, re-declaring nothing. The contract for every declaration in it is
the text of those files at the pin, and that text is the documentation.

`src/proj.h` carries all **292** `proj_*` function declarations
(`zig/translate.h:16`), the one exported data object `pj_release`, the
`PJ_COORD` union with its twelve arms, and every structure a caller can name.
`src/proj_constants.h` is 520 `#define`s and nothing else
(`zig/translate.h:19-21`), and it reaches the translation as `pub const` names
rather than macros.

The facade binds a subset of the 292. Everything it does not bind is reachable
here, on the same library, through the same calls. Three are named in
`zig/root.zig` as deliberate omissions:

* `proj_grid_info` (`src/proj.h:788`) describes an on-disk grid file, and this
  fork ships no grid. The type `GridInfo` is published for the type surface; the
  accessor is not.
* `proj_identify` (`src/proj.h:1291-1294`) is the only producer of the `int *`
  confidence array that `freeIntList` releases. Nothing in the typed surface
  produces such a list, so nothing in the typed surface needs the release either.
* `proj_suggests_code_for` (`src/iso19111/c_api.cpp:9509-9511`) is the one
  function at this pin whose own documentation says "to be freed with
  proj_string_destroy". `freeString` is the call for it, and the typed surface
  produces no such string.

`Context.createFromWkt` also passes null for upstream's two extra
`char **` out-parameters — parse warnings and grammar errors
(`src/proj.h:1207-1210`). A WKT string that parses with warnings therefore
parses quietly here. That is a stated gap, not a claim that there were none.

Two upstream spellings are deliberately absent from the typed surface, and both
reasons are worth stating because each is a place a plausible name does not
exist:

* There is no `PJ_CRS_INFO` at this pin. The record is `PROJ_CRS_INFO`
  (`src/proj.h:1043-1075`), so `CrsInfo` aliases that spelling.
* The short name `proj_use_proj4_init_rules` is not declared at this pin. Only
  `proj_context_use_proj4_init_rules` (`src/proj.h:421`) is, which is why the
  method is `Context.useProj4InitRules`.

In a runtime-loaded build `c` is a **generated dispatch** rather than the
translation step's own output. It publishes the same namespace: every type and
constant is re-exported from the translation rather than restated, so
`c.PJ_COORD` is the same nominal type either way and nothing needs a cast.

## The C allocator crossing, stated once

**Every `PJ`, every context, every WKT string and every SQLite connection in
this library is allocated with C `new`/`malloc` and released inside the library**
(`src/ctx.cpp:305-306`, `src/malloc.cpp:100-110`,
`src/iso19111/c_api.cpp:9557`). This facade allocates exactly one kind of thing
— the two copies named below, with the caller's allocator — and hands every other
pointer straight back.

Three consequences, each stated again where it applies:

* **`std.mem.Allocator` is not what PROJ's pointers belong to.** Handing one to
  a Zig allocator's `free` — including `std.testing.allocator` — is a
  *mismatched* free, not a leak. `destroy` exists so that a correct caller never
  has to remember which world a handle came from.
* **No leak oracle is available, and none is claimed.** A Zig test allocator
  detects a leak of memory *it* handed out, because it holds a record of its own
  outstanding blocks. It cannot detect a leak of PROJ's memory: the block was
  never its, so there is nothing for it to miss. **Nothing in this package
  asserts that PROJ leaks nothing, because no test in this package can observe
  that claim.**
* **Two values are copies, and they are the only two.** `Context.databasePath`
  and `Context.databaseMetadata` return memory in the caller's allocator, and
  the caller frees it. Upstream keeps one slot per context for each and the
  *next* call overwrites it (`src/iso19111/c_api.cpp:394-397`, `:418-421`), so
  two live at once would be one string and two pointers to it. Those two return
  `Error!` because the copy can fail. Everything else borrows.

## Two configurations: linked and runtime-loaded

`runtime_loaded` is a **comptime constant**, so a consumer can write two code
paths and have only the one it chose analyzed.

*Linked* is the default: the library is linked, `c` is the translation of
`src/proj.h` plus `src/proj_constants.h`, and every call is direct with no table
and no check.

*Runtime-loaded* is opt-in (`-Druntime`). No native library is linked into the
module; `c` is a dispatch generated from the same translation, and all 292
entry points are resolved through the platform loader after:

```zig
try proj.load(.{ .path = "/usr/lib/libproj.so.25" });
```

Before that, a call into the module stops the program with a message naming the
function, in every optimization mode. That is a programming error rather than a
recoverable condition: the table does not exist yet and there is no partial state
to fall back on.

`LoadSource` is a tagged union with two fields and no others: `path`, an
**absolute** file path, and `system`, a basename or SONAME for the platform
loader. The provider is reached, never guessed. `.path` names a file, `.system`
names a library for the platform loader, and **neither falls back to the
other**. A relative path is `InvalidSource`, never a search, and a system name
containing a path component is `InvalidSource` too. There is no unload, no
reset and no automatic retry; the handle and the loader's own copy of the
request live to the end of the process. `loadedSource()` answers the request
that succeeded, or null.

`load` can decline in nine ways, all named in `LoadError`: `EmptySource`,
`SourceTooLong`, `InvalidSource`, `UnsupportedTarget`, `OpenFailed`,
`MissingSymbol`, `ValidationFailed`, `ProviderMismatch`, `ReentrantLoad`. A
failed attempt publishes nothing and is retried only by calling `load` again; a
second call with the same request succeeds and changes nothing; a different
request after a success is `ProviderMismatch` and the library already in use
stays in use. A call from the thread already inside an attempt is
`ReentrantLoad` rather than a deadlock.

In a **linked** build there is no provider and nothing to load, so `load` stops
the program with a message saying exactly that — rather than quietly succeeding
and leaving a caller to think it had selected a provider. `runtime_loaded` is
false there, so a consumer that supports both configurations can tell them apart
at comptime instead of meeting this at run time.

## Errors

`Error` has exactly four members, and each is one condition this module
actually checked with an ordinary comparison, in every optimization mode. None is
a `std.debug.assert`: a check that disappears in ReleaseSafe would mean the
contract it guards is enforced nowhere.

* `NullReturn` is upstream's `NULL` where this facade had promised an object, and
  it is deliberately **one** error for every such return. PROJ reports *why* out
  of band rather than in the return value: it writes one code into the context
  slot (`src/proj.h:769`). `proj_create_argv` sets
  `PROJ_ERR_INVALID_OP_MISSING_ARG` for a null argv and `PROJ_ERR_INVALID_OP`
  for the allocation it then fails, while `proj_create_crs_to_crs` returns
  `NULL` for "no operation found matching criteria" and sets no code at all
  (`src/crs_to_crs.cpp:589-591`). A second error per constructor would claim a
  distinction the C does not make. **Read the code instead:**
  `Context.errno` or `Object.errno`.
* `OutOfMemory` is the caller's own allocator refusing one of the two copies
  above. Only `Context.databasePath` and `Context.databaseMetadata` can produce
  it.
* `UpstreamRefused` is an `int`-returning query that answered false. Upstream
  uses false both for an error and for "there is no such answer", and does not
  always separate them: `proj_get_area_of_use` returns false "in case of error
  or if the area of use is unknown" (`src/iso19111/c_api.cpp:1971-1972`), and
  `proj_trans_bounds` pre-fills all four outputs with `HUGE_VAL` before it starts
  (`src/trans_bounds.cpp:413-416`), so handing the box back would be handing back
  four infinities as an answer.
* `TooManyItems` is reached only by `Context.createArgv`, whose count upstream
  takes as `int argc` (`src/proj.h:594`).

**One error per condition, and one condition per error, is the whole rule.** The
taxonomy stops where this module's own checks stop.

### `errno` is one slot per context, not one per object

`Object.errno` and `Context.errno` answer the same question. `proj_errno(P)` is
literally `proj_context_errno(pj_get_ctx(P))` (`src/ctx.cpp:217-223`), so two
objects sharing a context share one slot and **a second failing call overwrites
what the first recorded.** Read it before the next call, not after.

A code of zero is not a clear. `proj_errno_set` returns early for `err == 0`
without touching anything (`src/ctx.cpp:242-243`), and `proj_errno_restore` does
the same and returns zero whatever it does (`:253-265`). `errnoReset` is the
clear; `errnoSet` and `errnoRestore` are the write and the put-back of upstream's
own bracket-and-restore pattern (`src/ctx.cpp:275-294`).

### `trans` has no error to return

`Object.trans` returns whatever upstream returned, including the error
coordinate, and that is deliberate: PROJ reports a transformation failure as
data. `isErrorCoordinate` is how a caller asks, and reading `v[0]` without
asking would be reading `HUGE_VAL` as a distance.

## The coordinate

`Coord` is `c.PJ_COORD`, **the translated union and not a copy**
(`src/proj.h:315-330`). The arms are load-bearing: `pj_fwd4d` and the projection
functions read and write through them directly (`src/fwd.cpp:47-56`,
`src/inv.cpp:41-42`), so `xy` and `lp` are the same four words read two ways and
`v` is the array they alias. The doc comment on `Coord` writes out all twelve
arms with their source lines.

| Facade | Upstream | Note |
|---|---|---|
| `coord(x, y, z, t)` | `proj_coord` (`src/proj.h:656`) | writes four words and returns the union; it does not validate, convert or check a unit |
| `toRad(angle_in_degrees)` | `proj_torad` (`:807`) | converts a number, not a coordinate |
| `toDeg(angle_in_radians)` | `proj_todeg` (`:808`) | |
| `isErrorCoordinate(point)` | `proj_coord_error` (`src/internal.cpp:65-68`) | four `HUGE_VAL`s. **A NaN is not this**: `proj_trans` propagates NaN into every component when handed one (`src/trans.cpp:352-354`), which is a different answer with a different cause |
| `xyDistance(a, b)` | `proj_xy_dist` (`:669`) | takes no `PJ`; upstream's own signature does not have one |
| `xyzDistance(a, b)` | `proj_xyz_dist` (`:672`) | |

Every structure below is `pub const X = c.Y;`, and that is the point of a
binding: re-typing one would create a second, hand-maintained copy of an ABI the
shipped header already states exactly, the two could drift while both compiled,
and the facade's type would stop being the type the library actually exchanges.

| Alias | Upstream | Note |
|---|---|---|
| `Coord` | `PJ_COORD` (`src/proj.h:315-330`) | the union `proj_trans` takes and returns. See the coordinate section |
| `Xyzt` | `PJ_XYZT` (`:273-275`) | `double x, y, z, t`; one of the union's arms |
| `Lpzt` | `PJ_LPZT` (`:280-281`) | `double lam, phi, z, t`; one of the union's arms |
| `Factors` | `PJ_FACTORS` (`:206-221`) | the struct `proj_factors` fills |
| `ProjInfo` | `PJ_PROJ_INFO` (`:346-353`) | the struct `proj_pj_info` fills |
| `Info` | `PJ_INFO` (`:332-344`) | the struct `proj_info` returns. Published for completeness of the type surface; `version()` does not return it — see the lifecycle section |
| `GridInfo` | `PJ_GRID_INFO` (`:355-363`) | published for completeness; `proj_grid_info` is deliberately not bound, because this fork ships no grid |
| `CrsInfo` | `PROJ_CRS_INFO` (`:1043-1075`) | **there is no `PJ_CRS_INFO` at this pin**; upstream spells this and the two records below with a `PROJ_` prefix |
| `UnitInfo` | `PROJ_UNIT_INFO` (`:1122-1146`) | |
| `CrsListParameters` | `PROJ_CRS_LIST_PARAMETERS` (`:1082-1114`) | the filter record `crsListParametersCreate` allocates |
| `ObjectListHandle` | `PJ_OBJ_LIST` (`:1184`) | opaque upstream and opaque here; `ObjectList` is the facade that wraps it |
| `LogFunction` | `PJ_LOG_FUNCTION` (`:383`) | the one function-pointer type in the surface |

**Units are never converted and never guessed.** A `Coord`'s fields are whatever
the CRS being used says they are: degrees for a geographic CRS, metres or feet
for a projected one, metres for a geocentric one. Nothing here inspects a CRS to
decide, because upstream does not: `proj_trans` hands the coordinate to the
operation and returns what comes out (`src/trans.cpp:355-359`).

## Axis order is the authority's, not the caller's

**`EPSG:4326` is latitude-then-longitude.** A CRS's axes are the CRS's own, and
the EPSG registry declares 4326 with GeodeticLatitude first. An operation built
by `Context.crsToCrs` respects that, so `Object.trans` on a 4326 → 3857
operation takes **latitude in `v[0]` and longitude in `v[1]`**.

`Object.normalizeForVisualization` is the documented other route
(`src/proj.h:602`; upstream's own summary is "Returns a PJ* object whose axis
order is the one expected for visualization purposes",
`src/iso19111/c_api.cpp:2205`). For `EPSG:4326` it inserts an axis-order reversal
so longitude comes first. The two routes are not interchangeable, and this facade
does not blur them.

## `Context` — the handle everything hangs off

`proj_context_create` (`src/proj.h:404`) makes one and `proj_context_destroy`
(`:405`) frees it.

**Never the default context.** Upstream has a process-wide default that
`PJ_DEFAULT_CTX` names (`src/proj.h:400-403`) and that many entry points
substitute for a null pointer; nothing here passes one, so every call below has a
context the caller owns and every answer belongs to it. Two contexts are
independent: separate database caches, separate log levels, separate error
codes.

### Construction and objects

| Facade | Upstream | Note |
|---|---|---|
| `Context.create()` | `proj_context_create` (`:404`) | upstream constructs with `new (std::nothrow)`, so a NULL here is `error.NullReturn` |
| `Context.destroy()` | `proj_context_destroy` (`:405`) | releases the context's database connection and grid cache. Destroy every `Object` first |
| `Context.clone()` | `proj_context_clone` (`:406`) | starts from the parent's settings and then diverges. Destroy both |
| `createFromProjString(definition)` | `proj_create` (`:593`) | the whole `+proj=...` pipeline text. Named to match `createFromWkt`/`createFromDatabase`: Zig has no overloading and `Context.create()` is the context constructor. `init=epsg:XXXX` needs `useProj4InitRules` turned on first (`src/create.cpp:301-303`) |
| `createArgv(argv)` | `proj_create_argv` (`:594`) | `argv` stays the caller's; upstream concatenates the elements into one string and frees that, writing nothing back (`src/create.cpp:275-283`). The only producer of `error.TooManyItems` |
| `createFromWkt(wkt, options)` | `proj_create_from_wkt` (`:1207-1210`) | `options` is a null-terminated string list; null for none. Upstream's two error out-parameters are passed null, so warnings are not surfaced |
| `createFromDatabase(auth_name, code, category, use_proj_alternative_grid_names, options)` | `proj_create_from_database` (`:1212-1215`) | `category` is a `Category`. The grid-names flag is an introspection question, not an ownership one |
| `crsToCrs(source, target, area)` | `proj_create_crs_to_crs` (`:595-596`) | takes **no options** — upstream's signature has none. `area` restricts the search; null for none. `error.NullReturn` here is a real answer: see the datum-grid section below |
| `crsToCrsFromPj(source, target, area, options)` | `proj_create_crs_to_crs_from_pj` (`:597-600`) | the form that takes options; the list is NULL-terminated and upstream calls `strlen` on each element (`src/crs_to_crs.cpp:471-477,505`), so the terminator is part of the value. `"ONLY_BEST=YES"` sets upstream's `errorIfBestTransformationNotAvailable` flag (`src/crs_to_crs.cpp:521-526`) and makes the **transform** fail on a missing grid — "With ONLY_BEST=YES a transformation will fail if a needed grid is unavailable" (`NEWS.md:751`) — with `PROJ_ERR_COORD_TRANSFM_NO_OPERATION` from `src/trans.cpp:289-294`; the constructor itself returns NULL only when a single candidate survives and is not instantiable (`src/crs_to_crs.cpp:617-641`, `:758-769`). When several candidates survive, what comes back is the "Set of coordinate operations" shell with `iso_obj` nulled (`src/crs_to_crs.cpp:783-795`): `name()` is null and the `coordoperation*` queries refuse it, so ask `lastUsedOperation()` for the operation a point actually used |

Every constructor above returns an `Object` that owns what upstream allocated, and
whose `destroy` is the caller's job.

### Database and search paths

| Facade | Upstream | Note |
|---|---|---|
| `setDatabasePath(db_path, aux_db_paths, options)` | `proj_context_set_database_path` (`:1192-1194`) | returns `bool`, not an error: false is upstream refusing and restoring the previous path (`src/iso19111/c_api.cpp:377-389`). There is no other way for it to fail. Null for `db_path` takes upstream's default resolution |
| `databasePath(gpa)` | `proj_context_get_database_path` (`:1196`) | **a copy in `gpa`, and that is not optional.** Null when upstream had no path to report |
| `databaseMetadata(gpa, key)` | `proj_context_get_database_metadata` (`:1198-1199`) | **also a copy.** A key with no value is null and that is not an error (`src/iso19111/c_api.cpp:457-459`) |
| `setSearchPaths(count_paths, paths)` | `proj_context_set_search_paths` (`:416-417`) | `paths` is a C array of exactly `count_paths` NUL-terminated strings, not a null-terminated list, so upstream gets an explicit length. This replaces the `PROJ_DATA`/`PROJ_LIB` resolution rather than adding to it |
| `setAutocloseDatabase(autoclose)` | `proj_context_set_autoclose_database` (`:1189-1190`) | upstream's own default is on; that is a fact about the default, not a promise this module makes |
| `setSqlite3VfsName(name)` | `proj_context_set_sqlite3_vfs_name` (`:494-495`) | the name must be one the vendored SQLite3 knows. An unknown name fails where the database is opened, not here |
| `authoritiesFromDatabase()` | `proj_get_authorities_from_database` (`:1304`) | needs an open database. A `StringList` the caller destroys |
| `codesFromDatabase(auth_name, kind, allow_deprecated)` | `proj_get_codes_from_database` (`:1306-1309`) | null `auth_name` searches every authority. `kind` is a `Type` |
| `guessWktDialect(wkt)` | `proj_context_guess_wkt_dialect` (`:1204-1205`) | a guess about text, not a parse: it builds nothing, and `not_wkt` is a normal answer |

`databaseMetadata`'s keys are the ones upstream documents at
`src/iso19111/c_api.cpp:423-439`: `DATABASE.LAYOUT.VERSION.MAJOR`,
`DATABASE.LAYOUT.VERSION.MINOR`, `EPSG.VERSION`, `EPSG.DATE`, `ESRI.VERSION`,
`ESRI.DATE`, `IGNF.SOURCE`, `IGNF.VERSION`, `IGNF.DATE`, `NKG.SOURCE`,
`NKG.VERSION`, `NKG.DATE`, `PROJ.VERSION` and `PROJ_DATA.VERSION`.

### Runtime settings, errors and logging

| Facade | Upstream | Note |
|---|---|---|
| `setNetworkEnabled(enabled)` | `proj_context_set_enable_network` (`:555`) | returns `bool`. This is the switch the datum-grid boundary depends on |
| `networkEnabled()` | `proj_context_is_network_enabled` (`:557`) | |
| `setUserWritableDirectory(path, create)` | `proj_context_set_user_writable_directory` (`:566-568`) | `create` asks upstream to create the directory. This facade does not create it and does not report whether upstream did |
| `userWritableDirectory(create)` | `proj_context_get_user_writable_directory` (`:563-564`) | a borrow into the context |
| `errno()` | `proj_context_errno` (`:769`) | where PROJ puts the reason for a NULL from any ISO19111 entry point, and for a failed transformation. Zero means no error *recorded*, which is a value and not a promise |
| `errnoString(err)` | `proj_context_errno_string` (`:774-776`) | a borrow from a static table; lives as long as the process |
| `logLevel(level)` | `proj_log_level` (`:778`) | returns the **previous** level, which is what makes restoring it possible |
| `logFunc(app_data, logf)` | `proj_log_func` (`:779-780`) | null removes the callback and returns to upstream's own logging. See the callbacks section |
| `useProj4InitRules(enable)` | `proj_context_use_proj4_init_rules` (`:421`) | the `+init=epsg:XXXX` compatibility rules |
| `getUseProj4InitRules(from_legacy_code_path)` | `proj_context_get_use_proj4_init_rules` (`:422-423`) | upstream distinguishes a legacy caller; this passes the flag through rather than deciding which caller it is |

## `Object` — a `PJ`

One type covers a CRS, a datum, an ellipsoid, a conversion, a transformation and
a ready-to-run coordinate operation, because upstream's `PJ` does
(`src/proj.h:36-49` explains why the C type is not a `void *`).

**An `Object` borrows its context.** Upstream stores the pointer, so destroying
the `Context` first leaves every method here a use-after-free this facade cannot
detect. Keep the context alive. `Object.assignContext(ctx)` is the one call that
moves an object to another context, and it rebinds the pointer and nothing else.

### Identity, names and the area of use

| Facade | Upstream | Note |
|---|---|---|
| `clone()` | `proj_clone` (`:1226`) | an independent copy on the same context |
| `destroy()` | `proj_destroy` (`:605`) | returns nothing; see the destroy note below |
| `getType()` | `proj_get_type` (`:1234`) | a `Type`. `PJ_TYPE_CRS` and `PJ_TYPE_GEOGRAPHIC_CRS` are documented as abstract and never returned (`src/proj.h:878-879`, `:884-886`); both are still in the enum so the mapping from the C's tag set is total |
| `isCrs()` | `proj_is_crs` (`:1247`) | |
| `isDeprecated()` | `proj_is_deprecated` (`:1236`) | |
| `isEquivalentTo(other, criterion)` | `proj_is_equivalent_to` (`:1240-1241`) | `criterion` is a `ComparisonCriterion` |
| `name()` | `proj_get_name` (`:1249`) | a borrow; null both for "not an identified object" and for "no name", which is one null for two cases because upstream has one null for two cases |
| `idAuthName(index)`, `idCode(index)` | `proj_get_id_auth_name` (`:1251`), `proj_get_id_code` (`:1253`) | borrows. `EPSG:4326` reports `"EPSG"` and `"4326"` |
| `scope()` | `proj_get_scope` (`:1259`) | a borrow |
| `remarks()` | `proj_get_remarks` (`:1255`) | a borrow |
| `areaOfUse()` | `proj_get_area_of_use` (`:1263-1268`) | an `AreaOfUse`. `error.UpstreamRefused` is both an error and "this object has no area of use"; `name` is a borrow from this object |
| `celestialBodyName()` | `proj_get_celestial_body_name` (`:1486-1487`) | a borrow into the object's own storage (`src/iso19111/c_api.cpp:2422`, `:2432`) |

**Every one of those string methods borrows.** Upstream says the lifetime is
"the same as the input obj parameter" (`src/iso19111/c_api.cpp:1505-1507`), and
the doc comment on each repeats the line. None of them is freed by the caller,
and `freeString` must not be called on any of them.

### Export

| Facade | Upstream | Note |
|---|---|---|
| `asWkt(kind, options)` | `proj_as_wkt` (`:1277-1278`) | a borrow, and a **short-lived** one: one object holds one WKT string, so a second call replaces the first (`src/iso19111/c_api.cpp:1708`, `:1611-1612`). Do not free it |
| `asProjString(kind, options)` | `proj_as_proj_string` (`:1280-1282`) | a borrow from a one-slot-per-object member, on the same terms. Upstream warns that a CRS not created from a PROJ string may not export to one (`src/iso19111/c_api.cpp:1724`), which arrives here as null |
| `asProjJson(options)` | `proj_as_projjson` (`:1284-1285`) | a borrow from a one-slot-per-object member (`src/iso19111/c_api.cpp:1815-1817`) |
| `pjInfo()` | `proj_pj_info` (`:787`) | a `ProjInfo`. `accuracy` is -1 when upstream does not know (`src/proj.h:351-352`), which is a value to test rather than an absence |
| `nonDeprecated()` | `proj_get_non_deprecated` (`:1238`) | an `ObjectList`. Upstream uses null both for "not deprecated" and for "no replacement exists", so this does too rather than inventing a distinction |

### Errors, on the object

`errno`, `errnoSet`, `errnoReset` and `errnoRestore` are `proj_errno` (`:770`),
`proj_errno_set` (`:771`), `proj_errno_reset` (`:772`) and `proj_errno_restore`
(`:773`). Read the slot note above: one per context, and zero is not a clear.

### The CRS graph — every one of these returns a new object

Each method below allocates what upstream allocates, and **each result is the
caller's to `destroy`**. They are grouped here because that is the rule that
applies to all of them.

| Facade | Upstream | Null when |
|---|---|---|
| `geodeticCrs()` | `proj_crs_get_geodetic_crs` (`:1437`) | this is not a CRS |
| `datum()` | `proj_crs_get_datum` (`:1443`) | the CRS is bound to a datum **ensemble**, which is upstream's own null (`src/iso19111/c_api.cpp:8808-8811`, `:8793-8794`). `EPSG:4326` is such a CRS in this package's `proj.db`, as upstream's own test records (`test/unit/test_factory.cpp:568-571`) |
| `datumEnsemble()` | `proj_crs_get_datum_ensemble` (`:1445`) | the CRS has a single datum rather than an ensemble, which is a fact about the CRS and not a failure |
| `datumForced()` | `proj_crs_get_datum_forced` (`:1447`) | upstream could not turn the ensemble into a datum at all (`src/iso19111/c_api.cpp:8986-8991`). This is the route that reaches `EPSG:4326`'s ellipsoid, where `datum()` is null |
| `horizontalDatum()` | `proj_crs_get_horizontal_datum` (`:1439`) | |
| `coordinateSystem()` | `proj_crs_get_coordinate_system` (`:1465`) | every axis question below is asked of what this returns |
| `subCrs(index)` | `proj_crs_get_sub_crs` (`:1441`) | the index the CRS does not have |
| `sourceCrs()`, `targetCrs()` | `proj_get_source_crs` (`:1287`), `proj_get_target_crs` (`:1289`) | not an operation with a source or target |
| `ellipsoid()` | `proj_get_ellipsoid` (`:1478`) | the object is neither a CRS nor a geodetic reference frame (`src/iso19111/c_api.cpp:2397-2399`) |
| `primeMeridian()` | `proj_get_prime_meridian` (`:1489`) | |
| `lastUsedOperation()` | `proj_trans_get_last_used_operation` (`:630`) | no last operation to name. Upstream's own comment says it must be freed with `proj_destroy` (`src/trans.cpp:363-369`) |
| `concatoperationStep(i_step)` | `proj_concatoperation_get_step` (`:1547-1549`) | the index is outside `concatoperationStepCount` |
| `crsGetCoordoperation()` | `proj_crs_get_coordoperation` (`:1497`) | this is not a BoundCRS |

The rest of the CRS graph answers rather than allocates:

| Facade | Upstream |
|---|---|
| `isDerived()` | `proj_crs_is_derived` (`src/proj.h:1433`) |
| `isDynamic()` | `proj_crs_is_dynamic` (`:1435`) — the one public `proj_*` entry point a `PROJ_RENAME_SYMBOLS` build does **not** rename; see the ABI section |
| `normalizeForVisualization()` | `proj_normalize_for_visualization` (`:602`) — a **new** object, so destroy it |
| `createBoundCrs(hub_crs, transformation)` | `proj_crs_create_bound_crs` (`:1848-1850`) — a new object; both arguments may be null |

### Shapes: ellipsoid, prime meridian, axes

| Facade | Upstream | Record |
|---|---|---|
| `ellipsoidParameters()` | `proj_ellipsoid_get_parameters` (`:1480-1484`) | `EllipsoidParameters` — semi-major, semi-minor, `semi_minor_computed`, inverse flattening. `semi_minor_computed` says which number is derived: the EPSG registry gives an inverse flattening, so `inv_flattening` is the registry's number and `semi_minor_metre` is upstream's arithmetic |
| `primeMeridianParameters()` | `proj_prime_meridian_get_parameters` (`:1491-1495`) | `PrimeMeridianParameters` — longitude, the factor to radians, and the unit name as a borrow |
| `csType()` | `proj_cs_get_type` (`:1467-1468`) | a `CoordinateSystemType` |
| `csAxisCount()` | `proj_cs_get_axis_count` (`:1470`) | |
| `csAxisInfo(index)` | `proj_cs_get_axis_info` (`:1472-1476`) | `AxisInfo`. Upstream has no struct for this — it passes seven pointers — so this record is the shape a caller wants over the shape the C has, and it owns nothing. `error.UpstreamRefused` for an index outside `0..csAxisCount` (`src/iso19111/c_api.cpp:9174-9177`) |

`AxisInfo` is the one record in this file with **no upstream type name at all**.
There is no `PJ_COORDINATE_SYSTEM_INFO` at this pin, and the doc comment says so
rather than pretending one exists.

### Coordinate transformation

| Facade | Upstream | Note |
|---|---|---|
| `trans(direction, point)` | `proj_trans` (`:629`) | coordinate by value, which is upstream's convention (`src/proj.h:65-71`) — but the by-value call is made in C, see the ABI section below. `Direction.ident` returns the coordinate untouched **by design** (`src/trans.cpp:222-223`) |
| `transArray(direction, coords)` | `proj_trans_array` (`:631-632`) | in place. Every element is transformed even if some fail, and the failures become the error coordinate (`src/trans.cpp:386-393`). Returns 0 when all succeeded, otherwise the code the failures share, or `PROJ_ERR_COORD_TRANSFM` when they do not share one |
| `transGeneric(direction, x, sx, nx, y, sy, ny, z, sz, nz, t, st, nt)` | `proj_trans_generic` (`:633-636`) | **strides are in bytes.** Null array or zero length means "not supplied"; a length of one means "a constant, broadcast" (`src/trans.cpp:427-436`). Work is in place, so even a constant comes back changed and must be reinitialised between calls (`:466-470`) |
| `transBounds(direction, input, densify_pts)` | `proj_trans_bounds` (`:638-642`) | a `Bounds` in the target CRS's units. Upstream suggests 21 and rejects anything outside `0..10000` (`src/trans_bounds.cpp:402-403`, `:423`) |
| `angularInput`, `angularOutput`, `degreeInput`, `degreeOutput` | `proj_angular_input` (`:623`), `proj_angular_output` (`:624`), `proj_degree_input` (`:626`), `proj_degree_output` (`:627`) | take a `Direction` |
| `roundtrip(direction, n, coords)` | `proj_roundtrip` (`:659-660`) | upstream calls it "measure internal consistency". A diagnostic, not an accuracy statement |
| `lpDist(a, b)` | `proj_lp_dist` (`:663`) | `HUGE_VAL` when the operation has no ellipsoid to measure on (`src/dist.cpp:43-45`), which is a value to test and not an error |
| `factors(lp)` | `proj_factors` (`:783`) | upstream's own `PJ_FACTORS` struct, not a re-spelling of it, so a field added upstream arrives here |

### A coordinate operation, read back

| Facade | Upstream | Note |
|---|---|---|
| `coordoperationMethodInfo()` | `proj_coordoperation_get_method_info` (`:1499-1501`) | a `MethodInfo`. This is a **registry read**: the name and code come out of `proj.db`, so an operation reporting "Transverse Mercator" / "9807" is reporting what the EPSG dataset says and not what this library computed |
| `coordoperationAccuracy()` | `proj_coordoperation_get_accuracy` (`:1535-1536`) | metres. Negative means upstream does not know, which for an operation this library built is the normal answer |
| `coordoperationParamCount()` | `proj_coordoperation_get_param_count` (`:1512-1513`) | |
| `coordoperationParam(index)` | `proj_coordoperation_get_param` (`:1519-1524`) | a `Param`. The parameter names are the registry's own — `proj_constants.h:307-308` gives `EPSG_NAME_PARAMETER_FALSE_EASTING` as "False easting" — and this is where a caller reads that back instead of comparing strings of its own |
| `coordoperationGridUsedCount()` | `proj_coordoperation_get_grid_used_count` (`:1526-1527`) | |
| `coordoperationGridUsed(index)` | `proj_coordoperation_get_grid_used` (`:1529-1533`) | a `GridUsed`. `available` is upstream's own answer to "can this build read that file", and it is the field the datum-grid boundary turns on |
| `coordoperationHasBallparkTransformation()` | `proj_coordoperation_has_ballpark_transformation` (`:1506-1507`) | "is this a real transformation, or did upstream fall back to something that does not move the point?" |
| `coordoperationIsInstantiable()` | `proj_coordoperation_is_instantiable` (`:1503-1504`) | false means a grid this operation needs is not reachable from this build |
| `coordoperationCreateInverse()` | `proj_coordoperation_create_inverse` (`:1542`) | a new object. Null when the operation cannot be reversed, which is `error.NullReturn` |
| `concatoperationStepCount()` | `proj_concatoperation_get_step_count` (`:1544-1545`) | |

## `Area` and `OperationFactory` — choosing an operation

`Area` is a `PJ_AREA` (`src/proj.h:607`, `:613`). It is opaque at the public
boundary: `src/proj.h:203-204` declares `struct PJ_AREA;` and nothing else, so no
layout of it crosses the C boundary and this file cannot describe one.

`setBbox` and `setName` take `*Area` because upstream writes through the pointer
rather than returning a new object (`src/proj.h:608-612`). The order is west,
south, east, north, all degrees.

`OperationFactory` is a `PJ_OPERATION_FACTORY_CONTEXT` (`src/proj.h:1362-1363`).
Every setter takes the `PJ_CONTEXT` explicitly (`src/proj.h:1368-1410`), which is
why this handle carries both pointers. **Unlike `Object`, this is a query
builder: nothing it produces is a transformation you can run. What it produces
is a list.**

| Facade | Upstream | Note |
|---|---|---|
| `OperationFactory.create(ctx, authority)` | `proj_create_operation_factory_context` (`:1362-1363`) | `authority` restricts the registry search, e.g. `"EPSG"`; null searches every authority |
| `destroy()` | `proj_operation_factory_context_destroy` (`:1365-1366`) | |
| `setDesiredAccuracy(accuracy)` | `..._set_desired_accuracy` (`:1368-1370`) | metres |
| `setAreaOfInterest(west, south, east, north)` | `..._set_area_of_interest` (`:1372-1375`) | what the spatial criterion is then applied to |
| `setSpatialCriterion(criterion)` | `..._set_spatial_criterion` (`:1385-1387`) | a `SpatialCriterion` |
| `setGridAvailabilityUse(use)` | `..._set_grid_availability_use` (`:1389-1391`) | a `GridAvailabilityUse`. `discard_operation_if_missing_grid` **removes** such an operation from the candidate list rather than sorting it last (`src/proj.h:977-978`) |
| `setAllowUseIntermediateCrs(use)` | `..._set_allow_use_intermediate_crs` (`:1398-1400`) | an `IntermediateCrsUse` |
| `setDiscardSuperseded(discard)` | `..._set_discard_superseded` (`:1406-1407`) | |
| `setAllowBallparkTransformations(allow)` | `..._set_allow_ballpark_transformations` (`:1409-1410`) | false is how a caller says "real transformations only" |
| `createOperations(source, target)` | `proj_create_operations` (`:1414-1417`) | an `ObjectList` |

**A list of length zero is the interesting answer, not an empty one.** It is how
upstream says no transformation exists under these constraints, and
`ObjectList.len` is where to read that.

## Lists

Five list types, five release calls, and one rule: **the container is the
caller's to release, and so is every element it handed out.**

| Type | Produced by | Released by | Element |
|---|---|---|---|
| `ObjectList` | `OperationFactory.createOperations`, `Object.nonDeprecated` | `destroy` → `proj_list_destroy` (`:1424`) | a new `Object` per `get`, the caller's to destroy |
| `StringList` | `Context.authoritiesFromDatabase`, `Context.codesFromDatabase` | `destroy` → `proj_string_list_destroy` (`:1187`) | **memory the C allocator owns.** `at` borrows; dead after `destroy` |
| `CrsInfoList` | `crsInfoListFromDatabase` | `destroy` → `proj_crs_info_list_destroy` (`:1326`) | a `*CrsInfo` borrowed from the array; dead after `destroy` |
| `UnitInfoList` | `unitsFromDatabase` | `destroy` → `proj_unit_list_destroy` (`:1334`) | a `*UnitInfo` borrowed; dead after `destroy` |
| `CelestialBodyList` | `celestialBodyListFromDatabase` | `destroy` → `proj_celestial_body_list_destroy` (`:1314`) | a `*c.PROJ_CELESTIAL_BODY_INFO` borrowed; dead after `destroy` |

`ObjectList.destroy` releases the container only. Every `Object` the list handed
out is still the caller's. `ObjectList.get(index)` is where one comes out: it
returns a **new** object, null for an index outside `0..len`, and that object
needs its own `destroy`. `ObjectList.suggestedOperation(direction, point)`
(`proj_get_suggested_operation`, `src/proj.h:1426-1429`) answers the index of
the candidate that suits a point, or a negative value when none covers it — and
it **does not transform anything**.

`StringList.len` and `StringList.at` walk to the null terminator, which is the
shape upstream documents for `PROJ_STRING_LIST` (`src/proj.h:829`); the other
three carry a count upstream reported. `ObjectList.len` returns `c_int` because
upstream's `proj_list_get_count` does (`src/proj.h:1419`) and it answers zero
for a null list as well as an empty one (`src/iso19111/c_api.cpp:8699-8702`), so
a zero means "none" and the facade's own null is what distinguishes "no list at
all". The other three return `usize`.

### The database queries that make them

| Facade | Upstream | Note |
|---|---|---|
| `crsListParametersCreate()` | `proj_get_crs_list_parameters_create` (`:1316`) | a `CrsListParametersHandle`, released by `destroy` → `proj_get_crs_list_parameters_destroy` (`:1318-1319`). Every field starts at zero, which is upstream's "no restriction" (`src/proj.h:1084-1113`). Upstream warns the struct may grow, so use its allocation rather than your own (`src/iso19111/c_api.cpp:3009-3011`) |
| `crsInfoListFromDatabase(ctx, auth_name, parameters)` | `proj_get_crs_info_list_from_database` (`:1321-1324`) | null `auth_name` searches every authority; null `parameters` applies no filter. Needs an open `proj.db` |
| `unitsFromDatabase(ctx, auth_name, category, allow_deprecated)` | `proj_get_units_from_database` (`:1328-1332`) | `category` is one of the words upstream documents at `src/proj.h:1132-1134`; null means every category |
| `celestialBodyListFromDatabase(ctx, auth_name)` | `proj_get_celestial_body_list_from_database` (`:1311-1312`) | null `auth_name` searches every authority |

### `destroy` returns nothing, and it is not idempotent

Upstream's own releases carry no information: `proj_context_destroy` returns
`nullptr` on every path including success (`src/ctx.cpp:309-320`) and
`proj_destroy` does the same (`src/malloc.cpp:100-110`). **A `destroy` method
that returned a success value would be inventing one upstream never produces, so
every one of them returns nothing.**

**No `destroy` in this file clears the handle.** `Context`, `Object`, `Area`,
`OperationFactory`, the five list types and `CrsListParametersHandle` are all
plain structs holding a pointer, they are copyable, and none of them writes
`null` back. **A second `destroy` on the same value is a double free**, which is
why the pattern to follow is one construction and one `destroy` on one path, not
a `defer` plus an early return. There is no `deinit` in this facade and no
alias for either name.

`OperationFactory` is the one exception to "one `destroy` releases everything":
upstream's factory setters take the context explicitly, so a factory outliving
its context is a use-after-free this facade cannot detect either.

## Options: the enumerations and the error codes

Every enum here is a `pub const` whose tag type is **upstream's own C enum**, so
each is one nominal type with the header rather than a copy of it, and **no
value is restated**: every tag is the translated enumerator.

| Facade | Upstream | Note |
|---|---|---|
| `Direction` | `PJ_DIRECTION` (`src/proj.h:616-621`) | `fwd` 1, `ident` 0, `inv` -1, and **the negative is load-bearing**: `PJ_IDENT` is not "no direction", it is the direction that means "do nothing" (`:618`) |
| `Type` | `PJ_TYPE` (`:865-910`) | 30 tags, complete. `PJ_TYPE_CRS` (8) and `PJ_TYPE_GEOGRAPHIC_CRS` (11) are documented as abstract and never returned by `proj_get_type`; both are present so the mapping from the C's tag set to the Zig one is total |
| `Category` | `PJ_CATEGORY` (`:855-862`) | six tags. Used by `Context.createFromDatabase` |
| `CoordinateSystemType` | `PJ_COORDINATE_SYSTEM_TYPE` (`:1024-1036`) | ten tags |
| `WktType` | `PJ_WKT_TYPE` (`:934-951`) | six fields. The C enum's two deprecated aliases are **not** fields: `PJ_WKT2_2018` is `PJ_WKT2_2019` (`:942`) and `PJ_WKT2_2018_SIMPLIFIED` is `PJ_WKT2_2019_SIMPLIFIED` (`:946`). They are the same numbers with a second spelling, and a Zig enum with two fields of one value would give a caller two names for one answer. Both are constants on the enum: `WktType.wkt2_2018`, `WktType.wkt2_2018_simplified` |
| `GuessedDialect` | `PJ_GUESSED_WKT_DIALECT` (`:834-852`) | five fields, with the same treatment: `PJ_GUESSED_WKT2_2018` (`:839`) is a constant `GuessedDialect.wkt2_2018`, not a field |
| `ProjStringType` | `PJ_PROJ_STRING_TYPE` (`:992-997`) | `proj5`, `proj4` |
| `GridAvailabilityUse` | `PROJ_GRID_AVAILABILITY_USE` (`:972-989`) | four tags. This is what makes a missing grid a boundary rather than a preference |
| `SpatialCriterion` | `PJ_SPATIAL_CRITERION` (`:1000-1008`) | two tags |
| `IntermediateCrsUse` | `PJ_INTERMEDIATE_CRS_USE` (`:1011-1021`) | three tags |
| `ComparisonCriterion` | `PJ_COMPARISON_CRITERION` (`:913-931`) | three tags |
| `LogLevel` | `PJ_LOG_LEVEL` (`:373-381`) | five fields. `PJ_LOG_DEBUG_MAJOR` (2) and `PJ_LOG_DEBUG_MINOR` (3) are the same two numbers as `debug` and `trace`, kept for `proj_api.h` compatibility (`:379-380`), so they are constants `LogLevel.debug_major` and `LogLevel.debug_minor` for the same reason `WktType` carries its aliases that way |

`Type` is the enum a caller switches on most, so its thirty tags are written out
here rather than left to a reader of the header. Values 0 to 29, in upstream's
order: `unknown`, `ellipsoid`, `prime_meridian`, `geodetic_reference_frame`,
`dynamic_geodetic_reference_frame`, `vertical_reference_frame`,
`dynamic_vertical_reference_frame`, `datum_ensemble`, `crs`, `geodetic_crs`,
`geocentric_crs`, `geographic_crs`, `geographic_2d_crs`, `geographic_3d_crs`,
`vertical_crs`, `projected_crs`, `compound_crs`, `temporal_crs`,
`engineering_crs`, `bound_crs`, `other_crs`, `conversion`, `transformation`,
`concatenated_operation`, `other_coordinate_operation`, `temporal_datum`,
`engineering_datum`, `parametric_datum`, `derived_projected_crs`,
`coordinate_metadata`.

### `ErrorCode` is the arithmetic of `src/proj.h`, written out

`ErrorCode` is a struct of `c_int` constants, and every value is the arithmetic
of `src/proj.h:715-766` written out rather than left to a macro expansion, so a
reader can check the number against the line. Three groups, each a base and its
increments:

| Group | Constants |
|---|---|
| `invalid_op`, base 1024 (`:715-730`) | `invalid_op` 1024, `invalid_op_wrong_syntax` 1025, `invalid_op_missing_arg` 1026, `invalid_op_illegal_arg_value` 1027, `invalid_op_mutually_exclusive_args` 1028, `invalid_op_file_not_found_or_invalid` 1029 |
| `coord_transfm`, base 2048 (`:733-757`) | `coord_transfm` 2048, `coord_transfm_invalid_coord` 2049, `coord_transfm_outside_projection_domain` 2050, `coord_transfm_no_operation` 2051, `coord_transfm_outside_grid` 2052, `coord_transfm_grid_at_nodata` 2053, `coord_transfm_no_convergence` 2054, `coord_transfm_missing_time` 2055 |
| `other`, base 4096 (`:760-766`) | `other` 4096, `other_api_misuse` 4097, `other_no_inverse_op` 4098, `other_network_error` 4099 |

**Nothing in this facade branches on these codes.** PROJ carries them on the
context or the object rather than in a return value (`src/proj.h:769-770`), so a
caller reads them with `Context.errno` or `Object.errno` and decides. They are
named because tests compare them, and because naming a number upstream computed
is not the same as re-deriving it.

Two paths set **no** code at all: "No operation found matching criteria" and the
early `proj_destroy(P); return nullptr` after a non-instantiable single candidate
(`src/crs_to_crs.cpp:589-591`, `:637-640`). A binding that reported a code there
would be inventing one.

One code deserves naming on its own: `ErrorCode.invalid_op_file_not_found_or_invalid`
(1029) is what a missing datum grid reports on the grid-loading path
(`src/grids.cpp:3235-3236`, `:3561-3562`).
`ErrorCode.other_network_error` (4099) is only reachable with networking on,
which this package's configuration turns off, and `src/grids.cpp:3233-3237` shows
it taking precedence over the file-not-found code, so a network failure is not
misreported as a missing file.

## Lifecycle and releases

| Facade | Upstream | Note |
|---|---|---|
| `version()` | `proj_info` (`src/proj.h:786`) | takes no arguments and touches no context, which is why it is a module function and not a method: `PJ_INFO` describes the *library*, and its `searchpath` field is whatever the process environment resolved, not whatever a particular context was told to look in. Returns a `Version` |
| `cleanup()` | `proj_cleanup` (`:816`) | upstream's global teardown for caches not attached to a context. It drops the shared database cache and the grid cache, so calling it while a context is live leaves that context's answers depending on what re-initialises afterwards. **Destroy your handles first.** There is no way back: nothing in PROJ re-creates what this dropped, so this is for a program that is finished with PROJ, not for a pause |
| `freeString(str)` | `proj_string_destroy` (`:1355`) | for a string PROJ allocated for the caller to free. **Do not call it on the result of `asWkt`, `asProjString` or `asProjJson`**: those are borrows from a slot inside the object, not a `malloc`ed string, and freeing one would corrupt the object. Nothing in the typed surface produces a string this releases — see the escape-hatch section |
| `freeIntList(list)` | `proj_int_list_destroy` (`:1300`) | upstream's only producer for this shape is `proj_identify`, which this facade does not bind, so nothing in the typed surface produces such a list. It is exposed because upstream declares it and because a caller who obtained one through `c` needs exactly this call and not an allocator's |

`Version`'s three strings borrow out of the static `PJ_INFO` upstream fills, so
they live as long as the process and need no release. Each is optional because
the C type is `const char *` and a binding promising a string where the C allows
null would promise more than upstream does.

`Info` is published as the translated `PJ_INFO` (`src/proj.h:332-344`) for
completeness of the type surface. **`version()` does not return it**: it returns
`Version`, because `PJ_INFO`'s `const char *` members and its `int` fields cross
the C boundary by value and this facade gathers them into a record whose string
fields are explicitly optional. Nothing in the typed surface consumes `Info`.

## Callbacks

`LogFunction` is `PJ_LOG_FUNCTION` (`src/proj.h:383`):
`void (*)(void *, int, const char *)`, upstream's own type, bound verbatim. It is
the only function-pointer type in the typed surface, and it crosses the boundary
**inward**: PROJ's own C calls a function this program wrote, with the provider's
calling convention and the provider's thread.

| Facade | Upstream | Contract |
|---|---|---|
| `Context.logFunc(app_data, logf)` | `proj_log_func` (`src/proj.h:779-780`) | `app_data` is handed back unchanged. Null removes the callback and returns to upstream's own logging. `level` is a `PJ_LOG_LEVEL` value, so read it as an `int` and cast it to a `LogLevel` yourself rather than assuming the facade validated it |

`msg` is `const char *`; upstream does not document a lifetime for it past the
call, so copy it if it must outlive the callback.

## Datum data and grids — what ships, and what does not

**No datum-shift grid ships in this package.** That is a decision, not an
oversight, and it is stated here because it is the one boundary a caller is most
likely to read as a missing dependency.

* `proj.db` is **generated at build time** from the 59 files under `data/sql/`.
  It is not imported, because it is not in the release tarball.
* `data/CH`, `GL27`, `ITRF2000`, `ITRF2008`, `ITRF2014`, `ITRF2020`, `nad27`,
  `nad83` and `world` are legacy `+init` **definition** files, not grids.
  `data/CH:5-6` says it outright: "You'll need to download the grids separately
  and put in a directory scanned by libproj", and `data/CH:20` names the file it
  needs, `CHENyx06_ETRS.gsb`.
* `data/tests/` is upstream's own **test** material, and upstream's own build
  keeps it out of the install set on purpose (`data/CMakeLists.txt:59-60`).

**Consequence:** every operation in `proj.db` that needs an NTv1/NTv2/GeoTIFF/
CTABLE2 grid reports that grid unavailable. `Context.crsToCrs` returns
`error.NullReturn` for a CRS pair with no operation available, and on that path
it sets **no** error code at all — only a debug-level log line
(`src/crs_to_crs.cpp:582-591`). A test demanding a code there would demand
something the C does not do.

With the network off, upstream chooses `PROJ_GRID_AVAILABILITY_DISCARD_OPERATION_IF_MISSING_GRID`
rather than assuming a grid could be fetched (`src/crs_to_crs.cpp:571-576`), so
a missing grid removes the candidate rather than sorting it last. That is the
boundary the typed surface exposes, and it is exposed in four places:

* `Context.setNetworkEnabled(false)` — the switch itself.
* `GridAvailabilityUse.discard_operation_if_missing_grid` on an
  `OperationFactory`.
* `Object.coordoperationGridUsed(index).available` — upstream's own answer to
  "can this build read that file".
* `Object.coordoperationIsInstantiable()` — false means a grid this operation
  needs is not reachable from this build.

**If you want a grid**, supply it yourself and tell PROJ where it is:

```sh
export PROJ_DATA=/path/to/this-package/share/proj   # for the installed data
export PROJ_DATA=/path/to/my/grids:$PROJ_DATA        # add your own directory
```

Resolution order is PROJ's own, read out of `src/filemanager.cpp:1113-1132` and
`:1718-1759`: `PROJ_DATA` first; the legacy `PROJ_LIB` second and deprecated; then
paths set on the context with `Context.setSearchPaths`. **This facade exposes
`setDatabasePath` and `setSearchPaths` and deliberately does not re-read
`PROJ_DATA` itself**, because that is a value upstream defines and a facade that
re-derived it would own a second answer to a question upstream already answers.

This package embeds no build-host path: `EMBED_PROJ_DATA_PATH` and
`EMBED_RESOURCE_FILES` are not used, so the library finds its data the way
upstream finds it.

**GeoTIFF grid reading is off in this build** (`TIFF_ENABLED` is not defined),
so a `.tif` grid will not be read even if you supply one, and with `CURL_ENABLED`
off there is no on-the-fly fallback either. The formats that work without TIFF
are the ones PROJ parses itself.

## The ABI boundary a loaded provider must satisfy

Resolving the symbols and translating the header **is** the boundary. They are
not proof that a provider is compatible. What a provider must be:

1. **All 292 `proj_*` functions, every one required.** Not 284: the difference
   is worked out name by name in `runtime/library.zig`, where a lowercase
   character class loses nine declarations that contain an uppercase letter and
   gains one name that appears only inside a Doxygen comment. A provider that
   exports fewer is refused with `MissingSymbol` before anything is published,
   and there is **no optional entry point**, because the header has no
   conditional entry point. The count is checked at compile time against the
   generated dispatch, as sets rather than positionally, so a translation that
   ever produced a different set stops the build with the offending name in the
   message.
2. **Layout.** The types a caller names by value are ABI: `PJ_INFO`
   (`src/proj.h:332-344`), `PJ_PROJ_INFO` (`:346-353`), `PJ_COORD` (`:315-330`)
   and every arm, `PJ_FACTORS` (`:206-221`), `PROJ_CRS_INFO` (`:1043-1075`) and
   the two list-parameter records. `PJ_AREA` is **opaque at the public boundary**
   (`src/proj.h:203-204` declares `struct PJ_AREA;` and nothing else), so no
   layout of it crosses the boundary at all; a caller only ever passes the
   `PJ_AREA *` that `proj_area_create` handed back.

   **A by-value `PJ_COORD` never crosses the Zig boundary.** Ten entry points
   take or return it that way, and `src/proj.h:65-71` says upstream means it.
   Zig 0.16.0's lowering of such a call does not agree with the C compiler that
   built this package's own archive about where the union goes, so the by-value
   call is made by fork-authored C instead — `zig/proj_abi.h` states the
   disagreement and the disassembly that establishes it, and
   `zig/root.zig`'s `transformCoord`, `makeCoord`, `lpDistance`,
   `xyDistanceBetween`, `xyzDistanceBetween`, `pointFactors` and
   `suggestionIndex` are where that choice is made. A runtime-loading build
   reaches the entry points directly instead, because its symbol table is
   checked against the 292 names above and a bridge would have to be in it;
   that route therefore still carries this boundary, and
   `FORK-NOTES.md` § 12 says so in full.
3. **Allocator.** PROJ returns strings and lists the caller must release, and it
   releases them with the provider's own C allocator, reached through the
   provider's own `libc`. **A Zig caller cannot supply a leak oracle for any of
   it**, and neither can this package's test framework. That is why the typed
   surface exposes those returns as borrows or as values it does not free with
   `Allocator.free`. See the allocator crossing above.
4. **The `PROJ_RENAME_SYMBOLS` family, which is refused by name.** A provider
   built with `PROJ_RENAME_SYMBOLS` defines `proj.h` with
   `proj_symbol_rename.h` included, and that header renames 314 symbols: 291
   `proj_*`, the 21 bundled GeographicLib `geod_*` entry points, `projinfo` and
   `pj_release`. Such an object exports `internal_proj_*` and exports **none** of
   the 292 names under the names this build asks for, so `load` refuses it with
   `MissingSymbol` at the first of them. That is the correct outcome, not a gap.
   The one detail worth knowing before someone reasons from it: the rename header
   does **not** mention `proj_crs_is_dynamic` (`src/proj.h:1435`) — all 291
   renames are present and that single declaration is absent — so a renamed
   provider exports 291 names renamed and this one unrenamed, and is still
   refused, because 291 missing is 291 missing. `Object.isDynamic` binds the
   plain spelling, which is the spelling this build's own library exports.
5. **SQLite3's and libc's ABI families are real** and belong to
   `runtime/library.zig` rather than to PROJ's descriptor. PROJ itself has no
   external ABI family of its own. Whether SQLite3's version check belongs
   inside the PROJ descriptor or beside it is recorded as `HYPOTHESIS`
   (`FORK-NOTES.md` § 11) and has not been settled.

What is checked **before anything is published**: every symbol resolved, then
three checks, and a non-null answer from any of them is `ValidationFailed` with
the candidate closed.

1. `proj_context_create()` answers non-null, and `proj_context_destroy` releases
   it through the same table. Neither opens a database.
2. `proj_coord(1.5, 2.5, 3.5, 4.5)` reads back through every arm of this build's
   `PJ_COORD` — `v[0..3]`, `xyzt`, `xyz`, `lpz`, which between them cover every
   member name and offset a caller could name. The four values are exact in
   binary64, so the comparison is `!=` against a constant and not a tolerance.
3. `proj_create(ctx, "+proj=longlat +ellps=WGS84 +type=crs")` answers non-null,
   `proj_get_type` calls it `PJ_TYPE_GEOGRAPHIC_2D_CRS`, and `proj_destroy`
   releases it. This is database-free on purpose: `proj_create` only opens
   `proj.db` when the text has no `proj=` or has an `init=`.

What is deliberately **not** called at load time: anything version-related. PROJ
publishes no symbol that answers "which version are you" — `PROJ_VERSION_MAJOR`
and its siblings (`src/proj.h:176-178`) are preprocessor macros, so they are
constants in *this* build's translation and there is nothing exported to ask a
provider. `PJ_INFO` carries `major`/`minor`/`patch` but it is filled in from the
same macros, so reading it would be reading this build's own constants back out
of the provider's memory, which proves nothing. A version check there would be a
check that cannot fail, which is worse than no check at all.

## What upstream does not promise, passed through

Restated because each of these surprises people:

* **Axis order is the CRS's own, and `EPSG:4326` is latitude-then-longitude.**
  `Object.trans` on a 4326 → 3857 operation takes latitude in `v[0]`.
  `Object.normalizeForVisualization` is the other route, and the two are not
  interchangeable.
* **A transformation failure is data, not an error.** `Object.trans` returns four
  `HUGE_VAL`s and `Object.errno` carries the reason. Read the coordinate with
  `isErrorCoordinate` before reading it as one.
* **The error code is per context, not per object.** Two objects sharing a
  context share one slot, and a second failing call overwrites the first.
* **A code of zero is not a clear.** `errnoReset` clears; `errnoSet` and
  `errnoRestore` do not.
* **`Direction.ident` returns the coordinate untouched by design**, and a NaN
  input makes all four outputs NaN.
* **A WKT string is a short-lived borrow from a one-slot-per-object member**, and
  a second export call replaces the first.
* **The two copying methods are the two copying methods.** Everything else
  borrows, and borrowing past its owner is a use-after-free this facade cannot
  detect.
* **Null is overloaded upstream in several places** — "not deprecated" and "no
  replacement", "no area of use" and "error" — and this facade does not split
  those into different answers where the C does not split them.
* **`transGeneric` works in place**, so even a broadcast constant comes back
  changed and must be reinitialised between calls.
* **`cleanup()` is one-way.** Nothing in PROJ re-creates the caches it drops.

## Fixtures: what a test in this package is allowed to be

The primary fixture is an **independent known answer**, or interoperability with
a reference implementation, with recorded provenance. A same-code round trip may
supplement that and may cover malformed input; alone it proves only that the code
agrees with itself. The three cases in `tests.zig` are named for what they are:

* **Fixture A** — an independent known answer. The spherical Mercator closed form
  from the EPSG Guidance Note, re-derived from the published formulas and
  compared against what PROJ computes. It does not come from PROJ, from a
  previous run of this library, or from a round trip. Its second leg compares
  the authority order and the visualization order as the different objects they
  are, with the different inputs they take.
* **Fixture B** — a registry read. The values EPSG itself defines, fetched back
  out of `proj.db` through the facade: the method name and code for `EPSG:32631`,
  the ellipsoid's inverse flattening, the parameter names. A facade that returns
  them is reading the registry, not agreeing with itself.
* **Fixture C** — a behavioural boundary. A datum shift whose grid this package
  does not ship must **report** the failure, with a code, and must never hand
  back a finite coordinate as though the shift had been applied. The network is
  off, so "no network" is a property of the test and not an accident.

Everything else in `tests.zig` is a **supplement and says so**: a malformed-input
error path, a metadata read, and a WKT round trip that is explicitly labelled
self-agreement.

Two constraints on what a test here can do:

* **Nothing is skipped when something is missing.** A case that quietly passed
  without a database or a provider would say nothing at all, so `openDatabase`
  fails loudly instead of skipping. Every case needs the linked archive, or under
  `-Druntime` a provider named by `PROJ_TEST_PROVIDER`, and every fixture needs
  `PROJ_DATA` pointing at the directory the build installed `proj.db` into.
* **No leak oracle is available, and no test here pretends otherwise.** A
  successful run of `tests.zig` would be a statement about the answers, not
  about PROJ's allocations. The two strings a test asks the facade to copy are
  the exception, and they are freed.

Provenance for the fixtures lives in [`testdata/`](testdata/). Upstream's own
test tree is retained and never replaced by a fetched substitute.
[`FORK-NOTES.md`](FORK-NOTES.md) § 11 records what is still owed, including that
this package's behavioural evidence is entirely in `testdata/` and `tests.zig`
with no upstream suite backstopping it.

## Verification status

**Every row is `PENDING-VERIFICATION`.** No gate has been run for this tree, and
this page quotes no result, no test count and no pass claim. The driver owns
every row, and a row changes only beside an observed run recording command,
optimize mode, target, exit code, date and receipt path.

| Gate | Command | Status |
|---|---|---|
| Native bytes | `sha256sum -c UPSTREAM.sha256` — 664 entries | PENDING-VERIFICATION |
| Provenance, file set and notices | `tools/check-provenance.sh` | PENDING-VERIFICATION |
| `proj.db` generation | the build step that runs `data/sql/` through the vendored amalgamation | PENDING-VERIFICATION |
| Library build, static | `zig build` | PENDING-VERIFICATION |
| Library build, shared | `zig build -Dlinkage=dynamic` — `libproj.so.25.9.0` | PENDING-VERIFICATION |
| Behavioural suite, Debug | `zig build test -Doptimize=Debug` | PENDING-VERIFICATION |
| Behavioural suite, ReleaseSafe | `zig build test -Doptimize=ReleaseSafe` | PENDING-VERIFICATION |
| Example program | `zig build smoke` | PENDING-VERIFICATION |
| Compile-only check, six targets | `zig build check` for `x86_64-linux-gnu`, `aarch64-linux-gnu`, `aarch64-macos-none`, `x86_64-windows-gnu`, `riscv64-linux-gnu`, `wasm32-wasi` | PENDING-VERIFICATION |
| 53-platform matrix | `"$HOME/.local/bin/cross-test"`, driven by `cross-test.profile.sh` | PENDING-VERIFICATION |
| Runtime-loaded route | `zig build -Druntime=true`, with a provider named by `PROJ_TEST_PROVIDER` | PENDING-VERIFICATION |
| Nested consumer build | `zig build consumer` | PENDING-VERIFICATION |
| Consumer program | `cd consumer && zig build run` | PENDING-VERIFICATION |

Two of those rows need a caution attached, because a reader will otherwise
misread them:

* **`check` compiles and runs nothing.** It exists to prove the facade bodies
  instantiate, through `zig/api_exercise.zig`, which calls every public method.
  No test number may be read out of it and none appears here. A successful
  foreign compile is build coverage of the compiler, not evidence about
  behaviour, and no cross-target row on this page is a test result.
* **The 53-platform matrix is a coverage statement, not a pass count.** A foreign
  target with no executor is reported as build-only — compiled, never executed —
  and never counted as a pass. Actual test counts, partial execution, missing
  runtimes, failures and deadlines are recorded separately by the driver.

## Where the evidence for all of this lives

* The module comment at the top of `zig/root.zig` states the type-alias decision,
  the pointer convention, the axis-order position, the failure convention, the
  three ownership families, the allocator crossing, both configurations and the
  upstream non-promises, each with its `src/` line.
* The doc comment on every public declaration in `zig/root.zig` names the
  upstream entry point, the header line it is declared on, and the lifetime or
  the NULL convention for that particular one.
* `zig/translate.h` states which header is translated, why the translation
  re-declares nothing, and why `proj_experimental.h` and the
  `PROJ_RENAME_SYMBOLS` include stay out — each with a line citation.
* `runtime/library.zig` states what a provider must be, the 292-name count and
  how it was established, the first four ABI points above, and what `validate`
  does and deliberately does not call.
* `runtime/graph.zig` states what is routed, what is required, and why
  `provider_excluded` and `libc_noise` are both empty.
* `tests.zig` states what each fixture proves and what it does not.
* [`FORK-NOTES.md`](FORK-NOTES.md) has the working record, the datum-data
  decision in full, the four licence findings that were not in the brief, the
  open risks and the conditions/symptoms/fixes/targets-bound lessons.
* [`README.md`](README.md) is the package overview: deviations, the support
  matrix, consumption, and the per-file licence inventory's location.
