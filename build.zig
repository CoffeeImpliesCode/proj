// SPDX-License-Identifier: MIT
//
// Fork-authored. `FORK-LICENSE.md` records the owner's authorization of that
// grant for this file, and `COPYING` holds upstream's own MIT text, unmodified.
// Nothing in this file is upstream's, and nothing here changes an upstream byte.

//! Zig 0.16 build for the OSGeo/PROJ coordinate transformation library.
//!
//! The library is upstream's own C and C++, byte for byte: the 219 translation
//! units that `src/lib_proj.cmake` and `src/apps/lib_projapps.cmake` put in the
//! `proj` target, plus the one vendored private dependency
//! (`vendor/sqlite3/sqlite3.c`) that upstream gets from
//! `find_package(SQLite3 3.11 REQUIRED)` (`CMakeLists.txt:247`) and links
//! `PRIVATE` (`src/lib_proj.cmake:352`). Nothing is downloaded, no CMake, Make
//! or configure script is executed, no `sqlite3` CLI is required, and every
//! mode compiles everything from this repository rather than linking an
//! installed copy.
//!
//! Upstream reference: git tag `9.9.0`. `src/proj.h:176-178` gives
//! `PROJ_VERSION_MAJOR 9`, `PROJ_VERSION_MINOR 9`, `PROJ_VERSION_PATCH 0`;
//! `CMakeLists.txt:169` is `proj_version(MAJOR 9 MINOR 9 PATCH 0)`;
//! `CMakeLists.txt:170` is `set(PROJ_SOVERSION 25)` and `:171` is
//! `set(PROJ_BUILD_VERSION "${PROJ_SOVERSION}.${PROJ_VERSION}")`, so the
//! shared object's `VERSION` is `25.9.0` with `SOVERSION` `25`
//! (`src/lib_proj.cmake:572-576`). `build()` refuses to configure when
//! `build.zig.zon .version` and those three components disagree, so the
//! manifest, the pkg-config `Version:` field and the upstream header cannot
//! describe three different releases. The pinned commit SHA belongs in
//! `FORK-NOTES.md` and `UPSTREAM.md`; this script does not restate a SHA it
//! cannot read.
//!
//! What is compiled, and what is not
//! --------------------------------
//! `core_sources`, `conversions_sources`, `projections_sources`,
//! `transformations_sources`, `iso19111_sources` and `apps_lib_source` below
//! are the five `SRC_LIBPROJ_*` groups and `SRC_PROJAPPS_LIBS`, copied out of
//! `src/lib_proj.cmake:22-265` and `src/apps/lib_projapps.cmake:1-3` in
//! upstream's own order, with the header entries (`HEADERS_LIBPROJ`,
//! the internal `.h`/`.hpp` files, and the generated `proj_config.h`) left out
//! because they are reached through the include path rather than compiled. The
//! list is enumerated rather than globbed, and that is a correctness
//! requirement rather than a style choice: `src/apps/` holds seven
//! command-line programs built from the `bin_*.cmake` includes at
//! `src/apps/CMakeLists.txt:52-86` -- `cct`, `cs2cs`, `geod`, `proj`,
//! `projinfo`, `gie` and `projsync` -- plus their shared support units
//! (`emess.cpp`, `geod_interface.cpp`, `geod_set.cpp`, `optargpm.h`,
//! `proj_strtod.cpp`, `utils.cpp`), `src/tests/` holds GTest suites, and a glob
//! over `src/**/*.cpp` would silently compile a different library from the one
//! upstream's CMake describes. `lib_proj.cmake` is the authority for what
//! belongs in the archive, so this file copies it.
//!
//! Deliberately **not** compiled, and retained in the tree byte for byte:
//!
//!   * the seven command-line applications and their shared support units:
//!     every `src/apps/*.cpp` except `apps/projinfo_lib.cpp`, which
//!     `src/apps/lib_projapps.cmake:1-3` puts in the `proj` target and
//!     `src/lib_proj.cmake:379` folds into `ALL_LIBPROJ_SOURCES`.
//!   * `src/embedded_resources.c` and `src/memvfs.c`, which
//!     `src/lib_proj.cmake:420-519` adds only under `EMBED_RESOURCE_FILES`.
//!     That option is off, and with it `EMBED_PROJ_DATA_PATH`
//!     (`src/lib_proj.cmake:285-287`) and the `file_embed/` sources
//!     (`src/lib_proj.cmake:409-513`). This package therefore never bakes a
//!     build-host path into the library; `PROJ_DATA` is how a consumer finds
//!     the datum data, and every run step below sets it.
//!   * the upstream test tree (`test/`, `src/tests/`), which is GTest-based and
//!     is not part of the `proj` target.
//!   * the bison parser-refresh targets (`generate_wkt1_parser`,
//!     `generate_wkt2_parser`, `check_wkt1_grammar_md5`,
//!     `check_wkt2_grammar_md5`, `src/lib_proj.cmake:326-368`). The parsers they
//!     would produce are checked in and are compiled here.
//!
//! Those are platform boundaries of this delivery, not reported failures, and
//! `README.md`, `UPSTREAM.md` and `FORK-NOTES.md` state the same boundary.
//!
//! The vendored SQLite3
//! --------------------
//! `vendor/sqlite3/sqlite3.c` is compiled into the *same* archive as the core,
//! so it is a private dependency that is linked in and never published: no
//! `libsqlite3` artifact is installed, no `-lsqlite3` appears in
//! `lib/pkgconfig/proj.pc`, and `sqlite3.h` is not installed either. Upstream
//! reaches the same closure from outside the archive with
//! `target_link_libraries(proj PRIVATE SQLite3::SQLite3)`
//! (`src/lib_proj.cmake:352`) and states `sqlite3` in `Requires.private:`
//! (`cmake/ProjUtilities.cmake:69`); this build reaches it from inside, so
//! that line is dropped and the omission is recorded here rather than left to
//! be discovered by a consumer whose static link then asks for a `sqlite3.pc`
//! that need not exist.
//!
//! The only SQL API this file's own generator uses is `sqlite3_open`,
//! `sqlite3_exec`, `sqlite3_errmsg` and `sqlite3_close`, all taken from the
//! vendored `vendor/sqlite3/sqlite3.h`.
//!
//! Compile settings
//! ----------------
//! * C++17 and C99, pinned rather than inherited. `CMakeLists.txt:26,29,30` is
//!   `set (CMAKE_CXX_STANDARD 17 ...)`, `CMAKE_CXX_STANDARD_REQUIRED ON`,
//!   `CMAKE_CXX_EXTENSIONS OFF`; `:35,38,39` is the same for
//!   `CMAKE_C_STANDARD 99`. Both `EXTENSIONS OFF`, so `-std=c99` and
//!   `-std=c++17` and not the `gnu` spellings.
//! * `-DPROJ_DLL=` on the compile line that produces the library.
//!   `src/lib_proj.cmake:399` does the same for a static build;
//!   `src/proj.h:143-155` is the `#ifndef PROJ_DLL` it satisfies, and
//!   `zig/translate.h:73-97` records the consequence. `PROJ_DLL` is not defined
//!   on the translation line: a consumer of a shared object wants default
//!   visibility, which `src/proj.h:151` already gives it under `__GNUC__`.
//! * `-DPROJ_HAS_PTHREADS` where the target has pthreads, and the matching
//!   link. `src/lib_proj.cmake:3-6` is `find_package(Threads QUIET)` gated on
//!   `CMAKE_USE_PTHREADS_INIT`. Its one reader in the compiled set is
//!   `src/iso19111/factory.cpp:96-99`, which opens `pthread.h` and defines
//!   `REOPEN_SQLITE_DB_AFTER_FORK`; `factory.cpp:87-89` `#undef`s the macro
//!   under `_WIN32`, so a Windows target does not need the definition either.
//! * `-DNOMINMAX` on Windows, which is `MSVC OR MINGW` in
//!   `src/lib_proj.cmake:401-403`.
//! * No `TIFF_ENABLED`. `CMakeLists.txt:256` defaults `ENABLE_TIFF` ON, and
//!   `src/lib_proj.cmake:363-366` turns it into `TIFF_ENABLED`; this build
//!   defines neither, so `src/grids.cpp` takes its non-TIFF branch and no
//!   `tiffio.h` is reached. The same holds for `CURL_ENABLED`
//!   (`src/lib_proj.cmake:368-373`): without it `src/networkfilemanager.cpp`
//!   takes the `#else` at `:2243-2246` and installs `no_op_network_open`, so
//!   the file compiles complete rather than half.
//! * `PROJ_RENAME_SYMBOLS` is **never** defined, so `src/proj.h:127-129` does
//!   not include `proj_symbol_rename.h` and the exported names are upstream's
//!   own `proj_*` names. A provider built *with* that macro exports
//!   `internal_proj_*` and is refused by the runtime loader; that is a
//!   different external ABI family, not a fallback.
//! * No `-fvisibility=hidden` and no version script. PROJ has no export list
//!   at this pin, `src/proj.h:151` already gives every `proj_*` declaration
//!   default visibility under `__GNUC__`, and a hand-written list beside the
//!   header could only drift from it. The shared object therefore exports what
//!   upstream's shared build exports.
//! * No `_FILE_OFFSET_BITS`. CMake's platform module adds it on Linux, and on
//!   every target in this package's matrix the C library's `off_t` is already
//!   64 bits, so the macro is a no-op here; it is named rather than silently
//!   assumed.
//!
//! Link: libm, libdl and pthreads exactly where `src/lib_proj.cmake:596-605`
//! finds them (`if(UNIX)`, so no Windows system libraries), plus the C++
//! runtime, which upstream gets from `CMAKE_CXX_IMPLICIT_LINK_LIBRARIES`
//! (`cmake/ProjUtilities.cmake:79-83`) because
//! `src/lib_proj.cmake:579-581` sets `LINKER_LANGUAGE CXX`.
//!
//! Generated inputs
//! ----------------
//! Two, and both are host-run programs in dependent steps that are told which
//! *target* they are generating for. Neither is hand-written and neither reads
//! the build machine's own configuration.
//!
//! 1. `proj_config.h`. Upstream's template is
//!    `cmake/proj_config.cmake.in` (nine `#cmakedefine`s) and
//!    `cmake/ProjConfig.cmake:11-19` decides the three `HAVE_*` macros with
//!    `check_function_exists`/`check_library_exists` against the target
//!    compiler and linker. `proj_config_gen_source` below reproduces that
//!    decision from `std.Target` for the target `addGraph` is building: the
//!    resolved target, never the host. The three facts it decides are
//!    `HAVE_LIBDL` (true exactly where `dlLibrary` below is non-null, which is
//!    what `check_library_exists(dl dladdr "" ...)` means), `HAVE_LOCALECONV`
//!    and `HAVE_STRERROR` (true on every target whose libc is C99, which is
//!    every target this package builds). The generated directory goes on the
//!    compile line and on the translation line, because
//!    `src/filemanager.cpp:33`, `src/strerrno.cpp:8` and `src/strtod.cpp:37`
//!    include `proj_config.h` by bare name and
//!    `src/lib_proj.cmake:264` lists it as a source of the target.
//! 2. `proj.db` and `PROJ_DB_SQL_MD5.h`, from
//!    `data/generate_proj_db.cmake` with `PROJ_DB_EXTRA_VALIDATION` OFF
//!    (`generate_proj_db.cmake:29`). `proj_db_gen_source` concatenates the
//!    50 files in `data/sql_filelist.cmake`'s order, substitutes
//!    `${PROJ_VERSION}`, computes the MD5 of the concatenation with every
//!    `INSERT INTO "metadata"` line removed, **asserts** that it equals the
//!    content of `data/sql/proj.db.sql.expected.md5`, writes
//!    `PROJ_DB_SQL_MD5.h`, and then executes the whole script against a host
//!    build of the vendored SQLite3 amalgamation. The assertion is upstream's
//!    own rule (`generate_proj_db.cmake:17-22` computes, `:32-48` compares
//!    against `PROJ_DB_SQL_EXPECTED_MD5` and reports a changed SQL content),
//!    and it is a stop rather than a warning: a build that cannot reproduce
//!    upstream's database must not produce one that looks like it.
//!
//! `PROJ_DB_SQL_MD5.h` is generated and reachable by bare name from the compile
//! and translation lines, and nothing in the compiled set includes it: its only
//! upstream reader is `src/embedded_resources.c:8-11`, which this build does not
//! compile. It is generated because upstream's recipe generates it, so that the
//! build carries the whole of that recipe rather than the convenient part of
//! it.
//!
//! Datum data
//! ----------
//! `data/proj.db` is **not** in the release tarball; `data/sql/` is 14 MiB of
//! generated SQL and `data/CMakeLists.txt:39-49` builds the database from it
//! through the `sqlite3` CLI. This build does the same work without a CLI,
//! without a download and without a host `sqlite3`.
//!
//! **No datum-shift grid ships in this package.** `data/CH` is a legacy `+init`
//! definition file, not a grid; `data/CH:9` says outright that the grids must be
//! downloaded separately. `data/tests/*` is upstream's test material, and is
//! installed by nothing here. Every `proj.db` operation that needs an
//! NTv2/GeoTIFF/CTABLE2 grid reports that grid unavailable. That is a
//! data-availability statement about this delivery, not a build result.
//!
//! PROJ's own resolution order is `PROJ_DATA` first, `PROJ_LIB` second and
//! deprecated (`src/filemanager.cpp:1119-1127`), then the paths set with
//! `proj_context_set_search_paths`. So `test`, `smoke` and `consumer` set
//! `PROJ_DATA` to the installed `share/proj` directory and `PROJ_NETWORK=OFF`,
//! which `src/filemanager.cpp:1994-1998` reads as off unless the value is `ON`,
//! `YES` or `TRUE`. "No network" is therefore a property of the gate rather
//! than an accident, and `PROJ_USER_WRITABLE_DIRECTORY` is left alone.
//!
//! Entry points
//! -----------
//!   zig build            install the delivered library, the four public
//!                        headers, `share/proj/`, the pkg-config file and
//!                        `share/doc/proj/`
//!   zig build test       run the facade tests for the selected target
//!                        (`-Dtarget`; the host when it is absent)
//!   zig build smoke      run the example program
//!   zig build check      compile the core, the facade, the API exercise, the
//!                        tests and the example for the six-target matrix,
//!                        running nothing
//!   zig build consumer   run the module consumer inside this build graph
//!   zig build provenance run `tools/check-provenance.sh`
//!
//!   cross-test           the same `test` step, for the published 53-platform
//!                        Zig 0.16.0 Tier 1/2 table rather than the host alone.
//!                        `cross-test` discovers `cross-test.profile.sh` from
//!                        the package root, runs `zig build test -Dtarget=TARGET`
//!                        for each of them, and executes the binary where a
//!                        runner exists and records explicit `build_only`
//!                        coverage where one does not. `test` is what the
//!                        harness reaches for, and it builds the same graph and
//!                        the same test binary for whatever `-Dtarget` says:
//!                        nothing in `build()` narrows the graph to the host,
//!                        and the `check` matrix below is compile-only and is
//!                        not a substitute for it.
//!
//! Options
//! -------
//!   -Dtarget=<triple>    build for one target; `zig build check` then checks
//!                        that target only instead of the whole matrix.
//!   -Doptimize=<mode>    the caller's mode, passed to every graph below. No
//!                        target-specific or mode-specific branch exists in this
//!                        file: the core, the facade, the tests and the example
//!                        are compiled the same way in Debug and ReleaseSafe,
//!                        so a bound that one mode checks and the other does not
//!                        cannot be written into them. `zig build test` is run by
//!                        the driver in both.
//!   -Dlinkage=static|dynamic
//!                        which native artifact this build delivers and
//!                        installs. The default is `static`. The dynamic
//!                        delivery is `libproj.so.25` with `VERSION` `25.9.0`,
//!                        which is what `src/lib_proj.cmake:572-576` and
//!                        `CMakeLists.txt:170-171` describe. A target whose OS
//!                        has no dynamic linker cannot carry a shared object,
//!                        and `-Dlinkage=dynamic` is refused for it at configure
//!                        time rather than answered with an archive; the static
//!                        default works on every target, `wasm32-wasi` included.
//!   -Druntime=true|false
//!                        how the facade reaches the native entry points, not
//!                        which artifact this build delivers. The default is
//!                        `false`, the linked route. `true` resolves them
//!                        through the generated dispatch from
//!                        `runtime/graph.zig` and links nothing native into the
//!                        module. The two options are orthogonal: under
//!                        `-Druntime=true` the library is still compiled and
//!                        still installed, so a caller may name this build's own
//!                        provider or another one.
//!
//! There is no system-library mode in this wave, by contract: the source pin
//! and the bounded contracts must stay identical in every mode, and a real
//! installed PROJ with matching headers is not something this repository can
//! promise to any of the six matrix targets. So the rule is recorded as NOT
//! APPLICABLE rather than claimed as a satisfied gate, and nothing here links
//! `-lproj` as a system library. There is likewise no `b.systemIntegrationOption`
//! call: an unused option is a knob nobody has checked.
//!
//! Published routes
//! ----------------
//!   * `dep.module("proj")`: the Zig facade, `zig/root.zig`. This is the one
//!     registered module. It carries `link_libc`, the C++ runtime where the
//!     archive is linked, the four include directories, the translated header as
//!     `c`, and the delivered library behind all of them.
//!   * `c` on that same module: the translated header, for a caller that needs a
//!     declaration the facade does not name. It is deliberately *not*
//!     registered as a module of its own: `addModule("c")` would make
//!     `dep.module("c")` resolve and hand a dependent the same declarations
//!     without the library that satisfies them, which is a reachability a
//!     dependent cannot tell from support.
//!   * `dep.artifact("proj")`: the compiled native library, for a dependent that
//!     links the archive into its own C or Zig build. `Libs:` in the installed
//!     `proj.pc` is `-lproj`, which is that artifact's name.
//!   * the installed `include/proj*.h`, the native library and
//!     `lib/pkgconfig/proj.pc` under `--prefix`, for a C consumer.
//!
//! `README.zig.md` states the same routes for a reader deciding what to import,
//! and `zig/root.zig` states the Zig one on the module itself.

const std = @import("std");

/// The runtime-loading build half, owned by the API role.
///
/// `createModule` builds the generated dispatch that replaces
/// `translate.createModule()` under `-Druntime=true`; it makes the loader-core
/// module itself and re-exports `LoadSource`/`LoadError` from it.
/// `createCoreModule` builds that same core module for the *linked* branch,
/// where there is no dispatch to carry the types and the facade's `rt` import
/// is where they come from.
///
/// The two branches must not both call `createCoreModule`: `LoadSource` and
/// `LoadError` are this SDK's public types, so they have to be the *same* types
/// in one build. A second core instance would be a second, nominally distinct
/// `LoadSource`, and `proj.load(source)` would hand the facade's type to a
/// function expecting the dispatch's. `addGraph` documents the branch and is the
/// only function that calls either of these.
const runtime_graph = @import("runtime/graph.zig");

/// `build.zig.zon` itself. `@import` of the manifest is how a build script reads
/// `.version` without a second copy of it.
const manifest = @import("build.zig.zon");

/// `build.zig.zon .version`, parsed. The parse is the loud part: a manifest
/// whose `.version` is not a semantic version fails to configure here rather
/// than being silently compared as something else.
const manifest_version = std.SemanticVersion.parse(manifest.version) catch
    @panic("build.zig.zon: .version is not a semantic version");

/// Upstream's own version, read out of `src/proj.h:176-178` and
/// `CMakeLists.txt:169`. It is the version of the C library, not a version of
/// this wrapper, so `build.zig.zon .version` carries the same three components.
/// The pkg-config `Version:` field spells it the way
/// `cmake/ProjUtilities.cmake:57` does, from `PROJ_VERSION`.
const upstream_version: std.SemanticVersion = .{ .major = 9, .minor = 9, .patch = 0 };

/// The same three components as text, for the strings that need it: the
/// `${PROJ_VERSION}` substitution, `PACKAGE_STRING` and the pkg-config
/// `Version:` field. Written once so the three cannot disagree.
const upstream_version_text = "9.9.0";

/// The shared object's ABI version, upstream's own `PROJ_SOVERSION`
/// (`CMakeLists.txt:170`) followed by the release, which is what
/// `CMakeLists.txt:171` builds into `PROJ_BUILD_VERSION` and
/// `src/lib_proj.cmake:574` puts in `VERSION`. `Step.Compile` derives the
/// `libproj.so.25` soname name and the `libproj.so` link name from
/// `version.major` (`lib/std/Build/Step/Compile.zig:501-503`), so this one
/// value is what produces both installed file names.
const library_version: std.SemanticVersion = .{ .major = 25, .minor = 9, .patch = 0 };

/// The name a dependent writes in its dependency map, and the name of the one
/// registered module. It is also `build.zig.zon .name` and the library's own
/// `PROJ_OUTPUT_NAME` off Windows (`src/lib_proj.cmake:551`), so `libproj.a`,
/// `libproj.so.25` and `-lproj` all come from this one spelling.
const module_name = "proj";

/// The compiled artifact's name. The installed archive is `libproj.a` because
/// of it, which is the name a C consumer's `-lproj` needs.
const lib_name = "proj";

/// The installed pkg-config file's base name. `pkg-config --libs proj` is how a
/// C consumer of the install asks for the library by name rather than spelling
/// `-L` and `-l` itself, which is the whole point of installing one.
const pkg_config_name = "proj";

/// The Zig facade: the published module's root source file. It is written by
/// this package's API role; this build graph names its path and creates
/// nothing there.
const facade_source = "zig/root.zig";

/// The explicit exercise of every public facade method. `zig build check`
/// compiles it for every matrix target, which is what forces each facade body
/// to be analysed rather than merely declared.
const exercise_source = "zig/api_exercise.zig";

/// The one header this package translates. A fork-authored wrapper whose whole
/// job is to name the pinned upstream headers; see the file for why it is a
/// wrapper and not a copy.
const translate_header = "zig/translate.h";

/// The fork-authored by-value ABI bridge, compiled into the same archive as the
/// core. `zig/proj_abi.h` is where the reasoning is; the build only has to put
/// the one translation unit on the compile line.
const bridge_source = "zig/proj_abi.c";

/// Test root. Every public facade method is called from here as well as from
/// `zig/api_exercise.zig`, which is what makes `zig build test` a run of the
/// facade rather than of an unreferenced archive.
const test_source = "tests.zig";

/// The deterministic example program that `zig build smoke` runs.
const example_source = "smoke.zig";

/// The vendored SQLite3 amalgamation, compiled into the same archive as the
/// core. The version is `vendor/sqlite3/sqlite3.h:149` (`SQLITE_VERSION
/// "3.53.4"`). Its licence is the public-domain blessing at
/// `vendor/sqlite3/sqlite3.h:4-9`, and `shell.c` (the CLI) is deliberately not
/// vendored, which is why the generator below needs no `sqlite3` binary.
const sqlite_source = "vendor/sqlite3/sqlite3.c";

/// Where `sqlite3.h` lives, and the only place `src/sqlite3_utils.hpp`,
/// `src/iso19111/internal.cpp` and `src/iso19111/factory.cpp` can find it.
const sqlite_dir = "vendor/sqlite3";

/// `src/`, the include path every C compilation below is given. It holds
/// `proj.h`, `proj_constants.h`, `proj_experimental.h`, `proj_symbol_rename.h`
/// and `geodesic.h` (`src/lib_proj.cmake:284-290`), and every internal header
/// the core reaches by bare name.
const source_dir = "src";

/// `include/`, the second directory `include_directories` gives the core
/// (`src/lib_proj.cmake:306`). It is a separate `-I` here rather than merged
/// into `src/`, because the two are separate upstream include directories and
/// a header that is absent from one of them should be absent here too.
const include_dir = "include";

/// The header this package translates for its own generator, written into the
/// local cache so that nothing outside this file has to own it. It includes
/// only `<sqlite3.h>`, because that is the only C API the generator calls.
const sqlite_translate_header_source =
    \\/* Written into the local cache by proj/build.zig.
    \\ *
    \\ * The one header the `proj.db` generator's translation uses. It names the
    \\ * vendored SQLite3 amalgamation's own public header and nothing else: the
    \\ * generator calls `sqlite3_open`, `sqlite3_exec`, `sqlite3_errmsg` and
    \\ * `sqlite3_close` and declares nothing of its own, so the translation
    \\ * describes the exact C ABI of the file `vendor/sqlite3/sqlite3.c` that
    \\ * this build links it against.
    \\ */
    \\#ifndef PROJ_SQLITE_TRANSLATE_H
    \\#define PROJ_SQLITE_TRANSLATE_H
    \\
    \\#include <sqlite3.h>
    \\
    \\#endif /* PROJ_SQLITE_TRANSLATE_H */
;

/// Language levels, pinned.
///
/// See the "Compile settings" section above for the `CMakeLists.txt` lines each
/// of these reproduces. Pinned rather than inherited so that a change of
/// clang's default cannot silently move the dialect a 219-unit C++ closure is
/// compiled at.
const c_flags = [_][]const u8{"-std=c99"};
const cxx_flags = [_][]const u8{"-std=c++17"};

/// Where the build root's `data/` lives, and the generated database's
/// neighbours. `data/CMakeLists.txt:30-31` puts `all.sql.in` and `proj.db` in
/// the *binary* directory; here they are the generator's own outputs, which is
/// the same separation with a directory nobody has to keep clean.
const data_dir = "data";

/// `data/sql/proj.db.sql.expected.md5`, the digest the generator asserts
/// against. `data/CMakeLists.txt:37` reads it with
/// `file(STRINGS ... LIMIT_COUNT 1)`; `data/CMakeLists.txt:34-36` even makes
/// it a configure-time dependency, which is why it is a tracked input here
/// rather than a constant written into the generator.
const expected_md5_file = "data/sql/proj.db.sql.expected.md5";

/// The installed data files, other than the generated `proj.db`.
///
/// `data/CMakeLists.txt:108-110` installs `${PROJ_INI}`, `${PROJ_DB}` and
/// `${PROJ_DICTIONARY}` into `${CMAKE_INSTALL_DATADIR}/proj` when
/// `USE_ONLY_EMBEDDED_RESOURCE_FILES` is off, and `:102-106` adds
/// `${SCHEMA_FILES}`. `PROJ_INI` is `proj.ini` (`:14-16`), `SCHEMA_FILES` is the
/// `*.json` glob (`:26`), and `PROJ_DICTIONARY` is the eleven-file list at
/// `CMakeLists.txt:427-439`.
///
/// Named one by one rather than globbed. A glob over `data/` would also pick up
/// `CMakeLists.txt`, `README`, `sql/`, `sql_filelist.cmake`,
/// `generate_proj_db.cmake`, `tests/` and the `.sql` sources, none of which
/// upstream installs.
const data_files = [_][]const u8{
    "data/proj.ini",
    "data/deformation_model.schema.json",
    "data/projjson.schema.json",
    "data/triangulation.schema.json",
    "data/world",
    "data/other.extra",
    "data/nad27",
    "data/GL27",
    "data/nad83",
    "data/nad.lst",
    "data/CH",
    "data/ITRF2000",
    "data/ITRF2008",
    "data/ITRF2014",
    "data/ITRF2020",
};

/// Upstream's licence text and this fork's records, installed under
/// `share/doc/proj/`.
///
/// `COPYING` is upstream's own MIT-style text, unmodified, and it covers
/// everything in the archive. The rest are the records that describe what this
/// fork did to it, and `UPSTREAM.sha256` travels with them because the digests
/// are what make the installed provenance claim checkable.
const doc_records = [_][]const u8{
    "COPYING",
    "NOTICE.md",
    "FORK-LICENSE.md",
    "UPSTREAM.md",
    "UPSTREAM.sha256",
    "README.upstream.md",
    "README.md",
    "README.zig.md",
    "CHANGELOG.md",
    "FORK-NOTES.md",
};

/// The cross-compilation matrix `check` walks when no target is named. The
/// order is the one this workspace uses everywhere; nothing is skipped, and
/// nothing here is pre-judged: if a target cannot be satisfied on the machine
/// running the gate, that is for the gate to report.
///
/// `wasm32-wasi` is in the list and stays in it. It has no pthreads
/// (`lib_proj.cmake:3-6` finds none) and no dynamic linker
/// (`lib/std/Target.zig`'s `DynamicLinker.kind` is `.none` for it), which is
/// why the static default covers it and `-Dlinkage=dynamic` refuses it. Neither
/// fact is a reason to drop the cell.
const check_targets = [_]std.Target.Query{
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .macos, .abi = .none },
    .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    .{ .cpu_arch = .riscv64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .wasm32, .os_tag = .wasi },
};

// ---------------------------------------------------------------------------
// The compile units, copied from src/lib_proj.cmake and
// src/apps/lib_projapps.cmake.
// ---------------------------------------------------------------------------

/// `SRC_LIBPROJ_CORE` (`src/lib_proj.cmake:195-265`), in upstream's order.
///
/// Sixty-nine entries become fifty-seven translation units here. The twelve that
/// are not compiled are the eleven internal headers (`filemanager.hpp`,
/// `grids.hpp`, `pj_list.h`, `proj_internal.h`, `proj_json_streaming_writer.hpp`,
/// `sqlite3_utils.hpp`, `wkt1_generated_parser.h`, `wkt1_parser.h`,
/// `wkt2_generated_parser.h`, `wkt2_parser.h`, `wkt_parser.hpp`), which the
/// compile line reaches through `src/`, and `${CMAKE_CURRENT_BINARY_DIR}/proj_config.h`,
/// which is generated per target by `addProjConfig` below. The four public
/// headers named by `HEADERS_LIBPROJ` (`src/lib_proj.cmake:284-290`) are
/// installed, not compiled.
///
/// Three of the fifty-seven are C, not C++: `geodesic.c` (GeographicLib's own
/// implementation, vendored into PROJ's tree), and the two bison-generated
/// WKT parsers, which `src/lib_proj.cmake:326-368` refreshes by hand and which
/// are checked in.
const core_sources = [_][]const u8{
    "src/aasincos.cpp",
    "src/adjlon.cpp",
    "src/area.cpp",
    "src/coord_operation.cpp",
    "src/coordinates.cpp",
    "src/create.cpp",
    "src/crs_to_crs.cpp",
    "src/ctx.cpp",
    "src/datum_set.cpp",
    "src/datums.cpp",
    "src/deriv.cpp",
    "src/dist.cpp",
    "src/dmstor.cpp",
    "src/ell_set.cpp",
    "src/ellps.cpp",
    "src/factors.cpp",
    "src/filemanager.cpp",
    "src/fwd.cpp",
    "src/gauss.cpp",
    "src/generic_inverse.cpp",
    "src/geodesic.c",
    "src/grids.cpp",
    "src/info.cpp",
    "src/init.cpp",
    "src/initcache.cpp",
    "src/internal.cpp",
    "src/inv.cpp",
    "src/latitudes.cpp",
    "src/list.cpp",
    "src/log.cpp",
    "src/malloc.cpp",
    "src/mlfn.cpp",
    "src/msfn.cpp",
    "src/mutex.cpp",
    "src/networkfilemanager.cpp",
    "src/param.cpp",
    "src/phi2.cpp",
    "src/pipeline.cpp",
    "src/pr_list.cpp",
    "src/proj_json_streaming_writer.cpp",
    "src/proj_mdist.cpp",
    "src/release.cpp",
    "src/rtodms.cpp",
    "src/strerrno.cpp",
    "src/strtod.cpp",
    "src/sqlite3_utils.cpp",
    "src/tracing.cpp",
    "src/trans.cpp",
    "src/trans_bounds.cpp",
    "src/tsfn.cpp",
    "src/units.cpp",
    "src/wkt1_generated_parser.c",
    "src/wkt1_parser.cpp",
    "src/wkt2_generated_parser.c",
    "src/wkt2_parser.cpp",
    "src/wkt_parser.cpp",
    "src/zpoly1.cpp",
};

/// `SRC_LIBPROJ_CONVERSIONS` (`src/lib_proj.cmake:142-151`): the eight units
/// that implement the operation steps that are not projections.
const conversions_sources = [_][]const u8{
    "src/conversions/axisswap.cpp",
    "src/conversions/cart.cpp",
    "src/conversions/geoc.cpp",
    "src/conversions/geocent.cpp",
    "src/conversions/noop.cpp",
    "src/conversions/topocentric.cpp",
    "src/conversions/set.cpp",
    "src/conversions/unitconvert.cpp",
};

/// `SRC_LIBPROJ_PROJECTIONS` (`src/lib_proj.cmake:22-140`): 117 units, all of
/// them, in upstream's order.
///
/// `src/projections/` holds exactly 117 `.cpp` files at this pin and every one
/// of them appears above, so the list is complete for that directory in both
/// directions. None of them is optional: `src/init.cpp` registers each
/// projection by name, and a facade that promised PROJ's projections and
/// delivered 116 would not be PROJ.
const projections_sources = [_][]const u8{
    "src/projections/airocean.cpp",
    "src/projections/aeqd.cpp",
    "src/projections/adams.cpp",
    "src/projections/gnom.cpp",
    "src/projections/laea.cpp",
    "src/projections/mod_ster.cpp",
    "src/projections/nsper.cpp",
    "src/projections/nzmg.cpp",
    "src/projections/ortho.cpp",
    "src/projections/stere.cpp",
    "src/projections/sterea.cpp",
    "src/projections/aea.cpp",
    "src/projections/bipc.cpp",
    "src/projections/bonne.cpp",
    "src/projections/eqdc.cpp",
    "src/projections/polyhedral.cpp",
    "src/projections/ccon.cpp",
    "src/projections/imw_p.cpp",
    "src/projections/krovak.cpp",
    "src/projections/lcc.cpp",
    "src/projections/poly.cpp",
    "src/projections/rpoly.cpp",
    "src/projections/sconics.cpp",
    "src/projections/rouss.cpp",
    "src/projections/cass.cpp",
    "src/projections/cc.cpp",
    "src/projections/cea.cpp",
    "src/projections/eqc.cpp",
    "src/projections/gall.cpp",
    "src/projections/labrd.cpp",
    "src/projections/som.cpp",
    "src/projections/merc.cpp",
    "src/projections/mill.cpp",
    "src/projections/ocea.cpp",
    "src/projections/omerc.cpp",
    "src/projections/somerc.cpp",
    "src/projections/tcc.cpp",
    "src/projections/tcea.cpp",
    "src/projections/times.cpp",
    "src/projections/tmerc.cpp",
    "src/projections/tmerczoned.cpp",
    "src/projections/tobmerc.cpp",
    "src/projections/airy.cpp",
    "src/projections/aitoff.cpp",
    "src/projections/august.cpp",
    "src/projections/bacon.cpp",
    "src/projections/bertin1953.cpp",
    "src/projections/chamb.cpp",
    "src/projections/hammer.cpp",
    "src/projections/lagrng.cpp",
    "src/projections/larr.cpp",
    "src/projections/lask.cpp",
    "src/projections/latlong.cpp",
    "src/projections/nicol.cpp",
    "src/projections/ob_tran.cpp",
    "src/projections/oea.cpp",
    "src/projections/tpeqd.cpp",
    "src/projections/vandg.cpp",
    "src/projections/vandg2.cpp",
    "src/projections/vandg4.cpp",
    "src/projections/wag7.cpp",
    "src/projections/lcca.cpp",
    "src/projections/geos.cpp",
    "src/projections/boggs.cpp",
    "src/projections/collg.cpp",
    "src/projections/comill.cpp",
    "src/projections/crast.cpp",
    "src/projections/denoy.cpp",
    "src/projections/eck1.cpp",
    "src/projections/eck2.cpp",
    "src/projections/eck3.cpp",
    "src/projections/eck4.cpp",
    "src/projections/eck5.cpp",
    "src/projections/fahey.cpp",
    "src/projections/fouc_s.cpp",
    "src/projections/gins8.cpp",
    "src/projections/gstmerc.cpp",
    "src/projections/gn_sinu.cpp",
    "src/projections/goode.cpp",
    "src/projections/igh.cpp",
    "src/projections/igh_o.cpp",
    "src/projections/imoll.cpp",
    "src/projections/imoll_o.cpp",
    "src/projections/hatano.cpp",
    "src/projections/loxim.cpp",
    "src/projections/mbt_fps.cpp",
    "src/projections/mbtfpp.cpp",
    "src/projections/mbtfpq.cpp",
    "src/projections/moll.cpp",
    "src/projections/nell.cpp",
    "src/projections/nell_h.cpp",
    "src/projections/patterson.cpp",
    "src/projections/putp2.cpp",
    "src/projections/putp3.cpp",
    "src/projections/putp4p.cpp",
    "src/projections/putp5.cpp",
    "src/projections/putp6.cpp",
    "src/projections/qsc.cpp",
    "src/projections/robin.cpp",
    "src/projections/s2.cpp",
    "src/projections/sch.cpp",
    "src/projections/sts.cpp",
    "src/projections/urm5.cpp",
    "src/projections/urmfps.cpp",
    "src/projections/wag2.cpp",
    "src/projections/wag3.cpp",
    "src/projections/wink1.cpp",
    "src/projections/wink2.cpp",
    "src/projections/healpix.cpp",
    "src/projections/natearth.cpp",
    "src/projections/natearth2.cpp",
    "src/projections/calcofi.cpp",
    "src/projections/eqearth.cpp",
    "src/projections/col_urban.cpp",
    "src/projections/spilhaus.cpp",
    "src/projections/hourglass.cpp",
    "src/projections/interrupted.cpp",
};

/// `SRC_LIBPROJ_TRANSFORMATIONS` (`src/lib_proj.cmake:153-167`): the thirteen
/// operation steps that move a coordinate between two frames.
const transformations_sources = [_][]const u8{
    "src/transformations/affine.cpp",
    "src/transformations/deformation.cpp",
    "src/transformations/gridshift.cpp",
    "src/transformations/helmert.cpp",
    "src/transformations/hgridshift.cpp",
    "src/transformations/horner.cpp",
    "src/transformations/molodensky.cpp",
    "src/transformations/vgridshift.cpp",
    "src/transformations/xyzgridshift.cpp",
    "src/transformations/defmodel.cpp",
    "src/transformations/tinshift.cpp",
    "src/transformations/tinshift_gpkg.cpp",
    "src/transformations/vertoffset.cpp",
};

/// `SRC_LIBPROJ_ISO19111` (`src/lib_proj.cmake:169-193`): twenty-three units,
/// twelve in `src/iso19111/` and eleven in `src/iso19111/operation/`. This is
/// the CRS, datum, coordinate-operation and metadata object model, and it is
/// where the C API in `src/iso19111/c_api.cpp` is implemented.
const iso19111_sources = [_][]const u8{
    "src/iso19111/static.cpp",
    "src/iso19111/util.cpp",
    "src/iso19111/metadata.cpp",
    "src/iso19111/common.cpp",
    "src/iso19111/coordinates.cpp",
    "src/iso19111/crs.cpp",
    "src/iso19111/datum.cpp",
    "src/iso19111/coordinatesystem.cpp",
    "src/iso19111/io.cpp",
    "src/iso19111/internal.cpp",
    "src/iso19111/factory.cpp",
    "src/iso19111/c_api.cpp",
    "src/iso19111/operation/concatenatedoperation.cpp",
    "src/iso19111/operation/coordinateoperationfactory.cpp",
    "src/iso19111/operation/conversion.cpp",
    "src/iso19111/operation/esriparammappings.cpp",
    "src/iso19111/operation/oputils.cpp",
    "src/iso19111/operation/parametervalue.cpp",
    "src/iso19111/operation/parammappings.cpp",
    "src/iso19111/operation/projbasedoperation.cpp",
    "src/iso19111/operation/singleoperation.cpp",
    "src/iso19111/operation/transformation.cpp",
    "src/iso19111/operation/vectorofvaluesparams.cpp",
};

/// `SRC_PROJAPPS_LIBS` (`src/apps/lib_projapps.cmake:1-3`), one unit.
///
/// It is in the `proj` target (`src/lib_proj.cmake:373-380` folds
/// `${SRC_PROJAPPS_LIBS}` into `ALL_LIBPROJ_SOURCES`) and is therefore compiled,
/// while the command-line programs that use it are not. It is the largest of
/// the 219 units.
const apps_lib_source = [_][]const u8{
    "src/apps/projinfo_lib.cpp",
};

/// Every translation unit of the `proj` target, in
/// `ALL_LIBPROJ_SOURCES`' order (`src/lib_proj.cmake:373-380`).
///
/// The count is asserted in `build()` rather than only documented: a number
/// that quietly changed would be a much harder defect to see than a duplicated
/// literal.
const target_translation_unit_count = 219;

/// `ALL_LIBPROJ_SOURCES`, in order.
const all_target_sources = blk: {
    const groups = .{
        core_sources,
        conversions_sources,
        projections_sources,
        transformations_sources,
        iso19111_sources,
        apps_lib_source,
    };
    var count: usize = 0;
    for (groups) |group| count += group.len;
    var list: [count][]const u8 = undefined;
    var index: usize = 0;
    for (groups) |group| {
        for (group) |s| {
            list[index] = s;
            index += 1;
        }
    }
    break :blk list;
};

/// The SQL files `data/sql_filelist.cmake` concatenates, in that file's order,
/// with `PROJ_DB_EXTRA_VALIDATION` OFF.
///
/// This is `data/sql_filelist.cmake:15-79` read with the two branches the OFF
/// value takes: `:19-21` does not append `SQL_FILES_CONSISTENCY_CHECKS_TRIGGERS`
/// early, `:68-70` does not append `show_useless_aliases.sql`, and `:74-78`
/// appends the consistency-check triggers at the very end instead of
/// `final_consistency_checks.sql`. Fifty files.
///
/// Fifty is the count this list reproduces, and the order is the one the
/// database depends on: the concatenation is what upstream's MD5 rule covers,
/// and 14264577 bytes of it is what `generate_proj_db.cmake:29` produces. Each
/// one is a tracked input of the generator's run step, so editing any of them
/// invalidates the database rather than leaving a stale one beside it.
const sql_files = [_][]const u8{
    "data/sql/begin.sql",
    "data/sql/proj_db_table_defs.sql",
    "data/sql/customizations_early.sql",
    "data/sql/metadata.sql",
    "data/sql/unit_of_measure.sql",
    "data/sql/extent.sql",
    "data/sql/scope.sql",
    "data/sql/coordinate_system.sql",
    "data/sql/axis.sql",
    "data/sql/ellipsoid.sql",
    "data/sql/prime_meridian.sql",
    "data/sql/geodetic_datum.sql",
    "data/sql/geodetic_datum_ensemble_member.sql",
    "data/sql/vertical_datum.sql",
    "data/sql/vertical_datum_ensemble_member.sql",
    "data/sql/engineering_datum.sql",
    "data/sql/conversion.sql",
    "data/sql/geodetic_crs.sql",
    "data/sql/projected_crs.sql",
    "data/sql/vertical_crs.sql",
    "data/sql/compound_crs.sql",
    "data/sql/engineering_crs.sql",
    "data/sql/helmert_transformation.sql",
    "data/sql/grid_transformation.sql",
    "data/sql/grid_transformation_custom.sql",
    "data/sql/other_transformation.sql",
    "data/sql/other_transformation_custom.sql",
    "data/sql/concatenated_operation.sql",
    "data/sql/concatenated_operation_step.sql",
    "data/sql/alias_name.sql",
    "data/sql/alias_name_old_epsg.sql",
    "data/sql/supersession.sql",
    "data/sql/deprecation.sql",
    "data/sql/esri.sql",
    "data/sql/ignf.sql",
    "data/sql/nkg.sql",
    "data/sql/iau.sql",
    "data/sql/nrcan.sql",
    "data/sql/transformations_czechia.sql",
    "data/sql/grid_alternatives.sql",
    "data/sql/grid_alternatives_generated_noaa.sql",
    "data/sql/nadcon5_concatenated_operations.sql",
    "data/sql/wgs84_realizations_concatenated_operations.sql",
    "data/sql/customizations.sql",
    "data/sql/nkg_post_customizations.sql",
    "data/sql/commit.sql",
    "data/sql/consistency_checks_triggers.sql",
    "data/sql/conversion_triggers.sql",
    "data/sql/conversion_triggers_hand_written.sql",
    "data/sql/analyze_vacuum.sql",
};

// ---------------------------------------------------------------------------
// The two host-run generators.
// ---------------------------------------------------------------------------

/// Host program that writes `proj_config.h` for one target.
///
/// Written into the local cache by `addHostProgram` rather than kept in `zig/`,
/// because it is this build graph's own tool and not part of the published
/// package: nothing in `build.zig.zon .paths` names it and no dependent reaches
/// it. It runs on the build host whatever `-Dtarget` says -- it is a program,
/// not a target library -- and everything about the *target* it writes arrives
/// on its command line from `configFacts`.
const proj_config_gen_source =
    \\// Host program. Written into the local cache by proj/build.zig; not part
    \\// of the published package.
    \\//
    \\// Reproduces cmake/proj_config.h.cmake.in's substitute,
    \\// cmake/proj_config.cmake.in, from facts the command line carries. Every
    \\// fact is the *target's*: build.zig resolves them from std.Target for the
    \\// target being compiled, so a cross build cannot pick up the build
    \\// machine's own libc. Nothing about the host is read, and no probe is run.
    \\
    \\const std = @import("std");
    \\
    \\// cmake/ProjConfig.cmake:21-27 sets these before `configure_file`.
    \\const package = "proj";
    \\const package_name = "PROJ";
    \\const package_bugreport = "https://github.com/OSGeo/PROJ/issues";
    \\const package_tarname = "proj";
    \\const version = "9.9.0";
    \\
    \\// The name of the temporary include guard CMake's configure_file writes
    \\// around a .cmake.in with no #cmakedefine-driven @VAR@ substitution.
    \\const include_guard = "PROJ_CONFIG_H_INCLUDED";
    \\
    \\pub fn main(init: std.process.Init) !void {
    \\    const arena = init.arena.allocator();
    \\    const io = init.io;
    \\    const cwd: std.Io.Dir = .cwd();
    \\
    \\    var target_triple: []const u8 = "<unnamed target>";
    \\    var have_libdl = false;
    \\    var have_localeconv = false;
    \\    var have_strerror = false;
    \\    var out_path: ?[]const u8 = null;
    \\
    \\    const argv = try init.minimal.args.toSlice(arena);
    \\    var i: usize = 1;
    \\    while (i < argv.len) : (i += 1) {
    \\        const arg = argv[i];
    \\        if (std.mem.startsWith(u8, arg, "--target=")) {
    \\            target_triple = arg["--target=".len..];
    \\        } else if (std.mem.startsWith(u8, arg, "--have-libdl=")) {
    \\            have_libdl = std.mem.eql(u8, arg["--have-libdl=".len..], "1");
    \\        } else if (std.mem.startsWith(u8, arg, "--have-localeconv=")) {
    \\            have_localeconv = std.mem.eql(u8, arg["--have-localeconv=".len..], "1");
    \\        } else if (std.mem.startsWith(u8, arg, "--have-strerror=")) {
    \\            have_strerror = std.mem.eql(u8, arg["--have-strerror=".len..], "1");
    \\        } else if (std.mem.startsWith(u8, arg, "--out=")) {
    \\            out_path = arg["--out=".len..];
    \\        } else {
    \\            std.log.err("proj-config-gen: unrecognised argument '{s}'", .{arg});
    \\            return error.BadArgument;
    \\        }
    \\    }
    \\
    \\    const out = out_path orelse {
    \\        std.log.err("proj-config-gen: no --out=<path> was given", .{});
    \\        return error.MissingOutputPath;
    \\    };
    \\
    \\    var text: std.ArrayList(u8) = .empty;
    \\    defer text.deinit(arena);
    \\
    \\    // Every line below is a line of cmake/proj_config.cmake.in, in that
    \\    // file's order, with `#cmakedefine X 1` rendered as `#define X 1` and
    \\    // `#cmakedefine X "..."` rendered as `#define X "..."`. A macro CMake
    \\    // would have left undefined becomes a commented-out `/* #undef X */`,
    \\    // which is what `configure_file` emits and what a reader of the
    \\    // generated header expects to see.
    \\
    \\    try text.print(arena, "#ifndef {s}\n#define {s}\n\n", .{ include_guard, include_guard });
    \\    try text.print(arena,
    \\        "/* Generated by proj/build.zig for {s}.\n" ++
    \\            " * Template: cmake/proj_config.cmake.in. The three HAVE_* macros below were\n" ++
    \\            " * decided for that target, from std.Target, by the three helpers named in\n" ++
    \\            " * build.zig; they are not what the build machine's libc happens to be. */\n\n",
    \\        .{target_triple},
    \\    );
    \\    try define(arena, &text, "HAVE_LIBDL", have_libdl);
    \\    try undefComment(arena, &text, "HAVE_LIBDL", !have_libdl);
    \\    try define(arena, &text, "HAVE_LOCALECONV", have_localeconv);
    \\    try undefComment(arena, &text, "HAVE_LOCALECONV", !have_localeconv);
    \\    try define(arena, &text, "HAVE_STRERROR", have_strerror);
    \\    try undefComment(arena, &text, "HAVE_STRERROR", !have_strerror);
    \\    try text.print(arena, "\n#define PACKAGE \"{s}\"\n", .{package});
    \\    try text.print(arena, "\n#define PACKAGE_BUGREPORT \"{s}\"\n", .{package_bugreport});
    \\    try text.print(arena, "\n#define PACKAGE_NAME \"{s}\"\n", .{package_name});
    \\    try text.print(arena, "\n#define PACKAGE_STRING \"{s} {s}\"\n", .{ package_name, version });
    \\    try text.print(arena, "\n#define PACKAGE_TARNAME \"{s}\"\n", .{package_tarname});
    \\    try text.print(arena, "\n#define PACKAGE_VERSION \"{s}\"\n", .{version});
    \\    // cmake/ProjVersion.cmake:30-38 sets `PROJ_VERSION`, never a bare
    \\    // `VERSION`, so the template's last `#cmakedefine VERSION "${VERSION}"`
    \\    // configures to the commented-out form. Defining it instead makes the
    \\    // macro `VERSION` expand over `include/proj/internal/io_internal.hpp:150`
    \\    // `static const std::string VERSION;`, which is a member name, not
    \\    // a declaration -- the collision upstream's own generated header
    \\    // avoids by leaving `VERSION` undefined.
    \\    try undefComment(arena, &text, "VERSION", true);
    \\    try text.print(arena, "\n#endif /* {s} */\n", .{include_guard});
    \\
    \\    try cwd.writeFile(io, .{ .sub_path = out, .data = text.items });
    \\    std.log.info("proj_config.h written for {s} (HAVE_LIBDL={d} HAVE_LOCALECONV={d} HAVE_STRERROR={d})", .{
    \\        target_triple,
    \\        @intFromBool(have_libdl),
    \\        @intFromBool(have_localeconv),
    \\        @intFromBool(have_strerror),
    \\    });
    \\}
    \\
    \\fn define(
    \\    arena: std.mem.Allocator,
    \\    out: *std.ArrayList(u8),
    \\    name: []const u8,
    \\    on: bool,
    \\) !void {
    \\    if (on) try out.print(arena, "#define {s} 1\n", .{name});
    \\}
    \\
    \\fn undefComment(
    \\    arena: std.mem.Allocator,
    \\    out: *std.ArrayList(u8),
    \\    name: []const u8,
    \\    on: bool,
    \\) !void {
    \\    if (on) try out.print(arena, "/* #undef {s} */\n", .{name});
    \\}
;

/// Host program that reproduces `data/generate_proj_db.cmake`.
///
/// Written into the local cache by `addHostProgram`; not part of the published
/// package. It replaces upstream's need for the `sqlite3` CLI binary
/// (`CMakeLists.txt:232-235` makes that a hard build requirement) with the
/// vendored amalgamation compiled into this very program, so no CLI is used,
/// none is required, and nothing is downloaded.
const proj_db_gen_source =
    \\// Host program. Written into the local cache by proj/build.zig; not part
    \\// of the published package.
    \\//
    \\// Reproduces data/generate_proj_db.cmake with PROJ_DB_EXTRA_VALIDATION
    \\// OFF, against the SQLite3 amalgamation compiled into this program.
    \\// Upstream's recipe concatenates the files of data/sql_filelist.cmake,
    \\// computes the MD5 of the concatenation with every `INSERT INTO
    \\// "metadata"` line removed, compares it against
    \\// data/sql/proj.db.sql.expected.md5, writes PROJ_DB_SQL_MD5.h, and then
    \\// runs the whole script through the `sqlite3` CLI on standard input.
    \\// Everything except the last step is reproduced byte for byte below; the
    \\// last step is `sqlite3_exec` against the vendored library instead.
    \\
    \\const std = @import("std");
    \\const c = @import("c");
    \\
    \\const metadata_prefix = "INSERT INTO \"metadata\"";
    \\const version_placeholder = "${PROJ_VERSION}";
    \\
    \\pub fn main(init: std.process.Init) !void {
    \\    const arena = init.arena.allocator();
    \\    const io = init.io;
    \\    const cwd: std.Io.Dir = .cwd();
    \\
    \\    var version: ?[]const u8 = null;
    \\    var expected_path: ?[]const u8 = null;
    \\    var md5_header_path: ?[]const u8 = null;
    \\    var db_path: ?[]const u8 = null;
    \\    var inputs: std.ArrayList([]const u8) = .empty;
    \\    defer inputs.deinit(arena);
    \\
    \\    const argv = try init.minimal.args.toSlice(arena);
    \\    var i: usize = 1;
    \\    while (i < argv.len) : (i += 1) {
    \\        const arg = argv[i];
    \\        if (std.mem.startsWith(u8, arg, "--version=")) {
    \\            version = arg["--version=".len..];
    \\        } else if (std.mem.startsWith(u8, arg, "--expected-md5-file=")) {
    \\            expected_path = arg["--expected-md5-file=".len..];
    \\        } else if (std.mem.startsWith(u8, arg, "--md5-header=")) {
    \\            md5_header_path = arg["--md5-header=".len..];
    \\        } else if (std.mem.startsWith(u8, arg, "--db=")) {
    \\            db_path = arg["--db=".len..];
    \\        } else if (std.mem.startsWith(u8, arg, "--in=")) {
    \\            try inputs.append(arena, arg["--in=".len..]);
    \\        } else {
    \\            std.log.err("proj-db-gen: unrecognised argument '{s}'", .{arg});
    \\            return error.BadArgument;
    \\        }
    \\    }
    \\
    \\    const proj_version = version orelse {
    \\        std.log.err("proj-db-gen: no --version=<string> was given", .{});
    \\        return error.MissingVersion;
    \\    };
    \\    const expected_file = expected_path orelse {
    \\        std.log.err("proj-db-gen: no --expected-md5-file=<path> was given", .{});
    \\        return error.MissingExpectedDigest;
    \\    };
    \\    const header_out = md5_header_path orelse {
    \\        std.log.err("proj-db-gen: no --md5-header=<path> was given", .{});
    \\        return error.MissingMd5HeaderPath;
    \\    };
    \\    const db_out = db_path orelse {
    \\        std.log.err("proj-db-gen: no --db=<path> was given", .{});
    \\        return error.MissingDatabasePath;
    \\    };
    \\    if (inputs.items.len == 0) {
    \\        std.log.err("proj-db-gen: no --in=<path> arguments were given", .{});
    \\        return error.MissingInputs;
    \\    }
    \\
    \\    // data/CMakeLists.txt:37 reads the expected digest with `file(STRINGS
    \\    // ... LIMIT_COUNT 1)`, which is the first whitespace-separated token.
    \\    const expected_raw = try cwd.readFileAlloc(io, expected_file, arena, .unlimited);
    \\    const expected_md5 = firstToken(expected_raw) orelse {
    \\        std.log.err("proj-db-gen: {s} holds no digest", .{expected_file});
    \\        return error.EmptyExpectedDigest;
    \\    };
    \\
    \\    // data/generate_proj_db.cmake:11-17: write an empty all.sql.in and
    \\    // `cat` each file onto it, in the order sql_filelist.cmake gives.
    \\    var all: std.ArrayList(u8) = .empty;
    \\    defer all.deinit(arena);
    \\    for (inputs.items) |path| {
    \\        const bytes = try cwd.readFileAlloc(io, path, arena, .unlimited);
    \\        try all.appendSlice(arena, bytes);
    \\    }
    \\    std.log.info("all.sql.in: {d} bytes from {d} files", .{ all.items.len, inputs.items.len });
    \\
    \\    // data/generate_proj_db.cmake:17-22 computes the MD5 *before* the
    \\    // version substitution, over the concatenation with every
    \\    // `INSERT INTO "metadata"` line removed, so that bumping PROJ_VERSION
    \\    // or PROJ_DATA.VERSION does not change it. The removal reproduces
    \\    // CMake's `string(REGEX REPLACE "INSERT INTO \"metadata\"[^\n]*\n?"
    \\    // "")`: from each occurrence of the literal, to the end of that line,
    \\    // including the newline when there is one. The pattern is unanchored,
    \\    // exactly as upstream writes it.
    \\    var without_metadata: std.ArrayList(u8) = .empty;
    \\    defer without_metadata.deinit(arena);
    \\    try stripMetadataLines(arena, all.items, &without_metadata);
    \\
    \\    var hasher = std.crypto.hash.Md5.init(.{});
    \\    hasher.update(without_metadata.items);
    \\    var digest: [std.crypto.hash.Md5.digest_length]u8 = undefined;
    \\    hasher.final(&digest);
    \\    const md5_hex = std.fmt.bytesToHex(digest, .lower);
    \\
    \\    // data/generate_proj_db.cmake:32-48: upstream warns and then, because
    \\    // the database built from the extra-validation script is still valid,
    \\    // fails and asks for the recorded digest to be updated. Here the digest
    \\    // is a stop: a database built from SQL this build cannot reproduce is
    \\    // not one to ship under upstream's name.
    \\    if (!std.mem.eql(u8, &md5_hex, expected_md5)) {
    \\        std.log.err(
    \\            "proj-db-gen: the concatenated SQL does not match {s}.\n" ++
    \\                "  computed: {s}\n" ++
    \\                "  recorded: {s}\n" ++
    \\                "Upstream's rule is generate_proj_db.cmake:32-48: this digest covers the\n" ++
    \\                "concatenation of data/sql_filelist.cmake with the INSERT INTO \"metadata\"\n" ++
    \\                "lines removed, and it must not change without upstream changing it.\n" ++
    \\                "No proj.db was written.",
    \\            .{ expected_file, &md5_hex, expected_md5 },
    \\        );
    \\        return error.SqlContentChanged;
    \\    }
    \\    std.log.info("all.sql.in md5 {s} matches {s}", .{ &md5_hex, expected_file });
    \\
    \\    // data/generate_proj_db.cmake:31 writes exactly this one line.
    \\    {
    \\        var header: std.ArrayList(u8) = .empty;
    \\        defer header.deinit(arena);
    \\        try header.print(arena, "const char* PROJ_DB_SQL_MD5=\"{s}\";\n", .{&md5_hex});
    \\        try cwd.writeFile(io, .{ .sub_path = header_out, .data = header.items });
    \\    }
    \\
    \\    // data/generate_proj_db.cmake:25-26 substitutes ${PROJ_VERSION} and
    \\    // writes the result back, so the executed script differs from the
    \\    // digested one in exactly the metadata lines.
    \\    var script: std.ArrayList(u8) = .empty;
    \\    defer script.deinit(arena);
    \\    try substitute(arena, all.items, version_placeholder, proj_version, &script);
    \\
    \\    // data/generate_proj_db.cmake:70-72 pipes that script into
    \\    // `sqlite3 <PROJ_DB>`, and `sqlite3_exec` with no callback runs every
    \\    // statement in turn, which is what the CLI does with a script on
    \\    // standard input.
    \\    //
    \\    // `sqlite3_open` opens an existing file read-write and creates a
    \\    // missing one; it does **not** truncate. Upstream only ever runs the
    \\    // CLI in a fresh build directory and removes the file outright in the
    \\    // one branch that can rerun (`:39`). This run step reuses one output
    \\    // path across runs, so the file is removed first: without it a second
    \\    // run applies the script on top of the first run's tables and stops
    \\    // at "table metadata already exists".
    \\    cwd.deleteFile(io, db_out) catch |err| switch (err) {
    \\        error.FileNotFound => {},
    \\        else => return err,
    \\    };
    \\    var maybe_db: ?*c.sqlite3 = null;
    \\    if (c.sqlite3_open(db_out.ptr, &maybe_db) != c.SQLITE_OK) {
    \\        const message = if (maybe_db) |handle|
    \\            std.mem.span(@as([*:0]const u8, c.sqlite3_errmsg(handle)))
    \\        else
    \\            "sqlite3_open returned no handle";
    \\        std.log.err("proj-db-gen: cannot open {s} as a SQLite database: {s}", .{ db_out, message });
    \\        return error.CannotOpenDatabase;
    \\    }
    \\    const db = maybe_db orelse {
    \\        std.log.err("proj-db-gen: sqlite3_open reported success but returned no handle", .{});
    \\        return error.CannotOpenDatabase;
    \\    };
    \\    defer _ = c.sqlite3_close(db);
    \\
    \\    const terminated = try arena.dupeZ(u8, script.items);
    \\    // sqlite3.h's `char **errmsg` translates to a `[*c][*c]u8`
    \\    // parameter, so the caller must hand over the *address* of a `char *`
    \\    // slot. `&slot` is a single-item pointer and does not coerce to a
    \\    // many-item pointer, hence the explicit `@ptrCast`. A `char *` is a
    \\    // non-optional pointer, and 0.16 rejects both `if (p)` and `p != null`
    \\    // on one, so the null test is on its address.
    \\    var errmsg_slot: [*:0]u8 = undefined;
    \\    const status = c.sqlite3_exec(db, terminated.ptr, null, null, @ptrCast(&errmsg_slot));
    \\    const errmsg: ?*anyopaque = if (@intFromPtr(errmsg_slot) != 0) errmsg_slot else null;
    \\    if (status != c.SQLITE_OK) {
    \\        std.log.err("proj-db-gen: running the concatenated SQL failed: {s}", .{
    \\            std.mem.span(@as([*:0]const u8, c.sqlite3_errmsg(db))),
    \\        });
    \\        if (errmsg) |message| c.sqlite3_free(message);
    \\        return error.DatabaseBuildFailed;
    \\    }
    \\    if (errmsg) |message| c.sqlite3_free(message);
    \\    std.log.info("proj.db built from {d} bytes of SQL (sqlite {s})", .{
    \\        script.items.len,
    \\        std.mem.span(@as([*:0]const u8, c.sqlite3_libversion())),
    \\    });
    \\}
    \\
    \\fn firstToken(bytes: []const u8) ?[]const u8 {
    \\    const trimmed = std.mem.trim(u8, bytes, " \t\r\n");
    \\    if (trimmed.len == 0) return null;
    \\    if (std.mem.indexOfAny(u8, trimmed, " \t\r\n")) |at| return trimmed[0..at];
    \\    return trimmed;
    \\}
    \\
    \\/// Copy `text` to `out`, dropping from each occurrence of
    \\/// `metadata_prefix` to the end of that line, newline included when there
    \\/// is one. See generate_proj_db.cmake:19-20 for the rule this reproduces.
    \\fn stripMetadataLines(
    \\    arena: std.mem.Allocator,
    \\    text: []const u8,
    \\    out: *std.ArrayList(u8),
    \\) !void {
    \\    var rest = text;
    \\    while (std.mem.indexOf(u8, rest, metadata_prefix)) |at| {
    \\        try out.appendSlice(arena, rest[0..at]);
    \\        const after = rest[at + metadata_prefix.len ..];
    \\        const line_end = std.mem.indexOfScalar(u8, after, '\n');
    \\        rest = if (line_end) |nl| after[nl + 1 ..] else after[0..0];
    \\    }
    \\    try out.appendSlice(arena, rest);
    \\}
    \\
    \\/// Copy `text` to `out`, replacing every occurrence of `needle` with
    \\/// `replacement`. See generate_proj_db.cmake:24-25.
    \\fn substitute(
    \\    arena: std.mem.Allocator,
    \\    text: []const u8,
    \\    needle: []const u8,
    \\    replacement: []const u8,
    \\    out: *std.ArrayList(u8),
    \\) !void {
    \\    var rest = text;
    \\    while (std.mem.indexOf(u8, rest, needle)) |at| {
    \\        try out.appendSlice(arena, rest[0..at]);
    \\        try out.appendSlice(arena, replacement);
    \\        rest = rest[at + needle.len ..];
    \\    }
    \\    try out.appendSlice(arena, rest);
    \\}
;

// ---------------------------------------------------------------------------
// Target facts.
// ---------------------------------------------------------------------------

/// The three toolchain facts `proj_config.h` carries, decided for `target`.
///
/// `cmake/ProjConfig.cmake:11-19` is what this reproduces:
///
///   * `HAVE_LIBDL` is `check_library_exists(dl dladdr "" HAVE_LIBDL)`, which
///     links against `-ldl` and so succeeds exactly where a separate `libdl`
///     exists. `dlLibrary` below is the same test expressed as a `std.Target`
///     question, so the macro and the link decision cannot disagree. Its only
///     compiled reader is `src/filemanager.cpp:66-68` (includes `<dlfcn.h>`)
///     and `:1402` (reaches the `dladdr` branch).
///   * `HAVE_LOCALECONV` is `check_function_exists(localeconv ...)`. ISO C99
///     7.11 requires `localeconv`, and every libc this package builds against
///     provides it, so it is true for every target. Its only compiled reader is
///     `src/strtod.cpp:68`, where the `#if !defined(...)` branch is the
///     `localeconv`-absent one and `src/strtod.cpp:74-78` gives up on locale
///     awareness.
///   * `HAVE_STRERROR` is `check_function_exists(strerror ...)`, and is
///     required by ISO C99 7.5. Its only reader in the whole tree is
///     `src/apps/emess.cpp:49-54`, and that file is one of the command-line
///     programs this build does not compile. It is still emitted, because the
///     generated header is upstream's and a reader should not have to know
///     which translation unit happens to look at it.
const ConfigFacts = struct {
    have_libdl: bool,
    have_localeconv: bool,
    have_strerror: bool,
};

fn configFacts(target: std.Build.ResolvedTarget) ConfigFacts {
    return .{
        .have_libdl = dlLibrary(target) != null,
        .have_localeconv = true,
        .have_strerror = true,
    };
}

/// The target's maths library, when it is a library of its own.
///
/// `cmake/ProjConfig.cmake:18` is `check_library_exists(m exp "" HAVE_LIBM)`
/// under `if(NOT WIN32)`, and `cmake/ProjUtilities.cmake:85-87` puts the same
/// answer in `Libs.private:`. libm is separate on glibc and the BSDs and part
/// of the system library on macOS, Windows and WASI, which is why this is a
/// list.
fn mathLibrary(target: std.Build.ResolvedTarget) ?[]const u8 {
    return switch (target.result.os.tag) {
        .linux, .freebsd, .netbsd, .openbsd, .dragonfly, .illumos => "m",
        else => null,
    };
}

/// The target's dynamic-loader library, when it is a library of its own.
///
/// The same rule as `mathLibrary`, and the answer `HAVE_LIBDL` is given. It is
/// null on macOS (where `dl*` is in the system library, which is also why
/// `check_library_exists(dl dladdr ...)` cannot succeed there), on Windows
/// (`cmake/ProjConfig.cmake:16` skips the whole block under `WIN32`, and
/// `src/filemanager.cpp:1402` reaches the `_WIN32` branch first), and on WASI.
fn dlLibrary(target: std.Build.ResolvedTarget) ?[]const u8 {
    return switch (target.result.os.tag) {
        .linux, .illumos => "dl",
        else => null,
    };
}

/// The target's pthreads library, when it is one.
///
/// `src/lib_proj.cmake:3-6` is `find_package(Threads QUIET)` gated on
/// `CMAKE_USE_PTHREADS_INIT`, and `cmake/ProjUtilities.cmake:59` puts
/// `${CMAKE_THREAD_LIBS_INIT}` first in `EXTRA_LIBS`. Null on macOS and WASI,
/// where the system library carries the threads implementation, and on
/// Windows, where `src/iso19111/factory.cpp:87-89` `#undef`s `PROJ_HAS_PTHREADS`
/// and so never reaches the `pthread_atfork` at `:96-99`.
fn pthreadLibrary(target: std.Build.ResolvedTarget) ?[]const u8 {
    return switch (target.result.os.tag) {
        .linux, .freebsd, .netbsd, .openbsd, .dragonfly => "pthread",
        else => null,
    };
}

/// Whether this target has pthreads, and so takes `PROJ_HAS_PTHREADS`.
///
/// It is `pthreadLibrary` again rather than a second list, because the
/// definition and the link have to be the same statement: `factory.cpp:96-99`
/// opens `<pthread.h>` and calls `pthread_atfork` when the macro is set, so a
/// target given the definition without the library would be a link error and a
/// target given the library without the definition would carry a dependency it
/// does not use.
fn hasPthreads(target: std.Build.ResolvedTarget) bool {
    return pthreadLibrary(target) != null;
}

/// Whether this target's `NOMINMAX` definition applies.
///
/// `src/lib_proj.cmake:401-403` is `if(MSVC OR MINGW)`. MinGW defines
/// `_WIN32` and the Windows SDK headers define `min` and `max` unless
/// `NOMINMAX` is set, which several of the 219 units would otherwise collide
/// with. No other platform has those macros, so no other target defines it.
fn needsNomInmax(target: std.Build.ResolvedTarget) bool {
    return target.result.os.tag == .windows;
}

/// The target's C++ runtime, for the installed `Libs.private:` line.
///
/// Upstream derives the same answer from the compiler rather than from the OS:
/// `cmake/ProjUtilities.cmake:79-83` takes every library
/// `CMAKE_CXX_IMPLICIT_LINK_LIBRARIES` names that `CMAKE_C_IMPLICIT_LINK_LIBRARIES`
/// does not, and `src/lib_proj.cmake:579-581` is what makes that necessary by
/// setting `LINKER_LANGUAGE CXX`. There is no `std.Target` question that answers
/// it, because it is the toolchain's choice, so this is a spelling per platform
/// and the file says so. `zig cc` links the C++ runtime itself for every
/// compilation in this graph (`link_libcpp` below); this is what a *foreign* C
/// toolchain needs from a `.pc` file.
fn cppRuntimeLibrary(target: std.Build.ResolvedTarget) ?[]const u8 {
    return switch (target.result.os.tag) {
        .linux, .windows => "stdc++",
        .macos, .freebsd, .netbsd, .openbsd, .dragonfly => "c++",
        else => null,
    };
}

/// Links the target's system dependencies the compiled core needs.
///
/// It goes on every module a dependent can end up importing, not only on the
/// archive's own module: a `linkSystemLibrary` recorded on a static library
/// stays inside that library's link line and never reaches the executable that
/// links the archive, which would leave every dependent to discover the
/// undefined `pthread_atfork` on its own.
fn linkSystemDependencies(module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    inline for (.{ mathLibrary, dlLibrary, pthreadLibrary }) |resolve| {
        if (resolve(target)) |lib| module.linkSystemLibrary(lib, .{});
    }
}

/// Whether this target can carry the linkage that was requested.
///
/// It gates a refusal and nothing else. There is deliberately no second return
/// value that would let a caller substitute another linkage: the option names
/// the artifact, and this build either produces that artifact or says it
/// cannot. Windows loads PE/COFF DLLs without an interpreter path; other
/// shared targets need a dynamic linker; static archives need neither.
fn targetCanCarry(
    target: std.Build.ResolvedTarget,
    requested: std.builtin.LinkMode,
) bool {
    return requested == .static or
        target.result.os.tag == .windows or
        std.Target.DynamicLinker.kind(target.result.os.tag) != .none;
}

/// The exact reason a linkage cannot be honoured for `target`.
///
/// One message, so the refusal a caller reads for one target is the refusal they
/// would read for any other.
fn unsupportedLinkageReason(b: *std.Build, target: std.Build.ResolvedTarget) []const u8 {
    return b.fmt(
        "proj: -Dlinkage=dynamic is unsupported for {s}: dynamic linker kind is {s}. " ++
            "No static archive is substituted. Use -Dlinkage=static for this target.",
        .{ @tagName(target.result.os.tag), @tagName(std.Target.DynamicLinker.kind(target.result.os.tag)) },
    );
}

/// Refuses a linkage this target cannot carry, naming the reason.
///
/// A configure-time refusal, before any step is created for the target.
/// `addGraph` calls it for the target it is about to build; `addTargetCheck` has
/// already filtered out the cells this function would refuse, and says so by
/// name.
fn requireSupportedLinkage(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    requested: std.builtin.LinkMode,
) void {
    if (!targetCanCarry(target, requested)) {
        @panic(unsupportedLinkageReason(b, target));
    }
}

/// The name a compiled artifact carries in this build graph.
///
/// The published graph installs `libproj.a` or `libproj.so.25`, the name a C
/// consumer's `-lproj` needs. A check graph installs nothing, so its artifacts
/// carry the target triple instead: six targets share one build graph, and six
/// steps all called `proj` make `--summary all` impossible to read.
fn artifactName(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    public: bool,
) []const u8 {
    if (public) return lib_name;
    const triple = target.result.zigTriple(b.allocator) catch @panic("unspellable target");
    return b.fmt("{s}-{s}", .{ lib_name, triple });
}

// ---------------------------------------------------------------------------
// Generated inputs.
// ---------------------------------------------------------------------------

/// One generated input's file and the directory it lives in.
///
/// The directory is what goes on an include path: a generated header included
/// by bare name needs its own directory on the path, and
/// `src/filemanager.cpp:33`, `src/strerrno.cpp:8` and `src/strtod.cpp:37`
/// include `proj_config.h` by bare name.
const Generated = struct {
    header: std.Build.LazyPath,
    dir: std.Build.LazyPath,
};

/// Compiles one of the generator sources for the host.
///
/// The generator runs on the machine running `zig build` whatever `-Dtarget`
/// says: it is a program, not a target library. What it writes is decided by its
/// command line, and `configFacts` / `sql_files` below are computed from the
/// target. `ReleaseSafe` is pinned so a generator that reads a missing file or
/// mismatches a digest stops with a message rather than continuing.
fn addHostProgram(
    b: *std.Build,
    name: []const u8,
    source: []const u8,
) *std.Build.Step.Compile {
    const files = b.addWriteFiles();
    const root = files.add(b.fmt("{s}.zig", .{name}), source);
    return b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = root,
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
            .link_libc = true,
        }),
    });
}

/// Builds and runs `proj_config_gen_source` for `target`.
///
/// One run per target, and the output directory is a fresh cache directory the
/// run step allocates, so a `aarch64-linux-gnu` compile line can never read a
/// `proj_config.h` written for `x86_64-windows-gnu`.
fn addProjConfig(b: *std.Build, target: std.Build.ResolvedTarget) Generated {
    const run = b.addRunArtifact(addHostProgram(b, "proj-config-gen", proj_config_gen_source));
    run.has_side_effects = true;

    const facts = configFacts(target);
    const triple = target.result.zigTriple(b.allocator) catch @panic("unspellable target");

    run.addArg(b.fmt("--target={s}", .{triple}));
    run.addArg(b.fmt("--have-libdl={d}", .{@intFromBool(facts.have_libdl)}));
    run.addArg(b.fmt("--have-localeconv={d}", .{@intFromBool(facts.have_localeconv)}));
    run.addArg(b.fmt("--have-strerror={d}", .{@intFromBool(facts.have_strerror)}));
    const header = run.addPrefixedOutputFileArg("--out=", "proj_config.h");

    return .{
        .header = header,
        .dir = header.dirname(),
    };
}

/// What `addProjDb` produces.
const ProjectDatabase = struct {
    /// The generated `proj.db`, the EPSG and PROJ registry `src/iso19111`
    /// reads at run time.
    db: std.Build.LazyPath,
    /// `PROJ_DB_SQL_MD5.h`, written beside it.
    md5_header: std.Build.LazyPath,
    /// The directory both live in.
    dir: std.Build.LazyPath,
};

/// Builds and runs `proj_db_gen_source`.
///
/// It is built and run **once** for the whole build, not once per target: its
/// fifty inputs are this repository's SQL files and its output is a datum
/// database, neither of which depends on the target being compiled. Six target
/// graphs therefore share one generated `proj.db` and one assertion.
fn addProjDb(b: *std.Build) ProjectDatabase {
    const translate = b.addTranslateC(.{
        .root_source_file = b.addWriteFiles().add("proj_sqlite_translate.h", sqlite_translate_header_source),
        .target = b.graph.host,
        .optimize = .ReleaseSafe,
        .link_libc = true,
    });
    // The only header search path the translation has. Without it the
    // translation would bind to whatever `sqlite3.h` happens to be installed on
    // the build machine and describe that library's declarations rather than
    // the vendored amalgamation's (`WISDOM.md` W14).
    translate.addIncludePath(b.path(sqlite_dir));

    // `proj_db_gen_source` is this program's root source. Without it the
    // executable has no `main` at all: `b.createModule` is given the SQLite
    // translation as an import and the amalgamation as a C source, neither of
    // which is an entry point.
    const files = b.addWriteFiles();
    const module = b.createModule(.{
        .root_source_file = files.add("proj-db-gen.zig", proj_db_gen_source),
        .target = b.graph.host,
        .optimize = .ReleaseSafe,
        .link_libc = true,
    });
    module.addImport("c", translate.createModule());
    // The amalgamation itself, compiled for the host, as its own translation
    // unit. It is a second copy on purpose: the copy inside `libproj` is for
    // the target being built and is never run, while this one is the library the
    // generator actually executes SQL against.
    module.addCSourceFile(.{
        .file = b.path(sqlite_source),
        .flags = &c_flags,
    });

    const run = b.addRunArtifact(b.addExecutable(.{
        .name = "proj-db-gen",
        .root_module = module,
    }));
    run.has_side_effects = true;

    run.addArg(b.fmt("--version={s}", .{upstream_version_text}));
    run.addPrefixedFileArg("--expected-md5-file=", b.path(expected_md5_file));
    for (sql_files) |file| run.addPrefixedFileArg("--in=", b.path(file));
    const md5_header = run.addPrefixedOutputFileArg("--md5-header=", "PROJ_DB_SQL_MD5.h");
    const db = run.addPrefixedOutputFileArg("--db=", "proj.db");

    return .{ .db = db, .md5_header = md5_header, .dir = md5_header.dirname() };
}

// ---------------------------------------------------------------------------
// The graph.
// ---------------------------------------------------------------------------

/// One target's library and facade.
const Graph = struct {
    /// The compiled native library, in whichever linkage this target can carry.
    library: *std.Build.Step.Compile,
    /// The facade module, with `c` bound to the translated header for the
    /// library this graph compiled.
    module: *std.Build.Module,
    /// The translated header, shared by the facade and by the API exercise so
    /// both describe exactly one C ABI in a graph. Under `-Druntime` this is the
    /// generated dispatch instead, which is what keeps the exercise honest about
    /// the route it is exercising.
    c_module: *std.Build.Module,
    /// The one loader-core module instance this graph built, or null when
    /// `-Druntime` is on and the generated dispatch owns the instance instead.
    ///
    /// It is a field rather than a second `createCoreModule` call in
    /// `addExercise` because there must be exactly one: `createModule` builds the
    /// core internally and re-exports `LoadSource`/`LoadError` from it, so a
    /// second instance would be a second, nominally distinct `LoadSource` and a
    /// `load(source)` written against one would be handed to the other.
    core_module: ?*std.Build.Module,
    /// The per-target generated header's directory. On the compile line and on
    /// the translation line, both.
    config_dir: std.Build.LazyPath,
};

/// Compiles the core library for one target, in the requested delivery.
///
/// `addCLibrary` is where every fact in the "Compile settings" section above
/// lands, so the shared flag cannot reach one unit and miss another.
fn addCLibrary(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    config: Generated,
    project_db: ProjectDatabase,
    name: []const u8,
) *std.Build.Step.Compile {
    const library = b.addLibrary(.{
        .name = name,
        .linkage = linkage,
        // `CMakeLists.txt:170-171` and `src/lib_proj.cmake:572-576`. Zig's
        // `Step.Compile` derives the `libproj.so.25` soname name and the
        // `libproj.so` link name from `version.major`
        // (`lib/std/Build/Step/Compile.zig:501-503`), so one value produces
        // both installed file names, and null produces an unversioned
        // `libproj.so` that upstream never builds on ELF.
        .version = library_version,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            // libc, because the core includes <stdlib.h>, <string.h>, <math.h>
            // and <stdio.h> throughout and its SQLite usage is a C library.
            .link_libc = true,
            // The C++ runtime. `src/lib_proj.cmake:579-581` sets
            // `LINKER_LANGUAGE CXX`, so a dependent's link line that pulls in
            // this archive needs it, and stating it here is what puts it there
            // (`lib/std/Build/Step/Compile.zig:1053-1057` walks every module in
            // the graph). Without it every dependent would discover the
            // undefined `std::` symbol on its own.
            .link_libcpp = true,
            // Stated rather than implied. A shared library is position
            // independent whether or not this says so; a static archive is
            // neither this nor anything else, and the flag is what says which of
            // the two this build is delivering.
            .pic = if (linkage == .dynamic) true else null,
        }),
    });
    const module = library.root_module;

    // `src/`, `include/`, the generated-header directory and the vendored
    // SQLite3, in that order, on both the compile line and the translation line
    // (`src/lib_proj.cmake:306-308` and `:529-532` are two of them; the fourth
    // is this package's own).
    module.addIncludePath(b.path(source_dir));
    module.addIncludePath(b.path(include_dir));
    module.addIncludePath(config.dir);
    module.addIncludePath(project_db.dir);
    module.addIncludePath(b.path(sqlite_dir));

    // `src/lib_proj.cmake:399` for a static build. Empty, because
    // `src/proj.h:143-155` gives `PROJ_DLL` a value only `#ifndef` it, and an
    // empty definition is exactly what upstream's `-DPROJ_DLL=` says.
    module.addCMacro("PROJ_DLL", "");

    if (needsNomInmax(target)) module.addCMacro("NOMINMAX", "1");

    // `src/lib_proj.cmake:3-6`. Null on Windows because
    // `src/iso19111/factory.cpp:87-89` `#undef`s it there anyway, and null on
    // WASI because `find_package(Threads)` finds nothing.
    if (hasPthreads(target)) module.addCMacro("PROJ_HAS_PTHREADS", "1");

    for (all_target_sources) |source| {
        module.addCSourceFile(.{
            .file = b.path(source),
            // The pinned dialect for the unit's language, chosen from its own
            // extension rather than from a per-unit table: a `.c` unit gets
            // `-std=c99` and a `.cpp` unit gets `-std=c++17`. The three C units
            // are `src/geodesic.c` and the two bison-generated WKT parsers.
            .flags = if (std.mem.endsWith(u8, source, ".c")) &c_flags else &cxx_flags,
        });
    }

    // The vendored SQLite3 amalgamation, into the same archive. `PRIVATE` in
    // `src/lib_proj.cmake:352` is what this reproduces: it is linked into the
    // library and never published as an artifact of its own.
    module.addCSourceFile(.{ .file = b.path(sqlite_source), .flags = &c_flags });

    // The by-value ABI bridge. Ten of upstream's entry points take or return
    // `PJ_COORD` by value (`src/proj.h:629,656,663,666,669,672,676,705,783` and
    // `:1426-1429`), and the compiler that builds this archive and the compiler
    // that builds the Zig side of a call into it disagree about where a 32-byte
    // union goes. `zig/proj_abi.h` states the disagreement and the evidence; the
    // repair is that the by-value call is made by C, so both halves of it come
    // from the same compiler. It goes in the archive rather than in a caller
    // because every route that links this library needs it, and because the
    // shared object carries it for a runtime-loading provider too.
    module.addCSourceFile(.{ .file = b.path(bridge_source), .flags = &c_flags });

    linkSystemDependencies(module, target);

    // Installing the four public headers also puts them on the include path of
    // anything that links this artifact, so a C consumer needs nothing from this
    // tree. They are upstream's `HEADERS_LIBPROJ` (`src/lib_proj.cmake:284-290`).
    // `geodesic.h` is upstream's fifth header there and is deliberately not
    // installed: it is a vendored third-party header, PROJ's own install rules do
    // not publish it, and `src/lib_proj.cmake:284-290` names it only so an IDE
    // lists it.
    library.installHeader(b.path("src/proj.h"), "proj.h");
    library.installHeader(b.path("src/proj_constants.h"), "proj_constants.h");
    library.installHeader(b.path("src/proj_experimental.h"), "proj_experimental.h");
    library.installHeader(b.path("src/proj_symbol_rename.h"), "proj_symbol_rename.h");

    return library;
}

/// Builds one target's library and facade.
///
/// `public` chooses between the package module set, which is what a dependent
/// reaches through `dep.module("proj")`, and a private module. A cross-target
/// check needs the private form: modules are registered by name against the
/// whole build, so registering `proj` once per matrix target would leave only
/// the last of them reachable and silently stop checking the rest. The
/// translated header is imported rather than registered in both forms.
fn addGraph(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    runtime_loaded: bool,
    public: bool,
    project_db: ProjectDatabase,
) Graph {
    // The one place a requested linkage is checked against what this target can
    // carry, before a single step exists for it.
    requireSupportedLinkage(b, target, linkage);

    // The generated `proj_config.h` is per target, and so is this graph's copy of
    // the generator run that produces it.
    const config = addProjConfig(b, target);

    const library = addCLibrary(b, target, optimize, linkage, config, project_db, artifactName(b, target, public));

    const translate = b.addTranslateC(.{
        .root_source_file = b.path(translate_header),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    // `zig/translate.h` includes `<proj.h>` and `<proj_constants.h>`, both of
    // which live in `src/`, and these are the only header search paths the
    // translation has. Without `src/` it would silently bind to whatever `proj.h`
    // happens to be installed on the build machine and describe that library's
    // declarations rather than the ones this graph compiles (`WISDOM.md` W14).
    // The generated directory is here too, so that a translation of a header
    // which includes `proj_config.h` by bare name resolves the same file the
    // compile line does.
    translate.addIncludePath(b.path(source_dir));
    translate.addIncludePath(b.path(include_dir));
    translate.addIncludePath(config.dir);

    const module = if (public)
        b.addModule(module_name, .{
            .root_source_file = b.path(facade_source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        })
    else
        b.createModule(.{
            .root_source_file = b.path(facade_source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

    // Where the runtime-loading seam is
    // ---------------------------------
    // `runtime/graph.zig`, which the API role owns, exposes
    //
    //     pub fn createModule(
    //         b: *std.Build,
    //         translate: *std.Build.Step.TranslateC,
    //         target: std.Build.ResolvedTarget,
    //         optimize: std.builtin.OptimizeMode,
    //     ) *std.Build.Module
    //
    // and `-Druntime=true` substitutes that one call for
    // `translate.createModule()`. It takes the `TranslateC` step this function has
    // already built, so the generated dispatch keeps the exact translated type and
    // constant namespace rather than compiling a second copy of the native extern
    // structs and casting between two nominally distinct Zig modules.
    //
    // `-Dlinkage` is orthogonal and keeps meaning what it means: it selects which
    // artifact this build *delivers* and installs, never which one the module
    // dispatches through. The library above was built and will be installed in
    // both branches.
    //
    // The `rt` import is for the linked branch only, and the reason is the
    // nominal type rather than the code. `runtime_graph.createModule` creates the
    // one core-module instance the generated dispatch uses and re-exports
    // `LoadSource`/`LoadError` from it; a second instance created here for the
    // facade would be a *different* `LoadSource`, and `proj.load(source)` would be
    // handing the facade's type to a function expecting the dispatch's. One
    // instance per build, no more. In a linked build there is no dispatch, so the
    // facade's own `rt` import is where those two public types come from, and
    // `zig/root.zig` picks between the two with a comptime branch, so the module
    // a configuration does not need is never resolved and never compiled.
    const c_module = if (runtime_loaded) blk: {
        // A loaded provider must arrive through the platform loader, so the link
        // line names nothing. Linking the archive or `-lm` as well would make the
        // linker resolve the same symbols itself and the runtime route would
        // quietly be a linked one.
        break :blk runtime_graph.createModule(b, translate, target, optimize);
    } else blk: {
        // The translated header is imported, never registered. `addModule("c")`
        // would make `dep.module("c")` resolve and hand a dependent the same
        // declarations without the library that satisfies them; `c` on the facade
        // is the supported way in and carries the facade's own linkage.
        break :blk translate.createModule();
    };
    module.addImport("c", c_module);

    const core_module: ?*std.Build.Module = if (runtime_loaded)
        null
    else
        runtime_graph.createCoreModule(b, target, optimize);

    if (core_module) |rt| {
        module.addImport("rt", rt);
        module.linkLibrary(library);
        // The archive's own system dependencies, on the module a dependent
        // actually imports, for the same reason `addCLibrary` puts them there.
        linkSystemDependencies(module, target);
        // The C++ runtime, because this is the branch that links the archive and
        // the archive is C++ (`LINKER_LANGUAGE CXX`).
        module.link_libcpp = true;
    }

    // `src/` is on the facade's include path in both branches, and this is not a
    // link decision: a dependent that compiles its own C against this package
    // must find the same `proj.h` the core was compiled with, whether or not this
    // configuration links anything native.
    module.addIncludePath(b.path(source_dir));
    module.addIncludePath(b.path(include_dir));
    module.addIncludePath(config.dir);
    module.addIncludePath(project_db.dir);
    module.addIncludePath(b.path(sqlite_dir));

    return .{
        .library = library,
        .module = module,
        .c_module = c_module,
        .core_module = core_module,
        .config_dir = config.dir,
    };
}

/// A Zig program or test root that imports the published facade module.
///
/// `link_libc` is stated on every one of them even though the facade carries it:
/// a dependent states its own, and this build should fail here if the facade
/// ever stopped bringing libc along.
fn facadeProgram(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    facade: *std.Build.Module,
    source: []const u8,
) *std.Build.Module {
    const module = b.createModule(.{
        .root_source_file = b.path(source),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    module.addImport(module_name, facade);
    return module;
}

/// The explicit API exercise, compiled as its own test artifact and never run.
///
/// It is a test root rather than an executable for one reason: a Zig function
/// body is analysed only when something calls it, and a `pub fn` nobody
/// references is not analysed however prominent it is. `zig/api_exercise.zig`
/// names one `test` block, and that block calls `exercise`; a test body is
/// semantically analysed at compile time, so compiling this artifact
/// instantiates every call the exercise makes. Nothing runs it — the file says
/// so, and under `-Druntime` running it would open a provider path that does
/// not exist and would then call upstream's one-way `cleanup`.
///
/// It imports `c` from the same translation the facade imports, and does not
/// import the facade module: the facade already contains this file, so a module
/// import from here would close a loop between the two. Under `-Druntime` that
/// `c` is the generated dispatch, so the exercise compiles the route the facade
/// actually calls, and it links nothing: the provider a run would need is named
/// by the API role's own loader tests.
fn addExercise(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    graph: Graph,
    runtime_loaded: bool,
    name: []const u8,
) *std.Build.Step.Compile {
    const module = b.createModule(.{
        .root_source_file = b.path(exercise_source),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    module.addImport("c", graph.c_module);
    // The same core-module instance the facade's own `rt` import names, and for
    // the same reason the facade needs it: this module's root includes
    // `zig/root.zig`, and an import inside that file resolves against *this*
    // module's table, not the facade's. Under `-Druntime` the dispatch carries
    // the public types itself and `rt` is never resolved, so there is nothing to
    // bind and `core_module` is null.
    if (graph.core_module) |rt| module.addImport("rt", rt);
    if (!runtime_loaded) {
        module.linkLibrary(graph.library);
        linkSystemDependencies(module, target);
        module.link_libcpp = true;
    }
    return b.addTest(.{ .name = name, .root_module = module });
}

// ---------------------------------------------------------------------------
// Installation.
// ---------------------------------------------------------------------------

/// Writes `lib/pkgconfig/proj.pc` and installs it.
///
/// Upstream ships `proj.pc.in` and `cmake/ProjUtilities.cmake:50-100`
/// substitutes it, so every field below is one of that function's values with
/// one change of mechanism and one deliberate difference.
///
///   * `prefix` is `${pcfiledir}/../..`. `configure_proj_pc` sets `prefix` to
///     `CMAKE_INSTALL_PREFIX` (`:51`), which is correct for a `cmake --install`
///     and wrong for a relocatable tree: this graph does not know where
///     `--prefix` will point when it writes the file. pkg-config resolves
///     `${pcfiledir}` against the `.pc` file it found, which makes the installed
///     file correct wherever the prefix landed, including a Nix store path known
///     only at build time. The remaining four path fields are then
///     `${prefix}/...`, which is what `configure_proj_pc` builds out of
///     `CMAKE_INSTALL_LIBDIR`, `CMAKE_INSTALL_INCLUDEDIR` and
///     `CMAKE_INSTALL_DATAROOTDIR` (`:52-55`) and what the install layout below
///     actually produces.
///   * `datadir=@datadir@/@PACKAGE@` becomes `${datarootdir}/proj`, because
///     `:55-56` sets `datadir` to `${datarootdir}` and `PACKAGE` to `proj`, and
///     the install writes `share/proj/`. That is the same directory
///     `PROJ_DATA` below names, so a consumer's `pkg-config --variable=datadir
///     proj` is the answer to "where is the database".
///   * `Version:` is `PROJ_VERSION` (`:57`), so `9.9.0` and not the ABI
///     `25.9.0` of the shared object's file name. `build()` has checked the three
///     components against `build.zig.zon .version`, so the manifest, this field
///     and `src/proj.h:176-178` cannot name three different releases.
///   * `Libs:` is the same in both deliveries, because the library *name* does not
///     change with linkage: a C consumer asks for `-lproj` and the linker resolves
///     it to `libproj.a` or, through `libproj.so`, to the shared object.
///
/// Two lines differ from upstream on purpose:
///
///   * `Requires.private:` is empty where upstream writes `sqlite3`
///     (`cmake/ProjUtilities.cmake:61,64,69`). This build compiles
///     `vendor/sqlite3/sqlite3.c` into `libproj` itself, so the static closure is
///     already complete; a `sqlite3` requirement would make every static
///     consumer's `pkg-config` demand a `sqlite3.pc` that is not needed and need
///     not exist.
///   * `Libs.private:` carries the libraries the *archive* needs beyond libc and
///     the platform's own answer to the same question: the C++ runtime (upstream
///     gets it from `CMAKE_CXX_IMPLICIT_LINK_LIBRARIES`, `:79-83`; see
///     `cppRuntimeLibrary`), `-lm`, `-ldl` and `-lpthread` exactly where
///     `mathLibrary`, `dlLibrary` and `pthreadLibrary` say this target needs
///     them. The whole line is omitted when there is nothing to say, because
///     pkg-config reads `--static` output as `Libs` plus `Libs.private` and a
///     stray `-lm` on `Libs` would be handed to every consumer whether or not it
///     links this library statically.
fn addPkgConfig(b: *std.Build, target: std.Build.ResolvedTarget) void {
    var libs_private: std.ArrayList(u8) = .empty;
    defer libs_private.deinit(b.allocator);
    var any = false;
    inline for (.{ cppRuntimeLibrary, mathLibrary, dlLibrary, pthreadLibrary }) |resolve| {
        if (resolve(target)) |lib| {
            libs_private.appendSlice(b.allocator, if (any) " -l" else "-l") catch @panic("OOM");
            libs_private.appendSlice(b.allocator, lib) catch @panic("OOM");
            any = true;
        }
    }
    const private_line = if (any)
        b.fmt("Libs.private: {s}\n", .{libs_private.items})
    else
        "";

    const pc = b.addWriteFiles().add(b.fmt("{s}.pc", .{pkg_config_name}), b.fmt(
        \\# Generated by proj/build.zig from proj.pc.in.
        \\# Substituted by cmake/ProjUtilities.cmake:50-100 upstream; see addPkgConfig
        \\# in build.zig for which field is which and which two differ on purpose.
        \\prefix=${{pcfiledir}}/../..
        \\exec_prefix=${{prefix}}
        \\libdir=${{prefix}}/lib
        \\includedir=${{prefix}}/include
        \\datarootdir=${{prefix}}/share
        \\datadir=${{datarootdir}}/{s}
        \\
        \\Name: PROJ
        \\Description: Coordinate transformation software library
        \\URL: https://proj.org/
        \\Version: {s}
        \\
        \\Requires:
        \\Libs: -L"${{libdir}}" -l{s}
        \\{s}Requires.private:
        \\Cflags: -I"${{includedir}}"
        \\
    , .{
        // cmake/ProjConfig.cmake:21 `set(PACKAGE "proj")`.
        "proj",
        // cmake/ProjUtilities.cmake:57 `set(VERSION ${PROJ_VERSION})`.
        upstream_version_text,
        lib_name,
        private_line,
    }));
    const install = b.addInstallFileWithDir(
        pc,
        .lib,
        b.fmt("pkgconfig/{s}.pc", .{pkg_config_name}),
    );
    b.getInstallStep().dependOn(&install.step);
}

/// Installs the generated database and the static data files into
/// `share/proj/`, and returns the step that installs the database.
///
/// That returned directory is what every run step below names in `PROJ_DATA`. It
/// is a configure-time path from `b.getInstallPath`, not a generated one, for
/// two reasons that are both load-bearing: the datum directory has to exist
/// before anything opens `proj.db`, and `GeneratedFile.path` is not set until a
/// step's `makeFn` has run (`lib/std/Build.zig:2275-2277`), so a generated
/// directory cannot be named at configure time at all. Depending on the install
/// step is therefore not a convenience; it is the only way to name it.
fn addDataDirectory(
    b: *std.Build,
    project_db: ProjectDatabase,
) *std.Build.Step.InstallFile {
    const install = b.addInstallFileWithDir(
        project_db.db,
        .prefix,
        "share/proj/proj.db",
    );
    // `Step.InstallFile.create` already recorded the database's generator as a
    // dependency of this step (`lib/std/Build/Step/InstallFile.zig:34`), so the
    // run step that produces `proj.db` happens before it can be copied.
    b.getInstallStep().dependOn(&install.step);

    for (data_files) |file| {
        const step = b.addInstallFileWithDir(
            b.path(file),
            .prefix,
            b.pathJoin(&.{ "share", "proj", std.fs.path.basename(file) }),
        );
        b.getInstallStep().dependOn(&step.step);
    }

    return install;
}

/// Installs the licence and the records under `share/doc/proj/`.
///
/// The directory is named after the **published module**, `proj`, and not after
/// this repository's directory (`proj`), the manifest's `.name` (`.proj`), the
/// artifact (`proj`) or the derivation's `pname`. They happen to be one spelling
/// here, which is the point: one spelling for the installed tree is what makes a
/// hand-written `zig build --prefix <p>` and a Nix `$out` the same directory tree
/// by construction rather than two that have to be kept in agreement.
fn installRecords(b: *std.Build) void {
    for (doc_records) |record| {
        const install = b.addInstallFileWithDir(
            b.path(record),
            .prefix,
            b.fmt("share/doc/{s}/{s}", .{ module_name, std.fs.path.basename(record) }),
        );
        b.getInstallStep().dependOn(&install.step);
    }
}

// ---------------------------------------------------------------------------
// The run steps.
// ---------------------------------------------------------------------------

/// Puts `PROJ_DATA` and `PROJ_NETWORK` on a run step.
///
/// `PROJ_DATA` is the installed `share/proj` directory, which is PROJ's own first
/// search path (`src/filemanager.cpp:1119-1127`); `PROJ_LIB` is second and
/// deprecated there, and is deliberately not set. `PROJ_NETWORK=OFF` is read by
/// `src/filemanager.cpp:1994-1998`, which enables networking only for `ON`,
/// `YES` or `TRUE`, so "no network" is a property of the gate rather than
/// something the machine happened to have. `PROJ_USER_WRITABLE_DIRECTORY` is left
/// alone: it is the user's, and nothing here should redirect it.
///
/// The step also depends on the data install, because a `PROJ_DATA` that points
/// at a directory the same invocation has not filled is not the directory.
fn applyProjEnvironment(run: *std.Build.Step.Run, data_install: *std.Build.Step, b: *std.Build) void {
    run.step.dependOn(data_install);
    run.setEnvironmentVariable("PROJ_DATA", b.getInstallPath(.prefix, "share/proj"));
    run.setEnvironmentVariable("PROJ_NETWORK", "OFF");
}

// ---------------------------------------------------------------------------
// Steps.
// ---------------------------------------------------------------------------

/// Compiles the full graph, the exercise, the tests and the example for one
/// matrix target, and attaches all of them to `step`.
///
/// Nothing is run here, so every result this produces is compile evidence and not
/// a claim that a cross-built binary executed.
fn addTargetCheck(
    b: *std.Build,
    step: *std.Build.Step,
    query: std.Target.Query,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    runtime_loaded: bool,
    project_db: ProjectDatabase,
) void {
    const cross_target = b.resolveTargetQuery(query);
    // The triple names the cross artifacts. Six targets in one build graph
    // otherwise produce six steps called `proj`, which makes `--summary all`
    // useless for telling them apart.
    const triple = cross_target.result.zigTriple(b.allocator) catch @panic("unspellable target");

    // A cell whose target cannot carry the requested linkage is left out of this
    // run, by name and with the reason, rather than checked against a different
    // artifact than the one that was asked for. Under the default static linkage
    // `targetCanCarry` is true for every target and all six are checked, so the
    // six-target matrix is complete for the default graph and nothing is lost by
    // the rule. Under `-Dlinkage=dynamic` a target with no dynamic linker is not
    // covered, and the line below says so: a printed exclusion is not a pass, and
    // this build will not produce a static archive to stand in for the shared
    // object the run asked for.
    if (!targetCanCarry(cross_target, linkage)) {
        std.debug.print(
            "proj: check: {s} is NOT covered by this run. {s}\n",
            .{ triple, unsupportedLinkageReason(b, cross_target) },
        );
        return;
    }

    const graph = addGraph(b, cross_target, optimize, linkage, runtime_loaded, false, project_db);

    step.dependOn(&addExercise(
        b,
        cross_target,
        optimize,
        graph,
        runtime_loaded,
        b.fmt("proj-exercise-{s}", .{triple}),
    ).step);

    step.dependOn(&b.addTest(.{
        .name = b.fmt("proj-tests-{s}", .{triple}),
        .root_module = facadeProgram(b, cross_target, optimize, graph.module, test_source),
    }).step);

    step.dependOn(&b.addExecutable(.{
        .name = b.fmt("proj-smoke-{s}", .{triple}),
        .root_module = facadeProgram(b, cross_target, optimize, graph.module, example_source),
    }).step);
}

pub fn build(b: *std.Build) void {
    // One version, or the build refuses to configure. The parse above already
    // refuses a manifest that is not a semantic version; this refuses one that is
    // a different release from upstream's header.
    if (manifest_version.order(upstream_version) != .eq) {
        @panic("build.zig.zon .version does not match upstream's version read from " ++
            "src/proj.h:176-178 and CMakeLists.txt:169");
    }

    // The compile list is copied from `src/lib_proj.cmake`, and a list that
    // quietly lost a unit would be a much harder defect to see than a duplicated
    // literal. `all_target_sources` is comptime, so this is a configure-time
    // check and costs nothing at run time.
    if (all_target_sources.len != target_translation_unit_count) {
        @panic(b.fmt(
            "build.zig: the compile list holds {d} translation units; lib_proj.cmake " ++
                "describes {d}. Nothing may be dropped from src/lib_proj.cmake's " ++
                "SRC_LIBPROJ_CORE, SRC_LIBPROJ_CONVERSIONS, SRC_LIBPROJ_PROJECTIONS, " ++
                "SRC_LIBPROJ_TRANSFORMATIONS and SRC_LIBPROJ_ISO19111, nor from " ++
                "src/apps/lib_projapps.cmake's SRC_PROJAPPS_LIBS.",
            .{ all_target_sources.len, target_translation_unit_count },
        ));
    }

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // The one delivery option.
    const linkage = b.option(
        std.builtin.LinkMode,
        "linkage",
        "Deliver the native library as a static archive (the default) or as a " ++
            "real shared object. The compiled C and C++, the generated headers, " ++
            "the translation, the facade, the tests and the example are identical " ++
            "either way: the option selects the delivery, never the dispatch. The " ++
            "dynamic delivery is libproj.so.25 with VERSION 25.9.0, which is what " ++
            "CMakeLists.txt:170-171 and src/lib_proj.cmake:572-576 describe. A " ++
            "target whose OS has no dynamic linker cannot carry a shared object, " ++
            "and -Dlinkage=dynamic is refused for it at configure time rather than " ++
            "delivered as an archive; the static default works on every target, " ++
            "including wasm32-wasi.",
    ) orelse .static;

    // The dispatch option, orthogonal to the delivery above.
    const runtime_loaded = b.option(
        bool,
        "runtime",
        "Resolve the native entry points at run time instead of linking them. " ++
            "The facade keeps the same translated header and the same public " ++
            "types; each selected native function becomes a dispatch through " ++
            "one process-lifetime table that an explicit load(source) fills, and " ++
            "nothing native is linked into the module. The native artifact is " ++
            "still compiled and still installed, so a caller may name this " ++
            "build's own provider or another one. Orthogonal to -Dlinkage: that " ++
            "option says which artifact is delivered, this one says how the " ++
            "module reaches it.",
    ) orelse false;

    // The datum database, generated once for the whole build and shared by every
    // target graph, because its fifty inputs are this repository's SQL files and
    // its output is data rather than target code.
    const project_db = addProjDb(b);

    const graph = addGraph(b, target, optimize, linkage, runtime_loaded, true, project_db);

    // The installed closure, in one place: the library and its four public
    // headers (through `installHeader` in `addCLibrary`), `share/proj/`, the
    // relocatable pkg-config file for the delivery this build produced, and
    // `share/doc/proj/` with upstream's licence and this fork's records.
    b.installArtifact(graph.library);
    addPkgConfig(b, target);
    installRecords(b);
    const data_install = addDataDirectory(b, project_db);

    // `zig build smoke` runs the example. The example is the cheapest thing that
    // proves the facade, the translated header and the C library agree on types,
    // symbols and link-time dependencies -- in particular that libm, libdl,
    // pthreads and the C++ runtime reached the dependent's link line. It is
    // compiled and run, not installed: it is a proof, not a deliverable.
    //
    // `zig build smoke` deliberately does not depend on the install step as a
    // whole; it depends on the data install, because `PROJ_DATA` names a real
    // directory that has to exist.
    const example = b.addExecutable(.{
        .name = "proj-smoke",
        .root_module = facadeProgram(b, target, optimize, graph.module, example_source),
    });
    const run_example = b.addRunArtifact(example);
    run_example.has_side_effects = true;
    applyProjEnvironment(run_example, &data_install.step, b);
    if (b.args) |args| run_example.addArgs(args);
    b.step("smoke", "Run the example program against the generated datum data").dependOn(&run_example.step);

    // The dependent package in `consumer/`, built and run as itself. It reaches
    // the library through the relative path dependency in its own manifest, so
    // this is the proof that `dep.module("proj")` works from outside this package.
    const consumer = b.addExecutable(.{
        .name = "proj-consumer",
        .root_module = facadeProgram(b, target, optimize, graph.module, "consumer/src/main.zig"),
    });
    const run_consumer = b.addRunArtifact(consumer);
    run_consumer.has_side_effects = true;
    applyProjEnvironment(run_consumer, &data_install.step, b);
    // Forwarded like the example's, and for the same reason: under `-Druntime`
    // this program has no library on its link line and is given the provider it
    // must load by an explicit argument, which only reaches it through `b.args`.
    if (b.args) |args| run_consumer.addArgs(args);
    b.step("consumer", "Run the module consumer").dependOn(&run_consumer.step);

    // The test root is `tests.zig`, which names the test blocks; a root that only
    // re-exported them would discover no tests and still exit zero.
    // `addRunArtifact` is used rather than a plain compile so that this is a real
    // runnable test step for whatever `-Dtarget` names: a foreign target is left
    // to whichever executor the cross-test harness detects, and this build does
    // not decide that.
    const unit_tests = b.addTest(.{
        .name = "proj-tests",
        .root_module = facadeProgram(b, target, optimize, graph.module, test_source),
    });
    const run_tests = b.addRunArtifact(unit_tests);
    run_tests.has_side_effects = true;
    applyProjEnvironment(run_tests, &data_install.step, b);
    const test_step = b.step("test", "Run the facade tests and every API operation");
    test_step.dependOn(&run_tests.step);

    // The exercise is **compiled, not run**. `zig/api_exercise.zig` says why, and
    // `addExercise` says how: it is a test root whose one `test` block calls
    // `exercise`, so compiling it instantiates every facade body without any of
    // them executing. `test` depends on the compile step and never on a run step.
    const exercise = addExercise(
        b,
        target,
        optimize,
        graph,
        runtime_loaded,
        "proj-exercise",
    );
    test_step.dependOn(&exercise.step);
    b.step("exercise", "Compile every supported facade operation").dependOn(&exercise.step);

    // The provenance gate. It is a separate script rather than a step of this
    // graph because it must work on a checkout with no compiler, no `build.zig`
    // dependency and no build cache at all; `bash` is named because the script is
    // Bash and the file says so in its own header.
    const run_provenance = b.addSystemCommand(&.{ "bash", "tools/check-provenance.sh" });
    run_provenance.has_side_effects = true;
    b.step("provenance", "Check the recorded upstream digests, the exact native file set and the licences").dependOn(&run_provenance.step);

    // The cross target gate. Compiling the exercise, the tests and the example for
    // each target is what makes this a check of the facade rather than of an
    // unreferenced archive, and `addTargetCheck` says why. Nothing runs here, and
    // no target is skipped.
    //
    // Note the cost, so that a slow `check` is not mistaken for a stuck one: each
    // cell compiles all 219 translation units of the `proj` target plus the
    // vendored SQLite3 amalgamation once, and then three small Zig programs
    // against it. Six targets, so roughly 1300 C and C++ compilations.
    const check_step = b.step(
        "check",
        "Compile the core, the facade, the API exercise, the tests and the " ++
            "example for the six-target matrix without running any of them",
    );
    if (!target.query.isNative()) {
        addTargetCheck(b, check_step, target.query, optimize, linkage, runtime_loaded, project_db);
    } else {
        for (check_targets) |query| {
            addTargetCheck(b, check_step, query, optimize, linkage, runtime_loaded, project_db);
        }
    }

    // Configure-time lines, not gate results: what this build graph compiled, in
    // which delivery, and where its data lives. They are printed whether or not
    // any step runs, and they say nothing about whether the results were
    // executed.
    std.debug.print(
        "proj: {d} translation units from src/lib_proj.cmake + src/apps/lib_projapps.cmake, " ++
            "plus vendor/sqlite3/sqlite3.c, delivered as a {s} library, C++17/C99, " ++
            "PROJ_DLL=, TIFF off, CURL off\n",
        .{ all_target_sources.len + 1, @tagName(linkage) },
    );
    if (linkage == .dynamic) {
        std.debug.print(
            "proj: dynamic delivery is libproj.so.{d} (VERSION {d}.{d}.{d}, CMakeLists.txt:170-171)\n",
            .{ library_version.major, library_version.major, library_version.minor, library_version.patch },
        );
    }
    std.debug.print(
        "proj: datum data is {d} generated SQL files plus proj.db, installed to {s}; " ++
            "PROJ_DATA names it and PROJ_NETWORK=OFF on every run step\n",
        .{ sql_files.len, b.getInstallPath(.prefix, "share/proj") },
    );
    // No substitution notice, because there is no substitution: a requested
    // `dynamic` this target cannot carry was refused by `addGraph` above, before
    // this line was reached.
    if (runtime_loaded) {
        std.debug.print(
            "proj: runtime-loaded dispatch (-Druntime=true); nothing native is linked " ++
                "into the module, and a provider is named by an explicit load(source)\n",
            .{},
        );
    }
}