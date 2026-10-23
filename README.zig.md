# Zig facade API

Reference for the typed facade. Package setup, linkage options, and target limits are in `README.md`.

## Basic use

```zig
const proj = @import("proj");

const ctx = try proj.Context.create();
defer ctx.destroy();
const crs = try ctx.createFromProjString("+proj=longlat +ellps=WGS84 +type=crs");
defer crs.destroy();
```

`proj.c` re-exports the translated C namespace. The aliases below refer to the same nominal C types; use it for declarations not wrapped by the facade.

## Types

C aliases: `Coord` (`PJ_COORD`), `Xyzt`, `Lpzt`, `Factors`, `ProjInfo`, `Info`, `GridInfo`, `CrsInfo`, `UnitInfo`, `CrsListParameters`, `ObjectListHandle`, and `LogFunction`.

Facade records: `Version`, `AreaOfUse`, `Bounds`, `AxisInfo`, `EllipsoidParameters`, `PrimeMeridianParameters`, `MethodInfo`, `Param`, `GridUsed`, and `CrsListParametersHandle`.

Enums: `Direction`, `Type`, `Category`, `CoordinateSystemType`, `WktType`, `GuessedDialect`, `ProjStringType`, `GridAvailabilityUse`, `SpatialCriterion`, `IntermediateCrsUse`, `ComparisonCriterion`, and `LogLevel`. Tags use translated C enum values; deprecated aliases are constants, not duplicate enum tags. `Direction` is `fwd=1`, `ident=0`, `inv=-1`; WKT 2018 aliases and debug log aliases are constants.

`Type` tags are `unknown`, `ellipsoid`, `prime_meridian`, `geodetic_reference_frame`, `dynamic_geodetic_reference_frame`, `vertical_reference_frame`, `dynamic_vertical_reference_frame`, `datum_ensemble`, `crs`, `geodetic_crs`, `geocentric_crs`, `geographic_crs`, `geographic_2d_crs`, `geographic_3d_crs`, `vertical_crs`, `projected_crs`, `compound_crs`, `temporal_crs`, `engineering_crs`, `bound_crs`, `other_crs`, `conversion`, `transformation`, `concatenated_operation`, `other_coordinate_operation`, `temporal_datum`, `engineering_datum`, `parametric_datum`, `derived_projected_crs`, and `coordinate_metadata`.

## Context

`Context.create`, `destroy`, and `clone` manage a context. Destroy every object that borrows a context before destroying the context; handle structs are copyable, but `destroy` is not idempotent.

Create objects with `createFromProjString`, `createArgv`, `createFromWkt`, `createFromDatabase`, `crsToCrs`, or `crsToCrsFromPj`. Each successful constructor returns a caller-owned `Object`. `createArgv` borrows its argument list and does not modify it. `createFromWkt` does not surface upstream's parse-warning outputs. `crsToCrs` has no options parameter; use `crsToCrsFromPj` when options are required. The latter's option list is NUL-terminated; `ONLY_BEST=YES` makes a transform fail when its required grid is unavailable.

Database API: `setDatabasePath`, `databasePath`, `databaseMetadata`, `setSearchPaths`, `setAutocloseDatabase`, `setSqlite3VfsName`, `authoritiesFromDatabase`, `codesFromDatabase`, and `guessWktDialect`.

`setDatabasePath` returns `bool`; false means upstream refused the change. `setSearchPaths(count, paths)` takes exactly `count` NUL-terminated strings. `databasePath(gpa)` and `databaseMetadata(gpa, key)` return copies allocated by `gpa`; the caller frees them.

Settings and diagnostics: `setNetworkEnabled`, `networkEnabled`, `setUserWritableDirectory`, `userWritableDirectory`, `errno`, `errnoString`, `logLevel`, `logFunc`, `useProj4InitRules`, and `getUseProj4InitRules`.

`userWritableDirectory` borrows from the context. `setUserWritableDirectory(path, create)` asks upstream to create the directory when requested; the facade does not report whether it did.

`Object.errno` and `Context.errno` read one slot per context. A later failing call overwrites it; zero is not a clear. Use `errnoReset` to clear, and `errnoSet`/`errnoRestore` for explicit updates.

## Object

Identity and names: `clone`, `destroy`, `getType`, `isCrs`, `isDeprecated`, `isEquivalentTo`, `name`, `idAuthName`, `idCode`, `scope`, `remarks`, `areaOfUse`, and `celestialBodyName`.

Export: `asWkt`, `asProjString`, `asProjJson`, `pjInfo`, and `nonDeprecated`. String results from `name`, identifiers, `scope`, `remarks`, `celestialBodyName`, and the three export methods are borrowed. `areaOfUse` returns a record with a borrowed name. The export methods use one slot per object; the next export overwrites the previous result. `nonDeprecated` can return null both when the object is not deprecated and when it has no replacement.

CRS/object graph: `geodeticCrs`, `datum`, `datumEnsemble`, `datumForced`, `horizontalDatum`, `coordinateSystem`, `subCrs`, `sourceCrs`, `targetCrs`, `ellipsoid`, `primeMeridian`, `lastUsedOperation`, `concatoperationStep`, and `crsGetCoordoperation` return new objects where applicable; destroy each returned object. `isDerived`, `isDynamic`, and `coordoperationIsInstantiable` answer questions. `normalizeForVisualization` and `createBoundCrs` return new objects.

Shape queries: `ellipsoidParameters`, `primeMeridianParameters`, `csType`, `csAxisCount`, and `csAxisInfo`.

Coordinate operations: `trans`, `transArray`, `transGeneric`, `transBounds`, `angularInput`, `angularOutput`, `degreeInput`, `degreeOutput`, `roundtrip`, `lpDist`, and `factors`.

`trans` returns the error coordinate on transformation failure; inspect it with `isErrorCoordinate` and read the reason from `errno`. `transArray` works in place and returns zero on success, otherwise a shared error code or `PROJ_ERR_COORD_TRANSFM`. `transGeneric` strides are bytes, operates in place, and a length-one array is broadcast and overwritten. `roundtrip` measures internal consistency, not accuracy.

Operation metadata: `coordoperationMethodInfo`, `coordoperationAccuracy`, `coordoperationParamCount`, `coordoperationParam`, `coordoperationGridUsedCount`, `coordoperationGridUsed`, `coordoperationHasBallparkTransformation`, `coordoperationIsInstantiable`, `coordoperationCreateInverse`, and `concatoperationStepCount`.

## Areas, operation factories, and lists

`Area` is opaque. `setBbox(west, south, east, north)` uses degrees and mutates the area; `setName` also mutates it. `OperationFactory.create(ctx, authority)` creates a query builder, not a runnable operation. It supports `destroy`, `setDesiredAccuracy`, `setAreaOfInterest`, `setSpatialCriterion`, `setGridAvailabilityUse`, `setAllowUseIntermediateCrs`, `setDiscardSuperseded`, `setAllowBallparkTransformations`, and `createOperations`. An empty result list is a normal answer when no operation meets the constraints.

List constructors: `crsListParametersCreate`, `crsInfoListFromDatabase`, `unitsFromDatabase`, and `celestialBodyListFromDatabase`. List types are `ObjectList`, `StringList`, `CrsInfoList`, `UnitInfoList`, and `CelestialBodyList`; each container has its matching `destroy`. `ObjectList.get` returns a caller-owned object or null for an invalid index; `suggestedOperation` returns an index, not a transformed point. `StringList.len`/`at` walk a null-terminated list; other lists carry counts. Their elements borrow from the list and expire when it is destroyed.

## Coordinates

`Coord` is the translated `PJ_COORD` union. Helpers are `coord`, `toRad`, `toDeg`, `isErrorCoordinate`, `xyDistance`, and `xyzDistance`. The error coordinate is four `HUGE_VAL` values; NaNs are not error coordinates. Geographic units follow the CRS; no conversion is inferred. `EPSG:4326` uses latitude then longitude; `normalizeForVisualization` switches to longitude then latitude.

The linked facade routes its seven exposed `PJ_COORD`-by-value operations through the fork's C ABI bridge. Raw `c` calls and the runtime-loaded dispatch call provider symbols directly and retain the by-value ABI limitation on affected targets.

## Errors, strings, and lifecycle

Facade `Error` has four members: `NullReturn` (upstream returned null), `OutOfMemory` (one of the two caller-allocator copies), `UpstreamRefused` (an integer query returned false), and `TooManyItems` (`createArgv` count exceeds `int`). A missing operation can return null without setting an error code. PROJ error codes remain on the context or object; the facade does not infer an error code from every null result.

`ErrorCode` constants follow three ranges: `invalid_op` 1024–1029, `coord_transfm` 2048–2055, and `other` 4096–4099. They are values to compare, not branches performed by the facade.

Only `databasePath` and `databaseMetadata` allocate with the caller's allocator. Other strings and returned list elements are borrowed. `freeString` is only for a string allocated by PROJ for the caller; `freeIntList` is exposed for lists obtained through the raw C namespace. `cleanup()` is process-wide and one-way; destroy all handles first.

## Runtime loading

`runtime_loaded` is a comptime flag. `load(.{ .path = absolute_path })` or `load(.{ .system = basename_or_soname })` selects a provider; paths must be absolute and system names cannot contain path separators or NUL. Requests do not fall back or normalize. `loadedSource()` reports the successful request. The handle and provider remain for process lifetime.

Loader errors: `EmptySource`, `SourceTooLong`, `InvalidSource`, `UnsupportedTarget`, `OpenFailed`, `MissingSymbol`, `ValidationFailed`, `ProviderMismatch`, and `ReentrantLoad`. A failed attempt publishes no partial table; retries are explicit. A routed call before loading panics with the library and symbol name in all optimization modes.

## Callbacks

`Context.logFunc(app_data, logf)` registers a `LogFunction` callback. PROJ calls it from its own C code, on the provider's thread; `app_data` is returned unchanged. The level is passed as an integer. The message's lifetime is not guaranteed beyond the callback, so copy it if needed later.