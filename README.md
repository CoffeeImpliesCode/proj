# proj

PROJ 9.9.0 — cartographic projections, geodetic transformations and the ISO 19111
object model behind them — as a standalone Zig SDK: the whole library core, its
public C and C++ headers, a typed Zig surface, the raw translated C route and an
optional runtime-loading route, built from the official release sources with no
CMake, no autotools and no build-time download.

* Upstream: the `proj-9.9.0.tar.gz` release, published 2026-09-15T12:21:00Z,
  sha256 `791a0610547eeabb17006cfd49cdbd2034f3240f47ed5e88a1031811f4e2bcf3` — see
  [`UPSTREAM.md`](UPSTREAM.md).
* Native source: unmodified. All **664 files** — 661 upstream plus the three
  vendored SQLite files — are recorded by digest in
  [`UPSTREAM.sha256`](UPSTREAM.sha256).
* Licence: **seven terms, not one.** PROJ's own tree is MIT-style
  (`COPYING`), and the package additionally contains Apache-2.0, GPL-2.0-or-later
  with the Bison special exception, BSD-3-Clause, Boost-1.0, MIT/X11 and SQLite's
  public-domain blessing, plus one dataset whose terms are **not in the tree**.
  The per-file inventory is [`NOTICE.md`](NOTICE.md); the grant for this fork's own
  files is [`FORK-LICENSE.md`](FORK-LICENSE.md).
* Upstream's own README is preserved verbatim in
  [`README.upstream.md`](README.upstream.md), together with `CITATION`,
  `CITATION.cff`, `NEWS.md`, `ChangeLog` and `AUTHORS.md`.
* **No gate has been run by this wave.** No build, test, smoke run, cross-target
  check, format run or provenance script has been executed. Every row of the
  status tables below is `PENDING-VERIFICATION` and the driver owns every result.
  This file prints no test count and makes no pass claim.

## Native-source deviations

**None.** Every one of the 661 imported upstream files is byte-identical to
`proj-9.9.0.tar.gz`. No portability patch, no reformat, no `#if` added around a
platform workaround, no upstream test deleted.

That is a checkable claim rather than an assertion:

```sh
sha256sum -c UPSTREAM.sha256     # 664 entries, all upstream digests
tools/check-provenance.sh        # the bytes, the exact file set, the notices
```

`UPSTREAM.sha256` holds 664 entries, every one an upstream digest and **none** a
fork digest — that is the machine-checkable form of the sentence above. The
per-file deviation table in [`NOTICE.md`](NOTICE.md) is correspondingly empty. Any
future native edit has to move those digests, add a per-file record to
`NOTICE.md` and add a numbered entry to [`CHANGELOG.md`](CHANGELOG.md) in the same
change, and needs an observed failure to justify it.

Four upstream facts shape this package, each read out of the source rather than
assumed:

* **The release tarball carries no Git history.** This is an archive import: no
  upstream commit is an ancestor of anything here, and there is no patch series.
  `UPSTREAM.md` records the annotated tag object
  `ce93bea6b5a18152b36e18c4179aae6df79a58b8` and its target commit
  `1df2be61c0e4732aa1326126113776b291ae7657` as the way back to upstream, not as
  a claim about this tree.
* **`data/proj.db` is not in the tarball.** It is generated at build time from the
  59 files under `data/sql/`. `data/sql/metadata.sql:12-13` records the dataset it
  is built from: `EPSG.VERSION 'v13.102'`, `EPSG.DATE '2026-08-27'`.
* **SQLite is the one external C dependency, and it is vendored.**
  `CMakeLists.txt:247` is `find_package(SQLite3 3.11 REQUIRED)` and
  `src/lib_proj.cmake:610` is `target_link_libraries(proj PRIVATE
  SQLite3::SQLite3)`. No wave slice owns sqlite3 and a system-installed default is
  forbidden, so the 3.53.4 amalgamation is vendored under `vendor/sqlite3/`.
  Only `sqlite3.c`, `sqlite3.h` and `sqlite3ext.h` are taken — `shell.c`, the
  CLI, is deliberately not, because upstream's `proj.db` recipe shells out to that
  binary and this build runs the same script through a host build of the
  amalgamation instead.
* **The upstream README is upstream's, not this fork's.** It is preserved
  byte-for-byte as `README.upstream.md`; this file is the fork document.

## Native-build deviations

What the compiled package does that upstream's CMake does not. Each is a fork
decision with a stated reason; none of them changes an algorithm.

* **Zig builds it; upstream's CMake is unused.** `build.zig` compiles exactly the
  closure `src/lib_proj.cmake` names — five source groups plus one file from the
  apps — and nothing is dropped from those groups. See
  [`FORK-NOTES.md`](FORK-NOTES.md) § 2 for the counts and for the two places a
  reader gets the closure wrong.
* **Two delivery linkages.** `-Dlinkage=static` (default) produces `libproj.a`;
  `-Dlinkage=dynamic` produces `libproj.so.25.9.0` with the soname `libproj.so.25`.
  The 25 is the ABI number upstream states (`CMakeLists.txt:170`), and
  `CMakeLists.txt:171` with `src/lib_proj.cmake:572-577` give `25.9.0`.
  Static is the default because upstream's own CMake default is a shared library
  and this package's policy preserves an archive-first delivery; shared is the
  added variant, never a substitution. A requested delivery is never silently
  replaced with the other one.
* **A typed Zig surface beside the raw one.** `zig/root.zig` publishes a documented
  facade over the same library. The translated C module is registered under the
  private name `c` and is **not** published: `dep.module("c")` must not resolve to
  it. The published module is `dep.module("proj")`.
  **[`README.zig.md`](README.zig.md) is the facade reference** — it documents the
  published surface by name, its ownership and error contracts, and the fixture
  policy.
* **Optional runtime loading.** `-Druntime=true` selects a load-at-runtime route:
  `dep.module("proj")` resolves to a generated dispatch, the module links **no**
  archive, and one process-lifetime table answers with an explicit provider path
  or a named-system selection. There is no fallback and no automatic retry; a
  failed load has to be retried explicitly, and every optimize mode gets an
  ordinary pre-initialization panic rather than a silent default. Linked calls stay
  direct. External ABI families are documented in `runtime/library.zig` — PROJ has
  none of its own, but SQLite3's and libc's are real.
* **A separate consumer package.** `consumer/` is its own Zig package that depends
  on this one by path, so it exercises the published dependency surface rather than
  the in-tree source. See "Consumption" below.
* **Per-target generated inputs.** Two generated headers — `proj_config.h` and
  `PROJ_DB_SQL_MD5.h` — are produced by host-run generators that are told the
  target they are generating for, resolved in a dependent step. Neither is a
  hand-written stand-in and neither is a host-configuration dump.
  `FORK-NOTES.md` § 4 gives the per-target argument and the reason it matters for
  `HAVE_LIBDL`, `HAVE_LOCALECONV` and `HAVE_STRERROR`.
* **No embedded resources, no embedded host path.**
  `EMBED_RESOURCE_FILES` and `EMBED_PROJ_DATA_PATH` are not used
  (`src/lib_proj.cmake:311-314`, `:420-445`, `:516-519`); `proj.db` and the data
  files are installed as files beside the library, and the library finds them the
  way upstream finds them.
* **TIFF and CURL are off.** Upstream defaults `ENABLE_TIFF` to ON
  (`CMakeLists.txt:256`); this build defines neither `TIFF_ENABLED`
  (`src/lib_proj.cmake:618-621`) nor `CURL_ENABLED` (`:623-632`). Two
  consequences, both stated rather than assumed: GeoTIFF grids are not readable,
  and PROJ cannot fetch anything over the network — which is why every gate sets
  `PROJ_NETWORK=OFF` as a property of the configuration rather than by luck.
* **`PROJ_RENAME_SYMBOLS` is never defined.** `src/proj.h:127-129` only includes
  `src/proj_symbol_rename.h` under that macro, so at this build the `proj_*` names
  stay `proj_*` and the `geod_*` geodesics names stay unrenamed too. A provider
  built with `PROJ_RENAME_SYMBOLS` exports a different ABI family and is refused
  by the loader rather than silently accepted.
* **One version, two places.** `build.zig.zon`'s `.version` is `9.9.0` and the
  library's version/soname is `25.9.0`, which is what `CMakeLists.txt:170-171`
  derives for this release. The package manifest and the shared object's name
  cannot describe two different releases.
* **`.fingerprint` is deliberately absent from `build.zig.zon`.** The Zig toolchain
  generates it on first configure and it never changes, so writing a value here
  would be a fabricated identifier that the toolchain also overwrites.
  `FORK-NOTES.md` § 7 records why and says whose job it is to observe the value.

### What upstream keeps that this package does not compile

An explicit platform boundary, not a failure. Everything below is present,
byte-identical, and digested:

* the seven command-line apps (`proj`, `cs2cs`, `geod`, `cct`, `gie`, `projinfo`,
  `projsync`) — only `projinfo_lib.cpp` joins the library;
* the upstream test tree, `test/` (98 files) and `src/tests/` (4 files);
* the bison-parser refresh targets — the generated parsers are checked in and
  compile as-is;
* `EMBED_RESOURCE_FILES` (`src/embedded_resources.c`, `src/memvfs.c`);
* the TIFF and CURL options.

[`UPSTREAM.md`](UPSTREAM.md) gives each one with its upstream location and the
reason it is outside this package. Upstream tests are retained and never replaced
by a fetched substitute.

### History of these deviations

All of them landed in this wave, the initial import. [`CHANGELOG.md`](CHANGELOG.md)
numbers each with its date, and [`FORK-NOTES.md`](FORK-NOTES.md) carries the
evidence, the reasoning and the open questions behind them — including the four
licence findings that were not in the brief and the five observations recorded in
the workspace's condition / symptom / fix / targets-bound shape.

## Current support matrix

### Status

| | |
|---|---|
| Native source | 664 files; `UPSTREAM.sha256` checked with `sha256sum -c` at import time — **no gate run by this wave** |
| Compiled closure | upstream's own five groups plus `projinfo_lib.cpp`; **not yet compiled** |
| `proj.db` | generated from `data/sql/`; **not yet generated** |
| Published module | `dep.module("proj")`; **not yet resolved by a build** |
| Translated C module | private name `c`, deliberately unpublished |
| Translated C module reachability | `dep.module("c")` **must not** resolve to it |

### Cross targets

`zig build check` compiles the facade exercise and the examples — and never runs
them — for all six of:

| Target | Notes |
|---|---|
| `x86_64-linux-gnu` | the native target |
| `aarch64-linux-gnu` | cross |
| `aarch64-macos-none` | cross |
| `x86_64-windows-gnu` | cross; `-DNOMINMAX` applies here (`src/lib_proj.cmake:401-403`) |
| `riscv64-linux-gnu` | cross |
| `wasm32-wasi` | cross; no pthreads, so `PROJ_HAS_PTHREADS` is **not** defined (`src/lib_proj.cmake:3-6`) |

No target is dropped silently. **All six rows are `PENDING-VERIFICATION`.**

A successful foreign compile is build coverage of the compiler, not evidence about
behaviour, and none of these rows is a test result.

### System mode

**Not offered, and the rule is therefore recorded as *vacuous, not satisfied*.**
There is no `-Dsystem` option. The published options are `-Dlinkage=static|dynamic`
and `-Druntime=bool`, and nothing else.

That is the exact wording this workspace requires for a fork with no system mode.
It is not "satisfied", not "verified" and not "refused" — there is no system mode
to be right or wrong about. Nothing here claims a system-library result of any
kind, and no system result may stand in for a source-package result.

### Datum data and grids

**No datum-shift grid ships in this package.** That is a decision, not an
oversight:

* `proj.db` is **generated** at build time from `data/sql/`. It is not imported,
  because it is not in the release tarball.
* `data/CH`, `GL27`, `ITRF2000`, `ITRF2008`, `ITRF2014`, `ITRF2020`, `nad27`,
  `nad83` and `world` are legacy `+init` **definition** files, not grids.
  `data/CH:5-6` says it outright: "You'll need to download the grids separately
  and put in a directory scanned by libproj", and `data/CH:20` names the file it
  needs, `CHENyx06_ETRS.gsb`.
* `data/tests/` is upstream's own **test** material — 88 grids and fixtures — and
  upstream keeps it out of the install set on purpose
  (`data/CMakeLists.txt:59-60`).

**Consequence:** every operation in `proj.db` that needs an NTv1/NTv2/GeoTIFF/
CTABLE2 grid will report that grid unavailable. That is a data-availability
statement, not a build result.

**If you want a grid**, supply it yourself and tell PROJ where it is:

```sh
export PROJ_DATA=/path/to/this-package/share/proj   # for the installed data
export PROJ_DATA=/path/to/my/grids:$PROJ_DATA        # add your own directory
```

Resolution order is PROJ's own, read out of
`src/filemanager.cpp:1113-1132` and `:1718-1759`: `PROJ_DATA` first; the legacy
`PROJ_LIB` second and deprecated; then paths set on the context with
`proj_context_set_search_paths`. The facade exposes `setDatabasePath` and
`setSearchPaths` and deliberately does **not** re-read `PROJ_DATA` itself,
because that is a value upstream defines. This package embeds no build-host path.

Note that with `TIFF_ENABLED` off, a GeoTIFF grid will not be read even if you
supply one. The formats that work without TIFF are the ones PROJ parses itself.

### Licence status

| Item | Status |
|---|---|
| Per-file inventory | complete; every claim names a file and a line range that was read |
| Upstream files modified | **none**; `UPSTREAM.sha256` is the check |
| Apache-2.0 `NOTICE` requirement | met by this package's `NOTICE.md`; the five files are unmodified, which is stated explicitly |
| Bison special exception | carried at `src/wkt*_generated_parser.{c,h}` `:21-29`; conditions preserved |
| Vendored SQLite | public-domain blessing, three files, `shell.c` omitted on purpose |
| **EPSG Geodetic Parameter Dataset terms** | **not in this tree.** No licence asserted. Must be obtained from IOGP/EPSG before redistributing `proj.db`. `NOTICE.md`, "The data" |

## Consumption

### The build graph's own steps

| Step | What it does | Status |
|---|---|---|
| `zig build` | the default step; builds the library | PENDING-VERIFICATION |
| `zig build test` | the behavioural suite, Debug and ReleaseSafe | PENDING-VERIFICATION |
| `zig build smoke` | the example program | PENDING-VERIFICATION |
| `zig build check` | compiles the facade exercise and the examples for all six cross targets; runs nothing | PENDING-VERIFICATION |
| `zig build consumer` | the nested consumer build | PENDING-VERIFICATION |
| `cd consumer && zig build run` | the consumer program, entered directly | PENDING-VERIFICATION |
| `tools/check-provenance.sh` | the bytes, the exact file set, the notices | PENDING-VERIFICATION |

`check` compiles and runs nothing, so **no test number may be read out of it** and
none appears here.

### As a Zig dependency

```zig
// build.zig.zon
.dependencies = .{
    .proj = .{ .path = "../proj" },
},

// build.zig
const proj_dep = b.dependency("proj", .{
    .linkage = .static,   // or .dynamic
    .runtime = false,     // or true for the load-at-runtime route
});
const proj = proj_dep.module("proj");
```

Two options a dependent may forward: `linkage` (`std.builtin.LinkMode`) and
`runtime` (`bool`). **There is no `-Dsystem` option**, for the reason given above.

The C consumer asks for `-lproj`, or links `libproj.a` /
`libproj.so.25`. The installed headers are `include/proj.h`,
`include/proj_constants.h`, `include/proj_experimental.h` and
`include/proj_symbol_rename.h`, plus the C++ headers under `include/proj/`.

**[`README.zig.md`](README.zig.md) is the facade reference** and is where the
published surface, its ownership and error contracts, and the fixture policy are
documented. This page is the package overview; that one is the API document.

### As a C consumer

```c
#include <proj.h>

PJ_CONTEXT *ctx = proj_context_create();
PJ *P = proj_create(ctx, "EPSG:4326");
PJ_COORD c = proj_coord(2.294481, 48.858370, 0, 0);   /* Eiffel Tower, lon/lat */
PJ_COORD out = proj_trans(P, PJ_FWD, c);
proj_destroy(P);
proj_context_destroy(ctx);
```

A C consumer resolves `proj.db` through `PROJ_DATA` exactly as a Zig consumer
does; the facade's `setDatabasePath` and `setSearchPaths` are conveniences over
the same upstream calls, not a second resolution mechanism.

### The consumer package

`consumer/` is a separate Zig package that depends on this one **by path**. It is
written to exercise the published dependency surface — `dep.module("proj")` and
the forwarded options — rather than anything reachable only from inside this tree.
It therefore fails when the published surface is wrong, which is the property that
makes it worth having as a separate package.

```sh
zig build consumer          # nested build from here
cd consumer && zig build run # entered directly
```

Both are `PENDING-VERIFICATION`.

### What a fixture here is allowed to be

The primary fixture is an **independent known answer** — computed from a published
formula or read back out of a registry — not a same-code round trip. Web Mercator
for EPSG:3857 comes from the closed form, EPSG registry constants come out of
`proj.db`, and the EPSG:4326 → EPSG:4277 boundary is proved by the *reported
failure* and its error code, not by "it threw". A same-code round trip may
supplement that. Provenance and a licence record for the fixtures live in
`testdata/`. [`FORK-NOTES.md`](FORK-NOTES.md) § 11 records what is still owed.

---

## Records in this repository

| File | What it is |
|---|---|
| [`UPSTREAM.md`](UPSTREAM.md) | the pin, how it was obtained and verified, what was and was not taken |
| [`UPSTREAM.sha256`](UPSTREAM.sha256) | 664 digests; the machine-checkable "no upstream file changed" claim |
| [`NOTICE.md`](NOTICE.md) | the per-file licence inventory, seven exceptions, and the one absent term |
| [`FORK-LICENSE.md`](FORK-LICENSE.md) | the owner's grant for this fork's own files |
| [`CHANGELOG.md`](CHANGELOG.md) | numbered entries; this is the initial import |
| [`FORK-NOTES.md`](FORK-NOTES.md) | the engineering record: observations, decisions, lessons, open risks |
| [`README.zig.md`](README.zig.md) | the facade reference |
| `README.upstream.md` | upstream's own README, preserved byte for byte |
| `COPYING` | PROJ's own grant, unmodified |

Local and unpublished. No remote it mentions is asserted to exist, and nothing
here has been distributed.