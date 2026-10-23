# Changelog

- Added a C ABI bridge for by-value `PJ_COORD` calls used by the typed facade.
- Added `Object.datumForced()` for CRS datum ensembles.
- Made `Object.name()` handle PROJ's documented null result.
- Updated the smoke and consumer examples to read network state and avoid a duplicate authority prefix.
- Added a Zig package for PROJ 9.9.0 with the `proj` library, typed facade, runtime-loading option, generated `proj.db`, and installed data.
