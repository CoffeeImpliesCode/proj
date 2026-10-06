# FORK-LICENSE.md — the grant for this fork's own files

[`NOTICE.md`](NOTICE.md) is the inventory: which files are upstream's, which are
this fork's, and which term covers each. This file is the grant, for the second
group only.

## 1. The native source is not covered by anything below

The 661 imported upstream files — PROJ's `proj-9.9.0.tar.gz` under `src/`,
`include/`, `data/`, `test/`, `examples/`, `man/`, `scripts/`, `cmake/` and the
ten root files — are PROJ's, whole, and never edited. They are governed by
`COPYING` (`COPYING:2-3`, grant at `:16-34`) and, file by file, by the terms
`NOTICE.md` inventories. Nothing in this file re-grants, narrows, widens or
conditions any of those terms, and nothing here asserts that any person named in
`AUTHORS.md` wrote, reviewed or endorses a line of fork code.

## 2. The fork-authored material

Everything else in this repository was written for this fork: the Zig build
graph and package manifest, the typed Zig facade and its translation header, the
fork-authored C bridge that carries a by-value `PJ_COORD` across into the
compiled library and back, the runtime-loading route, the tests, the example, the
separate consumer package, the independent-answer fixtures, the Nix and devenv
packaging, this fork's own CI, the provenance script and the documentation.

**What that list is not.** The grant below does not reach:

* **Any of the 661 upstream files.** All keep upstream's own terms, including the
  per-file exceptions.
* **The three vendored SQLite files** under `vendor/sqlite3/`. They are not
  upstream's and they are not this fork's authorship; they are a third-party
  import under SQLite's public-domain blessing, recorded at
  `NOTICE.md` § 6. Carrying them in this repository grants nothing over them.
* **The data in `data/sql/`** and the **grids in `data/tests/`**. Those are
  upstream's material carrying third-party dataset provenance, including CC-BY-4.0,
  IGN France's *Licence Ouverte* and the Canadian Open Government Licence. See
  `NOTICE.md` § "The data", and the open item on the EPSG Geodetic Parameter
  Dataset's terms, which this grant does not and cannot supply.
* **The algorithms and the numeric data inside upstream's files.** Where a fork
  file quotes an upstream figure or an upstream header, that quoted material stays
  under upstream's terms; the fork's arrangement of it is under the grant below.

### Grant

**Those files are released under the MIT License**, matching the primary upstream
term of this project — PROJ's own MIT-style grant at `COPYING:16-34` — whose text
is:

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

The permission and warranty paragraphs are `COPYING:18-34` verbatim; only the
holder line differs. The obligation is identical to PROJ's own: keep the notice
with copies of the fork's files.

### Authority for that grant

The owner of this repository authorized per-project licensing for fork-authored
additions as part of the SDK contract migration, with the term chosen per project
to match that project's primary upstream terms where that is appropriate. PROJ's
primary upstream term is the MIT-style grant in `COPYING`, so MIT is the choice.
The authorization is recorded here and in `NOTICE.md`; the term above is the
owner's, reached by that authorization and not by any upstream grant.

The owner is not named and no individual copyright holder is invented: the holder
line is deliberately the collective one. Supplying a name later changes that one
line and nothing else.

### SPDX identifier

```
MIT
```

The plain registered identifier, with no `LicenseRef-` wrapper. That is a
deliberate distinction and not a shortcut. This package's compiled tree contains
six other terms — Apache-2.0, GPL-2.0-or-later-with-Bison-exception, BSD-3-Clause,
Boost-1.0, MIT/X11 and SQLite's public-domain blessing — so a consumer scanning
for `MIT` here must be able to find the fork's own files under it **and** must
find `NOTICE.md` for the other six. Inventing a `LicenseRef-` for the fork's
files would misrepresent a plain grant as a variant one; inventing one for the
tree would misrepresent the tree, which is not licensed by a single term.

Every fork-authored **source, build, packaging and script** file carries
`SPDX-License-Identifier: MIT` on its own first comment line. Which files those
are is a per-file fact owned by the build and API roles and is recorded beside the
grant in `NOTICE.md`; no upstream file gains the tag, and the three upstream files
that already carry one keep it because it is theirs.

The eight documentation and digest records — `README.md`, `README.zig.md`,
`UPSTREAM.md`, `NOTICE.md`, `FORK-LICENSE.md`, `CHANGELOG.md`, `FORK-NOTES.md` and
`UPSTREAM.sha256` — carry the same grant without a tag. They are prose and data
with no comment position a tag is expected in, and `NOTICE.md` names each of them
explicitly so that a scanner finding no identifier in `README.md` reads a recorded
reason rather than an apparent gap.

## 3. What this grant does not do

* It does not re-license, sublicense or add a condition to any of the 661 upstream
  files.
* **It does not touch the five Apache-2.0 files.** `include/proj/nn.hpp`,
  `src/sphere.h`, `src/projections/polyhedral.cpp`,
  `src/projections/polyhedral/snyder.h` and `src/projections/patterson.cpp` keep
  Apache-2.0 with their own copyright holders — Dropbox, Inc.; the A5
  contributors; and Bojan Savric — and `snyder.h` additionally keeps the
  BSD-3-Clause grant at its `:26-56` from Ecere Corporation. Nothing in this
  section reaches them, and a downstream who receives this package still owes
  every Apache-2.0 obligation `NOTICE.md` lists, including the requirement that
  the notice travel.
* **It does not touch the four Bison-generated parser files.**
  `src/wkt1_generated_parser.{c,h}` and `src/wkt2_generated_parser.{c,h}` remain
  GPL-2.0-or-later **with the Bison special exception** at their `:21-29`. The
  exception — "you may create a larger work that contains part or all of the
  Bison parser skeleton and distribute that work under terms of your choice" — is
  what allows a permissive library like this one to link them, and it keeps its two
  conditions here: the surrounding work is not a parser generator built on the
  skeleton, and the skeleton is redistributed unmodified. Those two `.c` files also
  carry PROJ's own MIT header at `:75-100`, which upstream's own generator embedded;
  that too is untouched.
* **It does not touch the three Boost-1.0 files**, `cmake/ProjVersion.cmake`,
  `cmake/ProjUtilities.cmake` and `cmake/ProjConfig.cmake`, nor the MIT-derived
  `cmake/FileEmbed.cmake` (Copyright (c) 2022 Jonathan Hamberg).
* **It does not assert that Frank Warmerdam, Gerald Evenden, Kristian Evers, Even
  Rouault, Thomas Knudsen, Javier Jimenez Shaw, Charles F. F. Karney, Niels
  Lohmann, Dropbox, the A5 contributors, Bojan Savric, Ecere Corporation, Mateusz
  Loskot, Thomas Flemming, Jonathan Hamberg, the Free Software Foundation, the
  SQLite author, or anyone else wrote, reviewed, endorsed or is affiliated with
  the fork's files.** They did not.
* It does not discharge upstream's attribution obligation. A consumer who ships a
  PROJ 9.9.0 binary, static or shared library, its headers or `proj.db` still owes
  `COPYING` and every per-file notice `NOTICE.md` inventories.
* **It does not supply the EPSG Geodetic Parameter Dataset's terms of use.** Those
  are a separate obligation from any grant in this file, they are not in this tree,
  and they must be obtained from IOGP/EPSG before any redistribution of `proj.db`.
* It does not claim that MIT is the only term the owner could have chosen for
  independently authored work. It is the term chosen, and it happens to match
  upstream's.

## 4. Material carried but not authored here

Two groups, kept distinct rather than dropped into a third category.

**Vendored, third-party, imported:** `vendor/sqlite3/sqlite3.c`, `sqlite3.h` and
`sqlite3ext.h` — the SQLite 3.53.4 amalgamation, under SQLite's public-domain
blessing, pinned in `UPSTREAM.md`. They are neither PROJ's nor this fork's.

**Generated, never shipped as source:** `proj.db` and `PROJ_DB_SQL_MD5.h`. The
build produces both for the target being built from imported `data/sql/*.sql`; the
`PROJ_DB_SQL_MD5` value reproduces upstream's own recorded digest. Neither is
authored material, neither carries third-party code beyond what the imported SQL
already contains, and neither is a file in this tree. `proj.db` is
`PENDING-VERIFICATION`: it is produced by a build step that has not run.

## 5. Where a consumer finds these grants

The build graph owns every installed path, so the installed layout in this
package's published route carries the licence records beside the library. This
file does not assert *which* record is installed at *which* path, because
`build.zig` belongs to another role of this same wave and does not exist in this
tree yet.

What it does assert, because it is a requirement rather than a claim:

* `COPYING` must be installed **unmodified**. It is upstream's grant; a private
  repository removes no upstream obligation, and nothing rewrites, renames or
  replaces it with this fork's notice.
* `NOTICE.md` and `FORK-LICENSE.md` must both travel. A consumer who receives
  only a compiled artefact still needs the inventory that says which of the seven
  terms reaches which file, and the grant for the files this fork wrote.
* `UPSTREAM.md` and `UPSTREAM.sha256` must travel, so that a recipient can check
  the provenance claim instead of taking it on trust.

## 6. Why a separate file at all

`NOTICE.md` names which files are upstream's, which are this fork's, and which
term covers each — including the seven per-file exceptions and the one obligation
whose text is absent from this tree. That inventory is long, and mixing it with
the grant would make both harder to read and easier to quote out of context. So
the authority, the grant text and the limits of that grant live here, next to the
inventory rather than scattered through it.