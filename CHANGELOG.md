# Changelog

- Fix runtime builds in both linkage modes by raising the comptime branch quota for complete provider symbol validation.
- Fix runtime loading in both linkage modes by validating `pj_release` as required data alongside the 292 required functions.
- Fix Zig 0.17 runtime dispatch compilation by using ordinary comments on the ABI-check block.
- Fix runtime-loading builds for both linkage modes by removing malformed module documentation.
- Port to Zig 0.17.0.
- Restored the WKT argument in `Context.guessWktDialect`.
- Added a C ABI bridge for by-value `PJ_COORD` calls used by the typed facade.
- Added `Object.datumForced()` for CRS datum ensembles.
- Made `Object.name()` handle PROJ's documented null result.
- Updated the smoke and consumer examples to read network state and avoid a duplicate authority prefix.
- Added a Zig package for PROJ 9.9.0 with the `proj` library, typed facade, runtime-loading option, generated `proj.db`, and installed data.
