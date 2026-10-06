// SPDX-License-Identifier: MIT
// Fork-authored. `FORK-LICENSE.md` records the owner's authorization of that
// grant for this file, and `COPYING` holds upstream's own MIT text.

/* The pointer-shaped route into the compiled library.
 *
 * ## Why this file exists
 *
 * Upstream passes `PJ_COORD` by value and returns it by value, on purpose. Its
 * own comment says so at `src/proj.h:65-71`: passing PJ_LP and PJ_XYZ "on the
 * stack (\"call by value\"), and symmetrically returning the result on the
 * stack". Ten entry points are written that way - `src/proj.h:629` `proj_trans`,
 * `:656` `proj_coord`, `:663` `proj_lp_dist`, `:666` `proj_lpz_dist`, `:669`
 * `proj_xy_dist`, `:672` `proj_xyz_dist`, `:676` `proj_geod`, `:705`
 * `proj_geod_direct`, `:783` `proj_factors` and `:1426-1429`
 * `proj_get_suggested_operation`.
 *
 * **Zig 0.16.0 and the C compiler this package builds PROJ with do not agree
 * about where those go.** The C compiler classifies a 32-byte `PJ_COORD` as a
 * four-element floating-point aggregate and passes and returns it in four
 * consecutive SIMD registers; Zig's own lowering of a call to the same function
 * puts the aggregate in memory and reads the result from a slot the callee
 * never wrote. The two halves of the same call therefore do not meet, and the
 * caller sees whatever was in that slot - zeros, a previous result, or a piece
 * of somebody else's frame.
 *
 * That is not a difference of opinion this package gets to have. The library is
 * compiled by the C compiler that ships with Zig, its entry points have the
 * convention that compiler gave them, and a caller has to hand arguments back in
 * that same convention. So the by-value call happens where both halves agree:
 * here, in C, compiled by that same compiler. What crosses back into Zig is a
 * pointer and, at most, a `double` or an `int` - scalars whose calling
 * convention every one of these targets agrees on. The cost is one 32-byte copy
 * in and one out, on a function that reads `proj.db` and evaluates a projection
 * pipeline.
 *
 * ## What is not here, and why
 *
 * `PJ_FACTORS` (`src/proj.h:206-220`) is seven doubles, 56 bytes. A
 * homogeneous aggregate of more than four members is not register-classified, so
 * it is passed and returned in memory by both compilers; only its `PJ_COORD`
 * argument needed a route, and that is what `proj_abi_factors` provides. Nothing
 * here returns a struct or a union by value either: the ones that are written to
 * take an out-parameter, so the by-value return happens on the C side of this
 * file and never on a boundary this package cannot vouch for.
 *
 * These are not PROJ's entry points and PROJ does not declare them. They are
 * fork-authored, they live in this package's own namespace, and they are
 * compiled into the same archive as the library they forward to.
 */

#ifndef PROJ_ABI_H
#define PROJ_ABI_H

#include <proj.h>

#ifdef __cplusplus
extern "C" {
#endif

/* `proj_coord` - `src/proj.h:656`. */
void proj_abi_coord(double x, double y, double z, double t, PJ_COORD *out);

/* `proj_trans` - `src/proj.h:629`. */
void proj_abi_trans(PJ *P, PJ_DIRECTION direction, const PJ_COORD *in,
                    PJ_COORD *out);

/* `proj_lp_dist` - `src/proj.h:663`. */
double proj_abi_lp_dist(const PJ *P, const PJ_COORD *a, const PJ_COORD *b);

/* `proj_lpz_dist` - `src/proj.h:666`. */
double proj_abi_lpz_dist(const PJ *P, const PJ_COORD *a, const PJ_COORD *b);

/* `proj_xy_dist` - `src/proj.h:669`. */
double proj_abi_xy_dist(const PJ_COORD *a, const PJ_COORD *b);

/* `proj_xyz_dist` - `src/proj.h:672`. */
double proj_abi_xyz_dist(const PJ_COORD *a, const PJ_COORD *b);

/* `proj_geod` - `src/proj.h:676`. */
void proj_abi_geod(const PJ *P, const PJ_COORD *a, const PJ_COORD *b,
                   PJ_COORD *out);

/* `proj_geod_direct` - `src/proj.h:705`. */
void proj_abi_geod_direct(const PJ *P, const PJ_COORD *a, double azimuth,
                          double distance, PJ_COORD *out);

/* `proj_factors` - `src/proj.h:783`. */
void proj_abi_factors(PJ *P, const PJ_COORD *lp, PJ_FACTORS *out);

/* `proj_get_suggested_operation` - `src/proj.h:1426-1429`. */
int proj_abi_get_suggested_operation(PJ_CONTEXT *ctx, PJ_OBJ_LIST *operations,
                                     PJ_DIRECTION direction,
                                     const PJ_COORD *coord);

#ifdef __cplusplus
}
#endif

#endif /* PROJ_ABI_H */