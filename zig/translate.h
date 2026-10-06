// SPDX-License-Identifier: MIT
//
// Fork-authored. `FORK-LICENSE.md` records the owner's authorization of that
// grant for this file, and `COPYING` holds upstream's own MIT text.

/* The one header this package translates.
 *
 * `zig build` runs translate-c over this file and the translation becomes the
 * `c` module that the Zig facade (`zig/root.zig`) imports. Its whole job is to
 * name the headers that describe the library this build actually compiles: the
 * pinned upstream `src/proj.h` and `src/proj_constants.h` from OSGeo/PROJ
 * 9.9.0, byte for byte. It defines nothing and declares nothing.
 *
 * Why a wrapper and not a copy of the headers
 * -------------------------------------------
 * `src/proj.h` is the whole public C API — 292 `proj_*` function declarations
 * plus the one exported data object `pj_release` (`src/proj.h:195`), the
 * `PJ_COORD` union and its twelve arms (`:313-330`), and every structure a
 * caller can name. `src/proj_constants.h` is 520 `#define`s and nothing else:
 * every one of its 520 macro names is distinct, there is no redefinition and
 * no declaration in it. Re-typing any of that here would create a second,
 * hand-maintained copy of an ABI the shipped headers already state exactly, and
 * the two could drift apart silently while still compiling. So this file
 * re-declares nothing.
 *
 * Which headers this resolves to
 * ------------------------------
 * By the include path, not by a macro. `#include <proj.h>` is an ordinary
 * search: this file's own directory, then the `-I` paths `build.zig` adds, then
 * the system directories. There is no `proj.h` beside this file, and `build.zig`
 * puts the pinned `src/` on the translation line in every mode, so this always
 * names the `src/proj.h` of this repository and never a `proj.h` that happens to
 * be installed on the build machine. This build has no system-library mode — the
 * contract for this wave keeps the source pin and the bounded contracts
 * identical in every mode, so the header that is translated and the library that
 * is linked cannot disagree.
 *
 * Why `proj_experimental.h` is NOT included
 * -----------------------------------------
 * Because at this pin it declares no entry point at all. Its whole body after
 * `#include "proj.h"` (`src/proj_experimental.h:36`) is a doxygen block whose
 * summary line reads "Experimental C API (none currently)"
 * (`src/proj_experimental.h:38-41`), followed by a warning that the API "has
 * been considered now to be experimental, and may change or be removed in the
 * future" (`:43-46`), followed by an `extern "C" {` at `:48` and its `}` at
 * `:50` with nothing between them. Including it would add zero declarations and
 * one more include edge, and it would make this file look as though the fork
 * had a wider surface than the pinned tree actually has. It stays out; when
 * upstream adds a declaration there, adding the include is a one-line change
 * with a line citation beside it.
 *
 * Why `PROJ_RENAME_SYMBOLS` is never defined
 * ------------------------------------------
 * Because nothing in this fork defines it, and defining it would change the
 * exported names rather than the interface. `src/proj.h:127-129` is the whole of
 * the macro's effect on this header:
 *
 *     #ifdef PROJ_RENAME_SYMBOLS
 *     #include "proj_symbol_rename.h"
 *     #endif
 *
 * `src/proj_symbol_rename.h` is a table of `#define proj_* internal_proj_*`
 * lines (for example `src/proj_symbol_rename.h:32-36`, `:302-305`), which is
 * how PROJ contributes its symbols to a host that links several projection
 * libraries under one namespace. This fork is that host, not a guest in one, so
 * it defines neither `PROJ_RENAME_SYMBOLS` nor `PROJ_MSVC_DLL_EXPORT` and the
 * exported names are upstream's own `proj_*` names. The consequence is stated
 * rather than hidden: a provider built WITH `PROJ_RENAME_SYMBOLS` exports
 * `internal_proj_*` instead, and the runtime loader refuses it as a provider
 * that does not export the names `src/proj.h` declares. That is a different
 * external ABI family, not a fallback.
 *
 * `PROJ_DLL` is a compile-line fact, not an interface fact
 * ------------------------------------------------------
 * `src/proj.h:143-155` gives `PROJ_DLL` a default:
 *
 *     #ifndef PROJ_DLL
 *     #if defined(_MSC_VER)
 *     ... __declspec(dllexport) / __declspec(dllimport) ...
 *     #elif defined(__GNUC__)
 *     #define PROJ_DLL __attribute__((visibility("default")))
 *     #else
 *     #define PROJ_DLL
 *     #endif
 *     #endif
 *
 * Under every compiler this package uses that is clang or gcc, `__GNUC__` is
 * defined, so a consumer's declarations already carry default visibility — which
 * is exactly what a consumer of a shared object wants, and inert for a static
 * archive. That is a property of the header and the compiler, decided before
 * anything in this directory runs, and it changes no declaration's type: the
 * name, the parameter list and the calling convention are identical either way.
 * `build.zig` defines `PROJ_DLL` itself, empty, on the compile line that
 * produces the library (`src/lib_proj.cmake:399` does the same in upstream's own
 * CMake build), which is the header's own `#ifndef` guard and nothing more. A
 * build that wanted `__declspec` decoration would set that macro on its own
 * compilation; it is not an interface decision and nothing here depends on it.
 *
 * Macros defined here
 * -------------------
 * None, and none on the translation line either. `PROJ_DEPRECATED`
 * (`src/proj.h:157-173`) needs nothing: under `__GNUC__` it expands to
 * `decl __attribute__((deprecated))`, which is a spelling of upstream's own
 * declaration rather than a different declaration.
 *
 * This file is fork-authored. The terms that cover the compiled library are
 * upstream's, in `COPYING` and in the notice at `src/proj.h:96-116`.
 */

#ifndef PROJ_TRANSLATE_H
#define PROJ_TRANSLATE_H

#include <proj.h>
#include <proj_constants.h>

#endif /* PROJ_TRANSLATE_H */