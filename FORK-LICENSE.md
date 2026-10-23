# FORK-LICENSE.md — grant for fork-authored files

`NOTICE.md` inventories file ownership and per-file terms. This file grants permission only for fork-authored material.

## Scope

The 661 imported files from PROJ 9.9.0 (`src/`, `include/`, `data/`, `test/`, `examples/`, `man/`, `scripts/`, `cmake/`,
and ten root files) are PROJ's and unmodified. They retain the terms in `COPYING` and the per-file terms in `NOTICE.md`. Nothing in this file re-grants, narrows, widens or conditions any of those terms, and nothing here asserts that any person named in `AUTHORS.md` wrote, reviewed, endorsed or is affiliated with the fork's files.

Fork-authored material includes the Zig build graph and manifest, typed facade and translation header, C `PJ_COORD` bridge, runtime loader,
tests, example, consumer package, independent-answer fixtures, Nix and devenv packaging, provenance script, and documentation. The grant below covers that material except for the files and data listed here.

* The three SQLite files, `vendor/sqlite3/sqlite3.c`, `sqlite3.h`, and `sqlite3ext.h`,
  are the SQLite 3.53.4 amalgamation under SQLite's public-domain blessing. They are third-party files, not PROJ's or this fork's; see `UPSTREAM.md`.
* `data/sql/` and the grids in `data/tests/` are upstream datasets, not fork-authored material. Their provenance includes CC-BY-4.0, IGN France's Licence Ouverte,
  and the Canadian Open Government Licence. This grant does not supply terms for the EPSG Geodetic Parameter Dataset; obtain them from IOGP/EPSG before redistributing `proj.db`.
* Algorithms and numeric data inside upstream files remain under upstream's terms. A fork-authored file's arrangement of quoted upstream material is covered by this grant.
* The grant does not reach the five Apache-2.0 files: `include/proj/nn.hpp`, `src/sphere.h`, `src/projections/polyhedral.cpp`, `src/projections/polyhedral/snyder.h`, and `src/projections/patterson.cpp`.
  Their copyright holders are Dropbox, Inc., the A5 contributors, and Bojan Savric. `snyder.h` also retains Ecere Corporation's BSD-3-Clause grant. Downstream distributions must carry the Apache notices listed in `NOTICE.md`.
* `src/wkt1_generated_parser.c`, `src/wkt1_generated_parser.h`, `src/wkt2_generated_parser.c`, and `src/wkt2_generated_parser.h` remain GPL-2.0-or-later with the Bison special exception.
  The exception states: "you may create a larger work that contains part or all of the Bison parser skeleton and distribute that work under terms of your choice". Its conditions remain: the surrounding work is not a parser generator built on the skeleton, and the skeleton is redistributed unmodified. `src/wkt1_generated_parser.c` and `src/wkt2_generated_parser.c` also retain PROJ's MIT header embedded by upstream's generator.
* `cmake/ProjVersion.cmake`, `cmake/ProjUtilities.cmake`, and `cmake/ProjConfig.cmake` retain Boost-1.0. `cmake/FileEmbed.cmake` retains its MIT-derived terms and Copyright (c) 2022 Jonathan Hamberg.

## Grant

Those fork-authored files within scope are released under the MIT License:

```
MIT License

Copyright (c) 2026 the contributors to this fork

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
```

The repository owner authorized this MIT grant for fork-authored additions. It is not an upstream grant.

## SPDX identifier

```
MIT
```

The tree also contains Apache-2.0, GPL-2.0-or-later with Bison exception, BSD-3-Clause,
Boost-1.0, MIT/X11, and SQLite public-domain files. `NOTICE.md` inventories those terms.

Fork-authored source, build, packaging, and script files carry `SPDX-License-Identifier: MIT`; `NOTICE.md` lists them. Upstream files keep their own headers, including the three already tagged.

These eight documentation and digest files carry the same grant without an SPDX tag: `README.md`, `README.zig.md`, `UPSTREAM.md`, `NOTICE.md`, `FORK-LICENSE.md`, `CHANGELOG.md`, `FORK-NOTES.md`, and `UPSTREAM.sha256`.

## Generated outputs and distribution

The build generates `proj.db` and `PROJ_DB_SQL_MD5.h` from upstream's `data/sql/*.sql`; the digest reproduces upstream's recorded value. Neither output is fork-authored source or present in the tree.

A PROJ 9.9.0 binary, headers, or `proj.db` still requires `COPYING` and every notice in `NOTICE.md`. Distributions must carry `COPYING` unmodified, `NOTICE.md`, and `FORK-LICENSE.md` beside the library. Include `UPSTREAM.md` and `UPSTREAM.sha256` for provenance.