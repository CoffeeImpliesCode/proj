# FORK-NOTES.md — the worker's engineering record

What was done to get PROJ 9.9.0 into this package, what was observed while
reading it, what was decided, and what is still open.

Status vocabulary is the workspace's. `SOURCE-CONFIRMED` means read out of a named
file at a named line. `OBSERVED` means a command here printed it.
`PENDING-VERIFICATION` means it landed and no gate has observed it. `CONSTRAINT`
means a binding rule with no observation behind it. `HYPOTHESIS` means reasoned
and unexecuted.

**Nothing in this file is a gate result.** The import and packaging sections
below record no gate: no build, test, smoke run, cross-target check, formatter or
provenance script was executed for them. § 12 is the one exception and says so
where it applies: that section's `OBSERVED` lines are commands this slice ran and
the receipts are named with them.

---

## 1. How the sources were obtained and verified

**PROJ.** The GitHub releases API for `OSGeo/PROJ` tag `9.9.0` was read first: it
reports `prerelease=false`, `draft=false`, `published_at` 2026-09-15T12:21:00Z, and
one asset `proj-9.9.0.tar.gz` of 6048023 bytes with a `digest` field. The tarball
was then downloaded and **two** digests were computed locally.

| Digest | Computed here | Also published by |
|---|---|---|
| sha256 `791a0610547eeabb17006cfd49cdbd2034f3240f47ed5e88a1031811f4e2bcf3` | ✓ | the API `digest` field |
| md5 `50ed234d73d68f7bf4378e9a020a40a7` | ✓ | the `proj-9.9.0.tar.gz.md5` sidecar asset |

Both agree. That is the check, and the reason it is worth two sides rather than
one: an API field and a locally computed hash agreeing rules out a corrupt download
and a mislabelled asset at the same time. The tag object
`ce93bea6b5a18152b36e18c4179aae6df79a58b8` and its target commit
`1df2be61c0e4732aa1326126113776b291ae7657` came from the same API response, along
with the tagger identity and time.

`OBSERVED`: the extracted tree carries 664 files totalling 40952259 bytes, and
every path in `UPSTREAM.sha256` exists. No file named there is missing, and no file
in the tree is unaccounted for.

**SQLite.** <https://www.sqlite.org/2026/sqlite-amalgamation-3530400.zip>, 2946650
bytes. `OBSERVED`: sha256
`1e71ddf93849c6a6ecf58b827c0692073d2dd7ee40196158068f7b29f422e87d` computed here,
SHA3-256
`628a44cfe82c66aed1ccbbe85a562d2e33ebe64b3288981ed76285612227934e` computed here
and equal to the value published on <https://www.sqlite.org/download.html>.

`OBSERVED`: the zip contains more than the three files vendored here, including
`shell.c` at 1185915 bytes. Only `sqlite3.c`, `sqlite3.h` and `sqlite3ext.h` were
taken; the omission is deliberate and is recorded in `NOTICE.md` § 6 and § 7.

**`UPSTREAM.sha256` was written by the driver and not regenerated here.** It
already listed all 664 files and was already verified with `sha256sum -c` at import
time. This role did not add to it and did not edit it. Every licence claim in
`NOTICE.md` about bytes is therefore about *upstream* bytes, which is the correct
basis for a licence inventory: no fork edit could change what a notice says.

---

## 2. `lib_proj.cmake`: five groups and one app file

`SOURCE-CONFIRMED`. `src/lib_proj.cmake` defines the `proj` target in six lists.
Counts below are what the file says, counted over the `set(...)` bodies:

| Group | `set(` at | Entries | Entry lines |
|---|---|---:|---|
| `SRC_LIBPROJ_PROJECTIONS` | `:22` | 117 | `:23-139` |
| `SRC_LIBPROJ_CONVERSIONS` | `:142` | 8 | `:143-150` |
| `SRC_LIBPROJ_TRANSFORMATIONS` | `:153` | 13 | `:154-166` |
| `SRC_LIBPROJ_ISO19111` | `:169` | 23 | `:170-192` |
| `SRC_LIBPROJ_CORE` | `:195` | 69 | `:196-264` |
| `SRC_PROJAPPS_LIBS` | `src/apps/lib_projapps.cmake:1` | 1 | `:2` |

Two observations that changed how the closure was read.

**`SRC_LIBPROJ_CORE` ends with a generated file, not an upstream one.** `:264` is
`${CMAKE_CURRENT_BINARY_DIR}/proj_config.h`. So the core group is 68 upstream
paths plus one generated header, and any "how many upstream files does the core
compile" question has to answer 68 and then say what the 69th is. It is the reason
§ 4 exists.

**`SRC_LIBPROJ_ISO19111` is 23 entries, not 18.** All 23 are `.cpp`:
`static`, `util`, `metadata`, `common`, `coordinates`, `crs`, `datum`,
`coordinatesystem`, `io`, `internal`, `factory`, `c_api` at `:170-181`, then eleven
under `operation/` at `:182-192`. `HEADERS_LIBPROJ` (`:284-290`) names five headers
and they are listed separately, so no header is double-counted. A closure count
that reads 18 here has dropped five `operation/` units.

**`projinfo_lib.cpp` is inside the library, and that is unusual.** Seven apps are
built as executables, each with its own `bin_*.cmake`
(`bin_proj.cmake`, `bin_cs2cs.cmake`, `bin_geod.cmake`, `bin_cct.cmake`,
`bin_gie.cmake`, `bin_projinfo.cmake`, `bin_projsync.cmake`), and
`src/apps/lib_projapps.cmake:1-4` carves out exactly one of their sources:

```cmake
set(SRC_PROJAPPS_LIBS
  apps/projinfo_lib.cpp
  )
set(HEADERS_PROJAPPS_LIBS apps/projapps_lib.h)
```

`src/lib_proj.cmake:373-380` puts `${SRC_PROJAPPS_LIBS}` into
`ALL_LIBPROJ_SOURCES` and `:388-390` puts that into `add_library(proj ...)`. So
`projinfo`'s engine is linked into `libproj` even in a build that never links the
`projinfo` binary. `CONSTRAINT` for this fork: the compiled closure therefore
includes one file from `src/apps/` and must not be described as "the library plus
no app sources".

Also worth knowing before writing the closure: `src/lib_proj.cmake:268-282` names
`SKIP_UNITY_BUILD_FILES` — `list.cpp`, `transformations/defmodel.cpp`,
`transformations/tinshift.cpp`, `wkt1_parser.cpp`, `wkt2_parser.cpp`,
`wkt1_generated_parser.c`, `wkt2_generated_parser.c`, plus `networkfilemanager.cpp`
on Windows — with two named reasons (`"because if sets DO_NOT_DEFINE_PROJ_HEAD"`,
`"Evaluator class conflict"`). This build does no unity build, so the list is
inert; it is recorded because it is upstream's statement about which units cannot
share a translation unit.

---

## 3. `PROJ_DB_SQL_MD5`: the reproduction, and what it does not prove

`OBSERVED`. The rule is upstream's and it is at
`data/generate_proj_db.cmake:19-22`:

```cmake
file(READ ${ALL_SQL_IN_FILENAME} CONTENTS)
string(REGEX REPLACE "INSERT INTO \"metadata\"[^\n]*\n?" "" CONTENTS_WITHOUT_METADATA "${CONTENTS}")
string(MD5 OUT_MD5_LOCAL "${CONTENTS_WITHOUT_METADATA}")
```

The comment at `:17-18` gives the reason: "Compute the MD5 before any records in
the metadata table, to avoid refreshing the MD5 if we bump PROJ_VERSION or
PROJ_DATA.VERSION". So the digest deliberately excludes
`data/sql/metadata.sql`'s `INSERT` lines and nothing else, which is what makes it
stable across a version bump while still detecting any change to the schema or
the registry data.

Concatenating in `data/sql_filelist.cmake:15-79` order with
`PROJ_DB_EXTRA_VALIDATION` **OFF** and applying that rule gives

```
14264577 bytes
MD5 = 97f045739c534f9697ae359d4be8c95a
data/sql/proj.db.sql.expected.md5:1 = 97f045739c534f9697ae359d4be8c95a
```

**What this proves.** The imported `data/sql/*.sql` are complete, untruncated, in
the right concatenation order, and byte-identical in the bytes the digest covers.
If a single registry row were lost, reordered or altered in the import, this MD5
would move and the equality would fail. It is upstream's own consistency check,
run by upstream's own rule, against upstream's own expected value.

**What this does not prove.** Nothing about `proj.db`:

* No `sqlite3` CLI was invoked. `CMakeLists.txt:232-235` is upstream's route and it
  is not this build's.
* No `proj.db` file was produced, opened, queried or schema-checked.
* Nothing was downloaded.
* The triggers and the `ANALYZE`/`VACUUM` epilogue were concatenated as text; they
  were not executed.

So `proj.db` is `PENDING-VERIFICATION`, and every statement about it in `README.md`
is a statement about what the generator will do, read out of the generator, not
about an artefact that exists.

Two further details from the same file, because they change what a build step has
to do:

* `:25` substitutes `${PROJ_VERSION}` into the concatenated text. The
  substitution happens **after** the MD5, which is why the MD5 is stable across a
  version bump — and `data/sql/metadata.sql:17` is where the placeholder lives.
* `:32-48` compares the computed value against the expected one. On a mismatch it
  either runs the extra-validation build, or fails with "Database is valid; please
  update data/sql/proj.db.sql.expected.md5 with …". The failure message is
  deliberately the *opposite* of the usual one: a mismatch that survives
  extra validation means the expectation is stale, not the data.

---

## 4. The two generated inputs, and why they are per-target

`CONSTRAINT` from `../AGENTS.md` § 5, applied to two files upstream's CMake
generates. Both are produced by **host-run generators that are told the target
they are generating for**; neither is a host-configuration dump.

**`proj_config.h`.** Upstream's template is `cmake/proj_config.cmake.in` — 29
lines, ten `#cmakedefine`s: three `HAVE_` facts and seven strings. What it carries
is toolchain detection, not layout:

| `#cmakedefine` | Where upstream reads it |
|---|---|
| `HAVE_LIBDL` | `src/filemanager.cpp:32-35`, `:66`, `:1402` |
| `HAVE_LOCALECONV` | `src/strtod.cpp:68` |
| `HAVE_STRERROR` | `src/apps/emess.cpp:49-52` |
| `PACKAGE`, `PACKAGE_NAME`, `PACKAGE_STRING`, `PACKAGE_TARNAME`, `PACKAGE_VERSION`, `PACKAGE_BUGREPORT`, `VERSION` | strings, identical everywhere |

`cmake/ProjConfig.cmake:10-19` is where the three `HAVE_` facts are discovered:
`check_function_exists(localeconv HAVE_LOCALECONV)`,
`check_function_exists(strerror HAVE_STRERROR)`, and
`check_library_exists(dl dladdr "" HAVE_LIBDL)` guarded by `if(NOT WIN32)`.

*Why per-target, not per-host:* `HAVE_LIBDL` decides whether
`src/filemanager.cpp` calls `dladdr`, and `dladdr` exists or does not on the
**target**, not on the machine running the generator. A generator that configured
for the host and emitted the result into a `wasm32-wasi` or `aarch64-macos-none`
build would produce a header that disagrees with the libc that libc. Two further
requirements from the same rule: the generator writes into the build cache in a
**dependent** step, never during `build()`, and its output directory goes on
**both** the compile line and the translation line.

**`PROJ_DB_SQL_MD5.h`.** One line:
`const char* PROJ_DB_SQL_MD5="<md5>";`, written by
`data/generate_proj_db.cmake:31`. Its sole consumer is
`src/embedded_resources.c:8-11`:

```c
#include "PROJ_DB_SQL_MD5.h"
const unsigned char *pj_get_embedded_proj_db(unsigned int *pnSize) {
    (void)PROJ_DB_SQL_MD5;
```

and that file is compiled only under `EMBED_RESOURCE_FILES` (`src/lib_proj.cmake:420-421`).

This build does not set that, so nothing reads the header — and it still generates
it, for one reason: upstream's consistency rule (`src/generate_proj_db.cmake:32-48`)
has to be reproducible, and reproducing the rule is cheaper than arguing about
whether it still applies. `CONSTRAINT`: a target-independent value generated on a
per-target schedule, because its producer is a per-target step and mixing the two
is how a host fact leaks into a cross build.

`OBSERVED`, and worth stating plainly because it is the whole content of this
entry: neither input has been generated by this build. Both are `PENDING-VERIFICATION`.

---

## 5. Why SQLite is vendored

`SOURCE-CONFIRMED`. The chain is short and has no alternative branch:

1. `CMakeLists.txt:247` — `find_package(SQLite3 3.11 REQUIRED)`. `REQUIRED`: a
   build without SQLite does not configure.
2. `src/lib_proj.cmake:610` — `target_link_libraries(proj PRIVATE SQLite3::SQLite3)`.
   The library itself links it, so this is not an app-level optional dependency.
3. No wave slice owns sqlite3, and `../AGENTS.md` § 4 forbids a system-installed
   default.

Vendoring the amalgamation is therefore the only route that satisfies the
dependency without a system default and without a build-time download. The cost is
recorded honestly: 10245354 bytes, 9.5 MB of it one file, in every consumer's
build.

**Two things this decision changes**, both worth stating because they are easy to
get wrong:

* **`shell.c` is not vendored, and the reason is the build graph, not the
  licence.** `CMakeLists.txt:232-235` makes the `sqlite3` CLI a hard build
  requirement:
  `find_program(EXE_SQLITE3 sqlite3)` then
  `message(SEND_ERROR "sqlite3 binary not found!")`. And
  `data/generate_proj_db.cmake:40` pipes the concatenated SQL into
  `"${EXE_SQLITE3}"`. Upstream's route therefore needs the CLI binary, which is a
  *system-installed* program — the exact thing `../AGENTS.md` § 4 rules out. This
  build runs the concatenated script through a **host build of the vendored
  amalgamation** instead, which is why the omission is safe rather than a hole.
* **This adds a real external ABI family.** The dispatch in `runtime/` resolves
  `sqlite3_*` names at runtime, and SQLite3's ABI is not PROJ's. `runtime/library.zig`
  owns that family's validation. `HYPOTHESIS` until a gate runs: whether the SQLite3
  version check belongs in the same descriptor as PROJ's or beside it.

---

## 6. Datum data — the decision, in full

`OBSERVED`. This is the longest decision in the package and the one most likely to
be misread, so it is recorded end to end.

### What is not there

**`data/proj.db` is not in the release tarball.** `data/` holds `sql/` (59 files),
the three JSON schemas, `proj.ini`, `nad.lst`, `other.extra`, nine legacy `+init`
definition files and `tests/` (88 upstream test grids and fixtures). `data/README:18`
points at <https://github.com/OSGeo/PROJ-data> for the rest, and
`README.upstream.md:51-60` describes that separate grid package in prose.

### What is there, and what it is not

The `+init` files look like data and are not. `data/CH` is a **definition** file.
`data/CH:5-6`:

> You'll need to download the grids separately and put in a directory scanned by
> libproj

and `data/CH:20` names the file it needs:

```
<1903_LV03>  +proj=somerc ... +nadgrids=CHENyx06_ETRS.gsb +no_defs
```

Same for `GL27`, `ITRF2000`, `ITRF2008`, `ITRF2014`, `ITRF2020`, `nad27`, `nad83`
and `world`. **`data/tests/` is upstream test material, not installed data**, and
upstream's own build keeps it away from the install set on purpose —
`data/CMakeLists.txt:59-60`: "Copy select resource files in a for_tests
subdirectory so that we are not influenced by the presence of other grids".

### The decision

**`proj.db` is generated at build time from `data/sql/`; no datum-shift grid
ships.** The vendored datum data is exactly `proj.db`, `proj.ini`, the three
`*.schema.json`, `nad.lst` and `other.extra`.

**Consequence, stated as a data-availability fact and not as a build result:**
every operation in `proj.db` that needs an NTv1/NTv2/GeoTIFF/CTABLE2 grid reports
that grid unavailable. That is what the package does without one, and it is a
property of what was shipped rather than of whether anything ran.

`data/sql/grid_transformation.sql` names roughly every grid PROJ knows about and
`data/tests/` ships almost none of them. The two facts are consistent, and the
second is the point.

### How a consumer finds `proj.db`, without network

PROJ's own resolution, read out of the source:

* `src/filemanager.cpp:1113-1132`, `FileManager::getProjDataEnvVar`. `PROJ_DATA`
  first, at `:1119`. If unset, `PROJ_LIB` at `:1121`, which upstream annotates
  `"Legacy name. We should probably keep it for a long time for nostalgic people
  :-)"` and logs as deprecated at `:1124-1127`: "PROJ_LIB environment variable is
  deprecated, and will be removed in a future release. You are encouraged to set
  PROJ_DATA instead".
* `src/filemanager.cpp:1718-1759`, `pj_get_default_searchpaths`, is where the list
  is assembled, and `getProjDataEnvVar` is called at `:1730`.
* Paths set programmatically on the context via
  `proj_context_set_search_paths` are the third source.

**This package never embeds a build-host path.** `src/lib_proj.cmake:311-314`
guards `add_definitions(-DPROJ_DATA=...)` behind `EMBED_PROJ_DATA_PATH`, which is
not set; `EMBED_RESOURCE_FILES` (`src/lib_proj.cmake:420-445`, `:468-473`, `:516-519`)
is not set either. So the library finds its data the way upstream finds it: from
the environment or from the context, with `proj.db` installed as a file beside the
other data rather than compiled into the image.

Every gate in this package sets `PROJ_DATA` to the directory the build just
installed into and `PROJ_NETWORK=OFF`. That makes "no network" a property of the
gate's configuration rather than an accident — which matters because
`src/lib_proj.cmake:623-632` shows `CURL_ENABLED` is off, so PROJ cannot fetch
anything over the network even if a grid were missing. `PROJ_USER_WRITABLE_DIRECTORY`
is left alone: `src/filemanager.cpp:1723-1728` shows upstream consults it first
unless `PROJ_SKIP_READ_USER_WRITABLE_DIRECTORY` is set, and overriding that would
change what upstream decided rather than observe it.

The facade exposes `setDatabasePath` and `setSearchPaths`. It deliberately does
**not** re-read `PROJ_DATA` itself: that is a value upstream defines
(`src/filemanager.cpp:1730`), and a facade that re-derived it would own a second
answer to a question upstream already answers.

### What a consumer who wants a grid must do

Download it and point `PROJ_DATA` at the directory, or add the directory through
`proj_context_set_search_paths`. `data/CH:5-6` is upstream telling the user
exactly this. This package neither downloads nor proxies: `CURL_ENABLED` is off,
`EMBED_RESOURCE_FILES` is off, and no build step fetches a grid.

---

## 7. The absent `.fingerprint`, and why

`build.zig.zon` deliberately has **no** `.fingerprint` field.

`lib/init/build.zig.zon:16-25` states that the field is *generated by the Zig
toolchain when the package is first created* and that it never changes. Writing a
value by hand would therefore be two wrong things at once: a fabricated identifier,
which `../AGENTS.md` § 2 rule 3 forbids, and a value the toolchain will overwrite
on first configure, so it would be a lie that also fails.

**The observed value is the driver's to record**, after its first configure, in
this file. It is not recorded here because it was not observed here, and "not
observed" is the correct answer rather than a gap.

`SOURCE-CONFIRMED`, and the reason a reader should not patch this in: the field
does not carry meaning a package author controls. It is a toolchain bookkeeping
value. Its absence from source control is the correct state; its absence from
*this file's* record is a gap the driver closes.

---

## 8. System mode: recorded as vacuous, not satisfied

`CONSTRAINT`. `../AGENTS.md` § 4 says system-library mode uses
`b.systemIntegrationOption` only where a real compiled system library exists, that
the headers it links must be the real selected system headers or an explicitly
verified identical header and ABI version, and that a fork-only namespaced bridge
must be compiled from our own tree in every mode. The last sentence of that
section says a fork with no system mode "records the rule as vacuous, not
satisfied".

**This package offers no `-Dsystem` option.** The published options are
`-Dlinkage=static|dynamic` and `-Druntime=bool`, and nothing else.

So the record is: **vacuous**. Not "satisfied", not "verified", not "refused" —
none of those would be true. There is no system mode to be right or wrong about,
and `README.md` says so in the same words. What would *not* be acceptable is
letting "vacuous" quietly become "satisfied" in a later summary, which is exactly
the failure mode `../AGENTS.md` § 4 last sentence exists to prevent.

For the record, the reason the rule cannot be satisfied here even in principle:
the compiled closure is 230-odd upstream translation units plus a 9.5 MB
amalgamation, and a system mode would have to select a *matching* system PROJ
headers-and-library pair, verify the ABI version, and still compile a
fork-only bridge from this tree. Nothing here has attempted it and nothing here
asserts it works.

---

## 9. The compile boundary: what is retained and not compiled

An explicit platform boundary, not a failure and not something to repair by
fetching. Everything below is present, byte-identical, and digested in
`UPSTREAM.sha256`.

| Not compiled | Where upstream keeps it | Why |
|---|---|---|
| the seven CLI apps | `src/apps/*.cpp`, 13 translation units, one `bin_*.cmake` each; only `projinfo_lib.cpp` joins the library (see § 2) | this package ships a library and a facade, not seven executables |
| the upstream test tree | `test/` (98 files) and `src/tests/` (4 files: `geodtest.c`, `geodsigntest.c`, `multistresstest.cpp`, `CMakeLists.txt`) | needs GTest and the built binaries. Retained, never deleted, never replaced by a fetched substitute |
| the bison-parser refresh targets | `src/lib_proj.cmake:326-368` | the generated parsers are checked in and compile as-is; regenerating needs bison, which this build does not require |
| `EMBED_RESOURCE_FILES` | `src/embedded_resources.{c,h}`, `src/memvfs.{c,h}`, `src/lib_proj.cmake:420-445`, `:468-473`, `:516-519` | it embeds `proj.db` and data into the image; this package installs them as files |
| TIFF and CURL | `CMakeLists.txt:256` (`ENABLE_TIFF` default ON upstream), `src/lib_proj.cmake:618-621`, `:623-632` | this build defines neither `TIFF_ENABLED` nor `CURL_ENABLED` |

Two consequences worth carrying forward:

* **CURL off means no network, by construction.** `projsync`'s CDN path and
  GeoTIFF grid reading are unavailable, which is why every gate sets
  `PROJ_NETWORK=OFF` rather than relying on the absence of a network.
* **TIFF off narrows grid formats.** `.tif` grids in `data/tests/` cannot be read
  by the compiled library. Those files are upstream test material and are not
  compiled in any case, so nothing is lost — but a consumer must know that the
  GeoTIFF grid route is not in this package.

### 9a. `wasm32-wasi` is a real toolchain limit, named

`zig build check` compiles five of the six ledger targets and **fails on
`wasm32-wasi`**. It is reported here as a red cell, not as a pass: the other
five targets build, this one does not. Observed
(`zig build check`, pinned toolchain `zig 0.16.0`, `-j8`): 21 compilation
errors in `proj-wasm32-wasi`, and
`Build Summary: 55/60 steps succeeded (1 failed)`.

The cause is the pinned toolchain's own C++ library, not this package and not a
missing dependency. Two feature gates are off for this target, and PROJ uses
both unconditionally in its own sources:

| Missing | Gate in the pinned toolchain | Where PROJ needs it |
|---|---|---|
| `std::mutex`, `std::recursive_mutex`, `std::lock_guard` | `_LIBCPP_HAS_THREADS` is 0; `libcxx/include/mutex:219` and `libcxx/include/__mutex/mutex.h:20` wrap every definition in `#if _LIBCPP_HAS_THREADS` | `src/mutex.cpp:29`, `:33`, `src/transformations/gridshift.cpp:50`, `:1026`, `src/transformations/vgridshift.cpp:13`, `:238`, `src/transformations/hgridshift.cpp:13`, `:198`, `src/iso19111/factory.cpp:625`, `:654`, `:662`, `src/networkfilemanager.cpp:163`, `:187` |
| `std::ifstream`, `std::fstream` | `_LIBCPP_HAS_FILESYSTEM` is 0; `libcxx/include/fstream:194` wraps the whole body in `#if _LIBCPP_HAS_FILESYSTEM && _LIBCPP_HAS_LOCALIZATION` | `src/apps/projinfo_lib.cpp:343`, `:345` |

Both values were read out of the toolchain rather than inferred: compiling a
translation unit that tests `#if _LIBCPP_HAS_FILESYSTEM` and
`#if _LIBCPP_HAS_THREADS` against `-target wasm32-wasi-musl` reports
`FS_IS_0` and stays silent on the threads test, while the same file for
`x86_64-linux-gnu` reports `FS_IS_1` and `THREADS_IS_1`.

A third, smaller one is a deprecation the toolchain raises as an **error** in
this build: `src/networkfilemanager.cpp:2711` calls `getpid()`, and
`libc/include/wasm-wasi-musl/unistd.h:155` marks it
`__attribute__((__deprecated__("WASI lacks process identifiers; ...")))`
unless `_WASI_EMULATED_GETPID` is defined. PROJ calls it behind only
`#ifdef _WIN32` (`:2709`), so on WASI it takes the plain `getpid()` path.

**Why this is not repaired here.** Each repair would mean editing vendored
upstream sources under `src/`, which are byte-for-byte upstream and digested in
`UPSTREAM.sha256`. The workspace rule is that a fix belongs in this fork's own
files; there is no fork-owned file that can supply `std::mutex` to
`src/mutex.cpp`. Forcing `-D_LIBCPP_HAS_THREADS=1` *does* make `std::mutex`
compile, but that overrides a decision the toolchain makes about its own target
and is not a fix, so it is recorded here rather than applied.

**What this does and does not claim.** It claims the `wasm32-wasi` row of `check`
is red, with the toolchain header and line that make it red. It does not claim
PROJ is unfit for WASI in general - upstream builds it there with a libc++ that
has threads and filesystem. `riscv64-linux-gnu`, `x86_64-linux-gnu`,
`aarch64-linux-gnu`, `aarch64-macos-none` and `x86_64-windows-gnu` all pass
`zig build check` (exit 0) against the same toolchain.

---

## 10. Licence findings that were not in the brief

Four items surfaced while reading, each verified against a file, and each recorded
in `NOTICE.md`.

### 10a. Three `cmake/` files are Boost-1.0, and the licence file they name is not in the tree

`cmake/ProjVersion.cmake:1-7`, `cmake/ProjUtilities.cmake:1-13` and
`cmake/ProjConfig.cmake:1-9` each read "Distributed under the Boost Software
License, Version 1.0". Two of them point at an accompanying file:
`cmake/ProjUtilities.cmake:11-12` — "See accompanying file LICENSE_1_0.txt or copy
at <https://www.boost.org/LICENSE_1_0.txt>"; `cmake/ProjConfig.cmake:7-8` the same.

**`LICENSE_1_0.txt` does not exist in this tree.** A search for `LICENSE*` and
`COPYING*` across all 664 files returns exactly one hit: `COPYING`, which is
MIT-style. So the three files name a document the release tarball does not ship.

*Condition:* a tree contains files that grant under a named licence and reference
an accompanying licence file that is absent. *Symptom:* a reader following the
pointer finds nothing, and the natural repair — inventing the file or substituting
`COPYING` — would be wrong, because BSL-1.0 and MIT are different terms.
*Fix:* record the term and the absent reference as separate facts; obtain
`LICENSE_1_0.txt` from the URL the file itself names if a redistribution needs the
text. *Targets bound:* any release tarball whose `cmake/` modules are retained
uncompiled and unlicensed locally. Consequence here: none of the three is compiled
by this package, so nothing in the delivered library depends on the resolution.

`cmake/ProjUtilities.cmake:4-8` also records that it is "Based on
BoostUtilities.cmake from CMake configuration for Boost", with Douglas Gregor and
Troy Straszheim among the holders, and Mateusz Loskot in all three files. Loskot
appears **nowhere** in `src/` or `include/` — a reader who inventoried the compiled
core for names would not find him at all.

### 10b. `src/projections/polyhedral/snyder.h` carries two licences, not one

`snyder.h:8-24` is Apache-2.0 from the A5 contributors. `snyder.h:26-55` is a
complete BSD 3-Clause grant with all three numbered conditions and the disclaimer,
from Ecere Corporation. `:58-59` cites a third source
(<https://brsr.github.io/2021/08/31/snyder-equal-area.html>) with no stated term.

*Condition:* a per-file header that concatenates a derivation notice from project A
with a full grant from project B. *Symptom:* any inventory that reads the first
`*/` and stops reports one term for a file that has two, and a downstream
redistributor misses one obligation. *Fix:* read to the end of the header block, not
to the first blank line, and record both ranges separately.
*Targets bound:* any per-file licence inventory; the failure is silent and looks
correct.

### 10c. The two Bison `.c` files carry two notices each

`src/wkt1_generated_parser.c:1-32` and `src/wkt2_generated_parser.c:1-32` are the
GNU Bison GPL-2.0-or-later notice with the special exception at `:21-29`.
`:75-100` of the same files is **PROJ's own MIT header** —
`Copyright (c) 2013-2018 Even Rouault, <even.rouault at spatialys.com>` — because
upstream's `generate_wkt_parser.cmake` embeds the project's header into the
generated output.

*Condition:* a generated source whose upstream generator injects a project header
into the middle of a third-party skeleton. *Symptom:* a scan keyed on
`Permission is hereby granted` classifies the file as MIT and misses the GPL block
above it, or the reverse. *Fix:* classify per *block*, record both ranges, and note
that all four files are compiled. *Targets bound:* bison-generated files wherever
the generator injects a project header.

The four are compiled, and `src/lib_proj.cmake:274-275` names the two `.c` files in
`SKIP_UNITY_BUILD_FILES` — which is upstream's own statement that they are not
ordinary units. (The two `.h` files are headers, not translation units, so they
cannot appear in a unity build either way.)

### 10d. `data/tests/` carries real embedded provenance for twelve files

An earlier reading of this directory said it carried no provenance at all. That was
wrong, and the correction matters. **Twelve of the 88 entries carry licence
information as embedded file metadata** — GeoTIFF `ImageDescription`, GeoPackage
metadata table, GeoJSON `"license"` member:

* `fr_ign_RAGTBT2016.tif`, `subset_of_gr3df97a.tif` — "Derived from work by IGN
  France. Open License <https://www.etalab.gouv.fr/…/Open_Licence.pdf>"
* `test_hgrid_with_subgrid.tif`, `test_hgrid_with_subgrid_no_grid_name.tif` —
  "Derived from work by Natural Resources Canada. Open Government Licence -
  Canada: <http://open.canada.ca/en/open-government-licence-canada>"
* `nkgrf03vel_realigned_extract.tif`, its tiled variant, and all six
  `tinshift_*.json`/`tinshift_*.gpkg` pairs — `"license": "Creative Commons
  Attribution 4.0 International"`, `"href":
  "https://creativecommons.org/licenses/by/4.0/"`, `"rel": "license"`

*Condition:* a data directory whose files are binary containers with metadata
rather than text with headers. *Symptom:* a `grep -r copyright data/tests/` on text
files reports nothing and the directory gets recorded as provenance-free, which is
a stronger and wronger claim than "we did not look inside the files". *Fix:* look
inside binary containers before recording an absence; report "76 of 88 carry no
in-file statement" rather than "none does". *Targets bound:* any grid, fixture or
archive directory; the same mistake applies to `.tif`, `.gpkg`, `.zip` and `.nc`
anywhere.

Two of those files also carry a description that identifies them as **converted
derivatives** rather than the originals: `subset_of_gr3df97a.tif` reads
"Converted from gr3df97a.tif", and the two NRCan files read "Converted from
ntv2_0.gsb (last updated on 1995-07-05)".

The *Licence Ouverte* and the Open Government Licence – Canada are **named by URL
in the files and were not read here.** `NOTICE.md` records them as named, not as
understood.

### 10e. The EPSG terms of use are absent, and that is an open obligation

A search across all 664 files for the EPSG dataset's terms found the dataset named
only as data — `NEWS.md:2580-2581` "definitions imported from the IOGP EPSG
dataset", plus citations to IOGP *Guidance Note* publications in
`src/ell_set.cpp:441`, `src/conversions/topocentric.cpp:34-35`,
`src/projections/eqc.cpp:12-18`, `src/projections/col_urban.cpp:12-13` and
`src/projections/tmerczoned.cpp:6`. Those are bibliographic references to method
documentation, not a licence.

`data/sql/metadata.sql:12-13` pins the dataset precisely — `EPSG.VERSION 'v13.102'`,
`EPSG.DATE '2026-08-27'` — and `data/sql/README.md:24-60` names the generators for
five registries: EPSG via `build_db.py`, ESRI via `build_db_from_esri.py`, IGNF via
`build_db_create_ignf_from_xml.py`, IAU via `build_db_from_iau.py`, and NKG which is
"Hand-written".

**This is a finding, not an import failure.** The import is complete and
byte-verified. What is missing is a document upstream does not ship in its release
tarball either. PROJ's `COPYING:2-3` covers "All source, data files and other
contents of the PROJ package", read literally — but PROJ cannot grant what IOGP
holds over the EPSG dataset. The same question has four more shapes in the ESRI,
IGNF, IAU and NKG registries, and only NKG is described in-tree as hand-written.

*Condition:* a package whose compiled data is generated from a dataset published
under terms that are not in the tree. *Symptom:* the record reaches "MIT" by
inheriting the most prominent file, which is right about the code and wrong about
the rows. *Fix:* record the dataset identity and the absence separately, assert no
term, and name who must be asked. *Targets bound:* any package that generates a
database from a third-party registry; this is the shape to check first in every
geodetic, character-set and ICU-style SDK.

---

## 11. Open risks the driver must carry

Ordered by what would hurt most if it turned out wrong.

1. **The EPSG Geodetic Parameter Dataset's terms are not in this tree.**
   `proj.db` is generated from data derived from that dataset. Redistribution of
   `proj.db` needs IOGP/EPSG terms obtained and recorded first. `NOTICE.md` asserts
   no term. **Owner action, not a build action.**
2. **Nothing has been built.** 664 files are verified bytes and nothing else. The
   entire build graph, facade, runtime route, consumer, fixtures and all six
   cross-target cells are `PENDING-VERIFICATION`. A compile error anywhere in the
   230-unit closure is entirely possible and has not been looked for.
3. **`proj.db` has not been generated.** The MD5 reproduction (§ 3) proves the SQL
   input is intact; it says nothing about whether the script executes, whether the
   vendored amalgamation accepts it, or whether the schema comes out as the
   library expects. Fixture B reads constants back out of `proj.db`, so it depends
   on this working.
4. **`LICENSE_1_0.txt` is absent** (§ 10a) while three retained files name it.
   Nothing compiled depends on it. A redistribution that ships `cmake/` as source
   has an unresolved reference.
5. **A consumer who wants a grid has to supply one** (§ 6). Not a defect; a
   documented boundary that a reader could still mistake for a missing dependency.
6. **GeoTIFF grid reading is off** (`TIFF_ENABLED` undefined, § 9). `.tif` grids
   cannot be read by this library, and with `CURL_ENABLED` off there is no
   on-the-fly fallback either.
7. **The `.fingerprint` value is not recorded** (§ 7). The driver records it after
   its first configure; until then this file has a gap by design.
8. **Two external ABI families** are real — SQLite3's and libc's — and both are
   `runtime/library.zig`'s business. `HYPOTHESIS` (§ 5): whether SQLite3's version
   check belongs inside the PROJ descriptor or beside it is unsettled.
9. **`upstream` tests are retained and uncompiled.** That is the requirement, but
   it means this package's own behavioural evidence is entirely in `testdata/`
   and `tests.zig`. If those are thin, the package is thin, and no upstream suite
   backstops them.

10. **The 53-platform matrix has an open red: 13 cells execute and fail 3 of 7
    tests, and the fault is in this fork's Zig→C call, not in `libproj`.**
    `OBSERVED` at run id `20261005-194952-42348-15511`, harness exit 1, 53
    targets, 6 pass / 13 runtime fail / 2 build fail / 32 build-only. The 13 are
    `aarch64-linux`, `aarch64_be-linux`, `arm-linux`, `armeb-linux`,
    `loongarch64-linux`, `mips64-linux`, `mips64el-linux`, `powerpc-linux`,
    `powerpc64-linux`, `powerpc64le-linux`, `s390x-linux`, `thumb-linux`,
    `thumbeb-linux`, and all 13 fail the *same three* tests (fixture A, fixture A
    second leg, fixture C). Ruled out by control, not by inference: the same
    `libproj.a` in a plain C program under the same `qemu-aarch64` reproduces
    both published answers exactly; struct layout agrees between Zig and C
    (`PJ_COORD` 32/8); `ReleaseSafe` fails identically; `-cpu max` and
    `-cpu cortex-a72` are identical to the default; and a raw Zig program that
    bypasses this facade entirely returns `v[0]=-0.000000000 v[1]=-0.000000000`
    where C returns the correct value. `zig build smoke` on `aarch64-linux`
    independently prints `0.000 E, 0.000 N`. The transposition is visible in the
    failure text itself: `aarch64-linux` reports `got 4865942.279503176000` for
    `v[0]`, which is this package's own y constant (`tests.zig:266`), not a wrong
    number. **Not recorded as a platform boundary** — nothing in the pinned
    toolchain's source or in an observed message licenses that. It is fork work:
    reduce the raw-Zig call to a minimal repro. Receipts and the full cell table
    are in `$HOST_SCRATCH_ROOT/scratch/foundation-libs/cross/proj-j1/`
    (`matrix-report.md`, `cross-test-summary.json`, 53 `build-*.log`).
11. **Two cells are genuine boundaries, and each has its own source.**
    `hexagon-linux` fails 19 compiles in `zig/root.zig` with
    `expected type 'u8', found 'c_uint'`, because `aro/aro/Target.zig:500-504`
    makes hexagon the only architecture that packs C enums, so `PJ_CATEGORY`
    becomes `u8`-backed there while `zig/root.zig:485` pins `enum(c_uint)`.
    `wasm32-wasi` fails 21 compiles, led by `no type named 'mutex' in namespace
    'std'` (7×) at upstream `src/mutex.cpp:33` and
    `src/transformations/vgridshift.cpp:13`, confirmed with a two-line
    `zig c++ -target wasm32-wasi` probe that fails identically and compiles on
    `aarch64-linux`. This is **not** the `setjmp.h` failure recorded for
    `zig build check`; a separate observation, and the same libc++ gap.
12. **Running this matrix with `--jobs 8` reports all 53 cells red for a reason
    that has nothing to do with PROJ.** The harness gives every concurrent cell
    one `--cache-dir` (`cross-test:389`) and one `--prefix` (`cross-test:719`),
    while `build.zig:1601` marks the `proj-db-gen` run step `has_side_effects`
    and `build.zig:1607` gives it one fixed output name that `build.zig:2071-2075`
    installs to `share/proj/proj.db`. Eight cells therefore run eight
    `sqlite3_exec` sequences against one file: 45 `disk I/O error`, 7
    `attempt to write a readonly database`, 1 `database is locked`, all 53
    `DatabaseBuildFailed`. The same cell alone exits 0 with 7/7.
    *Condition:* a `has_side_effects` run step writing a fixed-name artifact into
    the install prefix, under a harness that shares one prefix across cells.
    *Symptom:* uniformly red with SQLite I/O errors that look like a library
    fault. *Fix:* run this matrix at `--jobs 1`; the profile's
    `CROSS_BUILD_JOBS=4` is inner parallelism and is unaffected. *Targets bound:*
    every tree whose build graph writes a generated artifact into the install
    prefix, which is all of them under this harness — not a proj-specific
    property.
13. **A matrix must be discarded if any source it compiles changed mid-run.**
    `consumer/src/main.zig` was modified at 21:45, inside the serialized run's
    window. It does not reach the `test` step: its only reference is
    `build.zig:2295`, inside the `consumer` executable, and `test` depends only on
    `run_tests` (`build.zig:2312-2320`) and `exercise` (`build.zig:2323-2334`).
    The run was kept only after re-hashing every file `test` does reach and
    finding all of them unchanged across the run. Hash the fork-owned sources
    before *and* after, not once — and note that an unchanged hash only settles
    the question if the file is on the step's graph at all.

## 12. The by-value `PJ_COORD` boundary, and the fork-authored bridge

### What the disagreement is

`SOURCE-CONFIRMED`. Ten entry points move `PJ_COORD` by value, and upstream says
that is deliberate: `src/proj.h:65-71` passes `PJ_LP` and `PJ_XYZ` "on the stack
(\"call by value\"), and symmetrically returning the result on the stack". The ten
are `src/proj.h:629` `proj_trans`, `:656` `proj_coord`, `:663` `proj_lp_dist`,
`:666` `proj_lpz_dist`, `:669` `proj_xy_dist`, `:672` `proj_xyz_dist`, `:676`
`proj_geod`, `:705` `proj_geod_direct`, `:783` `proj_factors` and `:1426-1429`
`proj_get_suggested_operation`. The union is 32 bytes with four doubles in `v`
(`src/proj.h:315-330`).

`OBSERVED` on 2026-10-06, by disassembly rather than by inference. The C compiler
that builds this archive classifies that union as a four-element floating-point
aggregate and passes and returns it in four consecutive SIMD registers.
`objdump -d` of a `union PJ_COORD proj_coord(double,double,double,double)`
compiled for `aarch64-linux` is a single `ret`: the arguments arrive in `d0`-`d3`
and the result leaves in `d0`-`d3`. Zig 0.16.0's own lowering of a call to the
same function does not: the caller sets `x8` to a result slot
(`add x8, sp, #0x10`), passes the arguments, and afterwards reads the result out
of that slot with `ldr q0, [sp, #16]` — a slot the callee never wrote. The two
halves of one call do not meet.

`OBSERVED` on the same day, on the failure itself. Fixture A reported
`4865942.279503176` where `tests.zig:266` records `-8348961.809495518` as `x_m`
and `4865942.279503176` as `y_m` for the same point: the coordinate came back
with two of its four words in the wrong place. A C program compiled against the
same `libproj.a` for the same target returned both numbers correctly, so the
library is not at fault and neither is QEMU.

The trigger is the **union**, not the size. `OBSERVED`: on `aarch64-linux` a
`struct { double a, b, c, d; }` moved by value crosses correctly from Zig, while
`union { double v[4]; }` — the same 32 bytes, the same four doubles — does not.

### The shape of the failure across targets

`OBSERVED` on 2026-10-06 with a reduction that carries PROJ's exact `PJ_COORD`
(`src/proj.h:273-330`, twelve arms) and nothing else of upstream: one C
constructor, one C `PJ_COORD`-in/`PJ_COORD`-out function, one pointer-shaped
equivalent of each, and a Zig caller for all four. Results, by-value against
pointer-shaped:

| Target | by value | through pointers |
|---|---|---|
| `aarch64-linux`, `aarch64_be-linux` | four zeros | correct |
| `arm-linux`, `armeb-linux`, `thumb-linux`, `thumbeb-linux` | scrambled words | correct |
| `powerpc64-linux`, `powerpc64le-linux` | four zeros | correct |
| `mips64-linux`, `mips64el-linux` | return right, argument wrong | correct |
| `riscv64-linux`, `x86-linux` | return wrong in the last two words | correct |
| `loongarch64-linux`, `powerpc-linux`, `s390x-linux` | **segmentation fault** in the callee | correct |

Nothing about this is a big-endian or 64-bit property: `mips64el-linux` and
`powerpc64le-linux` fail and `x86-linux` and `riscv64-linux` fail too, only
differently. What the table does establish is that the pointer-shaped route is
correct on **every** target tried, which is why it is the repair.

### The repair, and why it is in C

`zig/proj_abi.h` and `zig/proj_abi.c` are the bridge, and `build.zig:1739` puts
the one translation unit on the same compile line as upstream's. Each body is
the call upstream writes — the aggregate goes and comes back by value — and only
pointers, a `double` and an `int` come back out. Both halves of the by-value call
are then produced by one compiler, which is the only arrangement either of them
can be relied on to agree with. `zig/root.zig` reaches the ten entry points
through the bridge; the seven the typed surface exposes are declared in the
`c_abi` block at `zig/root.zig:825`, and the other three (`proj_lpz_dist`,
`proj_geod`, `proj_geod_direct`) are in the header for a caller who reaches them
through `pub const c`.

The alternative — spelling the aggregate as an `extern struct` in Zig and
declaring the same symbol through `@extern` — was not taken. It would restate
upstream's layout in a second hand-maintained place, which `zig/root.zig:762-788`
rejects on purpose, and it would depend on Zig's struct lowering agreeing with
clang's union lowering on every target rather than on the C compiler's own
consistency.

### What was observed

`OBSERVED` on 2026-10-06, host scratch at
`$HOST_SCRATCH_ROOT/cache/foundation-libs/wave10/proj`, `-j8 --summary all`,
every cell executed by the build runner under the same QEMU the matrix uses.
The full table is `CHANGELOG.md` § 3; the shape of it is:

* **Before:** `zig build test -Dtarget=aarch64-linux` exits 1 with
  `4 pass, 3 fail`.
* **After:** the same command exits 0 with `16/16 steps succeeded; 7/7 tests
  passed`, and the binary run by hand under `qemu-aarch64` prints
  `All 7 tests passed.` and exits 0. Nineteen targets in total were run the same
  way — the thirteen that failed, plus `x86_64-linux`, `riscv64-linux`,
  `riscv32-linux`, `mips-linux` and `mipsel-linux` that had been passing — and
  all nineteen print `7/7 tests passed` with exit 0.
* `x86-linux` cannot be run by `zig build test -Dtarget=x86-linux` alone: the
  build runner refuses on the target dynamic linker
  (`/lib/ld-musl-i386.so.1` against the host's `/lib64/ld-linux-x86-64.so.2`),
  which is the seam `cross-test` patches at `cross-test:389`. Run by hand under
  `qemu-i386` it prints `All 7 tests passed.` and exits 0.
* Host gates, host target: `zig build` exit 0 (39/39), `zig build test` exit 0
  (16/16, 7/7), `zig build test -Doptimize=ReleaseSafe` exit 0 (16/16, 7/7),
  `zig build smoke` exit 0 (15/15), `zig build consumer` exit 0 (15/15),
  `zig build provenance` exit 0 (2/2, "provenance checks passed" — so no
  vendored file was edited).
* `zig build check` exits 1 with `55/60 steps succeeded (1 failed)`. The one
  failure is `wasm32-wasi` compiling **upstream's** C++ — `src/mutex.cpp:33`,
  `src/networkfilemanager.cpp:163,167,187,2711`,
  `src/transformations/{vgridshift,hgridshift,gridshift}.cpp` — which § 9a of
  this file already records with the same evidence. No bridge file appears in
  any error, and the other five cells compiled `proj-exercise`, `proj-tests` and
  `proj-smoke`, which is what forces every public facade method to be analysed
  against the bridge.

### What is still open

* **The runtime-loading route is unchanged and still carries this boundary.**
  `-Druntime` resolves all 292 entry points through the platform loader, and
  `runtime/library.zig:748-796` checks at compile time that the dispatch routes
  exactly the names `src/proj.h` declares. Ten fork names in that table would
  fail that check, so the bridge is reached only where the C is linked; the
  helpers at `zig/root.zig:836-881` take the direct route under
  `comptime runtime_loaded`. The generated wrapper is a Zig function, so its own
  call into the loaded entry point has the same disagreement. Fixing that route
  means changing `runtime/generate.zig` and `runtime/library.zig`, which this
  slice did not own. `SOURCE-CONFIRMED`; **not observed as a run**.

---

## 13. What was deliberately *not* done, and why

* **No `zig build` gate, formatter, linter or provenance run.** The import and
  packaging sections record none: this slice read files, computed digests over
  file contents, and stopped there. The exception is § 12's repair, which was
  reproduced and re-run by this slice with the commands named beside each result;
  those runs are `OBSERVED` and belong to that section, not here.
* **No git operation of any kind.** No commit, branch, repo or remote.
* **`UPSTREAM.sha256` was not regenerated or edited.** It was already written and
  already verified. A slice that believes a file is missing from it has a finding
  to report, not a line to add.
* **No upstream file was edited**, so the per-file deviation table in `NOTICE.md`
  is empty. `sha256sum -c UPSTREAM.sha256` is what would catch a violation, and it
  has not been run by this role.
* **No licence was asserted for anything not read.** Where a document is absent —
  the EPSG terms, `LICENSE_1_0.txt` — that is recorded as an absence with a named
  next step, not filled with the nearest plausible term.
* **No sibling SDK and no top-level file was read for content or edited.** The
  template forks in `lua/` and `geographiclib-c/` were read for structure and
  honesty only; no statement in these six files is copied from them, and the two
  projects' facts are not interchangeable.