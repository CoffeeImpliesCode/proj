# Upstream

Which upstream this SDK is built from, what was taken from it byte for byte, what
was deliberately not taken, and what upstream retains that this build does not
compile.

## Canonical source

| | |
|---|---|
| Project | PROJ, OSGeo |
| Authoritative site | <https://proj.org/> |
| Repository | `OSGeo/PROJ`, <https://github.com/OSGeo/PROJ> |
| Release | 9.9.0, published 2026-09-15T12:21:00Z, `prerelease=false`, `draft=false` (GitHub releases API, read 2026-10-05) |
| Annotated tag object | `ce93bea6b5a18152b36e18c4179aae6df79a58b8` |
| Tag points at commit | `1df2be61c0e4732aa1326126113776b291ae7657` |
| Tagger | Kristian Evers `<kristian@evers.dev>`, 2026-09-15T12:19:01Z |
| Artifact | `proj-9.9.0.tar.gz`, 6048023 bytes |
| sha256 | `791a0610547eeabb17006cfd49cdbd2034f3240f47ed5e88a1031811f4e2bcf3` |
| md5 | `50ed234d73d68f7bf4378e9a020a40a7` |
| URL | <https://github.com/OSGeo/PROJ/releases/download/9.9.0/proj-9.9.0.tar.gz> |

`OBSERVED` on 2026-10-05, and it is a two-sided check rather than one value: the
sha256 equals **both** the `digest` field the GitHub releases API reports for the
asset and the digest computed here over the downloaded bytes; the md5 equals
**both** the published `proj-9.9.0.tar.gz.md5` sidecar and the md5 computed here.

The version in the imported source agrees with the tag: `src/proj.h:175-178` reads
"The version numbers should be updated with every release!" and then
`PROJ_VERSION_MAJOR 9`, `PROJ_VERSION_MINOR 9`, `PROJ_VERSION_PATCH 0`.
`CMakeLists.txt:169` repeats it as `proj_version(MAJOR 9 MINOR 9 PATCH 0)`.

## What upstream is

A coordinate transformation library: cartographic projections, geodetic
transformations, and the ISO 19111 object model (CRS, datum, coordinate
operation) behind them. Its public surface is the C API in `src/proj.h`, the C++
headers under `include/proj/`, and the versioned ABI described by
`CMakeLists.txt:170` `set(PROJ_SOVERSION 25)`, with
`CMakeLists.txt:171` `set(PROJ_BUILD_VERSION "${PROJ_SOVERSION}.${PROJ_VERSION}")`
giving `25.9.0` and `src/lib_proj.cmake:572-577` applying `VERSION` and `SOVERSION`
to the target. Its dialects are C++17 (`CMakeLists.txt:26`, `REQUIRED ON`) and
C99 (`CMakeLists.txt:35`).

Upstream's own build system is CMake and this SDK uses none of it. `build.zig`
compiles the same source list; see README.md, "Native-build deviations".

## The preserved upstream README

The release tarball ships a file called `README.md`. Upstream's own copy is
preserved here under this repository's naming convention, byte for byte, as
`README.upstream.md` (3664 bytes, digest recorded in `UPSTREAM.sha256`). The
canonical fork document is [`README.md`](README.md). Upstream's citation material
travels unaltered beside it in `CITATION`, `CITATION.cff`, `NEWS.md`,
`ChangeLog`, `AUTHORS.md` and `INSTALL`.

## What is in the tarball

**664 files, 40952259 bytes** after extraction, and every one is recorded by
digest in [`UPSTREAM.sha256`](UPSTREAM.sha256), which lists exactly 664 entries.

| Path | Files | Bytes | What it is |
|---|---:|---:|---|
| `src/` | 307 | 6126676 | the library core, the apps, the ISO 19111 model, the generated WKT parsers, three embedded upstream test programs |
| `data/` | 166 | 18191844 | 59 files of generated SQL under `data/sql/`, the nine legacy `+init` definition files, `proj.ini`, three JSON schemas, and 88 upstream test grids and fixtures under `data/tests/` |
| `test/` | 98 | 4138533 | upstream's own test tree: `unit/` (GTest), `cli/` (YAML-driven CLI tests), `gie/`, `gigs/`, `benchmark/` |
| `scripts/` | 31 | 602070 | the Python and shell generators that produce `data/sql/*.sql`, plus maintenance scripts |
| `include/` | 21 | 1303663 | the public C++ headers, and one vendored third-party header |
| `cmake/` | 14 | 30020 | upstream's CMake modules |
| root files | 10 | 199889 | `COPYING`, `AUTHORS.md`, `CITATION`, `CITATION.cff`, `ChangeLog`, `INSTALL`, `NEWS.md`, `README.upstream.md`, `CMakeLists.txt`, `proj.pc.in` |
| `man/` | 8 | 94522 | seven `man1` pages and upstream's `CMakeLists.txt` |
| `examples/` | 6 | 19688 | three example programs and `s45b.pol`, `val_def.demo` |
| `vendor/sqlite3/` | 3 | 10245354 | the vendored SQLite amalgamation — **not** upstream's; see below |

The whole upstream project is imported. Nothing is dropped for size, and nothing
is dropped for being uncompiled by this fork.

## The core closure, as upstream lists it

`src/lib_proj.cmake` defines the `proj` target. It is **five** source groups
plus the apps library, and every file named in them is compiled; nothing in the
group is dropped. The counts and ranges below are what the file says:

| Group | `set(...)` | Entries | Lines of entries |
|---|---|---:|---|
| `SRC_LIBPROJ_CORE` | `:195` | 69 | `:196-264` |
| `SRC_LIBPROJ_CONVERSIONS` | `:142` | 8 | `:143-150` |
| `SRC_LIBPROJ_PROJECTIONS` | `:22` | 117 | `:23-139` |
| `SRC_LIBPROJ_TRANSFORMATIONS` | `:153` | 13 | `:154-166` |
| `SRC_LIBPROJ_ISO19111` | `:169` | 23 | `:170-192` |
| `SRC_PROJAPPS_LIBS` | `src/apps/lib_projapps.cmake:1` | 1 | `:2` — `apps/projinfo_lib.cpp` |

`src/lib_proj.cmake:373-380` concatenates exactly those six into
`ALL_LIBPROJ_SOURCES`, and `:388-390` puts them in `add_library(proj ...)`.
`SRC_LIBPROJ_CORE` ends at `:264` with
`${CMAKE_CURRENT_BINARY_DIR}/proj_config.h` — a **generated** input, not an
upstream file; see `data/` and FORK-NOTES.md § 4.

`HEADERS_LIBPROJ` (`:284-290`) names the five headers the target treats as its
own: `proj.h`, `proj_experimental.h`, `proj_constants.h`, `proj_symbol_rename.h`
and `geodesic.h`.

Link settings this closure needs, all read out of the same file:
`-DPROJ_DLL=` on a static build (`:639-645`), `-DNOMINMAX` on MSVC/MinGW
(`:401-403`), `-DPROJ_HAS_PTHREADS` only where `find_package(Threads)` and
pthreads both succeeded (`:3-6`, linked at `:606-608`), SQLite3 (`:610`),
TIFF only under `TIFF_ENABLED` (`:618-621`) and CURL only under `CURL_ENABLED`
(`:623-632`). `PROJ_RENAME_SYMBOLS` is never defined, so `src/proj.h:127-129`
does not pull in `proj_symbol_rename.h` and the `proj_*` names stay `proj_*`.

## The second dependency: SQLite, vendored in-tree

PROJ needs SQLite 3.11 or newer. `CMakeLists.txt:247` is
`find_package(SQLite3 3.11 REQUIRED)` and `src/lib_proj.cmake:610` is
`target_link_libraries(proj PRIVATE SQLite3::SQLite3)`. A system-installed
default is forbidden in this workspace, and no wave slice owns sqlite3, so the
amalgamation is vendored:

| | |
|---|---|
| Project | SQLite amalgamation, version 3.53.4 |
| Artifact | `sqlite-amalgamation-3530400.zip`, 2946650 bytes |
| SHA3-256 | `628a44cfe82c66aed1ccbbe85a562d2e33ebe64b3288981ed76285612227934e` (matches the value published on <https://www.sqlite.org/download.html>) |
| sha256 | `1e71ddf93849c6a6ecf58b827c0692073d2dd7ee40196158068f7b29f422e87d` (computed here) |
| URL | <https://www.sqlite.org/2026/sqlite-amalgamation-3530400.zip> |
| Shipped | `vendor/sqlite3/sqlite3.c`, `sqlite3.h`, `sqlite3ext.h` — three files, 10245354 bytes |
| Not shipped | `shell.c`, the SQLite CLI, 1185915 bytes |

The `sqlite3` CLI is *not* vendored, and that is load-bearing rather than
incidental: `CMakeLists.txt:232-235` makes the CLI a hard build requirement
(`find_program(EXE_SQLITE3 sqlite3)` followed by
`message(SEND_ERROR "sqlite3 binary not found!")`), and
`data/generate_proj_db.cmake:40` pipes the concatenated SQL into
`${EXE_SQLITE3}`. This build does not use upstream's recipe for that step; it
runs the concatenated script through a **host build of the vendored
amalgamation** instead, so no CLI is required on the machine. The omission is
recorded in [`NOTICE.md`](NOTICE.md).

## Datum data: the `proj.db` generation chain

**OBSERVED: `data/proj.db` is not in the release tarball.** `data/` holds
`sql/` (59 files, the generated SQL), the three JSON schemas, `proj.ini`,
`nad.lst`, `other.extra`, nine legacy `+init` definition files (`CH`, `GL27`,
`ITRF2000`, `ITRF2008`, `ITRF2014`, `ITRF2020`, `nad27`, `nad83`, `world`) and
`tests/` (88 upstream test grids and fixtures). `data/README:18` says where the
rest of the data lives: "Additional data files are available in
https://github.com/OSGeo/PROJ-data".

The generation chain, read out of the tree:

1. `data/CMakeLists.txt:34-37` reads the expected digest out of
   `data/sql/proj.db.sql.expected.md5` and makes that file a configure
   dependency.
2. `data/CMakeLists.txt:39-49` defines the `proj.db` custom command; `:51` names
   the `generate_proj_db` target.
3. `data/generate_proj_db.cmake:9-27` is the function that does the work.
   `PROJ_DB_EXTRA_VALIDATION` selects the file list, `:13-15` concatenates the
   files in the order `data/sql_filelist.cmake` gives, and `:25` substitutes
   `${PROJ_VERSION}`.
4. `data/generate_proj_db.cmake:19-22` computes the digest **with the metadata
   records removed first**:
   `string(REGEX REPLACE "INSERT INTO \"metadata\"[^\n]*\n?" "" CONTENTS_WITHOUT_METADATA ...)`
   then `string(MD5 ...)`. The comment at `:17-18` says why: "Compute the MD5
   before any records in the metadata table, to avoid refreshing the MD5 if we
   bump PROJ_VERSION or PROJ_DATA.VERSION".
5. `data/generate_proj_db.cmake:29` runs the concatenation with extra validation
   OFF; `:31` writes `PROJ_DB_SQL_MD5.h`; `:32-48` compares against the expected
   value and, on a mismatch, either runs the extra-validation build or fails with
   "Database is valid; please update data/sql/proj.db.sql.expected.md5 with …".
   That equality is upstream's own consistency rule, not a rule invented here.
6. `src/embedded_resources.c:6-17` is the only consumer of `PROJ_DB_SQL_MD5.h`
   (`#include "PROJ_DB_SQL_MD5.h"` at `:8`, `(void)PROJ_DB_SQL_MD5;` at `:11`),
   and that file is compiled only under `EMBED_RESOURCE_FILES`
   (`src/lib_proj.cmake:420-421`, `:516-519`). This build does not compile it,
   and still generates the header so that upstream's rule stays reproducible.

### The `PROJ_DB_SQL_MD5` reproduction, and exactly what it proves

`OBSERVED` here. Concatenating the SQL files in the order contract § 5 lists —
which is the order `data/sql_filelist.cmake:15-79` produces with
`PROJ_DB_EXTRA_VALIDATION` **OFF**, so no `show_useless_aliases.sql` and no
`final_consistency_checks.sql` — yields

```
14264577 bytes
MD5 with every INSERT INTO "metadata" line removed
  = 97f045739c534f9697ae359d4be8c95a
```

and `data/sql/proj.db.sql.expected.md5:1` contains exactly
`97f045739c534f9697ae359d4be8c95a`. Equality holds.

**What that is:** a computation over the *contents* of the imported SQL files,
reproducing upstream's own consistency digest. It shows that the imported
`data/sql/*.sql` are complete, untruncated and in the right concatenation order,
and that the import did not disturb them.

**What that is not:** it is not a run of any generated artefact. No `sqlite3`
CLI was invoked, no `proj.db` was produced, no database was opened, and nothing
was downloaded. `proj.db` remains **PENDING-VERIFICATION** — it is produced by a
build step that has not run.

### No datum-shift grid ships, and what ships instead

The vendored datum data is exactly `proj.db` (generated at build time),
`proj.ini`, the three `*.schema.json`, `nad.lst`, `other.extra` and the nine
`+init` files. **No NTv1/NTv2/GeoTIFF/CTABLE2 grid is in this package.**

`data/CH` is the clearest statement of that, and it says it in its own words:
`data/CH:5-6` reads "You'll need to download the grids separately and put in a
directory scanned by libproj", and `:20` names the file —
`+nadgrids=CHENyx06_ETRS.gsb`. `data/CH` is an `+init` **definition** file, not a
grid; so are `GL27`, `ITRF2000`, `ITRF2008`, `ITRF2014`, `ITRF2020`, `nad27`,
`nad83` and `world`.

Consequence, stated as a data-availability fact and not as a build result: every
operation in `proj.db` that needs a grid will report that grid unavailable. That
is what the package was built to do without one.

Resolution order is PROJ's own, not this fork's:
`src/filemanager.cpp:1113-1132` (`getProjDataEnvVar`) reads `PROJ_DATA` first and
falls back to `PROJ_LIB`, which it calls "Legacy name" and logs as deprecated;
`src/filemanager.cpp:1718-1759` (`pj_get_default_searchpaths`) is where the
paths are assembled. The package never embeds a build-host path:
`EMBED_PROJ_DATA_PATH` (`src/lib_proj.cmake:311-314`) is not used, and
`EMBED_RESOURCE_FILES` is not either.

## Import mechanism

**An archive import. The tarball has no history.** There is no `.git` directory
in this tree, no upstream commit as an ancestor of any commit here, and no patch
series: `UPSTREAM.sha256` is the check that the tree still matches the tarball.

The commit and tag SHAs above are recorded because the GitHub releases API
reports them for the `9.9.0` release, and they are the way back to upstream's
history. They are **not** claims that this tree contains that history. The
statement this package can make is exactly: 664 files, 664 digests, byte-identical
to `proj-9.9.0.tar.gz`.

If a future wave re-syncs to another release, the correct sequence is: download
the new tarball, verify its published sha256, replace the imported files, update
`UPSTREAM.sha256`, `UPSTREAM.md`, `NOTICE.md` and `README.md`, and add a numbered
`CHANGELOG.md` entry — in one change.

## What upstream retains that this build does not compile

This is an **explicit platform boundary**, not a reported failure and not an
omission to be repaired by fetching something. Everything below is present,
byte-identical, and digested in `UPSTREAM.sha256`:

| Not compiled | Where upstream keeps it | Why it is outside this package |
|---|---|---|
| the command-line apps — `proj`, `cs2cs`, `geod`, `cct`, `gie`, `projinfo`, `projsync` | `src/apps/*.cpp`, 13 translation units, each with its own `bin_*.cmake`; only `projinfo_lib.cpp` is in the `proj` target (`src/apps/lib_projapps.cmake:1-3`) | this package ships a library and its facade, not seven executables |
| the upstream test tree | `test/` (98 files: `unit/`, `cli/`, `gie/`, `gigs/`, `benchmark/`) and `src/tests/` (4 files: `geodtest.c`, `geodsigntest.c`, `multistresstest.cpp`, `CMakeLists.txt`) | it needs GTest and the built binaries; upstream tests are retained, never deleted and never replaced by a fetched substitute |
| the bison-parser refresh targets | `src/lib_proj.cmake:326-368` (`check_wkt1_grammar_md5` at `:329`, `generate_wkt1_parser` at `:339`, `check_wkt2_grammar_md5` at `:351`, `generate_wkt2_parser` at `:361`) | the generated parsers are checked in and are compiled as-is; regenerating them needs bison, which this build does not require |
| `EMBED_RESOURCE_FILES` | `src/embedded_resources.c`, `src/embedded_resources.h`, `src/memvfs.c`, `src/memvfs.h`, and the CMake block at `src/lib_proj.cmake:420-445` | it embeds `proj.db` and data files into the library image; this package installs them as files instead, so `EMBED_PROJ_DATA_PATH` is not used either |
| the TIFF and CURL options | `CMakeLists.txt:256` `option(ENABLE_TIFF … ON)`, `src/lib_proj.cmake:618-621` and `:623-632` | this build defines neither `TIFF_ENABLED` nor `CURL_ENABLED`, so the network-enabled `projsync` path and GeoTIFF grid reading are off |

The last row has a consequence worth stating plainly: with `CURL_ENABLED` off,
PROJ cannot fetch resources over the network. That is why every gate in this
package sets `PROJ_NETWORK=OFF` — "no network" is a property of the build's
configuration, not an accident.

## Third-party material in this repository

Four distinct pieces, each with its own file and its own terms. None is reduced to
the licence of the file beside it; the per-file inventory is
[`NOTICE.md`](NOTICE.md).

1. **`vendor/sqlite3/`** — the SQLite 3.53.4 amalgamation, public-domain blessing
   in each of the three files' own headers. Not upstream's.
2. **`include/proj/internal/vendor/nlohmann/json.hpp`** — JSON for Modern C++
   v3.9.1, MIT, Copyright (c) 2013-2019 Niels Lohmann. This one *is* upstream's
   vendoring; it is compiled into the library through
   `include/proj/internal/include_nlohmann_json.hpp`, and it is the default
   because `CMakeLists.txt:201-226` resolves `auto` to `internal` when no external
   package is found.
3. **`src/geodesic.h`, `src/geodesic.c`** — Charles F. F. Karney's MIT/X11
   geodesics, the same upstream project as this workspace's separate
   `geographiclib-c` SDK. PROJ compiles it here without `PROJ_RENAME_SYMBOLS`, so
   the `geod_*` names are exported unrenamed; a PROJ build that *does* define that
   macro routes them through `src/proj_symbol_rename.h`.
4. **`src/projections/polyhedral/` and friends** — material derived from A5
   (Apache-2.0) and gl-matrix (MIT), plus one BSD-3-Clause header. Five files,
   five separate notices; see `NOTICE.md`.

And one thing that is **not** here and is recorded as an open obligation rather
than a licence: the EPSG Geodetic Parameter Dataset's own terms of use are not in
the tarball. `NOTICE.md` states that as a finding.