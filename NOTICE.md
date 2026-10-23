# Notice

## Scope

`COPYING` states: “All source, data files and other contents of the PROJ package are available under the following terms.” It also says: “Copyright information can be found in source files.” The full MIT terms remain in `COPYING`; per-file notices below apply where present.

The 664 PROJ release files are listed in `UPSTREAM.sha256` and remain unmodified. `README.upstream.md` is the upstream README. `vendor/sqlite3/` is a separate SQLite import, not a PROJ upstream path. Fork-authored files and their grant are listed below.

## Per-path licence inventory

| Path | Term and attribution |
|---|---|
| `src/`, `include/`, `data/`, and other PROJ package files | PROJ package-wide MIT terms in `COPYING`; retain copyright notices in each file. The compiled `src/` and `include/` tree also contains the exceptions below. |
| `src/wkt1_generated_parser.c`, `src/wkt1_generated_parser.h`, `src/wkt2_generated_parser.c`, `src/wkt2_generated_parser.h` | GPL-2.0-or-later with the GNU Bison special exception; copyright Free Software Foundation. The two `.c` files also carry PROJ's MIT notice. |
| `include/proj/nn.hpp` | Apache-2.0; Dropbox, Inc. |
| `src/sphere.h`, `src/projections/polyhedral.cpp` | Apache-2.0; A5 contributors. `sphere.h` names A5's `modules/utils/vector.ts` as its source. |
| `src/projections/polyhedral/snyder.h` | Apache-2.0; A5 contributors. Also BSD-3-Clause, derived from DGGAL; Ecere Corporation. |
| `src/projections/patterson.cpp` | Apache-2.0; Bojan Savric. The file also records Tom Patterson's 2014 design and its references. |
| `cmake/ProjVersion.cmake`, `cmake/ProjConfig.cmake` | Boost Software License 1.0; Mateusz Loskot. |
| `cmake/ProjUtilities.cmake` | Boost Software License 1.0; Douglas Gregor, Troy Straszheim, and Mateusz Loskot. |
| `cmake/FileEmbed.cmake` | MIT; derived from `cmake-examples`, copyright Jonathan Hamberg. |
| `src/vec3.h` | MIT; derived from gl-matrix, copyright Brandon Jones and Colin MacKenzie IV. |
| `include/proj/internal/vendor/nlohmann/json.hpp` | MIT; Niels Lohmann. The file also records Florian Loitsch's code under MIT. This is upstream's vendoring and is compiled through `include/proj/internal/include_nlohmann_json.hpp`. |
| `src/geodesic.h` | MIT/X11; Charles Karney, 2012–2022. |
| `src/geodesic.c` | MIT/X11; Charles Karney, 2012–2025. The different year ranges are upstream's. |
| `vendor/sqlite3/sqlite3.c`, `vendor/sqlite3/sqlite3.h`, `vendor/sqlite3/sqlite3ext.h` | SQLite public-domain blessing; these three files came from the separate SQLite 3.53.4 amalgamation archive. |
| `src/memvfs.c` | Upstream PROJ file derived from SQLite's `memvfs.c`; SQLite public-domain blessing. It is compiled only when `EMBED_RESOURCE_FILES` is enabled. |
| `data/sql/*.sql` | Covered by PROJ's package-wide grant. The SQL includes EPSG and other registry data; this tree does not contain their separate terms. Obtain EPSG terms from IOGP before redistributing generated `proj.db`. |
| `data/tests/fr_ign_RAGTBT2016.tif`, `data/tests/subset_of_gr3df97a.tif` | Embedded attribution to IGN France and the Licence Ouverte. |
| `data/tests/test_hgrid_with_subgrid.tif`, `data/tests/test_hgrid_with_subgrid_no_grid_name.tif` | Embedded attribution to Natural Resources Canada and the Open Government Licence – Canada. |
| `data/tests/nkgrf03vel_realigned_extract.tif`, `data/tests/nkgrf03vel_realigned_extract_tiled_256x256.tif`, `data/tests/tinshift_crs_implicit.json`, `data/tests/tinshift_crs_implicit.gpkg`, `data/tests/tinshift_simplified_kkj_etrs.json`, `data/tests/tinshift_simplified_kkj_etrs.gpkg`, `data/tests/tinshift_simplified_n60_n2000.json`, `data/tests/tinshift_simplified_n60_n2000.gpkg` | Embedded CC-BY-4.0 licence metadata. |
| Other `data/tests/` files | No per-file licence or provenance statement is present in this tree; no separate term is asserted here. |

The Licence Ouverte and Open Government Licence – Canada are named by URL in the files; their terms are not reproduced here. The EPSG Geodetic Parameter Dataset's terms are absent from the PROJ archive. No licence for EPSG-derived `proj.db` is asserted beyond the PROJ package grant to its own files.

### Bison exception

The four parser files state:

> As a special exception, you may create a larger work that contains part or all
> of the Bison parser skeleton and distribute that work under terms of your
> choice, so long as that work isn't itself a parser generator using the skeleton
> or a modified version thereof as a parser skeleton.

A downstream may use its own terms for the surrounding work, subject to that exception. The exception's conditions remain with the parser files.

### SQLite blessing

The three vendored SQLite files and `src/memvfs.c` state:

> The author disclaims copyright to this source code. In place of a legal
> notice, here is a blessing:
>
> May you do good and not evil.
> May you find forgiveness for yourself and forgive others.
> May you share freely, never taking more than you give.

`vendor/sqlite3/shell.c` is not included. It is the SQLite command-line shell from the separate amalgamation archive, not a removed PROJ file.

## Fork-authored files

The grant in `FORK-LICENSE.md` covers `build.zig`, `build.zig.zon`, `zig/`, `runtime/`, `tests.zig`, `smoke.zig`, `consumer/`, `testdata/`, `tools/check-provenance.sh`, `package.nix`, `flake.nix`, `devenv.nix`, `devenv.yaml`, `.envrc`, `cross-test.profile.sh`, `.gitignore`, `README.md`, `README.zig.md`, `UPSTREAM.md`, `UPSTREAM.sha256`, `FORK-LICENSE.md`, `CHANGELOG.md`, `FORK-NOTES.md`, and this file. `UPSTREAM.sha256` contains upstream digests; the fork grant covers its arrangement, not the upstream file contents.

No upstream file receives an SPDX tag from this fork. The three upstream files that already carry one are `src/transformations/tinshift_iface.hpp`, `src/transformations/tinshift_gpkg.hpp`, and `src/transformations/tinshift_gpkg.cpp`.

## Downstream attribution

- Keep `COPYING` and every per-file notice with the files. Apache-2.0 notices for Dropbox, A5, Ecere, and Bojan Savric must travel with their files.
- Retain the Bison exception with the four parser files.
- Obtain the EPSG terms before redistributing `proj.db`.
- PROJ's authors and citation are in `AUTHORS.md`, `CITATION`, and `CITATION.cff`. The geodesic algorithm reference is in `src/geodesic.c`.
- Do not attribute this fork's Zig package to upstream; upstream wrote none of the fork-authored files listed above.
