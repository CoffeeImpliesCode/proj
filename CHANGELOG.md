# Changelog

Numbered, newest last. Each entry says what changed and what it did **not**
prove.

This is the initial import. Every entry is `PENDING-VERIFICATION`: no build, test,
smoke run, cross-target check, provenance script or format run has been executed
by this wave, and no gate result is recorded anywhere in this repository. The
driver owns every gate.

Statements read out of files are marked `SOURCE-CONFIRMED` and name the file and
line they came from. Statements about the digest reproduction are marked
`OBSERVED` and say exactly what computation ran and what did not.

## 1. 2026-10-05 — initial import of PROJ 9.9.0, and this SDK around it

### The import

`OBSERVED` on 2026-10-05. Upstream release `proj-9.9.0.tar.gz` (published
2026-09-15T12:21:00Z, 6048023 bytes) was downloaded and imported whole.

| Check | Value | Compared against |
|---|---|---|
| sha256 | `791a0610547eeabb17006cfd49cdbd2034f3240f47ed5e88a1031811f4e2bcf3` | **both** the GitHub releases API `digest` field and the locally computed digest |
| md5 | `50ed234d73d68f7bf4378e9a020a40a7` | **both** the published `proj-9.9.0.tar.gz.md5` sidecar and the locally computed md5 |

The annotated tag `9.9.0` is object
`ce93bea6b5a18152b36e18c4179aae6df79a58b8`, pointing at commit
`1df2be61c0e4732aa1326126113776b291ae7657`, tagged by Kristian Evers
`<kristian@evers.dev>` at 2026-09-15T12:19:01Z.

**664 files, 40952259 bytes**, every one recorded by digest in `UPSTREAM.sha256`:
307 under `src/`, 166 under `data/`, 98 under `test/`, 31 under `scripts/`, 21
under `include/`, 14 under `cmake/`, ten root files, 8 under `man/`, 6 under
`examples/`, and the three vendored SQLite files.

**This is an archive import and the tarball carries no history.** There is no
upstream `.git` in this tree, no upstream commit as an ancestor here, and no patch
series. The tag and commit SHAs above are recorded because the GitHub releases API
reports them, and they are the way back to upstream — not as a claim that this tree
contains that history.

### The second import: the SQLite amalgamation

`OBSERVED`. `sqlite-amalgamation-3530400.zip` (2946650 bytes,
<https://www.sqlite.org/2026/sqlite-amalgamation-3530400.zip>), SHA3-256
`628a44cfe82c66aed1ccbbe85a562d2e33ebe64b3288981ed76285612227934e` matching the
value published on <https://www.sqlite.org/download.html>, sha256
`1e71ddf93849c6a6ecf58b827c0692073d2dd7ee40196158068f7b29f422e87d` computed here.

**Why it is in-tree.** `CMakeLists.txt:247` is
`find_package(SQLite3 3.11 REQUIRED)` and `src/lib_proj.cmake:610` is
`target_link_libraries(proj PRIVATE SQLite3::SQLite3)`. A system-installed default
is forbidden in this workspace and no wave slice owns sqlite3, so the dependency
is vendored rather than resolved.

**Only three files are vendored:** `vendor/sqlite3/sqlite3.c`, `sqlite3.h` and
`sqlite3ext.h`. `shell.c`, the SQLite CLI, 1185915 bytes, is **deliberately not
vendored**, and the omission is recorded in `NOTICE.md`. Upstream's own recipe
would need it — `CMakeLists.txt:232-235` makes the CLI a hard build requirement —
and this build does not use that recipe: the concatenated SQL is run through a
**host build of the amalgamation** instead, so no `sqlite3` binary is needed on any
machine.

### The build graph, the facade, the runtime route, the consumer, the fixtures

* **`build.zig` / `build.zig.zon`.** Zig 0.16, package `proj`, version `9.9.0`,
  minimum Zig `0.16.0`, no dependencies. One `addLibrary` named `proj`; `-Dlinkage`
  selects `static` (default) or `dynamic`, `-Druntime` selects the load-at-runtime
  route. Version and soname are `25.9.0` / `25`, which is what
  `CMakeLists.txt:170-171` and `src/lib_proj.cmake:572-577` say for 9.9.0.
* **The compiled closure is upstream's own**, read out of
  `src/lib_proj.cmake`: `SRC_LIBPROJ_CORE` (69 entries, `:196-264`),
  `SRC_LIBPROJ_CONVERSIONS` (8, `:143-150`), `SRC_LIBPROJ_PROJECTIONS`
  (117, `:23-139`), `SRC_LIBPROJ_TRANSFORMATIONS` (13, `:154-166`),
  `SRC_LIBPROJ_ISO19111` (23, `:170-192`) and `SRC_PROJAPPS_LIBS` — one file,
  `apps/projinfo_lib.cpp`, `src/apps/lib_projapps.cmake:1-3` — concatenated at
  `:373-380` and put in `add_library(proj …)` at `:388-390`. Nothing in those
  groups is dropped.
* **Two generated inputs**, both produced by host-run generators told the target
  they are generating for: `proj_config.h` (from `cmake/proj_config.cmake.in`)
  and `PROJ_DB_SQL_MD5.h`.
* **A typed Zig facade** at `zig/root.zig` over the same library, with the
  translated C reached from it. The translated module is registered under the
  private name `c` and is **not** published: `dep.module("c")` must not resolve.
  The published module is `dep.module("proj")`.
* **A runtime-loading route** under `-Druntime`: `dep.module("proj")` resolves to
  a generated dispatch and the module links no archive. One process-lifetime
  table, explicit path or named-system selection, no fallback, atomic publication,
  explicit retry after a failed load, and an ordinary pre-initialization panic in
  every optimize mode. Linked calls stay direct.
* **A separate consumer package** under `consumer/` that depends on this one by
  path.
* **Independent-answer fixtures** under `testdata/`, with a licence record and a
  provenance README: a Web Mercator closed-form known answer for EPSG:3857
  computed from the EPSG Guidance Note 7-2 method formula rather than from PROJ
  code; EPSG registry constants read back out of `proj.db`; and a behavioural
  boundary at EPSG:4326 → EPSG:4277, which needs a grid this package does not
  ship.
* **`tools/check-provenance.sh`**, which checks the bytes, the exact file set and
  the notices.

### Datum data

**`proj.db` is generated, not imported.** `data/proj.db` is not in the release
tarball; `data/sql/` holds 59 files of generated SQL.
`data/sql/metadata.sql:12-13` records the dataset the database is built from:
`EPSG.VERSION 'v13.102'`, `EPSG.DATE '2026-08-27'`.

**No datum-shift grid ships.** `data/CH:5-6` says it outright — "You'll need to
download the grids separately and put in a directory scanned by libproj" — and
`:20` names `CHENyx06_ETRS.gsb`. The `data/CH`, `GL27`, `ITRF2000`, `ITRF2008`,
`ITRF2014`, `ITRF2020`, `nad27`, `nad83` and `world` files are legacy `+init`
**definition** files, not grids. The vendored datum data is exactly `proj.db`,
`proj.ini`, the three `*.schema.json`, `nad.lst` and `other.extra`.

Resolution order is PROJ's own: `PROJ_DATA` first, then the deprecated `PROJ_LIB`,
then the paths set on the context — `src/filemanager.cpp:1113-1132` and
`:1718-1759`. No build-host path is embedded: `EMBED_PROJ_DATA_PATH`
(`src/lib_proj.cmake:311-314`) is not used.

### The `PROJ_DB_SQL_MD5` reproduction

`OBSERVED`, and it is a computation over file contents rather than a run of
anything generated. Concatenating the `data/sql/*.sql` files in the order
`data/sql_filelist.cmake:15-79` gives with `PROJ_DB_EXTRA_VALIDATION` **OFF**,
then removing every `INSERT INTO "metadata"` line — the rule at
`data/generate_proj_db.cmake:19-22` — then taking the MD5, yields

```
14264577 bytes
MD5 = 97f045739c534f9697ae359d4be8c95a
```

and `data/sql/proj.db.sql.expected.md5:1` contains exactly
`97f045739c534f9697ae359d4be8c95a`. Equality holds, which is upstream's own
consistency rule (`data/generate_proj_db.cmake:32-48`).

What it proves: the imported SQL is complete, untruncated and in the right order.
What it does not prove: **no `sqlite3` CLI ran, no `proj.db` was produced, no
database was opened and nothing was downloaded.** `proj.db` is
`PENDING-VERIFICATION`.

### Licence and provenance records

Added `README.md`, `README.zig.md`, `UPSTREAM.md`, `UPSTREAM.sha256`,
`NOTICE.md`, `FORK-LICENSE.md`, `FORK-NOTES.md`, this file and
`tools/check-provenance.sh`.

* **No upstream file was modified.** 664 entries in `UPSTREAM.sha256`, all of
  them upstream digests and none of them a fork digest. The per-file deviation
  table in `NOTICE.md` is empty, and that emptiness is the machine-checkable
  form of the claim.
* **PROJ's term is MIT-style** — `COPYING:2-3` covers "All source, data files and
  other contents of the PROJ package", and `COPYING:14` says "Copyright information
  can be found in source files", which is why `NOTICE.md` is a per-file inventory
  rather than a single label.
* **The tree holds six other terms besides MIT**, each named by file and line:
  Apache-2.0 in five files; GPL-2.0-or-later **with the Bison special exception**
  in four; BSD-3-Clause inside `src/projections/polyhedral/snyder.h`; Boost-1.0 in
  three `cmake/` modules; MIT/X11 from Charles F. F. Karney in `src/geodesic.{c,h}`;
  and SQLite's public-domain blessing in the three vendored files plus
  `src/memvfs.c`.
* **One obligation is recorded as an open item, not as a licence.** The EPSG
  Geodetic Parameter Dataset's terms of use are **not in the tarball**; a search
  of all 664 files found the dataset named only as data and never with a terms
  text. `NOTICE.md` asserts no licence for it and records that the terms must be
  obtained from IOGP/EPSG before any redistribution of `proj.db`.
* **This fork's own files are MIT** under the owner's per-project authorization,
  with the full grant, the authority and the limits in `FORK-LICENSE.md`. No
  individual copyright holder is named and no upstream authorship of fork code is
  claimed.

### Not verified

Everything requiring a compiler, a toolchain or a runtime. No `zig build`, no
`zig build test`, no `zig build smoke`, no `zig build check`, no
`zig build consumer`, no `cd consumer && zig build run`, no `cross-test`, no `nix
build`, no `devenv`, and no execution of `tools/check-provenance.sh`. `proj.db` has
not been generated. The `.fingerprint` value has not been observed.

`tools/check-provenance.sh` is delivered as source and has never been executed.
The provenance claim it exists to check rests, at this moment, on the recorded
digests and on the digests having matched at import — which is an observation
about bytes, not a gate.

## 2. 2026-10-05 — three failing behavioural fixtures, diagnosed and corrected

### What was wrong, and which side was fixed

`zig build test` reported `4 pass, 3 fail`. None of the three was a bug in the
compiled C; two were a facade defect and one was an assertion that stated the
opposite of its own comment.

1. **`fixture A, second leg`** failed with `swapped input is not the same answer:
   expected 426857.98771728170000000, got 6278533.30711677400000000, tolerance 0`.
   The assertion was `expectNumberNear(by_authority.v[0], mixed.v[0], 0.0, …)`,
   which asks for **equality**: `std.math.approxEqAbs(x, y, 0.0)` is `x == y`
   fast-path plus `abs(x - y) <= 0` (`lib/std/math.zig:76-88`). The comment three
   lines above it says the two answers *must not* match — "It is 47 degrees away in
   latitude, which no rounding could explain" — and the library agrees with the
   comment: longitude 49, latitude 2 through EPSG:32631 is a different point.
   **Expectation fixed**: a separate `expectNumberDifferent` was added, because a
   tolerance of zero on a near-assertion reads as equality at every call site.

2. **`fixture B`** failed because `Object.datum()` answered null for `EPSG:4326`.
   That is upstream's own answer, not a gap. `EPSG:4326` is bound in this
   package's own `proj.db` to the **datum ensemble** `EPSG:6326` — the row is
   named "World Geodetic System 1984 ensemble", carries `ensemble_accuracy = 2.0`
   and has eight rows in `geodetic_datum_ensemble_member` — so the factory takes
   the ensemble branch (`src/iso19111/factory.cpp:4960-4977`, `:5538-5541`) and
   `proj_crs_get_datum` returns NULL for want of a datum
   (`src/iso19111/c_api.cpp:8808-8811`, `:8793-8794`). Upstream's own test asserts
   exactly this shape for `EPSG:4326` (`test/unit/test_factory.cpp:568-571`).
   **Both sides were wrong and both were fixed**: the facade's doc comment on
   `datum()` claimed "or its datum ensemble as a datum-like object", which is
   upstream's *other* function; and `proj_crs_get_datum_forced`
   (`src/proj.h:1447`), the entry point upstream provides for exactly this case
   (`src/iso19111/c_api.cpp:8951-8956`), was not bound at all. `datumForced` is
   added and the fixture reads the registry through it. The two Fixture B numbers
   did not change: a = 6378137 m and 1/f = 298.257223563, EPSG ellipsoid 7030.

3. **`fixture C`** failed with `expected error.NullReturn, found …PJconsts`. Two of
   its claims were wrong about the C.
   * **`ONLY_BEST=YES` does not make the constructor fail.** Upstream's own
     release note is "With ONLY_BEST=YES a transformation will fail if a needed
     grid is unavailable" (`NEWS.md:751`) — a transformation, not a construction.
     `proj_create_crs_to_crs_from_pj` answers NULL only when the factory left one
     candidate and it is not instantiable (`src/crs_to_crs.cpp:617-641`,
     `:758-769`); for `EPSG:4326` to `EPSG:4277` several survive, the object is
     built as the "Set of coordinate operations" shell
     (`src/crs_to_crs.cpp:783-795`), and `proj_trans` does the refusing by warning
     about the missing grid and setting `PROJ_ERR_COORD_TRANSFM_NO_OPERATION`
     (`src/trans.cpp:289-294`). The fixture now asserts that refusal and that code.
   * **A finite coordinate here is not a fault, and it is not a ballpark.** The
     fixture required the used operation to declare itself a ballpark
     substitution. The default route instead picks "Inverse of OSGB36 to WGS 84
     (6)", a seven-parameter Helmert that needs **no** grid at all and is honestly
     not a ballpark. The replacement assertion is the one the boundary actually
     turns on: the operation PROJ names as the one it used
     (`proj_trans_get_last_used_operation`, `src/proj.h:630`) must list no grid
     this build cannot reach — upstream's own `out_available`, `src/proj.h:1533` —
     and must be instantiable as it reports itself (`src/proj.h:1503-1504`).
   * Part one still holds and now says what it holds under: a factory that
     discards missing-grid operations and refuses ballpark substitutions returns
     zero for this pair **under its default spatial criterion**,
     `PROJ_SPATIAL_CRITERION_STRICT_CONTAINMENT` (`src/proj.h:1003`), whereas
     `proj_create_crs_to_crs_from_pj` asks for
     `PROJ_SPATIAL_CRITERION_PARTIAL_INTERSECTION` (`src/crs_to_crs.cpp:568-569`).
     Both answers were observed on this machine: 0 operations under strict
     containment, 7 under partial intersection, with the other two settings held
     constant. That difference is why parts two and three find operations at all.

### A facade defect the fixtures did not name

`Object.name()` aborted the process on a NULL that upstream documents as an
answer. `maybeSpan` took `[:0]const u8`, and a translated `const char *` arrives
as `[*c]const u8`; handing that to a sentinel-slice parameter makes the compiler
insert a **non-null check at the call site**, so the `@intFromPtr(ptr) == 0` test
inside the body was unreachable. `proj_get_name` answers NULL for the
"Set of coordinate operations" object, whose `iso_obj` is nulled
(`src/crs_to_crs.cpp:783-795`), and upstream says so
(`src/iso19111/c_api.cpp:1516-1519`). Observed as
`thread … panic: cast causes pointer to be null`. `maybeSpan` and `copyString` now
take the translated pointer type `[*c]const u8`, which is the same type the
call site passes and therefore coerces to nothing. An optional pointer parameter
was tried first and is **not** a fix: `?[*c]const u8` holding address zero is a
present value wrapping a null pointer, `orelse` does not fire, and
`std.mem.span` asserts on it.

### Two programs with the same `setNetworkEnabled` mistake

`smoke.zig` and `consumer/src/main.zig` both tested the **return value** of
`Context.setNetworkEnabled(false)` as if it were an acceptance flag. It is not:
`proj_context_set_enable_network` answers what the network was *before* the
request (`src/proj.h:555`), and both programs run with the network already off, so
the answer is false and the program failed itself. `tests.zig` already had this
right; both now read `networkEnabled()` back instead. `smoke.zig` also printed
`EPSG:EPSG:4326` and `consumer` printed `registry: EPSG:EPSG:4326`, because
`idAuthName(0)` already returns `"EPSG"`; the literal prefix is gone.

### Gate results observed here

`OBSERVED` on 2026-10-05, native `x86_64-linux-gnu`, Debug, Zig 0.16.0 at
`$ZIG_GLOBAL_CACHE_DIR/p/N-V-__8AAFFSVRWqblwBIcA-Yqv-u7sbjsJoww8K0mWaHbmJ/zig`,
`--cache-dir $HOST_SCRATCH_ROOT/cache/foundation-libs/wave10/proj -j8`. Receipts
are in `$HOST_SCRATCH_ROOT/scratch/foundation-libs/wave10-proj/`.

| Command | Exit | Receipt |
|---|---|---|
| `zig build` | 0 | `proj-build.log` |
| `zig build test` | 0 | `proj-test-3.log`, `7/7 tests passed` |
| `zig build smoke` | 0 | `proj-smoke5.log` |
| `zig build test -Doptimize=ReleaseSafe` | 0 | `proj-test-releasesafe.log`, `7/7 tests passed` |
| `zig build check` | **1** | `proj-check.log`, `55/60 steps succeeded (1 failed)` |

`zig build test` before the corrections is `proj-test-1.log`: `4 pass, 3 fail
(7 total)`. `proj-test-2.log` is a compile error of an intermediate edit and is
kept only so the sequence is not hidden.

### The failing `check` row, and why it is a boundary

**One target of six fails: `wasm32-wasi`.** The other five
(`x86_64-linux-gnu`, `aarch64-linux-gnu`, `aarch64-macos-none`,
`x86_64-windows-gnu`, `riscv64-linux-gnu`) compiled all three rows —
`proj-exercise`, `proj-tests`, `proj-smoke` — against the full archive. The
failure is in the **C++ library**, before any Zig of ours is reached:
`compile lib proj-wasm32-wasi … 21 errors`, in
`src/mutex.cpp:33`, `src/transformations/{vgridshift,hgridshift,gridshift}.cpp`,
`src/networkfilemanager.cpp:163,167,187,2711`,
`src/apps/projinfo_lib.cpp:343,345` and `src/iso19111/factory.cpp:625,654,662`.
Three causes, only one of which is configuration:

* `std::mutex` and `std::recursive_mutex` do not exist. libc++ for `wasm32-wasi`
  has no threads, so `<mutex>` does not declare them.
* `std::ifstream` and `std::fstream` are declared but undefined — the toolchain
  ships only `libcxx/include/__fwd/fstream.h`.
* `getpid` is deprecated on WASI; the compiler names the fix, `-D_WASI_EMULATED_GETPID`
  with `-lwasi-emulated-getpid`.

Only the third is reachable from the build graph, and adding it alone changes no
outcome: the target still fails on the other two. The first two would need either
a wasi libc++ with threads and file streams, or edits to vendored upstream C++.
**No upstream file was edited**, and the target is still checked rather than
dropped. This is an explicit platform boundary, recorded as `SYMPTOM` until a
cause in the toolchain or an owner-authorised upstream patch is established; it
is not a claim that PROJ cannot target WASI.

### Not verified

`zig build consumer`, `cd consumer && zig build run`, `zig build provenance`,
`tools/check-provenance.sh`, `cross-test`, the 53-platform matrix, `nix build`
and `devenv` were not run. The database
arrangement is unchanged and still asserted: `proj_config.h` per target from
`proj-config-gen`, and `proj.db` plus `PROJ_DB_SQL_MD5.h` once per build from
`proj-db-gen` over `data/sql` in `data/sql_filelist.cmake` order, whose
`all.sql.in` MD5 `97f045739c534f9697ae359d4be8c95a` matched
`data/sql/proj.db.sql.expected.md5` on every run above. The verification table at
the end of `README.zig.md` is left `PENDING-VERIFICATION`: moving it is the
driver's edit beside its own observed run, not this entry's.

No upstream file was modified. `UPSTREAM.sha256` still holds 664 upstream
digests, the per-file deviation table in `NOTICE.md` is still empty, and
`tools/check-provenance.sh` remains unexecuted.

## 3. 2026-10-06 — the by-value `PJ_COORD` boundary, repaired in fork-owned C

### What was wrong

`SOURCE-CONFIRMED`. Upstream declares `union PJ_COORD` at `src/proj.h:315-330`
— 32 bytes, `double v[4]` — and moves it **by value** in and out of ten entry
points: `src/proj.h:629` `proj_trans`, `:656` `proj_coord`, `:663`
`proj_lp_dist`, `:666` `proj_lpz_dist`, `:669` `proj_xy_dist`, `:672`
`proj_xyz_dist`, `:676` `proj_geod`, `:705` `proj_geod_direct`, `:783`
`proj_factors`, `:1426-1429` `proj_get_suggested_operation`. `src/proj.h:65-71`
states that this is deliberate.

The facade called seven of them straight through the translation:
`zig/root.zig:996` `c.proj_coord`, `:1035` `c.proj_xy_dist`, `:1041`
`c.proj_xyz_dist`, `:2062` `c.proj_trans`, `:2204` `c.proj_lp_dist`, `:2216`
`c.proj_factors`, `:2654` `c.proj_get_suggested_operation`.

**The two sides of that call disagreed about where the union goes.** `OBSERVED`
by disassembly on 2026-10-06: the C compiler that builds this archive classifies
the 32-byte union as a four-element floating-point aggregate and passes and
returns it in four consecutive SIMD registers — `objdump -d` of `proj_coord` for
`aarch64-linux` is a single `ret`, `d0`-`d3` in and `d0`-`d3` out. Zig 0.16.0
lowers the same call to memory: the caller sets `x8` to a result slot
(`add x8, sp, #0x10`) and reads the answer back with `ldr q0, [sp, #16]`, a slot
the callee never wrote. The trigger is the **union**, not the size: on
`aarch64-linux` a `struct { double a, b, c, d; }` crosses correctly from Zig and
`union { double v[4]; }` — the same 32 bytes of the same four doubles — does not.

`OBSERVED` symptom: Fixture A reported `4865942.279503176` where
`tests.zig:265-266` records `x_m = -8348961.809495518` and
`y_m = 4865942.279503176` for the same point — the coordinate came back with its
words displaced. A C program against the same `libproj.a` for the same target
returned both numbers correctly, so neither the vendored library nor QEMU was at
fault.

### What changed, and what did not

* **Added `zig/proj_abi.h` and `zig/proj_abi.c`**, fork-authored. Each body is
  the call upstream writes — the aggregate goes and comes back by value — and
  only a pointer, a `double` and an `int` come back out, so both halves of every
  by-value call are produced by one compiler.
* **`build.zig:1739`** puts that one translation unit on the same compile line
  as upstream's, so the bridge is in `libproj.a` and in `libproj.so` alike.
* **`zig/root.zig:825-881`** declares the bridge and reaches it through
  `makeCoord`, `transformCoord`, `lpDistance`, `xyDistanceBetween`,
  `xyzDistanceBetween`, `pointFactors` and `suggestionIndex`;
  `zig/root.zig:1092`, `:1131`, `:1137`, `:2166`, `:2308`, `:2320` and `:2758`
  are the seven call sites. A `comptime runtime_loaded` branch keeps the direct
  route in a runtime-loading build — see the boundary below.
* **No upstream file was edited.** `src/` is byte for byte as imported, and
  `zig build provenance` observed all 664 recorded digests still matching.

### Observed after the change

Every cell is `zig build test -Dtarget=<T> -j8 --summary all`, executed by the
build runner under the QEMU the matrix uses. Exit code as returned by the
command, and the summary line as printed.

| Target | exit | Build Summary |
|---|---|---|
| `aarch64-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |
| `aarch64_be-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |
| `arm-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |
| `armeb-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |
| `loongarch64-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |
| `mips64-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |
| `mips64el-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |
| `powerpc-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |
| `powerpc64-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |
| `powerpc64le-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |
| `s390x-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |
| `thumb-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |
| `thumbeb-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |
| `x86_64-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |
| `riscv64-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |
| `riscv32-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |
| `mips-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |
| `mipsel-linux` | 0 | 16/16 steps succeeded; 7/7 tests passed |

`x86-linux` is reported separately, because `zig build test -Dtarget=x86-linux`
on its own cannot run it and that is not a test result: the build runner refuses
with `the host system is unable to execute binaries from the target … the host
dynamic linker is '/lib64/ld-linux-x86-64.so.2', while the target dynamic linker
is '/lib/ld-musl-i386.so.1'`. That is the foreign-runner seam `cross-test`
patches (`cross-test:389`). Run by hand under `qemu-i386` the binary printed
`All 7 tests passed.` and exited 0.

`zig build smoke -Dtarget=aarch64-linux` exits 0 and prints
`40N 75W  ->  -8348961.809 E, 4865942.280 N  (EPSG:4326 -> EPSG:3857)`, where
before the change the same command printed `0.000 E, 0.000 N`.

Host gates, host target, `--prefix` on approved scratch: `zig build` exit 0
(39/39 steps); `zig build test` exit 0 (16/16 steps, 7/7 tests);
`zig build test -Doptimize=ReleaseSafe` exit 0 (16/16 steps, 7/7 tests);
`zig build smoke` exit 0 (15/15 steps); `zig build consumer` exit 0 (15/15
steps); `zig build provenance` exit 0 (2/2 steps, "provenance checks passed").

`zig build check` exit 1, `55/60 steps succeeded (1 failed)`. The one failure is
`wasm32-wasi` and it is **upstream's own C++**, in `src/mutex.cpp:33`,
`src/networkfilemanager.cpp:163,167,187,801,1016,1055,2711` and
`src/transformations/{vgridshift,hgridshift,gridshift}.cpp` — 21 errors, of
which the first kind is `no type named 'recursive_mutex' in namespace 'std'` and
the last is `getpid is deprecated: WASI lacks process identifiers`. That is the
boundary entry 2 of this changelog already recorded, with the same file and line
evidence, and no bridge file appears in any of the errors. The other five cells
of the matrix — `x86_64-linux-gnu`, `aarch64-linux-gnu`, `aarch64-macos-none`,
`x86_64-windows-gnu`, `riscv64-linux-gnu` — compiled `proj-exercise`,
`proj-tests` and `proj-smoke`, so every public facade method reaches the bridge
and compiles on all of them.

### Not verified

**The full `cross-test` 53-platform matrix was not run by this slice.** The
nineteen rows above are `zig build test` per target, which is a different
command with a different runner and a different prefix discipline.

**The runtime-loading route is unchanged and still carries this boundary.**
`-Druntime` resolves the 292 entry points through the platform loader, and
`runtime/library.zig:748-796` checks at compile time that the dispatch routes
exactly the names `src/proj.h` declares; ten fork names in that table would fail
that check, so `runtime/generate.zig` and `runtime/library.zig` would both have to
change and neither was in this slice's scope. `SOURCE-CONFIRMED`, **not observed
as a run**.