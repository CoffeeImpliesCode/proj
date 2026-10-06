// SPDX-License-Identifier: MIT
//
// Fork-authored. `FORK-LICENSE.md` records the owner's authorization of that
// grant for this file, and `../COPYING` holds upstream's own MIT-style text.

//! PROJ's side of the runtime loader: the names its synchronization binding
//! has, what it requires of a provider beyond resolving its symbols, and what
//! the external ABI boundary for this provider actually is.
//!
//! Everything else about the runtime route is generic. `runtime/loader.zig` is
//! the state machine and the platform layer; `runtime/generate.zig` builds the
//! dispatch from whatever the translation step actually produced;
//! `runtime/graph.zig` wires them together. This file is what makes them PROJ's,
//! and it is the file another SDK replaces.
//!
//! ## What a provider must be
//!
//! **All 292 `proj_*` functions that `src/proj.h` declares, every one of them,
//! all required.** Not 284: see "How the count was established" below, where the
//! difference is worked out name by name. A provider that exports fewer is
//! refused with `MissingSymbol` before anything is published, and there is no
//! optional entry point, because the header has no conditional entry point.
//!
//! The header declares no exported data object, so all 292 are
//! `rt.SymbolKind.function` and this package has no accessor. No other
//! `proj_`-prefixed name in `src/proj.h` is an entry point: the only ones a scan
//! for `proj_[a-z0-9_]+` finds that are *not* followed by `(` are
//! `proj_file_finder`, a callback typedef (`:409`), the four
//! `proj_network_*_type` callback typedefs (`:516`, `:522`, `:527`, `:544`) and
//! `proj_short_name`, a member of `PROJ_UNIT_INFO` (`:1142`). The remaining two
//! matches, `proj_api` and `proj_symbol_rename`, occur only inside comments and
//! inside the `#include` line at `:128`. The opaque handle types - `PJ_CONTEXT`
//! (`:386-387`), `PJ_AREA` (`:203-204`), `PJ_OBJ_LIST` (`:1183`) - are spelled in
//! upper case and are types as well, so the translation step re-exports every one
//! of these as a Zig declaration rather than resolving it as a symbol.
//!
//! `src/proj_experimental.h` is **not** in this set and does not need to be: at
//! this pin its entire body after `#include "proj.h"` is the doc comment
//! "Experimental C API (none currently)" (`src/proj_experimental.h:38-46`)
//! followed by an `extern "C" { }` with nothing between it (`:48-50`). It
//! declares no function, so including it would add one include edge and no name.
//!
//! ### How the count was established
//!
//! Read out of `src/proj.h` at this pin, not taken on trust, with two commands
//! and one subtraction. The lower-case recipe
//! `grep -oE '\bproj_[a-z0-9_]+\s*\(' src/proj.h | sort -u` answers **284**,
//! and that answer is wrong in both directions:
//!
//!   * it **loses nine** names, because nine declarations contain an uppercase
//!     letter that `[a-z0-9_]` cannot match, and the character before their `(`
//!     is then not part of any match: `proj_create_cartesian_2D_cs` (`:1673`),
//!     `proj_create_ellipsoidal_2D_cs` (`:1678`),
//!     `proj_create_ellipsoidal_3D_cs` (`:1684`),
//!     `proj_create_linear_3D_affine_parametric_conversion` (`:1805`),
//!     `proj_crs_create_bound_crs_to_WGS84` (`:1852`),
//!     `proj_crs_create_projected_3D_crs_from_2D` (`:1754`),
//!     `proj_crs_demote_to_2D` (`:1758`), `proj_crs_promote_to_3D` (`:1750`)
//!     and `proj_trans_bounds_3D` (`:644`);
//!   * it **adds one** that the header never declares:
!     `proj_get_crs_list` appears only inside a Doxygen comment at
//!     `src/proj.h:1077`, and the function itself is not declared in this
//!     header at this pin.
//!
//! Widening the character class to `[A-Za-z0-9_]` answers **293**: the nine
//! uppercase names come back and the one comment-only mention is still there, so
//! 293 - 1 mention = **292 declarations**. Every occurrence was then checked to
//! be a declaration and not a mention: the 292 names below are the ones that
//! appear at a declarator, and the whole list is reproduced in
//! `const header_symbols` with the line each one is declared on, so any reader
//! can audit a name against the header without rerunning anything.
//!
//! ### The count is checked at compile time, not asserted in prose
//!
//! `Config` below compares the generated dispatch's routed `symbols` against
//! `header_symbols` in a `comptime` block, as sets rather than positionally
//! (the dispatch's order is the translation's declaration order, which is not
//! sorted). Three failures are named: a count mismatch, a routed name the header
//! does not declare, and a header name the dispatch does not route - plus a
//! routed symbol that is not a function. That is what makes "no more, no fewer"
//! a fact about every configuration this package builds rather than a claim
//! about this one: if a target's translation ever produced a different set, the
//! build stops with the offending name in the message instead of routing it.
//!
//! ### What `optional_symbols` is, and why it is empty
//!
//! It is written out as empty, in code as well as in this paragraph:
//! `Config` below asserts `optional_symbols.len == 0` at compile time. Every
//! declaration in `src/proj.h` is unconditional at this pin. The header's
//! complete set of conditionals is: the include guard (`:118-119`, `:2318`), the
//! `ACCEPT_USE_OF_DEPRECATED_PROJ_API_H` opt-out (`:123-125`), the
//! `PROJ_RENAME_SYMBOLS` include (`:127-129`), the C++ `extern "C"` opening
//! (`:131-133`), the `PJ_DEFAULT_CTX` macro (`:399-403`), and `PROJ_DEPRECATED`
//! choosing among four spellings of the same attribute (`:157-173`). Four
//! declarations go through `PROJ_DEPRECATED` - `proj_errno_string` (`:775`),
//! `proj_list_units` (`:795`), `proj_list_angular_units` (`:797`) and
//! `proj_rtodms` (`:811`) - and every branch of that macro still declares the
//! function; only the attribute changes. A name that were optional would be
//! routed into a nullable table field and its wrapper would stop the program by
//! name when the provider lacks it, which for this header can only ever be a way
//! of deferring an error that is better reported at load time.
//!
//! ### `provider_excluded`, and what the include closure actually contains
//!
//! `provider_excluded` in `runtime/graph.zig` is **empty**, and so is
//! `libc_noise` beside it. Neither is an omission; both are a reading of the
//! header.
//!
//! The translated unit is `zig/translate.h`, and its whole body is two includes:
//! `<proj.h>` and `<proj_constants.h>`. Of the upstream headers those reach:
//!
//!   * `src/proj.h:121` includes `<stddef.h>`, "For size_t". `<stddef.h>`
//!     declares types and macros - `size_t`, `ptrdiff_t`, `NULL`, `offsetof`,
//!     `max_align_t` - and **no function at all**. So the C library contributes
//!     zero `extern` declarations to this translation, zero names to classify,
//!     and zero names that could be misrouted. This is the one header in this
//!     package whose translated closure is empty, and it is empty for a reason
//!     the header states in a comment on the include line.
//!   * `src/proj.h:127-129` includes `proj_symbol_rename.h` **only** under
//!     `PROJ_RENAME_SYMBOLS`, which neither delivery defines (the build puts
//!     `-DPROJ_DLL=` on the compile line for a static build and never defines
//!     `PROJ_RENAME_SYMBOLS`), so at this build the exported names are upstream's
//!     own `proj_*` names. See "The `PROJ_RENAME_SYMBOLS` family" below for what
//!     that means for a provider built the other way.
//!   * `src/proj_constants.h` is 520 `#define`s and nothing else: no function, no
//!     declaration, no type. The translation step evaluates it into Zig `pub
//!     const` declarations that the generator re-exports, so `EPSG_*` and the
//!     rest are available to a facade without one of them being an `extern`.
//!
//! PROJ's own compiled sources include `<math.h>`, `<stdio.h>`, `<string.h>` and
//! more, but the library is a separate translation unit and a declaration
//! reaches the dispatch only if a header this build translates declares it.
//!
//! ## The ABI boundary, stated honestly
//!
//! Three families are real, and one is refused by name.
//!
//! **1. The target C ABI.** `size_t` is the header's `size_t` from `<stddef.h>`,
//! `int` is 32-bit on every target this package builds for
//! (`x86_64-linux-gnu`, `aarch64-linux-gnu`, `aarch64-macos-none`,
//! `x86_64-windows-gnu`, `riscv64-linux-gnu`, `wasm32-wasi`), `double` is
//! IEEE-754 binary64, and `PJ_DIRECTION`, `PJ_TYPE`, `PJ_LOG_LEVEL`,
//! `PJ_GUESSED_WKT_DIALECT` and `PJ_COORDINATE_SYSTEM_TYPE` are C enumerations
//! whose underlying type the provider chose. The build puts `-DPROJ_DLL=` on
//! the compile line, which skips the whole `#ifndef PROJ_DLL` chain at
//! `src/proj.h:143-155` and leaves the macro empty; without that define the GCC
//! branch makes it `__attribute__((visibility("default")))` (`:151`) and the
//! MSVC branch `__declspec(dllexport)`/`__declspec(dllimport)` (`:145-149`),
//! which changes linkage and not layout. A provider is a shared object, so its
//! own `DT_NEEDED` must resolve: it links `libm`, `libdl` where they exist,
//! pthreads where they exist (`-DPROJ_HAS_PTHREADS`), and the vendored SQLite3
//! amalgamation. None of that is negotiable from here and none of it is checked;
//! it is named so that "a compatible provider" means something a caller can
//! reason about.
//!
//! **2. The record layouts.** These cross the boundary by pointer, by value, or
//! as the callee's own storage, and a provider compiled against a different
//! declaration of any of them writes into or reads out of the wrong places.
//!
//!   * `PJ_COORD` (`src/proj.h:315-330`) is a union of fourteen arms over four
//!     doubles: `double v[4]` (`:316`), `PJ_XYZT xyzt` (`:318`),
//!     `PJ_UVWT uvwt` (`:319`), `PJ_LPZT lpzt` (`:320`), `PJ_GEOD geod` (`:321`),
//!     `PJ_OPK opk` (`:322`), `PJ_ENU enu` (`:323`), `PJ_XYZ xyz` (`:324`),
//!     `PJ_UVW uvw` (`:325`), `PJ_LPZ lpz` (`:326`), `PJ_XY xy` (`:327`),
//!     `PJ_UV uv` (`:328`) and `PJ_LP lp` (`:329`). It crosses the boundary by
//!     value in both directions: `proj_coord` (`:656`), `proj_trans` (`:629`),
//!     `proj_geod` (`:676`), `proj_geod_direct` (`:705`),
//!     `proj_get_suggested_operation` (`:1426`), `proj_lp_dist` (`:663`),
//!     `proj_lpz_dist` (`:666`), `proj_xy_dist` (`:669`) and `proj_xyz_dist`
//!     (`:672`) all take or return one, `proj_trans_array` (`:631`) and
//!     `proj_roundtrip` (`:659`) write through a `PJ_COORD *`, and `proj_factors`
//!     (`:783`) takes one by value. So its size and every member offset are ABI,
//!     not convenience. `validate` below checks it through four arms.
//!   * The arm types themselves: `PJ_XYZT` is `{x, y, z, t}` (`:273-275`),
//!     `PJ_UVWT` is `{u, v, w, t}` (`:276-278`), `PJ_LPZT` is `{lam, phi, z, t}`
//!     (`:279-281`), `PJ_XYZ`/`PJ_UVW`/`PJ_LPZ` are the three-member forms
//!     (`:303-311`), and `PJ_GEOD`, `PJ_OPK`, `PJ_ENU` are three-member
//!     (`:282-290`). All are plain `double` runs, so a provider cannot disagree
//!     about a member's width - only about offsets, which `PJ_COORD`'s own
//!     layout check covers.
//!   * `PJ_FACTORS` (`:206-221`, the alias of `struct P5_FACTORS`) is thirteen
//!     `double`s in a fixed order, returned by value from `proj_factors`
//!     (`:783`).
//!   * `PJ_INFO` (`:332-344`) is three `int`s, four `const char *`, one
//!     `const char *const *` and one `size_t`, returned by value from
//!     `proj_info` (`:786`).
//!   * `PJ_PROJ_INFO` (`:346-353`) is three `const char *`, one `int` and one
//!     `double`, returned by value from `proj_pj_info` (`:787`).
//!   * `PROJ_CRS_INFO` (`:1043-1075`) is the record a caller reads *through a
//!     provider's array*, so every member offset is ABI. It is **not** named
//!     `PJ_CRS_INFO`: there is no `PJ_CRS_INFO` at this pin, and a caller that
//!     writes that name is writing one that does not exist.
//!   * `PJ_AREA` is **opaque at the public boundary**: `src/proj.h:203-204`
//!     declares `struct PJ_AREA;` and nothing else. Its definition lives in
//!     `src/proj_internal.h:273-280` and is a C++ struct containing a
//!     `std::string`, so no layout of it crosses this boundary at all. A caller
//!     only ever holds the `PJ_AREA *` that `proj_area_create` (`:607`) hands
//!     back and passes unchanged to `proj_area_set_name` (`:612`),
//!     `proj_area_set_bbox` (`:608`) and `proj_area_destroy` (`:613`). This file
//!     records that rather than describing a layout it cannot see.
//!
//! **3. The allocator, which is libc's inside PROJ.** PROJ returns strings and
//! lists the caller must release, and it releases them with the provider's own
//! allocator, not with anything a Zig caller owns:
//!
//!   * `proj_as_wkt` (`:1277`), `proj_as_proj_string` (`:1280`),
//!     `proj_as_projjson` (`:1284`), `proj_context_errno_string` (`:776`),
//!     `proj_errno_string` (`:775`) and `proj_get_name` (`:1249`) return
//!     `const char *` that is the provider's own storage or its own allocation.
//!     For the `const char *` that is documented as owned by the object
//!     (`proj_get_name`) it is a borrow and nothing is freed; for the strings a
//!     caller must release it is `proj_string_destroy` (`:1355`).
//!   * `proj_get_authorities_from_database` (`:1304`),
//!     `proj_get_codes_from_database` (`:1306`),
//!     `proj_get_geoid_models_from_database` (`:1296`) return a
//!     `PROJ_STRING_LIST` that `proj_string_list_destroy` (`:1187`) releases.
//!   * `proj_get_units_from_database` (`:1328`) returns a
//!     `PROJ_UNIT_INFO **` that `proj_unit_list_destroy` (`:1334`) releases, and
//!     each `PROJ_UNIT_INFO` carries its own `char *` members (`:1120-1146`).
//!   * `proj_get_celestial_body_list_from_database` (`:1311`) returns a
//!     `PROJ_CELESTIAL_BODY_INFO **` that `proj_celestial_body_list_destroy`
//!     (`:1314`) releases.
//!
//! None of that memory comes from a Zig allocator: a provider's
//! `proj_string_destroy` is `free` on the provider's C library, reached through
//! the provider's own `libc`. **A Zig caller cannot supply a leak oracle for
//! any of it**, and neither can this package's test framework: the allocation
//! happens inside the loaded object, whose allocator is not ours to instrument.
//! A facade therefore exposes those returns as borrows or as values it does not
//! free with `Allocator.free`, and this file records that as a boundary rather
//! than pretending a leak check covers it.
//!
//! **4. The `PROJ_RENAME_SYMBOLS` family, which is refused by name.** A provider
//! built with `PROJ_RENAME_SYMBOLS` defines `proj.h` with
//! `proj_symbol_rename.h` included, and that header renames **314** symbols:
//! 291 `proj_*` (`#define proj_area_create internal_proj_area_create` and so on),
//! the 21 bundled GeographicLib `geod_*` entry points, `projinfo` and
//! `pj_release`. Such an object exports `internal_proj_*` and exports **none** of
//! the 292 names under the names this build asks for, so `load` refuses it with
//! `MissingSymbol` at the first of them.
//!
//! That is the correct outcome, not a gap. A PROJ build that renames its symbols
//! is a different external ABI family from one that does not, and nothing in a
//! symbol's spelling says which a given object is. The one detail worth
//! recording because it is not uniform: the generated rename header does **not**
//! mention `proj_crs_is_dynamic` (`:1435`) - all 291 renames are present and
//! that single declaration is absent - so a `PROJ_RENAME_SYMBOLS` build exports
//! 291 names renamed and this one unrenamed, and is still refused, because 291
//! missing is 291 missing.
//!
//! ## What `validate` checks, and what it does not
//!
//! Three checks, run after every symbol has resolved and before anything is
//! published. A non-null answer is `ValidationFailed` and the candidate is
//! closed. None of them compares a version string, and none of them calls an
//! entry point whose failure mode is `abort`.
//!
//!   1. **`proj_context_create()` answers non-null, and `proj_context_destroy`
//!      releases it.** Upstream implements the first as
//!      `new (std::nothrow) pj_ctx(*pj_get_default_ctx())`
//!      (`src/ctx.cpp:305-307`), so a null answer means the provider could not
//!      satisfy one fresh context at all - and it is the provider's own
//!      allocator that failed. The destroy goes through this same table, so the
//!      check never creates a context with one provider and releases it with
//!      another, and `proj_context_destroy` is `delete ctx` (`src/ctx.cpp:318`)
//!      after two explicit no-op guards (`:310-314`). It also touches no
//!      database: `pj_get_default_ctx()` (`src/ctx.cpp:188-194`) is a function
//!      -local static default context, and nothing in either function opens
//!      `proj.db`. **What it does not prove:** that the provider's later
//!      allocations succeed, and nothing about the C++ runtime underneath it
//!      beyond the one `new` this call makes.
//!   2. **`proj_coord(1.5, 2.5, 3.5, 4.5)` reads back through every arm of this
//!      build's `PJ_COORD`.** Upstream writes exactly four stores -
//!      `res.v[0] = x; res.v[1] = y; res.v[2] = z; res.v[3] = t;` and returns it
//!      (`src/coordinates.cpp:38-45`) - so this is a direct statement about the
//!      union's layout rather than a coincidence: a provider whose `PJ_COORD`
//!      packed, reordered, or narrowed its arms would not place 1.5 at
//!      `v[0]`. The values are exact in binary64 (all four are dyadic
//!      rationals), so the comparison is `!=` against a constant and not a
//!      tolerance. The arms checked are `v[0..3]` (the four `double`s
//!      themselves), `xyzt` (`.x .y .z .t`, the member-name aliasing
//!      `src/proj.h:273-275`), `xyz` (`.x .y .z`) and `lpz` (`.lam .phi .z`) -
//!      between them, every member name and every offset in the union that a
//!      caller could name, since every other arm of `PJ_COORD` is a prefix of one
//!      of these three. **What it does not prove:** anything about a provider
//!      whose union happens to be laid out compatibly but whose *other* records
//!      disagree; those are not checked at load time and the tests are where they
//!      are observed.
//!   3. **`proj_create(ctx, "+proj=longlat +ellps=WGS84 +type=crs")` answers
//!      non-null, `proj_get_type` calls it `PJ_TYPE_GEOGRAPHIC_2D_CRS`, and
//!      `proj_destroy` releases it.** This is the object lifecycle check, and it
//!      is deliberately database-free: `proj_create` only opens `proj.db` when
//!      the text has no `proj=` or has an `init=`
//!      (`src/iso19111/c_api.cpp:624-627`), and this definition has a `proj=`
//!      and no `init=`, so the database is never touched. That the definition is
//!      a geographic 2D CRS is upstream's own statement: `+proj=longlat +ellps=
//!      WGS84 +type=crs` builds a `GeographicCRS` with `CS[ellipsoidal,2]`
//!      (`test/unit/test_io.cpp:11082-11097`), and `proj_get_type` maps a
//!      `GeographicCRS` with a two-axis coordinate system to
//!      `PJ_TYPE_GEOGRAPHIC_2D_CRS` (`src/iso19111/c_api.cpp:1282-1284`).
//!      `proj_get_type` answers `PJ_TYPE_UNKNOWN` for a null object
//!      (`:1240-1242`) and otherwise walks the ISO 19111 object, so a non-null
//!      answer of the right type is a statement about the provider's type
//!      registry and not about a hard-coded word. **What it does not prove:**
//!      anything numerical, and nothing about grid availability, which for this
//!      package is a data statement (`§4` of the shared contract) rather than a
//!      build result.
//!
//! Everything `validate` calls is one of the 292 symbols that already resolved,
//! every call works on storage `validate` owns or on a context it created, it
//! runs in one thread before publication, it allocates nothing itself, and it
//! leaves nothing behind except the provider's own one-time statics - the
//! default context of check 1, which is `static` (`src/ctx.cpp:192`) and
//! process-lifetime by upstream's own design. It has no `proj.db`, no network,
//! no environment variable and no grid.
//!
//! What `validate` deliberately does **not** call is `proj_errno_string` or
//! anything else for a version. PROJ publishes no symbol that answers "which
//! version are you": `PROJ_VERSION_MAJOR`/`_MINOR`/`_PATCH` (`src/proj.h:176-178`)
//! are preprocessor macros, so they are constants in *this* build's translation
//! and there is nothing exported to ask a provider. `PJ_INFO` carries
//! `major`/`minor`/`patch` (`src/proj.h:333-335`) but it is filled in from the
//! same macros, so reading it would be reading this build's own constants back
//! out of the provider's memory, which proves nothing about the provider. A
//! version check here would be a check that cannot fail, which is worse than no
//! check at all: this file names the boundary it can establish and does not
//! dress up a constant as one.

const rt = @import("rt");
const std = @import("std");

/// The synchronization this loader calls, bound by exact name.
///
/// The names below are `runtime/sync.h` compiled with
/// `RT_SYNC_PREFIX=proj_rt`, which is what `runtime/graph.zig` passes. Two
/// spellings of that prefix have to agree: this file names the symbols, and
/// graph.zig defines the macro. A build where they disagree does not link, and
/// that is the whole error report: there is no runtime path that could hide it.
///
/// The core in `runtime/loader.zig` never names a symbol of its own, which is
/// what lets two SDKs, or two configurations of one SDK, hold their own loader
/// state in one process without sharing any of it.
pub const Sync = struct {
    extern fn proj_rt_lock() void;
    extern fn proj_rt_unlock() void;
    extern fn proj_rt_wait() void;
    extern fn proj_rt_broadcast() void;
    // `unsigned long long`. Declared as u64, which is the same type in every
    // ABI this SDK targets: 64-bit on x86_64, aarch64, riscv64 and wasm32.
    extern fn proj_rt_thread_self() u64;

    pub fn lock() void {
        proj_rt_lock();
    }
    pub fn unlock() void {
        proj_rt_unlock();
    }
    pub fn wait() void {
        proj_rt_wait();
    }
    pub fn broadcast() void {
        proj_rt_broadcast();
    }
    pub fn threadSelf() u64 {
        return proj_rt_thread_self();
    }
};

/// The four coordinates `validate` writes through `proj_coord` and reads back.
///
/// Exact in binary64 - each is a dyadic rational - so the layout check is `!=`
/// against a constant rather than a tolerance, and a provider that agrees to
/// within a rounding error still fails it if it disagrees about a field's place.
const check_x: f64 = 1.5;
const check_y: f64 = 2.5;
const check_z: f64 = 3.5;
const check_t: f64 = 4.5;

/// Every `proj_*` function `src/proj.h` declares at this pin, with the line it
/// is declared on.
///
/// Derived, not written from memory: see "How the count was established" above.
/// This is the list `Config` checks the generated dispatch against, and it is
/// the record of what a provider owes this build. Sorted so a diff against a
/// future header reads as a change in the set rather than in a reordering.
const header_symbols = [_][]const u8{
    "proj_alter_id",                     // src/proj.h:1727
    "proj_alter_name",                   // src/proj.h:1725
    "proj_angular_input",                // src/proj.h:623
    "proj_angular_output",               // src/proj.h:624
    "proj_area_create",                  // src/proj.h:607
    "proj_area_destroy",                 // src/proj.h:613
    "proj_area_set_bbox",                // src/proj.h:608
    "proj_area_set_name",                // src/proj.h:612
    "proj_as_proj_string",               // src/proj.h:1280
    "proj_as_projjson",                  // src/proj.h:1284
    "proj_as_wkt",                       // src/proj.h:1277
    "proj_assign_context",               // src/proj.h:604
    "proj_celestial_body_list_destroy",  // src/proj.h:1314
    "proj_cleanup",                      // src/proj.h:816
    "proj_clone",                        // src/proj.h:1226
    "proj_concatoperation_get_step",     // src/proj.h:1547
    "proj_concatoperation_get_step_count", // src/proj.h:1544
    "proj_context_clone",                // src/proj.h:406
    "proj_context_create",               // src/proj.h:404
    "proj_context_destroy",              // src/proj.h:405
    "proj_context_errno",                // src/proj.h:769
    "proj_context_errno_string",         // src/proj.h:776
    "proj_context_get_database_metadata", // src/proj.h:1198
    "proj_context_get_database_path",    // src/proj.h:1196
    "proj_context_get_database_structure", // src/proj.h:1201
    "proj_context_get_url_endpoint",     // src/proj.h:561
    "proj_context_get_use_proj4_init_rules", // src/proj.h:422
    "proj_context_get_user_writable_directory", // src/proj.h:563
    "proj_context_guess_wkt_dialect",    // src/proj.h:1204
    "proj_context_is_network_enabled",   // src/proj.h:557
    "proj_context_set_autoclose_database", // src/proj.h:1189
    "proj_context_set_ca_bundle_path",   // src/proj.h:418
    "proj_context_set_database_path",    // src/proj.h:1192
    "proj_context_set_enable_network",   // src/proj.h:555
    "proj_context_set_file_finder",      // src/proj.h:413
    "proj_context_set_fileapi",          // src/proj.h:490
    "proj_context_set_network_callbacks", // src/proj.h:549
    "proj_context_set_search_paths",     // src/proj.h:416
    "proj_context_set_sqlite3_vfs_name", // src/proj.h:494
    "proj_context_set_url_endpoint",     // src/proj.h:559
    "proj_context_set_user_writable_directory", // src/proj.h:566
    "proj_context_use_proj4_init_rules", // src/proj.h:421
    "proj_convert_conversion_to_other_method", // src/proj.h:1829
    "proj_coord",                        // src/proj.h:656
    "proj_coordinate_metadata_create",   // src/proj.h:1551
    "proj_coordinate_metadata_get_epoch", // src/proj.h:1554
    "proj_coordoperation_create_inverse", // src/proj.h:1542
    "proj_coordoperation_get_accuracy",  // src/proj.h:1535
    "proj_coordoperation_get_grid_used", // src/proj.h:1529
    "proj_coordoperation_get_grid_used_count", // src/proj.h:1526
    "proj_coordoperation_get_method_info", // src/proj.h:1499
    "proj_coordoperation_get_param",     // src/proj.h:1519
    "proj_coordoperation_get_param_count", // src/proj.h:1512
    "proj_coordoperation_get_param_index", // src/proj.h:1515
    "proj_coordoperation_get_towgs84_values", // src/proj.h:1538
    "proj_coordoperation_has_ballpark_transformation", // src/proj.h:1506
    "proj_coordoperation_is_instantiable", // src/proj.h:1503
    "proj_coordoperation_requires_per_coordinate_input_time", // src/proj.h:1509
    "proj_create",                       // src/proj.h:593
    "proj_create_argv",                  // src/proj.h:594
    "proj_create_cartesian_2D_cs",       // src/proj.h:1673
    "proj_create_compound_crs",          // src/proj.h:1776
    "proj_create_conversion",            // src/proj.h:1779
    "proj_create_conversion_albers_equal_area", // src/proj.h:1900
    "proj_create_conversion_american_polyconic", // src/proj.h:2191
    "proj_create_conversion_azimuthal_equidistant", // src/proj.h:1945
    "proj_create_conversion_bonne",      // src/proj.h:1957
    "proj_create_conversion_cassini_soldner", // src/proj.h:1975
    "proj_create_conversion_eckert_i",   // src/proj.h:1988
    "proj_create_conversion_eckert_ii",  // src/proj.h:1994
    "proj_create_conversion_eckert_iii", // src/proj.h:2000
    "proj_create_conversion_eckert_iv",  // src/proj.h:2006
    "proj_create_conversion_eckert_v",   // src/proj.h:2012
    "proj_create_conversion_eckert_vi",  // src/proj.h:2018
    "proj_create_conversion_equal_earth", // src/proj.h:2287
    "proj_create_conversion_equidistant_conic", // src/proj.h:1981
    "proj_create_conversion_equidistant_cylindrical", // src/proj.h:2024
    "proj_create_conversion_equidistant_cylindrical_spherical", // src/proj.h:2030
    "proj_create_conversion_gall",       // src/proj.h:2036
    "proj_create_conversion_gauss_schreiber_transverse_mercator", // src/proj.h:1869
    "proj_create_conversion_geostationary_satellite_sweep_x", // src/proj.h:2056
    "proj_create_conversion_geostationary_satellite_sweep_y", // src/proj.h:2062
    "proj_create_conversion_gnomonic",   // src/proj.h:2068
    "proj_create_conversion_goode_homolosine", // src/proj.h:2044
    "proj_create_conversion_guam_projection", // src/proj.h:1951
    "proj_create_conversion_hotine_oblique_mercator_two_point_natural_origin", // src/proj.h:2091
    "proj_create_conversion_hotine_oblique_mercator_variant_a", // src/proj.h:2074
    "proj_create_conversion_hotine_oblique_mercator_variant_b", // src/proj.h:2082
    "proj_create_conversion_international_map_world_polyconic", // src/proj.h:2106
    "proj_create_conversion_interrupted_goode_homolosine", // src/proj.h:2050
    "proj_create_conversion_krovak",     // src/proj.h:2122
    "proj_create_conversion_krovak_north_oriented", // src/proj.h:2113
    "proj_create_conversion_laborde_oblique_mercator", // src/proj.h:2099
    "proj_create_conversion_lambert_azimuthal_equal_area", // src/proj.h:2131
    "proj_create_conversion_lambert_conic_conformal_1sp", // src/proj.h:1908
    "proj_create_conversion_lambert_conic_conformal_1sp_variant_b", // src/proj.h:1914
    "proj_create_conversion_lambert_conic_conformal_2sp", // src/proj.h:1921
    "proj_create_conversion_lambert_conic_conformal_2sp_belgium", // src/proj.h:1937
    "proj_create_conversion_lambert_conic_conformal_2sp_michigan", // src/proj.h:1929
    "proj_create_conversion_lambert_cylindrical_equal_area", // src/proj.h:1969
    "proj_create_conversion_lambert_cylindrical_equal_area_spherical", // src/proj.h:1963
    "proj_create_conversion_local_orthographic", // src/proj.h:2185
    "proj_create_conversion_mercator_variant_a", // src/proj.h:2143
    "proj_create_conversion_mercator_variant_b", // src/proj.h:2149
    "proj_create_conversion_miller_cylindrical", // src/proj.h:2137
    "proj_create_conversion_mollweide",  // src/proj.h:2161
    "proj_create_conversion_new_zealand_mapping_grid", // src/proj.h:2167
    "proj_create_conversion_oblique_stereographic", // src/proj.h:2173
    "proj_create_conversion_orthographic", // src/proj.h:2179
    "proj_create_conversion_polar_stereographic_variant_a", // src/proj.h:2197
    "proj_create_conversion_polar_stereographic_variant_b", // src/proj.h:2203
    "proj_create_conversion_pole_rotation_grib_convention", // src/proj.h:2300
    "proj_create_conversion_pole_rotation_netcdf_cf_convention", // src/proj.h:2305
    "proj_create_conversion_popular_visualisation_pseudo_mercator", // src/proj.h:2155
    "proj_create_conversion_quadrilateralized_spherical_cube", // src/proj.h:2275
    "proj_create_conversion_robinson",   // src/proj.h:2209
    "proj_create_conversion_sinusoidal", // src/proj.h:2215
    "proj_create_conversion_spherical_cross_track_height", // src/proj.h:2281
    "proj_create_conversion_stereographic", // src/proj.h:2221
    "proj_create_conversion_transverse_mercator", // src/proj.h:1863
    "proj_create_conversion_transverse_mercator_south_oriented", // src/proj.h:1875
    "proj_create_conversion_tunisia_mapping_grid", // src/proj.h:1888
    "proj_create_conversion_tunisia_mining_grid", // src/proj.h:1894
    "proj_create_conversion_two_point_equidistant", // src/proj.h:1881
    "proj_create_conversion_utm",        // src/proj.h:1861
    "proj_create_conversion_van_der_grinten", // src/proj.h:2227
    "proj_create_conversion_vertical_perspective", // src/proj.h:2293
    "proj_create_conversion_wagner_i",   // src/proj.h:2233
    "proj_create_conversion_wagner_ii",  // src/proj.h:2239
    "proj_create_conversion_wagner_iii", // src/proj.h:2245
    "proj_create_conversion_wagner_iv",  // src/proj.h:2251
    "proj_create_conversion_wagner_v",   // src/proj.h:2257
    "proj_create_conversion_wagner_vi",  // src/proj.h:2263
    "proj_create_conversion_wagner_vii", // src/proj.h:2269
    "proj_create_crs_to_crs",            // src/proj.h:595
    "proj_create_crs_to_crs_from_pj",    // src/proj.h:597
    "proj_create_cs",                    // src/proj.h:1670
    "proj_create_derived_geographic_crs", // src/proj.h:1717
    "proj_create_derived_projected_crs", // src/proj.h:1838
    "proj_create_ellipsoidal_2D_cs",     // src/proj.h:1678
    "proj_create_ellipsoidal_3D_cs",     // src/proj.h:1684
    "proj_create_engineering_crs",       // src/proj.h:1761
    "proj_create_from_database",         // src/proj.h:1212
    "proj_create_from_name",             // src/proj.h:1229
    "proj_create_from_wkt",              // src/proj.h:1207
    "proj_create_geocentric_crs",        // src/proj.h:1706
    "proj_create_geocentric_crs_from_datum", // src/proj.h:1713
    "proj_create_geographic_crs",        // src/proj.h:1694
    "proj_create_geographic_crs_from_datum", // src/proj.h:1702
    "proj_create_linear_3D_affine_parametric_conversion", // src/proj.h:1805
    "proj_create_linear_affine_parametric_conversion", // src/proj.h:1794
    "proj_create_operation_factory_context", // src/proj.h:1363
    "proj_create_operations",            // src/proj.h:1415
    "proj_create_projected_crs",         // src/proj.h:1833
    "proj_create_transformation",        // src/proj.h:1821
    "proj_create_vertical_crs",          // src/proj.h:1763
    "proj_create_vertical_crs_ex",       // src/proj.h:1768
    "proj_crs_add_horizontal_derived_conversion", // src/proj.h:1844
    "proj_crs_alter_cs_angular_unit",    // src/proj.h:1733
    "proj_crs_alter_cs_linear_unit",     // src/proj.h:1739
    "proj_crs_alter_geodetic_crs",       // src/proj.h:1730
    "proj_crs_alter_parameters_linear_unit", // src/proj.h:1745
    "proj_crs_create_bound_crs",         // src/proj.h:1848
    "proj_crs_create_bound_crs_to_WGS84", // src/proj.h:1852
    "proj_crs_create_bound_vertical_crs", // src/proj.h:1855
    "proj_crs_create_projected_3D_crs_from_2D", // src/proj.h:1754
    "proj_crs_demote_to_2D",             // src/proj.h:1758
    "proj_crs_get_coordinate_system",    // src/proj.h:1465
    "proj_crs_get_coordoperation",       // src/proj.h:1497
    "proj_crs_get_datum",                // src/proj.h:1443
    "proj_crs_get_datum_ensemble",       // src/proj.h:1445
    "proj_crs_get_datum_forced",         // src/proj.h:1447
    "proj_crs_get_geodetic_crs",         // src/proj.h:1437
    "proj_crs_get_horizontal_datum",     // src/proj.h:1439
    "proj_crs_get_sub_crs",              // src/proj.h:1441
    "proj_crs_has_point_motion_operation", // src/proj.h:1449
    "proj_crs_info_list_destroy",        // src/proj.h:1326
    "proj_crs_is_derived",               // src/proj.h:1433
    "proj_crs_is_dynamic",               // src/proj.h:1435
    "proj_crs_promote_to_3D",            // src/proj.h:1750
    "proj_cs_get_axis_count",            // src/proj.h:1470
    "proj_cs_get_axis_info",             // src/proj.h:1472
    "proj_cs_get_type",                  // src/proj.h:1467
    "proj_datum_ensemble_get_accuracy",  // src/proj.h:1455
    "proj_datum_ensemble_get_member",    // src/proj.h:1458
    "proj_datum_ensemble_get_member_count", // src/proj.h:1452
    "proj_degree_input",                 // src/proj.h:626
    "proj_degree_output",                // src/proj.h:627
    "proj_destroy",                      // src/proj.h:605
    "proj_dmstor",                       // src/proj.h:810
    "proj_download_file",                // src/proj.h:584
    "proj_dynamic_datum_get_frame_reference_epoch", // src/proj.h:1462
    "proj_ellipsoid_get_parameters",     // src/proj.h:1480
    "proj_errno",                        // src/proj.h:770
    "proj_errno_reset",                  // src/proj.h:772
    "proj_errno_restore",                // src/proj.h:773
    "proj_errno_set",                    // src/proj.h:771
    "proj_errno_string",                 // src/proj.h:775
    "proj_factors",                      // src/proj.h:783
    "proj_geod",                         // src/proj.h:676
    "proj_geod_direct",                  // src/proj.h:705
    "proj_get_area_of_use",              // src/proj.h:1263
    "proj_get_area_of_use_ex",           // src/proj.h:1270
    "proj_get_authorities_from_database", // src/proj.h:1304
    "proj_get_celestial_body_list_from_database", // src/proj.h:1311
    "proj_get_celestial_body_name",      // src/proj.h:1486
    "proj_get_codes_from_database",      // src/proj.h:1306
    "proj_get_crs_info_list_from_database", // src/proj.h:1322
    "proj_get_crs_list_parameters_create", // src/proj.h:1316
    "proj_get_crs_list_parameters_destroy", // src/proj.h:1319
    "proj_get_domain_count",             // src/proj.h:1257
    "proj_get_ellipsoid",                // src/proj.h:1478
    "proj_get_geoid_models_from_database", // src/proj.h:1296
    "proj_get_id_auth_name",             // src/proj.h:1251
    "proj_get_id_code",                  // src/proj.h:1253
    "proj_get_insert_statements",        // src/proj.h:1346
    "proj_get_name",                     // src/proj.h:1249
    "proj_get_non_deprecated",           // src/proj.h:1238
    "proj_get_prime_meridian",           // src/proj.h:1489
    "proj_get_remarks",                  // src/proj.h:1255
    "proj_get_scope",                    // src/proj.h:1259
    "proj_get_scope_ex",                 // src/proj.h:1261
    "proj_get_source_crs",               // src/proj.h:1287
    "proj_get_suggested_operation",      // src/proj.h:1426
    "proj_get_target_crs",               // src/proj.h:1289
    "proj_get_type",                     // src/proj.h:1234
    "proj_get_units_from_database",      // src/proj.h:1328
    "proj_grid_cache_clear",             // src/proj.h:579
    "proj_grid_cache_set_enable",        // src/proj.h:570
    "proj_grid_cache_set_filename",      // src/proj.h:572
    "proj_grid_cache_set_max_size",      // src/proj.h:575
    "proj_grid_cache_set_ttl",           // src/proj.h:577
    "proj_grid_get_info_from_database",  // src/proj.h:1221
    "proj_grid_info",                    // src/proj.h:788
    "proj_identify",                     // src/proj.h:1291
    "proj_info",                         // src/proj.h:786
    "proj_init_info",                    // src/proj.h:789
    "proj_insert_object_session_create", // src/proj.h:1341
    "proj_insert_object_session_destroy", // src/proj.h:1343
    "proj_int_list_destroy",             // src/proj.h:1300
    "proj_is_crs",                       // src/proj.h:1247
    "proj_is_deprecated",                // src/proj.h:1236
    "proj_is_derived_crs",               // src/proj.h:1723
    "proj_is_download_needed",           // src/proj.h:581
    "proj_is_equivalent_to",             // src/proj.h:1240
    "proj_is_equivalent_to_with_ctx",    // src/proj.h:1243
    "proj_list_angular_units",           // src/proj.h:797
    "proj_list_destroy",                 // src/proj.h:1424
    "proj_list_ellps",                   // src/proj.h:794
    "proj_list_get",                     // src/proj.h:1421
    "proj_list_get_count",               // src/proj.h:1419
    "proj_list_operations",              // src/proj.h:793
    "proj_list_prime_meridians",         // src/proj.h:799
    "proj_list_units",                   // src/proj.h:795
    "proj_log_func",                     // src/proj.h:779
    "proj_log_level",                    // src/proj.h:778
    "proj_lp_dist",                      // src/proj.h:663
    "proj_lpz_dist",                     // src/proj.h:666
    "proj_normalize_for_visualization",  // src/proj.h:602
    "proj_operation_factory_context_destroy", // src/proj.h:1366
    "proj_operation_factory_context_set_allow_ballpark_transformations", // src/proj.h:1409
    "proj_operation_factory_context_set_allow_use_intermediate_crs", // src/proj.h:1398
    "proj_operation_factory_context_set_allowed_intermediate_crs", // src/proj.h:1402
    "proj_operation_factory_context_set_area_of_interest", // src/proj.h:1372
    "proj_operation_factory_context_set_area_of_interest_name", // src/proj.h:1377
    "proj_operation_factory_context_set_crs_extent_use", // src/proj.h:1381
    "proj_operation_factory_context_set_desired_accuracy", // src/proj.h:1368
    "proj_operation_factory_context_set_discard_superseded", // src/proj.h:1406
    "proj_operation_factory_context_set_grid_availability_use", // src/proj.h:1389
    "proj_operation_factory_context_set_spatial_criterion", // src/proj.h:1385
    "proj_operation_factory_context_set_use_proj_alternative_grid_names", // src/proj.h:1394
    "proj_pj_info",                      // src/proj.h:787
    "proj_prime_meridian_get_parameters", // src/proj.h:1491
    "proj_query_geodetic_crs_from_datum", // src/proj.h:1690
    "proj_roundtrip",                    // src/proj.h:659
    "proj_rtodms",                       // src/proj.h:811
    "proj_rtodms2",                      // src/proj.h:813
    "proj_string_destroy",               // src/proj.h:1355
    "proj_string_list_destroy",          // src/proj.h:1187
    "proj_suggests_code_for",            // src/proj.h:1351
    "proj_todeg",                        // src/proj.h:808
    "proj_torad",                        // src/proj.h:807
    "proj_trans",                        // src/proj.h:629
    "proj_trans_array",                  // src/proj.h:631
    "proj_trans_bounds",                 // src/proj.h:638
    "proj_trans_bounds_3D",              // src/proj.h:644
    "proj_trans_generic",                // src/proj.h:633
    "proj_trans_get_last_used_operation", // src/proj.h:630
    "proj_unit_list_destroy",            // src/proj.h:1334
    "proj_uom_get_info_from_database",   // src/proj.h:1217
    "proj_xy_dist",                      // src/proj.h:669
    "proj_xyz_dist",                     // src/proj.h:672
};

/// Whether `names` holds `name`, exactly.
///
/// `std.mem.eql` rather than pointer identity, because the dispatch's names and
/// the list's names come from two different texts and only their bytes matter.
fn listHas(names: []const []const u8, name: []const u8) bool {
    for (names) |candidate| {
        if (std.mem.eql(u8, candidate, name)) return true;
    }
    return false;
}

/// The same question of `symbols`, which is a slice of `rt.Symbol`.
fn tableHas(names: []const rt.Symbol, name: []const u8) bool {
    for (names) |symbol| {
        if (std.mem.eql(u8, symbol.name, name)) return true;
    }
    return false;
}

/// The loader's configuration for this SDK, given the dispatch that owns the
/// table.
///
/// `dispatch` is the generated module, passed as a type by the dispatch itself
/// so that this file never has to import it. The direction is one-way on
/// purpose: the descriptor knows what the loader needs, the dispatch knows what
/// the header said, and neither imports the other.
pub fn Config(comptime dispatch: type) type {
    return struct {
        /// Named in the pre-load panic, so the message says which library was
        /// reached for before it was loaded.
        pub const library_name = "proj";

        /// The table the generated dispatch declares, and the symbols it needs
        /// to fill it. Both come from the translated header, not from this file;
        /// what this file does is hold the header's own list and check the two
        /// against each other, in the `comptime` block below.
        pub const table = dispatch.Table;
        pub const symbols = dispatch.symbols;
        pub const optional_symbols = dispatch.optional_symbols;

        /// This project's namespaced synchronization binding.
        pub const sync = Sync;

        /// Set equality, checked rather than claimed.
        ///
        /// Four failures are named, and each one is a fact about this build's
        /// translation that a reader would otherwise have to take on trust:
        ///
        ///   * a count mismatch, which means the header and the translation
        ///     disagree about how many entry points there are;
        ///   * a routed name the header does not declare, which means
        ///     something reached the translation that is not PROJ's - the only
        ///     way that can happen is the include closure, so the message says
        ///     so and points at `graph.zig`'s `libc_noise`;
        ///   * a declared name the dispatch does not route, which means a
        ///     declaration was dropped between the header and the translation;
        ///   * a routed symbol that is not a function, which would mean an
        ///     `extern` object appeared where this package expects none.
        ///
        /// Position is deliberately not compared: the dispatch's order is the
        /// translation's declaration order and `header_symbols` is sorted, so
        /// only the sets mean anything.
        ///
        /// `optional_symbols.len == 0` is checked here for the same reason and
        /// with the reason stated above the list: `src/proj.h` has no
        /// conditional entry point at this pin, so there is nothing for it to
        /// hold.
        comptime {
            if (symbols.len != header_symbols.len) {
                @compileError(std.fmt.comptimePrint(
                    "runtime/library.zig: the dispatch routes {d} symbols and " ++
                        "src/proj.h declares {d} proj_* functions; the header " ++
                        "and the translation disagree about the entry points",
                    .{ symbols.len, header_symbols.len },
                ));
            }
            for (symbols) |symbol| {
                if (symbol.kind != .function) {
                    @compileError(std.fmt.comptimePrint(
                        "runtime/library.zig: {s} is routed as exported data; " ++
                            "every proj_* function src/proj.h declares is a " ++
                            "function and this package has no accessor",
                        .{symbol.name},
                    ));
                }
                if (!listHas(&header_symbols, symbol.name)) {
                    @compileError(std.fmt.comptimePrint(
                        "runtime/library.zig: the dispatch routes {s}, which " ++
                            "src/proj.h does not declare; a name that is not " ++
                            "the provider's reached the translation through the " ++
                            "include closure and belongs in graph.zig's " ++
                            "libc_noise, not in a provider's table",
                        .{symbol.name},
                    ));
                }
            }
            for (header_symbols) |name| {
                if (!tableHas(symbols, name)) {
                    @compileError(std.fmt.comptimePrint(
                        "runtime/library.zig: src/proj.h declares {s} but the " ++
                            "dispatch does not route it; the translation did " ++
                            "not reach that declaration",
                        .{name},
                    ));
                }
            }
            if (optional_symbols.len != 0) {
                @compileError(std.fmt.comptimePrint(
                    "runtime/library.zig: the translation routed {d} optional " ++
                        "symbol(s), but src/proj.h has no conditional entry " ++
                        "point at this pin and every proj_* function it " ++
                        "declares is required",
                    .{optional_symbols.len},
                ));
            }
        }

        pub fn tablePtr() *table {
            return dispatch.tablePtr();
        }

        pub fn ready() *rt.Ready {
            return &dispatch.ready;
        }

        pub fn assign(comptime index: usize, dst: *table, address: *const anyopaque) void {
            dispatch.assign(index, dst, address);
        }

        /// One resolved address into one optional table field, and the empty
        /// case beside it. Both index `optional_symbols`, which is empty at this
        /// configuration, and both are kept because the loader calls them for
        /// every optional symbol before each attempt and because a build that
        /// did gain a conditional entry point would need them.
        pub inline fn assignOptional(comptime index: usize, dst: *table, address: *const anyopaque) void {
            dispatch.assignOptional(index, dst, address);
        }

        pub inline fn assignMissing(comptime index: usize, dst: *table) void {
            dispatch.assignMissing(index, dst);
        }

        /// The library-specific checks, run after every symbol resolved and
        /// before anything is published.
        ///
        /// A non-null answer is `ValidationFailed` and the candidate is closed
        /// without being published. What each check proves and what it does not
        /// is stated in the module comment above; in short: one context can be
        /// created and destroyed, this build's `PJ_COORD` is laid out where the
        /// header says it is, and one CRS can be built from a PROJ string,
        /// typed and destroyed without a database.
        ///
        /// Nothing here allocates, nothing here reads `proj.db`, nothing here
        /// needs the network, and every symbol called is one of the 292 that
        /// already resolved - so the work is entirely on storage this function
        /// owns, in one thread, before publication.
        pub fn validate(dst: *const table) ?[]const u8 {
            // `proj_context_create` is `new (std::nothrow) pj_ctx(*pj_get_default_ctx())`
            // upstream (src/ctx.cpp:305-307): one fresh context, out of the
            // provider's own allocator, with no database open.
            //
            // `@intFromPtr` is the null test rather than `== null` because it is
            // the one spelling that is correct whether the translated return
            // type is `*PJ_CONTEXT` or `?*PJ_CONTEXT` (`doc/langref.html`,
            // `@intFromPtr`: "value can be *T or ?*T"), and which of the two a
            // given target's translation produced is not a thing this file can
            // know at compile time.
            const ctx = dst.proj_context_create();
            if (@intFromPtr(ctx) == 0) {
                return "proj_context_create() answered null, so this provider " ++
                    "could not satisfy one fresh context at all";
            }
            // Declared first, so it runs last: the CRS below is released before
            // the context that owns it.
            defer _ = dst.proj_context_destroy(ctx);

            // `proj_coord` writes exactly four stores into `v[0..3]` and returns
            // the union by value (src/coordinates.cpp:38-45). Reading them back
            // through three of the arms is a layout check against the provider:
            // `v` is the four doubles themselves, `xyzt` is the member-name
            // aliasing of the same four (src/proj.h:273-275), `xyz` is the
            // three-member form (`:303-305`) and `lpz` is the latitude/longitude
            // three-member form (`:309-311`). Every other arm of `PJ_COORD` is a
            // prefix of one of these three, so between them these four reads
            // cover every offset and every member name the union has.
            //
            // The four values are exact in binary64, so this is `!=` against a
            // constant and not a tolerance.
            const coord = dst.proj_coord(check_x, check_y, check_z, check_t);
            if (coord.v[0] != check_x or coord.v[1] != check_y or
                coord.v[2] != check_z or coord.v[3] != check_t)
            {
                return "proj_coord() did not store its four arguments where " ++
                    "src/proj.h:316-317 says the double v[4] of PJ_COORD is, " ++
                    "so this provider was compiled against a different " ++
                    "declaration of that union";
            }
            if (coord.xyzt.x != check_x or coord.xyzt.y != check_y or
                coord.xyzt.z != check_z or coord.xyzt.t != check_t)
            {
                return "proj_coord() did not store its four arguments where " ++
                    "this header's PJ_XYZT xyzt arm (src/proj.h:273-275, :318) " ++
                    "says they go, so this provider's PJ_COORD layout is not " ++
                    "the one these headers describe";
            }
            if (coord.xyz.x != check_x or coord.xyz.y != check_y or coord.xyz.z != check_z) {
                return "proj_coord() did not store the first three arguments " ++
                    "where this header's PJ_XYZ xyz arm (src/proj.h:303-305, " ++
                    ":324) says they go, so this provider's PJ_COORD layout is " ++
                    "not the one these headers describe";
            }
            if (coord.lpz.lam != check_x or coord.lpz.phi != check_y or coord.lpz.z != check_z) {
                return "proj_coord() did not store the first three arguments " ++
                    "where this header's PJ_LPZ lpz arm (src/proj.h:309-311, " ++
                    ":326) says they go, so this provider's PJ_COORD layout is " ++
                    "not the one these headers describe";
            }

            // The object lifecycle, with no database: `proj_create` only opens
            // proj.db when the text has no "proj=" or has an "init="
            // (src/iso19111/c_api.cpp:624-627), and this definition has a
            // "proj=" and no "init=". That the answer is a geographic 2D CRS is
            // upstream's own reading of this string
            // (test/unit/test_io.cpp:11082-11097) mapped through
            // `proj_get_type` (src/iso19111/c_api.cpp:1282-1284), so the check
            // is a statement about the provider's type registry and not about a
            // word this file chose.
            const crs = dst.proj_create(ctx, "+proj=longlat +ellps=WGS84 +type=crs");
            if (@intFromPtr(crs) == 0) {
                return "proj_create(\"+proj=longlat +ellps=WGS84 +type=crs\") " ++
                    "answered null, so this provider could not build a CRS from " ++
                    "a PROJ string with no proj.db available";
            }
            defer _ = dst.proj_destroy(crs);

            const kind = dst.proj_get_type(crs);
            // The comparison is against the *translated* constant, not a number
            // written here. `PJ_TYPE_GEOGRAPHIC_2D_CRS` arrives from
            // `src/proj.h:888` as a top-level `pub const` in the translation -
            // Aro renders a C enum's tag type as one `pub const` and each
            // enumerator as another (`lib/compiler/translate-c/Translator.zig`,
            // `transEnumDecl`, and `ast.zig`'s `.enum_constant` renderer) - so
            // naming it here cannot drift from the header, and rewriting it as
            // an ordinal would be the one change that could.
            if (kind != dispatch.PJ_TYPE_GEOGRAPHIC_2D_CRS) {
                return "proj_get_type() did not report " ++
                    "PJ_TYPE_GEOGRAPHIC_2D_CRS for a \"+proj=longlat +type=crs\" " ++
                    "object, so this provider's ISO 19111 type registry is not " ++
                    "the one these headers describe";
            }

            return null;
        }
    };
}