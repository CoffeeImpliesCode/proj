// SPDX-License-Identifier: MIT
// Fork-authored. `FORK-LICENSE.md` records the owner's authorization of that
// grant for this file, and `COPYING` holds upstream's own MIT text.

/* The definitions behind `zig/proj_abi.h`, which is where the reasoning is.
 *
 * Every body below is one call, written the way the C header writes it: the
 * aggregate goes and comes back by value. That is the point of the file - the
 * by-value call is made here, by the compiler that compiled the callee, and the
 * Zig side of the boundary only ever sees pointers and scalars.
 */

#include "proj_abi.h"

void proj_abi_coord(double x, double y, double z, double t, PJ_COORD *out) {
    *out = proj_coord(x, y, z, t);
}

void proj_abi_trans(PJ *P, PJ_DIRECTION direction, const PJ_COORD *in,
                    PJ_COORD *out) {
    *out = proj_trans(P, direction, *in);
}

double proj_abi_lp_dist(const PJ *P, const PJ_COORD *a, const PJ_COORD *b) {
    return proj_lp_dist(P, *a, *b);
}

double proj_abi_lpz_dist(const PJ *P, const PJ_COORD *a, const PJ_COORD *b) {
    return proj_lpz_dist(P, *a, *b);
}

double proj_abi_xy_dist(const PJ_COORD *a, const PJ_COORD *b) {
    return proj_xy_dist(*a, *b);
}

double proj_abi_xyz_dist(const PJ_COORD *a, const PJ_COORD *b) {
    return proj_xyz_dist(*a, *b);
}

void proj_abi_geod(const PJ *P, const PJ_COORD *a, const PJ_COORD *b,
                   PJ_COORD *out) {
    *out = proj_geod(P, *a, *b);
}

void proj_abi_geod_direct(const PJ *P, const PJ_COORD *a, double azimuth,
                          double distance, PJ_COORD *out) {
    *out = proj_geod_direct(P, *a, azimuth, distance);
}

void proj_abi_factors(PJ *P, const PJ_COORD *lp, PJ_FACTORS *out) {
    *out = proj_factors(P, *lp);
}

int proj_abi_get_suggested_operation(PJ_CONTEXT *ctx, PJ_OBJ_LIST *operations,
                                     PJ_DIRECTION direction,
                                     const PJ_COORD *coord) {
    return proj_get_suggested_operation(ctx, operations, direction, *coord);
}