# Licence of the material in this directory

## What this directory contains

Three files, all of them **fork-authored**:

* `README.md` — where each expected value came from and what it may be used for.
* `webmercator-known-answers.md` — the audit record for Fixture A: the published
  spherical Mercator formulas, the four points, their exact decimal expansions and
  the argument for the tolerance.
* this file.

**No upstream file is vendored here.** Nothing in `proj/`'s `data/`, `src/`,
`test/`, `examples/` or `man/` is copied into this directory, and no upstream file
is quoted at more than the length needed to cite it.

## The grant

The fork's own additions, including every file in this directory, are covered by
the grant recorded in `../FORK-LICENSE.md`. That file is the fork's provenance
owner's to write and is not restated here; this directory's files carry the same
SPDX identifier it records.

That grant matches the project's primary upstream terms. PROJ is MIT — see
`../COPYING` and the notice at `../src/proj.h:96-116` — and it is MIT for the
fork's own additions too. Nothing here narrows or replaces it.

## Where the *numbers* come from, and what a licence covers about numbers

Three distinct sources appear in this directory, and it is worth being exact about
which is which.

1. **Computed here, from published formulas.** Every figure in
   `webmercator-known-answers.md` was computed in this repository from the EPSG
   Guidance Note 7-2 method formulas, in IEEE-754 double arithmetic, with no PROJ
   code and no previous run of this fork involved. Those are derived numerical
   results of a published mathematical definition. The EPSG dataset itself is
   published by the International Association of Oil and Gas Producers under its
   own terms, and **this repository does not redistribute it**: the registry values
   Fixture B checks are read out of the `proj.db` the build generates from
   `data/sql/`, and they are not copied into a file here.

2. **Quoted upstream, by citation.** Two numbers in
   `webmercator-known-answers.md` are upstream's own published figures: easting
   `426857.988` and northing `5427937.523` for `EPSG:4326` to `EPSG:32631`, from
   `../examples/EPSG_4326_to_32631.cpp:84-85`. They are quoted under PROJ's MIT
   terms (`../COPYING`) with attribution, which is all the licence requires and
   more than a bare number would.

3. **Upstream's own constants, by name.** The method name and code for Transverse
   Mercator and the four projection-parameter names and codes are cited from
   `../src/proj_constants.h` by macro name and line. Macro names and numeric codes
   are identifiers, and the files are already in this repository under
   `../COPYING`; nothing is being redistributed by naming them.

No grid file, no `proj.db`, and no part of the EPSG dataset is present in this
directory.

## Attribution

The closed-form method description is from the EPSG *Guidance Note 7-2*, published
by the International Association of Oil and Gas Producers (IOGP) through its
Geomatics Committee. It is cited here as the source of a published formula, and no
text of the Guidance Note is reproduced.