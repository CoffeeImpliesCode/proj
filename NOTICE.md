# Notice

A per-file record of who owns what in this repository and under which terms.

Written by this fork. It is not upstream's file and no licence in the tree
requires it. The obligation it meets is this workspace's own rule that material
is licensed by its own file rather than by the licence of the most prominent file
beside it — which in **this** tree is not a formality, because the tree holds
seven distinct terms and one material whose terms are absent.

Every entry below is `SOURCE-CONFIRMED`: it was read out of a named file at a
named line range in this tree. Nothing here is inherited from a sibling SDK's
record.

## The upstream term

`COPYING` is PROJ's own statement, 1784 bytes, and it is not a bare licence
label. `COPYING:2-3` reads:

> All source, data files and other contents of the PROJ package are available
> under the following terms.

`COPYING:4-12` records the history: PROJ 4.3 and earlier "public domain", Frank
Warmerdam moved everything under "this MIT style license because he believed it
is effectively the same as public domain", and "Essentially all work was done by
Gerald Evenden".

The load-bearing sentence is `COPYING:14`:

> Copyright information can be found in source files.

**That is an instruction, not a summary.** It is why this inventory is per-file
and long, and why it cannot be collapsed into "PROJ is MIT". The grant text is
`COPYING:16-34` — the standard three-clause MIT permission and warranty
disclaimer. `COPYING` is byte-identical to the tarball's and its digest is in
`UPSTREAM.sha256`.

## Inventory of the upstream files

664 files, 40952259 bytes, digests in [`UPSTREAM.sha256`](UPSTREAM.sha256).

Scoped to the **compiled tree** — the 328 files under `src/` and `include/`,
read one by one:

| Term | Files | Where |
|---|---:|---|
| MIT grant text in the file (`Permission is hereby granted`) | 146 | throughout `src/` and `include/` |
| Apache-2.0 in the file | 5 | `include/proj/nn.hpp`, `src/sphere.h`, `src/projections/polyhedral.cpp`, `src/projections/polyhedral/snyder.h`, `src/projections/patterson.cpp` |
| GPL-2.0-or-later **with the Bison special exception** | 4 | `src/wkt1_generated_parser.{c,h}`, `src/wkt2_generated_parser.{c,h}` |
| SQLite's public-domain blessing | 1 | `src/memvfs.c` |
| No notice in the file | 174 | the rest of `src/` and `include/` |

Over the whole 664-file tree the same scan finds 186 files carrying MIT-style
text, 3 files carrying the Boost Software License, and 4 carrying SQLite's
blessing (the three vendored files plus `src/memvfs.c`).

**462 of the 664 files carry no licence notice of their own.** They are covered
by `COPYING`'s package-wide statement at `COPYING:2-3`. That blanket is upstream's
own, and this file leans on it only where it applies — which is nowhere near the
files that carry a second notice.

### The per-file copyright lines inside the MIT core

Counted by scanning each of the 328 `src/` + `include/` files for the holder's
name. These are the counts **in the compiled tree**; they are attribution lines
inside otherwise-MIT files, not separate grants:

| Holder | Files | Where they concentrate |
|---|---:|---|
| Even Rouault (`even dot rouault at spatialys dot com`, `even.rouault at spatialys.com`, `even.rouault at spatialys dot com`, and the 2013 `mines-paris dot org` form) | 97 | `src/iso19111/`, `src/transformations/`, `include/proj/`, `src/apps/` |
| Thomas Knudsen / SDFE | 24 | `src/projections/`, `src/conversions/`, `src/transformations/` |
| Frank Warmerdam | 16 | the core `.cpp` units, `src/apps/proj.cpp`, `man/man1/proj.1` |
| Felix Palmer | 15 | `src/projections/` (the A5-derived polyhedral work), `src/sphere.h`, `src/vec3.h` |
| Gerald Evenden (both the `Gerald Evenden` and `Gerald I. Evenden` spellings) | 11 and 8 | the original projection and transform kernels: `src/fwd.cpp`, `src/inv.cpp`, `src/gauss.cpp`, `src/ell_set.cpp`, `src/init.cpp`, `src/malloc.cpp`, `src/proj_mdist.cpp` |
| Kristian Evers / SDFE | 8 | `src/transformations/`, `src/conversions/`, `src/projections/`, `src/proj.h` |
| Charles F. F. Karney | 6 | `src/geodesic.c`, `src/geodesic.h`, `src/tests/`, `src/malloc.cpp` |
| Javier Jimenez Shaw | 5 | `src/latitudes.cpp`, `src/projections/`, `src/apps/` |
| Bojan Savric | 5 | `src/projections/` (the Patterson family) |
| Thomas Flemming, `tf@ttqv.com` | 2 | `src/projections/healpix.cpp:11`, `src/projections/krovak.cpp:5` and `:8` |

Two spellings of the same contributor name coexist (`Kristian Evers` and
`Kristian Evers / SDFE`; `Thomas Knudsen` and `Thomas Knudsen / SDFE`), as do two
year-range styles for Gerald Evenden. Those are upstream's, they are not
normalised here, and a reader who greps for one string and finds variants has
found upstream's tree rather than a defect introduced by this fork.

`AUTHORS.md:1-33` names the same people from upstream's side: Gerald Evenden as
"Original Author"; Kristian Evers and Even Rouault as maintainers; and a Project
Steering Committee list that includes Frank Warmerdam, Howard Butler, Charles
Karney, Thomas Knudsen, Even Rouault and Kurt Schwehr. `AUTHORS.md:32-33`
points at the full contributor list on GitHub, which this tree does not vendor.

### Files outside `src/` and `include/` that carry their own notice

* **`cmake/ProjVersion.cmake:1-7`** — Boost Software License, Version 1.0.
  Copyright (C) 2010 Mateusz Loskot `<mateusz@loskot.net>`.
* **`cmake/ProjUtilities.cmake:1-13`** — Boost Software License, Version 1.0.
  "Based on BoostUtilities.cmake from CMake configuration for Boost".
  Copyright (C) 2007 Douglas Gregor, (C) 2007 Troy Straszheim, (C) 2010 Mateusz
  Loskot.
* **`cmake/ProjConfig.cmake:1-9`** — Boost Software License, Version 1.0.
  Copyright (C) 2010 Mateusz Loskot.
* **`cmake/FileEmbed.cmake:1-3`** — "Derived from
  <https://gitlab.com/jhamberg/cmake-examples/-/blob/master/cmake/FileEmbed.cmake>",
  "MIT licensed", "Copyright (c) 2022 Jonathan Hamberg". The file states the
  term and the origin in three lines and carries no full MIT text.
* **`src/memvfs.c:1-11`** — "Derived from
  <https://www.sqlite.org/src/doc/tip/ext/misc/memvfs.c>", then SQLite's blessing.
* **`src/transformations/tinshift_iface.hpp:1-10`,
  `src/transformations/tinshift_gpkg.hpp:1-10`,
  `src/transformations/tinshift_gpkg.cpp:1-10`** — the only three upstream files
  in this tree that carry an SPDX tag. All three read
  `SPDX-License-Identifier: MIT` with
  `Copyright (c) 2025, Even Rouault, <even.rouault at spatialys.com>`.
  `scripts/build_db_from_iau.py:2` and
  `scripts/build_wgs84_realizations_concatenated_operations.py:12` carry the same
  tag. **That is upstream's convention, not a rule this fork extends**: nothing
  else in the tree has an SPDX tag and none is added to an upstream file.

## The per-file exceptions

Seven items. Each one changes what a downstream must do.

### 1. The four Bison-generated parsers — GPL-2.0-or-later with the Bison special exception

| File | Bison notice | PROJ notice |
|---|---|---|
| `src/wkt1_generated_parser.c` | `:1-32` | `:75-100`, MIT, `Copyright (c) 2013-2018 Even Rouault, <even.rouault at spatialys.com>` |
| `src/wkt1_generated_parser.h` | `:1-32` | — |
| `src/wkt2_generated_parser.c` | `:1-32` | `:75-100`, MIT, Even Rouault, as above |
| `src/wkt2_generated_parser.h` | `:1-32` | — |

The Bison block is `GNU Bison 3.5.1`. `:5-6` names the holder: "Copyright (C) 1984,
1989-1990, 2000-2015, 2018-2020 Free Software Foundation, Inc." `:8-11` grants
"either version 3 of the License, or (at your option) any later version" — so
**GPL-2.0-or-later**, and the files say so themselves rather than being inferred.

`:21-29` is the exception, and it is the whole reason these four files are not a
licensing problem for a downstream:

> As a special exception, you may create a larger work that contains part or all
> of the Bison parser skeleton and distribute that work under terms of your
> choice, so long as that work isn't itself a parser generator using the skeleton
> or a modified version thereof as a parser skeleton.

**What it means concretely.** A downstream that links this library may keep its
own terms for the surrounding work. The exception bites in two ways, and both are
in the text: the surrounding work must not itself be a parser generator built on
the skeleton, and a downstream that modifies or redistributes the skeleton
*itself* may, at its option, remove the exception — at which point the skeleton
and the resulting Bison output files revert to plain GPL.

Note the second column of the table: the two `.c` files carry BOTH notices. They
are a Bison skeleton with PROJ's own header embedded further down. All four are
**compiled into the library** — the `.c` files are entries in `SRC_LIBPROJ_CORE`
and the `.h` files sit beside them. `src/lib_proj.cmake:274-275` names both `.c`
files in `SKIP_UNITY_BUILD_FILES`, so upstream excludes them from a unity build;
the two `.h` files are headers and are not translation units.

### 2. The five Apache-2.0 files

Each carries its own Apache-2.0 header with its own copyright, and each is a
different derivation:

| File | Lines | Holder | Origin stated in the file |
|---|---|---|---|
| `include/proj/nn.hpp` | `:3-17` | Dropbox, Inc. | `Copyright (c) 2015 Dropbox, Inc.` — no derivation stated |
| `src/sphere.h` | `:15-28` | A5 contributors | `:10-11` "Derived from A5 (Apache-2.0). <https://github.com/felixpalmer/a5>"; `:13` names the origin file `modules/utils/vector.ts` |
| `src/projections/polyhedral.cpp` | `:7-22` | A5 contributors | `:7-8` the same A5 origin |
| `src/projections/polyhedral/snyder.h` | `:1-25` **and** `:26-56` | A5 contributors **and** Ecere Corporation | Apache-2.0 for the A5 part; `:26-28` "Derived from DGGAL (BSD 3-Clause License)", `Copyright (c) 2014-2025, Ecere Corporation` |
| `src/projections/patterson.cpp` | `:1-15` | Bojan Savric | `Copyright (c) 2014 Bojan Savric`; `:17-34` records Tom Patterson's 2014 design, the JMapProjLib Java reference and two bibliographic references |

`snyder.h` is the one that is easy to miss and would be wrong to reduce to a
single label: it is **two notices in one file**, Apache-2.0 at `:8-24` and a
complete BSD 3-Clause text with all three conditions and the disclaimer at
`:26-55`. It also cites a third source at `:58-59`,
<https://brsr.github.io/2021/08/31/snyder-equal-area.html>, with no stated term.

**What Apache-2.0 requires of a downstream, and what this package does about it.**
The three obligations are a `NOTICE` file, a statement of which files were
changed, and the patent-grant termination clause. All three are recorded here:

* **The licence text.** The tarball ships **no `LICENSE-APACHE` file**. A search
  of the whole 664-file tree finds no file by that name; the only file matching
  `LICENSE*` or `COPYING*` is `COPYING`, and `COPYING` is MIT. The authoritative
  Apache-2.0 text for these five files is therefore the one each file quotes in
  its own header, and **it travels with the file** — which is why these files are
  preserved byte for byte and digested.
* **Changes.** `UPSTREAM.sha256` records the shipped digest of all five, and
  every digest matches the tarball. **This package changes none of the five.** A
  downstream that modifies one must say so, in the Apache-2.0 way, and must
  re-run the provenance check.
* **Patent grant and its termination.** Apache-2.0 §3 grants a licence over
  patent claims and terminates that grant, for any contributor, on that
  contributor's initiation, if that contributor brings a patent litigation
  alleging that the work constitutes direct or contributory patent
  infringement. Nothing in this package narrows, waives or extends that clause;
  it passes through with the terms.
* **The notice must travel.** Apache-2.0 is permissive, but the obligation to
  carry the notice is not optional. A consumer who receives only
  `libproj.a`/`libproj.so.25` still owes Dropbox, the A5 contributors, Ecere
  Corporation and Bojan Savric their notices. `NOTICE.md` is the file that carries
  them, and `FORK-LICENSE.md` names what installs it.

### 3. `src/vec3.h` — MIT, derived from gl-matrix

`src/vec3.h:1-30`. `:8-11`: "Derived from gl-matrix (MIT License). / gl-matrix:
Copyright (c) 2015-2021, Brandon Jones, Colin MacKenzie IV. /
<https://github.com/toji/gl-matrix>", followed by the full MIT text at `:13-29`.
Same term as PROJ's own, different holder — recorded because the holder is a third
party and because a reader grepping for PROJ's copyright holders would not find
it.

### 4. `include/proj/internal/vendor/nlohmann/json.hpp` — MIT, vendored third-party

`:1-27`. The header identifies itself as `JSON for Modern C++ version 3.9.1`,
`Licensed under the MIT License <http://opensource.org/licenses/MIT>`,
`SPDX-License-Identifier: MIT`,
`Copyright (c) 2013-2019 Niels Lohmann <http://nlohmann.me>`, followed by the
full MIT grant at `:11-27`.

This is bundled third-party material **inside a compiled header**. It is reached
through `include/proj/internal/include_nlohmann_json.hpp:36-45`, which either
includes `<nlohmann/json.hpp>` (under `EXTERNAL_NLOHMANN_JSON`) or falls through
to the vendored copy. `include/proj/internal/include_nlohmann_json.hpp:43` also
does `#define nlohmann proj_nlohmann` "to avoid any clash if PROJ users have
another version of nlohmann/json.hpp" — an upstream decision, recorded here
because it is the reason the vendored copy is namespaced.

`CMakeLists.txt:199-226` is the switch: `NLOHMANN_JSON_ORIGIN` defaults to `auto`
(`:193`), and `auto` resolves to `internal` whenever no external package is found
(`:206-212`) or an external one is older than 3.7.0 (`:217-220`). **This build
takes the `internal` path**, so the vendored header is what compiles.

One further holder appears inside the vendored file and is recorded rather than
folded in: `include/proj/internal/vendor/nlohmann/json.hpp:14365` reads "The code
is distributed under the MIT license, Copyright (c) 2009 Florian Loitsch" — a
component nlohmann carries inside its own file, in nlohmann's file, under nlohmann's
own statement. This package asserts nothing about it beyond repeating what the
file says.

### 5. `src/geodesic.h` and `src/geodesic.c` — MIT/X11, Charles Karney

* `src/geodesic.h:1-20`. The copyright is at `:17-19`: "Copyright (c) Charles
  Karney (2012-2022) `<karney@alum.mit.edu>` and licensed under the MIT/X11
  License. For more information, see <https://geographiclib.sourceforge.io/>".
* `src/geodesic.c:1-24`. The copyright is at `:21-23`: "Copyright (c) Charles
  Karney (2012-2025) `<karney@alum.mit.edu>` and licensed under the MIT/X11
  License."

**The two files carry different year ranges**, `(2012-2022)` in the header and
`(2012-2025)` in the implementation. That is upstream's own inconsistency, it is
not normalised here, and a reader who greps for one range and misses the other
has found upstream's tree.

Two facts a consumer needs that the notice alone does not carry:

* **This is the same upstream project as this workspace's `geographiclib-c` SDK.**
  PROJ's copy and the standalone C project are two imports of Charles F. F.
  Karney's geodesics. They are separately versioned, separately pinned and
  separately digested; neither imports the other, and this package does not
  require a sibling.
* **The compiled naming depends on a macro this build does not set.** PROJ
  compiles `src/geodesic.c` here without `PROJ_RENAME_SYMBOLS`, so the `geod_*`
  symbols are exported under those names. A PROJ build that *does* define
  `PROJ_RENAME_SYMBOLS` routes them through `src/proj_symbol_rename.h` — which
  `src/proj.h:127-129` includes only under that macro — and exports
  `internal_proj_*`-style names instead. That is a different ABI family, not a
  build variation of this one.

Both files are compiled: `geodesic.h` is in `HEADERS_LIBPROJ`
(`src/lib_proj.cmake:284-290`) and `src/lib_proj.cmake:409-418` applies
`-fp-model precise` to `geodesic.c` alone for Intel and MSVC, which is a sign
upstream considers its floating point load-bearing.

### 6. `vendor/sqlite3/` — SQLite's public-domain blessing, not MIT

| File | Blessing | Other notice in the file |
|---|---|---|
| `vendor/sqlite3/sqlite3.h` | `:1-32`, at `:4-10` | — |
| `vendor/sqlite3/sqlite3.c` | `:1-24` opening, blessing at `:32-41` | `:20-21` records the Fossil check-in the amalgamation came from: `bf7c7f30031888f4e796e429ab3978879485` |
| `vendor/sqlite3/sqlite3ext.h` | `:1-17`, blessing at `:4-10` | — |

The text is the same in all three:

> The author disclaims copyright to this source code. In place of a legal
> notice, here is a blessing:
>
> May you do good and not evil.
> May you find forgiveness for yourself and forgive others.
> May you share freely, never taking more than you give.

**This is not MIT and is not described as MIT here.** It is a dedication of the
copyright — the strongest grant the three terms in this tree provide, and the one
with the fewest obligations. The blessing is a courtesy in place of a legal
notice; it is not a licence with conditions to satisfy. What it does not do is
carry the SQLite name into an attribution obligation, and this file therefore
records it as a dedication rather than as a notice a consumer must reproduce.

`vendor/sqlite3/sqlite3.c:1-18` also states what the amalgamation is and what it
is not: "This file contains only code for the core SQLite library", and "The code
for the 'sqlite3' command-line shell is also in a separate file."

**`shell.c` is deliberately not vendored.** The zip carries it at 1185915 bytes;
this package ships `sqlite3.c`, `sqlite3.h` and `sqlite3ext.h` and nothing else.
The reason is in [`UPSTREAM.md`](UPSTREAM.md): upstream's `proj.db` recipe shells
out to the CLI binary, and this build runs the same script through a host build of
the amalgamation instead, so no CLI is needed on any machine.

### 7. `src/memvfs.c` — SQLite's blessing, inside PROJ's own tree

`src/memvfs.c:1-11`. Line 1 states the origin —
"Derived from <https://www.sqlite.org/src/doc/tip/ext/misc/memvfs.c>" — and lines
2-11 carry the same blessing, dated 2016-09-07.

This one is **not compiled by this package**: `src/lib_proj.cmake:516-519` adds
`memvfs.c` to the `proj` target only under `EMBED_RESOURCE_FILES`, and this build
does not set that. It is retained, uncompiled, unmodified. It is listed as a
distinct item rather than folded into the `vendor/sqlite3/` row because it is
upstream's file in upstream's tree, not something this fork vendored.

## The data

`data/` is not code and is not covered by the code analysis above. Its licence
situation is genuinely unresolved in this tree, and this file records the gap
rather than closing it with a plausible label.

### `data/sql/*.sql` — generated from the EPSG Geodetic Parameter Dataset, and the terms are not here

**SOURCE-CONFIRMED:** `data/sql/metadata.sql:12-13` records the dataset's own
identity in the database it produces:

```
INSERT INTO "metadata" VALUES('EPSG.VERSION', 'v13.102');
INSERT INTO "metadata" VALUES('EPSG.DATE', '2026-08-27');
```

`data/sql/README.md:24-51` names the generator and the provenance: "Files
generated from EPSG dataset by [build_db.py]" lists 26 `.sql` files, and
`:53-60` names four more — `esri.sql` from ESRI, `ignf.sql` from IGN France,
`iau.sql` from the IAU 2015 registry, and `nkg.sql` as "Nordic Geodetic Commission
registry. Hand-written". `scripts/build_db.py:1-22` is the generator, MIT,
Even Rouault 2018.

**The EPSG Geodetic Parameter Dataset's own terms of use are not in this tree.**
A search for the terms across all 664 files found the dataset named only as data:
`NEWS.md:2580-2581` "definitions imported from the IOGP EPSG dataset", plus
citations to IOGP *Guidance Note* publications in `src/ell_set.cpp:441`,
`src/conversions/topocentric.cpp:34-35`, `src/projections/eqc.cpp:12-18`,
`src/projections/col_urban.cpp:12-13` and others. Those are bibliographic
references to method documentation, not a licence. **No terms text was found, and
this file therefore asserts none.**

**What this package does carry, and what it does not.**

* What it carries: PROJ's own package-wide statement at `COPYING:2-3`, "All
  source, data files and other contents of the PROJ package are available under
  the following terms", plus the MIT grant at `:16-34`. Read literally, that
  covers `data/sql/*.sql`.
* What it does not carry, and this is the open item: the EPSG Geodetic Parameter
  Dataset is published by IOGP under its **own** terms, which are a separate
  obligation from PROJ's grant to its own files. PROJ's `COPYING` cannot grant
  what IOGP holds. Those terms must be obtained from IOGP/EPSG **before any
  redistribution of `proj.db`**, which is a generated artefact containing
  EPSG-derived rows.

**This is recorded as a finding, not a failure of the import.** The import is
complete and byte-verified; what is missing is a document that upstream does not
ship in its release tarball either. Two things follow for the owner:

1. The four other registries carry the same question in different shapes. ESRI,
   IGNF, IAU and NKG each publish their own data; only NKG is described in-tree
   as hand-written (`data/sql/README.md:59`), and no terms text for any of the
   five was found.
2. Until the EPSG terms are obtained and recorded, the safest statement this
   package can make is the one above, and no licence for `proj.db` is asserted in
   these documents.

### `data/tests/` — upstream's own test grids, retained and uncompiled

88 entries, 3543751 bytes. The inventory, by extension:

| Kind | Count | Examples |
|---|---:|---|
| `.tif` | 54 | `test_vgrid_*.tif`, `test_hgrid*.tif`, `us_noaa_nadcon5_*.tif`, `us_noaa_geoid06_ak_subset_at_antimeridian.tif`, `subset_of_gr3df97a.tif`, `fr_ign_RAGTBT2016.tif`, `nkgrf03vel_realigned_extract.tif` |
| `.json` | 15 | `simple_model_*.json`, `tinshift_*.json` |
| `.gpkg` | 6 | `tinshift_*.gpkg` |
| `.gsb` | 5 | `BETA2007.gsb`, `ntf_r93.gsb`, `ntv2_0_downsampled.gsb`, `test_hgrid_big_endian.gsb`, `test_hgrid_little_endian.gsb` |
| `.gtx` | 3 | `egm96_15_downsampled.gtx`, `nkgrf03vel_realigned_z_extract.gtx`, `test_nodata.gtx` |
| no extension | 3 | `conus`, `alaska`, `MD` |
| `.ct2` | 1 | `nkgrf03vel_realigned_xy_extract.ct2` |
| `.dat` | 1 | `ntv1_can.dat` |

**Twelve of the 88 entries carry licence and provenance information inside the
file** — not in a header, but as embedded metadata: the GeoTIFF `ImageDescription`
tag for the `.tif` files, the GeoPackage metadata table for the `.gpkg` files,
and a GeoJSON `"license"` member for the `.json` files. Those twelve are the
per-file provenance the tree actually supplies, and they name three distinct
third-party terms:

| Entries | Embedded statement | Term |
|---|---|---|
| `fr_ign_RAGTBT2016.tif`, `subset_of_gr3df97a.tif` | "Derived from work by IGN France. Open License <https://www.etalab.gouv.fr/wp-content/uploads/2014/05/Open_Licence.pdf>" | IGN France's *Licence Ouverte* — **not read here, only named** |
| `test_hgrid_with_subgrid.tif`, `test_hgrid_with_subgrid_no_grid_name.tif` | "Derived from work by Natural Resources Canada. Open Government Licence - Canada: <http://open.canada.ca/en/open-government-licence-canada>" | the Canadian Open Government Licence — **not read here, only named** |
| `nkgrf03vel_realigned_extract.tif`, `nkgrf03vel_realigned_extract_tiled_256x256.tif`, and all six `tinshift_*.json` / `tinshift_*.gpkg` pairs | `"license": "Creative Commons Attribution 4.0 International"`, `"href": "https://creativecommons.org/licenses/by/4.0/"`, `"rel": "license"` | **CC-BY-4.0**, whose attribution and licence-link conditions apply |

Two of those entries also carry a description in the same metadata:
`subset_of_gr3df97a.tif` reads "Geocentric translation from NTF (IGNF:NTF) to
RGF93 (EPSG:4964). Converted from gr3df97a.tif", and the two NRCan files read
"NAD27 (EPSG:4267) to NAD83 (EPSG:4269). Converted from ntv2_0.gsb (last updated
on 1995-07-05)" — which is also how this file knows those two are *converted
derivatives* rather than the original grids.

**The remaining 76 entries carry no licence or provenance statement in any form,
and this file asserts nothing for them.** Their attribution reaches this tree
only indirectly, through the `grid_transformation.sql` rows that name each grid
and its authority:

* `data/sql/grid_transformation.sql:7` — `conus.las`/`conus.los`, NAD27 to
  NAD83 (1), authority `'NGS-US Conus'`.
* `data/sql/grid_transformation.sql:9` — `alaska.las`/`alaska.los`,
  `'NGS-US Conus'`-family NADCON work for Alaska.
* `data/sql/grid_transformation.sql:539` — `nadcon5.nad27.nad83_1986.conus.lat.trn.20160901.b`
  and the matching `.lon` file, method NADCON5.
* `data/sql/grid_transformation.sql:2177` and `:2179` — `BETA2007.gsb` for three
  German transformations, authority `'OGP-Deu BeTA2007'`.
* `data/sql/grid_transformation.sql:383`, `:385` and `:2025` — `DLx_ETRS89_geo.gsb`
  and `D73_ETRS89_geo.gsb`, authority `'IGP-Prt'`, i.e. the Portuguese IGNF.
* `data/sql/grid_alternatives.sql:195-201` — the `-- fr_ign - IGN France`
  comment introduces rows mapping official grid names to PROJ's own, including
  `rgf93_ntf.gsb` → `fr_ign_ntf_r93.tif` and `gr3df97a.txt` →
  `fr_ign_gr3df97a.tif`.

Those rows attribute the *registry entries* to NOAA/NGS, to IOGP/EPSG and to
IGN France. That is not a licence and not a per-file provenance record.

**Where the tree does not state it, and this file does not guess:**

* There is no `data/tests/README`, no manifest and no `.license` file; the only
  provenance that exists is the embedded metadata of the twelve entries above.
* Nothing in the tree says whether `conus`, `alaska` and `MD` are full grids,
  downsampled extracts or test subsets — only the filenames suggest it.
* Nothing states the terms for the NOAA/NGS grids, for `BETA2007.gsb`, for the
  Nordic extracts beyond the two that name CC-BY-4.0, or for the IGN grids beyond
  the two that name the *Licence Ouverte*.
* The *Licence Ouverte* and the Open Government Licence – Canada are **named by
  URL in the files and not read here.** Their conditions are not restated in this
  record because nobody read them; a redistribution that relies on either has to
  read it first.
* US federal grid data is often public domain by US Government works, but **this
  file does not assert that**, because no document in this tree says so and the
  assertion was not read from a source.

**What these files are in this package.** Upstream test material. `data/CMakeLists.txt:59-60`
describes copying "select resource files in a for_tests subdirectory so that we
are not influenced by the presence of other grids" — they are inputs to upstream's
own test suite, kept in a separate directory precisely so they cannot be mistaken
for installable data. This package **retains them, uncompiled and uninstalled**,
digested in `UPSTREAM.sha256`, and asserts no licence over them beyond what
`COPYING:2-3` says.

### The `+init` definition files and the rest of `data/`

`data/CH`, `GL27`, `ITRF2000`, `ITRF2008`, `ITRF2014`, `ITRF2020`, `nad27`,
`nad83` and `world` are legacy `+init` **definition** files, not grids. `data/CH:5-6`
states the distinction outright — "You'll need to download the grids separately and
put in a directory scanned by libproj" — and `:20` names `CHENyx06_ETRS.gsb` as the
file the definition *needs*. `data/README:1-18` describes the directory contents
and points at `<https://github.com/OSGeo/PROJ-data>` for the rest.

These nine files, `data/proj.ini`, `data/nad.lst`, `data/other.extra` and the
three `*.schema.json` are the data this package actually installs alongside the
generated `proj.db`.

## Retained upstream material this package does not compile

Recorded as retained-and-uncompiled, which is a platform boundary and not a
defect. `NOTICE.md` still inventories them because "not compiled" never meant
"not present" and never meant "no notice":

* `test/` — 98 files. `unit/` is GTest-based (`test/unit/main.cpp:10`,
  `test/unit/gtest_include.h:10` and 20 sibling test units, each carrying the MIT
  text at line 10), `cli/` is YAML-driven with `test/cli/run_cli_test.py`,
  `gie/` holds geodetic test files, `gigs/` holds test fixtures, `benchmark/`
  holds `bench_proj_trans.cpp`. All PROJ, all MIT, none compiled.
* `examples/` — 6 files: `crs_to_geodetic.c`, `EPSG_4326_to_32631.cpp`,
  `pj_obs_api_mini_demo.c`, `s45b.pol`, `val_def.demo`, `CMakeLists.txt`.
  Upstream's examples, none compiled.
* `man/` — 8 files: seven `man1` pages (`proj`, `cs2cs`, `geod`, `cct`, `gie`,
  `projinfo`, `projsync`) plus `CMakeLists.txt`. The pages carry attribution
  without a licence line and are not compiled or installed.
* `scripts/` — 31 files. 13 Python generators and checkers carry the MIT text
  (`scripts/build_db.py:12`, `build_db_from_esri.py:14`,
  `create_c_api_projections.py:13`, `grid_checks.py:13`,
  `generate_itrf2020.py:13`, and the rest at line 12); two carry the SPDX tag
  noted above. None is run by this build.
* `cmake/` — 14 files, of which the three Boost-licensed and one MIT-derived
  `FileEmbed.cmake` are inventoried above. Upstream's CMake is not used by this
  package; it is retained because upstream ships it and deleting upstream's
  material is not this fork's call.

## What this fork changed in upstream files

**Nothing.** No file among the 661 imported upstream files has been edited,
reformatted, patched or deleted.

This is a checkable claim and not an assertion:

```sh
sha256sum -c UPSTREAM.sha256     # all 664 digests
```

`UPSTREAM.sha256` is the machine-checkable form of this paragraph: 664 entries,
all of which are upstream digests and none of which is a fork digest. A per-file
deviation table belongs here and is **empty**. Any future native edit has to add a
row to it, move the digest in `UPSTREAM.sha256`, and add a numbered entry to
[`CHANGELOG.md`](CHANGELOG.md) — in one change.

`STATUS`: `SOURCE-CONFIRMED` from the recorded digests. That is a claim about
bytes. **No build result is recorded in this file**, and no gate has run.

## Fork-specific notice

Every file below was written for this fork. None of it carries an upstream
copyright, no upstream permission is claimed over it, and it is released under the
MIT terms recorded in [`FORK-LICENSE.md`](FORK-LICENSE.md):

* `build.zig`, `build.zig.zon` — the Zig build graph and package manifest
* `zig/` — the typed facade, its translation header, the compile exercise and the
  two C files of the by-value ABI bridge (`proj_abi.h`, `proj_abi.c`), which exist
  because Zig 0.16.0 and the compiler that builds this archive disagree about
  where a by-value `PJ_COORD` goes; `zig/proj_abi.h` states the disagreement in
  full
* `runtime/` — the load-at-runtime route: the reusable loader, this SDK's
  descriptor, the build half that wires them together, the build-time generator,
  and the two C files that supply the process-global synchronization the
  descriptor binds
* `tests.zig`, `smoke.zig`
* `consumer/` — a separate package that depends on this one by path
* `testdata/` — the independent known answers and their provenance record
* `tools/check-provenance.sh`
* `package.nix`, `flake.nix`, `devenv.nix`, `devenv.yaml`, `.envrc`,
  `cross-test.profile.sh`, `.gitignore`
* `.github/workflows/verify.yml` — **this fork's own CI.** Upstream's release
  tarball contains no `.github/` directory, so there is no upstream CI here to
  leave alone and none to retarget. It runs only this repository's own steps.
* this file, `README.md`, `README.zig.md`, `UPSTREAM.md`, `UPSTREAM.sha256`,
  `FORK-LICENSE.md`, `CHANGELOG.md`, `FORK-NOTES.md`

`UPSTREAM.sha256` is a data file, not authored prose: it is a list of upstream
digests, and the fork's grant covers its arrangement rather than its content,
which remains upstream's.

Which of those files carry `SPDX-License-Identifier: MIT` on their own first
comment line is a per-file fact owned by the build and API roles and is named in
`FORK-LICENSE.md`; the eight documentation and digest records carry the same grant
without a tag, because they are prose and data with no comment position a tag is
expected in.

**No upstream file gains an SPDX tag.** The three upstream files that already
carry one — `src/transformations/tinshift_iface.hpp:9`,
`src/transformations/tinshift_gpkg.hpp:9`,
`src/transformations/tinshift_gpkg.cpp:9` — keep it because it is theirs.

## Attribution a downstream must keep

1. **`COPYING` and every per-file notice listed above**, byte for byte. This
   package keeps them all unmodified and `sha256sum -c UPSTREAM.sha256` fails
   loudly if one is edited.
2. **The four Apache-2.0 files' notices**, because Apache-2.0 requires the notice
   to travel with the work even though the work is permissive. See "The five
   Apache-2.0 files" above for what this package does about the `NOTICE`
   requirement and the "files changed" requirement.
3. **The Bison special exception's conditions.** A downstream may use its own
   terms for the surrounding work; it may not build a parser generator on the
   skeleton, and if it modifies or redistributes the skeleton itself it must
   decide whether the exception stays.
4. **The EPSG terms, before redistributing `proj.db`.** Not obtained, not asserted
   here, and recorded as an open item.
5. **The algorithms.** PROJ is the work of the people `AUTHORS.md` names.
   Upstream asks for the citation in `CITATION` and `CITATION.cff`, and
   `README.upstream.md:74-77` points at it. Karney's geodesics additionally ask
   for the *Algorithms for geodesics* reference, which `src/geodesic.c:13-17`
   gives in full.
6. **Do not attribute this fork's Zig package to upstream.** Upstream wrote none
   of it. This paragraph is where that distinction is made.
7. **Keep this fork's own grant with the files it covers.** `FORK-LICENSE.md` is
   that grant; `NOTICE.md` is the inventory that says which files it reaches.

## What a consumer receives

A consumer who receives only a compiled artefact still owes items 1-5 above.
Nothing in this file discharges them, and nothing here should be read as though a
binary carries the notice by itself.