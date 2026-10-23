# PROJ

A Zig SDK for PROJ 9.9.0: cartographic projections, geodetic transformations, and the ISO 19111 object model.
Built from the official PROJ 9.9.0 release.

## Source deviations

- Upstream PROJ C/C++ sources are unmodified.
- Fork additions provide the Zig facade, translation, and runtime loader. Linked builds route by-value `PJ_COORD` calls through C wrappers. Zig 0.16 lowered those union calls differently on some targets (observed with Zig 0.16; not rechecked on 0.17.0). Runtime loading calls provider symbols directly, across the Zig/C ABI boundary.
- PROJ does not ship SQLite. The package adds the SQLite 3.53.4 amalgamation: `vendor/sqlite3/sqlite3.c`, `sqlite3.h`, and `sqlite3ext.h`.

## Build deviations

- `build.zig` replaces upstream CMake and compiles the PROJ library closure, including `src/apps/projinfo_lib.cpp`. The command-line applications and upstream tests are retained but not compiled.
- The build generates `proj_config.h`, `PROJ_DB_SQL_MD5.h`, and `proj.db` from upstream inputs. `proj.db` is not in the release archive; it is generated from `data/sql/` with a host build of the vendored SQLite amalgamation. No build-time download or system-SQLite mode is used.
- Static linkage is the default and produces `libproj.a`. `-Dlinkage=dynamic` produces `libproj.so.25.9.0` with soname `libproj.so.25`. `-Druntime=true` selects explicit runtime loading instead of linking the archive; it has no fallback and requires all 292 translated PROJ symbols. There is no `-Dsystem` mode.
- TIFF and CURL are disabled. The package embeds neither data nor a build-host path, and ships no datum-shift grids. PROJ resolves data through `PROJ_DATA`/`PROJ_LIB` or context search paths; it cannot fetch grids over the network.

## Last recorded support matrix (observed with Zig 0.16.0)

Compile-only targets; a successful cross-compile does not establish runtime behavior.

| Target | Compile status |
|---|---|
| `x86_64-linux-gnu` | Native target |
| `aarch64-linux-gnu` | Recorded compile pass |
| `aarch64-macos-none` | Recorded compile pass |
| `x86_64-windows-gnu` | Recorded compile pass |
| `riscv64-linux-gnu` | Recorded compile pass |
| `wasm32-wasi` | Blocked under Zig 0.16.0 by its pinned libc++: threads and filesystem are unavailable, and `getpid` is deprecated as an error |

The matrix was not rechecked with Zig 0.17.0. The runtime loader is unavailable on WASI, Emscripten, and freestanding targets. TIFF/CURL and grid limits are build boundaries, not runtime test results.

## Consumption

Add the package by path in a dependent `build.zig.zon`:

```zig
.dependencies = .{
    .proj = .{ .path = "../proj" },
},
```

Select a module and, when needed, the native artifact in the dependent `build.zig`:

```zig
const proj_dep = b.dependency("proj", .{
    .linkage = .static, // or .dynamic
    .runtime = false,   // or true
});
const proj = proj_dep.module("proj");
const proj_library = proj_dep.artifact("proj");
```

The module and artifact name are both `proj`; the module re-exports the raw translated C namespace as `proj.c`. The C namespace is not registered as a separate package module. Options are `linkage` (`std.lang.LinkMode`, default `.static`) and `runtime` (`bool`, default `false`).

For C consumers, the installed headers are `proj.h`, `proj_constants.h`, `proj_experimental.h`, `proj_symbol_rename.h`, and the headers under `include/proj/`; link with `-lproj`.
