// SPDX-License-Identifier: MIT
// Fork-authored. `FORK-LICENSE.md` records the owner's authorization of that
// grant for this file, and `COPYING` holds upstream's own MIT text.

/* Fork-owned wrappers keep `PJ_COORD` by-value calls inside C; see `src/proj.h`.
 * Zig's union-call lowering differed on some targets (observed with Zig 0.16.0;
 * not rechecked with Zig 0.17.0). */

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