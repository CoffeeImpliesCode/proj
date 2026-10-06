# `testdata/` — the fixture material

Three files. One is the licence, one is the audit record for a numeric fixture, and
this one says where every number came from and what each is allowed to be used for.

Nothing in this directory is an oracle. `../tests.zig` re-derives the numbers it
checks from published formulas and compares PROJ against that derivation; the
records here exist so a reader can audit the derivation and so a change to it has
somewhere to be written down. A fixture that only recorded what PROJ printed would
prove that PROJ is deterministic, which is not what these tests are for.

## `webmercator-known-answers.md`

Fixture A. The spherical Mercator (EPSG:3857, method "Popular Visualisation Pseudo
Mercator", EPSG code 1024) forward and inverse closed form from the EPSG Guidance
Note 7-2, for four points, with exact decimal expansions and the intermediate
values needed to redo each row by hand.

* **Where the formulas come from.** The EPSG Guidance Note 7-2 method description.
  They are also what upstream implements, differently: `src/projections/merc.cpp:24-29`
  computes `k0 * asinh(tan(phi))` and `src/projections/merc.cpp:38-43` computes
  `atan(sinh(y / k0))`, which are the same functions written through the identity
  `asinh(t) = ln(t + sqrt(1 + t^2))` and `tan(pi/4 + phi/2) = t + sqrt(1 + t^2)`.
  The record spells that out because "same function, different arithmetic" is what
  makes the comparison evidence rather than a tautology.
* **How the numbers were computed.** In IEEE-754 double arithmetic from the closed
  form, here, with no PROJ code and no previous run of this fork involved. The
  exact expansions in the record are the shortest decimal strings that round-trip
  to the same doubles.
* **Why it is independent.** No component of any expected value came out of PROJ.
  It is reproducible from the published formulas with any double calculator, which
  is stated in the record so the claim can be checked rather than trusted.
* **The second known answer in the package** is the pair of figures upstream
  publishes for `EPSG:4326` to `EPSG:32631` in `examples/EPSG_4326_to_32631.cpp:84-85`
  (easting 426857.988, northing 5427937.523). The record cites the file and lines,
  notes that they are printed to three decimal places, and says why the test
  therefore compares them at 5e-4 m.

## The EPSG registry values (Fixture B)

Fixture B's numbers are not in a file here, because they are read out of
`proj.db` at test time — that is the point of the fixture. What `../tests.zig`
asserts, and where each value is defined:

| value | CRS or parameter | defined by |
|---|---|---|
| name `WGS 84`, type geographic 2D | EPSG:4326 | EPSG Geodetic Parameter Dataset, via `proj.db` |
| semi-major axis `6378137` m | WGS 84 ellipsoid | EPSG ellipsoid 7030 |
| inverse flattening `298.257223563` | WGS 84 ellipsoid | EPSG ellipsoid 7030 |
| name `WGS 84 / UTM zone 31N` | EPSG:32631 | EPSG projected CRS 32631 |
| method name `Transverse Mercator`, code `9807` | EPSG:32631 | EPSG method 9807 |
| `Longitude of natural origin` = 3° (code 8802) | EPSG:32631 | EPSG parameter 8802 |
| `Scale factor at natural origin` = 0.9996 (code 8805) | EPSG:32631 | EPSG parameter 8805 |
| `False easting` = 500000 m (code 8806) | EPSG:32631 | EPSG parameter 8806 |
| `False northing` = 0 m (code 8807) | EPSG:32631 | EPSG parameter 8807 |

The four parameter names and codes are upstream's own constants, in
`src/proj_constants.h:299-311`, and the test matches each parameter by its EPSG
**code** rather than by its position in the list, because the codes are the
registry's identifiers and the order is an implementation detail. The method name
and code are upstream's constants at `src/proj_constants.h:34-35`.

Nothing in that table was computed. PROJ is reading the dataset and passing it
back, which is exactly what the fixture is for: a facade that returns these is
reading the registry, not agreeing with itself.

`EPSG:4326` is reached through `datumForced`, not `datum`, and that is a fact
about the registry rather than about the facade. Its `geodetic_crs` row names
`EPSG:6326` (`data/sql/geodetic_crs.sql:523`), that row is the ensemble
"World Geodetic System 1984 ensemble" with a non-null `ensemble_accuracy` and
eight rows in `geodetic_datum_ensemble_member`, and upstream's own test records
the resulting shape — `datum()` null, `datumEnsemble()` present
(`test/unit/test_factory.cpp:568-571`). So `proj_crs_get_datum` answers NULL
(`src/iso19111/c_api.cpp:8808-8811`, `:8793-8794`), and
`proj_crs_get_datum_forced` is the entry point upstream provides for exactly this
case (`src/iso19111/c_api.cpp:8951-8956`). The two ellipsoid numbers above are
read from that object, and are the registry's EPSG ellipsoid 7030 either way.

The tolerances on the Fixture B numbers are rounding tolerances and are justified
in the test: 6378137 is an integer-valued double, 298.257223563 and 0.9996 are
decimal text in SQLite read back as the nearest double (half an ulp, 1.4e-14 and
below), and 500000 m has an ulp of 5.8e-11 m. The test uses 1e-9, four to five
orders of magnitude above those and six orders below anything that could be a
wrong number.

## The missing grid (Fixture C)

Fixture C has no known answer to record, because its content is a refusal or a
deliberately gridless operation rather than a number. What is recorded instead
is the data-availability fact it rests on: **this package ships no NTv2, NADCON or
GeoTIFF grid**, so every `proj.db` operation that needs one has it listed but
not present. The test therefore asserts:

1. a factory configured to discard grid-requiring operations
   (`PROJ_GRID_AVAILABILITY_DISCARD_OPERATION_IF_MISSING_GRID`, `src/proj.h:977-978`)
   and to refuse ballpark substitutions (`src/proj.h:1409-1410`) returns **zero**
   candidate operations for `EPSG:4326` to `EPSG:4277`, through
   `proj_list_get_count`. That zero holds under the spatial criterion such a
   factory has by default, `PROJ_SPATIAL_CRITERION_STRICT_CONTAINMENT`
   (`src/proj.h:1003`), which is why it is stated here;
2. the same factory returns **at least one** for `EPSG:4326` to `EPSG:3857`, which
   needs no grid — the positive control, so that a zero in (1) means "for this
   pair" rather than "this factory finds nothing";
3. `crsToCrsFromPj` with `ONLY_BEST=YES` **builds an object**, and the transform
   through it **fails** with `PROJ_ERR_COORD_TRANSFM_NO_OPERATION`. Upstream says
   this is where the option bites — "With ONLY_BEST=YES a transformation will
   fail if a needed grid is unavailable" (`NEWS.md:751`) — and the source agrees:
   the constructor answers NULL only when there is a single candidate and it is
   not instantiable (`src/crs_to_crs.cpp:617-641`, `:758-769`), while
   `proj_trans` warns about the missing grid and sets that code
   (`src/trans.cpp:289-294`). The test therefore asserts the refusal and the code,
   not `error.NullReturn`;
4. the default route *does* produce an operation, and that is not a fault:
   `EPSG:4326` to `EPSG:4277` has a seven-parameter Helmert route in `proj.db`
   that needs no grid. `proj_create_crs_to_crs_from_pj` asks the factory for
   `PROJ_SPATIAL_CRITERION_PARTIAL_INTERSECTION` (`src/crs_to_crs.cpp:568-569`),
   which the factory in (1) would answer with a non-empty list. So a finite
   coordinate is expected here, and what the test proves about it is that the
   operation PROJ names as the one it used
   (`proj_trans_get_last_used_operation`, `src/proj.h:630`) needs no grid this
   build cannot reach — upstream's own `out_available` answer, `src/proj.h:1533` —
   and is instantiable as it reports itself (`src/proj.h:1503-1504`). A
   coordinate produced by a step that needed an absent grid, or an undocumented
   refusal code, is the failure this case exists to catch.

Point 3 asserts one code, and the test says which: `PROJ_ERR_COORD_TRANSFM_NO_OPERATION`,
which is the code `src/trans.cpp:293` writes on the refusal. Where upstream takes its
other route — `src/crs_to_crs.cpp:637-640` destroys the candidate and returns NULL —
it writes no code at all, and the test asks for none.

## `LICENSE.md`

What covers this directory, and what does not.

## The provider and the database

Every fixture needs the library and `proj.db`. Under `-Druntime=true` the provider
is named by `PROJ_TEST_PROVIDER`; the database is at whatever `PROJ_DATA` points
at, which is what the build's test, smoke and check steps set. Both are described
in `../tests.zig`, and a missing one fails loudly rather than skipping, because a
case that quietly passed without a database would say nothing.