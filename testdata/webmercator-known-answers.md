# Web Mercator (EPSG:3857) known answers — Fixture A

This file is the **audit record** for Fixture A. It is not the oracle.
`../tests.zig` re-derives every number below from the published closed form and
compares PROJ against that; the test also compares its own re-derivation against
the literals transcribed here, and that comparison is the tie between the two. If
this file and the test ever disagree, the test is not wrong about PROJ — it is
right and this record is stale.

## The method

EPSG:3857, "WGS 84 / Pseudo-Mercator", uses the EPSG method **"Popular
Visualisation Pseudo Mercator"** (EPSG code **1024**;
`EPSG_NAME_METHOD_POPULAR_VISUALISATION_PSEUDO_MERCATOR` and
`EPSG_CODE_METHOD_POPULAR_VISUALISATION_PSEUDO_MERCATOR` at
`src/proj_constants.h:199-201`). The method is defined on a **sphere** of radius

    R = 6378137 m

and on no ellipsoid. The forward formulas, from the EPSG Guidance Note 7-2 method
description, are

    x = R * lambda
    y = R * ln(tan(pi/4 + phi/2))

with `lambda` and `phi` in radians. The inverse is

    lambda = x / R
    phi    = 2 * atan(exp(y / R)) - pi/2

## Why this is an independent answer, and not PROJ restated

PROJ computes the same function by a different route. `src/projections/merc.cpp:24-29`
is the spheroidal branch:

    static PJ_XY merc_s_forward(PJ_LP lp, PJ *P) { /* Spheroidal, forward */
        PJ_XY xy = {0.0, 0.0};
        xy.x = P->k0 * lp.lam;
        xy.y = P->k0 * asinh(tan(lp.phi));
        return xy;
    }

with `k0 = 1` for EPSG:3857. The identity that makes those the same function is

    asinh(t) = ln(t + sqrt(1 + t^2))
    tan(pi/4 + phi/2) = (1 + sin phi) / cos phi = t + sqrt(1 + t^2)   for t = tan(phi)

so `asinh(tan(phi)) = ln(tan(pi/4 + phi/2))` exactly in real arithmetic. They are
not the same computation: different libm calls, different rounding, a different
number of them. Agreement is therefore evidence about the projection, and a
disagreement would be evidence too. The inverse is the same story one step further:
`src/projections/merc.cpp:38-43` computes `atan(sinh(y / k0))` and `x / k0`,
whereas the published inverse is `2 * atan(exp(y / R)) - pi/2`.

Every number below was computed here, in IEEE-754 double arithmetic, from the
closed form and nothing else. No PROJ code, no previous run of this fork, and no
round trip contributed to any of them.

## The points

Chosen so that the set contains an exact zero, a 45-degree latitude with a closed
algebraic form, two mid-latitudes, and two longitudes on either side of the prime
meridian. `%.17g` is the shortest decimal string that round-trips to the same
double; `repr` length is what a Zig `f64` literal must be to denote exactly these
bits.

| name | lon° | lat° | x (m) | y (m) |
|---|---|---|---|---|
| P1 Philadelphia | −75.0 | 40.0 | −8348961.809496 | 4865942.279503 |
| P2 Eiffel Tower | 2.294481 | 48.858370 | 255420.456555 | 6250863.825524 |
| P3 | 0.0 | 45.0 | 0.000000 | 5621521.486192 |
| P4 Tokyo | 139.691711 | 35.689487 | 15550410.136561 | 4257978.950394 |

Exact expansions, so each row can be recomputed by hand:

| name | `lambda` (rad) | `phi` (rad) | `x` exactly | `y` exactly |
|---|---|---|---|---|
| P1 | −1.3089969389957472 | 0.6981317007977318 | −8348961.809495518 | 4865942.279503176 |
| P2 | 0.040046248074452014 | 0.8527394236576219 | 255420.45655484113 | 6250863.8255242556 |
| P3 | 0.0 | 0.7853981633974483 | 0.0 | 5621521.4861920662 |
| P4 | 2.4380802946943807 | 0.6228990564977135 | 15550410.136561133 | 4257978.9503935715 |

Intermediate values, for the same hand check:

| name | `tan(pi/4 + phi/2)` | `asinh(tan(phi))` | PROJ's intermediate | agree to |
|---|---|---|---|---|
| P1 | 2.1445069205095586 | 0.7629096520666105 | same two expressions | — |
| P2 | 2.664577210196881 | 0.9800453997028058 | | |
| P3 | 2.414213562373095 | 0.8813735870195429 | | |
| P4 | 1.9495328118542177 | 0.6675897602064007 | | |

### P3 in closed form

P3 is the row that can be verified with no decimal arithmetic at all. At
`phi = 45°`, `phi/2 = 22.5°` and `tan(67.5°) = 1 + sqrt(2)` exactly, because
`tan(45° + 22.5°) = (1 + tan 22.5°) / (1 − tan 22.5°)` and `tan 22.5° = sqrt(2) − 1`.
So

    sqrt(2)          = 1.4142135623730951
    1 + sqrt(2)      = 2.4142135623730949
    ln(1 + sqrt(2))  = 0.8813735870195429
    6378137 * that   = 5621521.4861920662

and `lambda = 0` gives `x = 0` with no rounding at all. The same
`0.8813735870195429` is `asinh(1)` — `asinh(1) = ln(1 + sqrt(1 + 1)) = ln(1 + sqrt 2)`
— which is why P3 is also the row where PROJ's `asinh` form and the published
`ln tan` form meet on a value that can be written down in full.

The inverse of P3 comes back the same way: `exp(y/R) = exp(ln(1 + sqrt 2)) = 2.414213562373095`,
`atan(2.414213562373095) = 1.1780972450961724` rad, and
`2 * 1.1780972450961724 − pi/2 = 0.7853981633974483` rad = 45.000000000000000°.

## The axis order the test passes, and why

`EPSG:4326` declares **GeodeticLatitude as its first axis**, so
`proj_create_crs_to_crs` builds an operation that takes latitude in `v[0]` and
longitude in `v[1]`. `../tests.zig` says so on the test and passes
`proj.coord(lat, lon, 0, 0)`.

The evidence is upstream's own:

* `examples/EPSG_4326_to_32631.cpp:74-79` fills the coordinate with
  `49.0` labelled `// latitude in degree` and `2.0` labelled `// longitude in degree`,
  and `examples/EPSG_4326_to_32631.cpp:84-85` reads `c.v[0]` back as
  "Easting" and `c.v[1]` as "Northing".
* `test/unit/test_c_api.cpp:4374-4387` builds `EPSG:4326` to `EPSG:32631` and then
  calls `proj_normalize_for_visualization`; the expected pipeline at
  `test/unit/test_c_api.cpp:4382-4384` has **no** `axisswap` step, whereas the
  un-normalized operation has one. That is the evidence that the swap belongs to the
  authority route and that removing it is the visualization route.

`proj_normalize_for_visualization` is therefore exercised **separately** in
`../tests.zig`, on its own object and with its own input order
(`coord(lon, lat, 0, 0)`), against the two figures upstream publishes for
`EPSG:4326` to `EPSG:32631` in the example quoted above:

| quantity | published value | source line |
|---|---|---|
| easting | 426857.988 | `examples/EPSG_4326_to_32631.cpp:84` |
| northing | 5427937.523 | `examples/EPSG_4326_to_32631.cpp:85` |

Those two are upstream's own regression figures for a different CRS pair, printed
to three decimal places, and they are the second independent known answer in this
package. `../tests.zig` compares them at 5e-4 m, which is half of the last printed
digit and nothing tighter.

## The tolerance, and why it is 1e-6 m

`../tests.zig` compares at **1e-6 m absolute** and says the same thing there. The
argument:

* The two computations differ in the transcendental used for the northing
  (`asinh` versus `ln` of a `tan`) and in the order of the multiplications around
  it. Nothing else differs: `k0` is exactly 1 for EPSG:3857, and the degree→radian
  step is one multiply by `pi/180` on both sides.
* A double has a 53-bit significand. One ulp of a number near 6.3e6 — the largest
  northing here — is 2^(22−52) = **8.9e-10 m**. Three or four such roundings
  accumulate to a few times 1e-9 m.
* 1e-6 m therefore leaves three orders of magnitude of headroom over the arithmetic
  difference while remaining four orders of magnitude **finer** than the 1 m
  precision the EPSG method itself publishes.
* Anything tighter would be testing this host's `libm` against itself. `asinh` and
  `log`/`tan` are different implementations with no reason to agree to the last
  bit, on any platform, and a tolerance chosen to demand that would fail for a
  reason that has nothing to do with PROJ.

## What this file is not

It is not a round trip, not a copy of PROJ's output, and not a version pin. Every
figure in it is reproducible from the formulas above with any IEEE-754 double
calculator, which is what makes it an independent answer rather than a recorded
observation.