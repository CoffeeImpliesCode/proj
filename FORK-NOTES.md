# Fork notes

Upstream files under `src/` are unmodified. Fork-owned additions:

| File | Change and purpose |
|---|---|
| `zig/root.zig` | Adds a Zig facade over translated PROJ declarations for Zig consumers. |
| `zig/translate.h` | Collects public headers into one translation unit for the facade. |
| `zig/proj_abi.h` | Declares C wrappers for by-value `PJ_COORD` calls to keep their ABI explicit. |
| `zig/proj_abi.c` | Calls those upstream functions from C and exposes pointer-shaped wrappers, avoiding Zig 0.16 union-call lowering differences. |
| `runtime/library.zig` | Defines and validates the provider symbol table for runtime-loaded libraries. |
| `runtime/generate.zig` | Parses target translation to generate dispatch and patched native modules with translated C signatures. |
| `runtime/graph.zig` | Connects generated dispatch, loader core, and translated declarations for runtime calls. |
| `runtime/loader.zig` | Loads one native provider and resolves symbols for explicit runtime loading. |
| `runtime/sync.h` | Declares namespaced synchronization hooks so SDK copies can coexist. |
| `runtime/sync.c` | Implements hooks with Windows, POSIX, or single-thread backends for the loader. |
| `vendor/sqlite3/sqlite3.c`, `sqlite3.h`, `sqlite3ext.h` | Vendor SQLite's implementation and headers for the private `libproj` dependency and host database generator, without a system package or download. |
| `zig/api_exercise.zig` | Instantiates facade APIs in compile-only checks to catch declaration errors. |
| `tests.zig` | Adds package-level facade tests. |
| `smoke.zig` | Adds a deterministic example for the `smoke` step. |

## Build graph

- `build.zig` replaces upstream CMake and uses explicit source lists. It builds the library closure, including `src/apps/projinfo_lib.cpp`, but not the command-line applications or upstream test tree.
- Host-run steps generate target-specific `proj_config.h` and build `proj.db` from `data/sql/` with the vendored SQLite source.
- SQLite is compiled into `libproj` as a private dependency; the package publishes no SQLite library or build-time download.
- Static linkage is the default; dynamic linkage requires a target dynamic linker. Runtime loading is a separate route and requires an explicit provider load.
- `check` compiles its target matrix without running tests. The `test`, `smoke`, and `consumer` steps handle runtime execution or consumption separately.
- `TIFF_ENABLED`, `CURL_ENABLED`, and `EMBED_RESOURCE_FILES` are disabled. The build installs `proj.db` as data rather than embedding it in the library.

## Platform boundaries

- The compile matrix covers `x86_64-linux-gnu`, `aarch64-linux-gnu`, `aarch64-macos-none`, `x86_64-windows-gnu`, `riscv64-linux-gnu`, and `wasm32-wasi`.
- `wasm32-wasi` is blocked by the pinned Zig 0.16 libc++: it lacks the required thread and filesystem APIs, and upstream's `getpid` call is a deprecation error.
- Runtime loading is unavailable on WASI, Emscripten, and freestanding targets. Dynamic linkage requires a dynamic linker.
- No datum-shift grids ship. With TIFF and CURL disabled, GeoTIFF grids and network grid retrieval are unavailable.
- The C bridge covers linked by-value `PJ_COORD` calls. The runtime-loaded route calls provider symbols directly and retains the target-dependent Zig/C union ABI boundary.
