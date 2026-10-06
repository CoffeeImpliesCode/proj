# cross-test settings profile for the OSGeo/PROJ SDK.
#
# `cross-test` looks for this file at the root of the project it is run from
# (or names it with --profile; --no-profile ignores it). It is trusted Bash that
# the harness `source`s, so this file is *settings only*: ordinary variable
# assignments and nothing else. No command runs, no compiler is probed, and no
# path in here names a host.
#
# There is deliberately no CROSS_MATRIX. The published 53-platform Zig 0.16
# Tier 1/2 table is the matrix this package is checked against, and a matrix
# named here would replace it. There is no TARGETS array either, for the same
# reason: a subset selected here would narrow the run rather than add to it.
# Both belong on the command line, where --targets selects from the active
# matrix and never adds to it.
#
# CROSS_BUILD_STEP stays the standard `test` step, which is what this profile
# states explicitly. There are no `cross_build_command` / `cross_artifact`
# hooks here, so the harness keeps its standard Zig-build mode and runs
# `zig build test -Dtarget=TARGET` per target with a fresh cache. What that
# means for a given target is the harness's decision, not this package's: a
# host target runs, a foreign target runs under whatever executor the harness
# detects (QEMU user mode, Wine, wasmtime), and a foreign target with no
# executor is reported as build-only coverage -- compiled, never executed, and
# never counted as a pass. `build.zig` gives the test binary a Run step for
# every target, which is what leaves that choice open.
#
# A target graph compiles the whole 218-unit closure of `SRC_LIBPROJ_CORE`,
# `SRC_LIBPROJ_CONVERSIONS`, `SRC_LIBPROJ_PROJECTIONS`,
# `SRC_LIBPROJ_TRANSFORMATIONS` and `SRC_LIBPROJ_ISO19111` plus
# `SRC_PROJAPPS_LIBS`, and the vendored `vendor/sqlite3/sqlite3.c`, so roughly
# 220 C and C++ translation units per cell. Several of them are large:
# `src/iso19111/factory.cpp` is over ten thousand lines and
# `src/iso19111/operation/coordinateoperationfactory.cpp` is the other big one,
# and each of them is a C++17 unit that clang has to optimise.
#
# Four jobs, not eight, and that is a memory decision rather than a speed one.
# A C++17 translation unit of this size peaks in the low gigabytes, and four
# concurrent ones stay inside a normal development machine while eight do not.
# CROSS_BUILD_TIMEOUT is therefore generous rather than tight: a full cell is
# hundreds of compilations, and a timeout that fires halfway through a cell
# would produce a result about the timeout rather than about PROJ.
#
# The datum database is generated once per build and shared by every target, so
# the 50-file SQL concatenation, its MD5 assertion against
# `data/sql/proj.db.sql.expected.md5`, and the `sqlite3_exec` that produces
# `proj.db` happen once per cell rather than once per target. The `test` run
# step sets `PROJ_DATA` to the installed `share/proj` directory and
# `PROJ_NETWORK=OFF`, so "no network" is a property of the gate: every run in
# this matrix reads the database this build generated and can reach nothing
# else.
#
# Nothing here narrows the gate to what is expected to work. Which platforms
# PROJ itself supports is decided by `cmake/proj_config.cmake.in`'s three
# `HAVE_*` macros, which `build.zig` resolves for the target being built and
# never for the host, and by the C library behind it. A cell that fails is a
# fact to record and diagnose; it is not a reason to drop the cell, sample the
# tests or remap Debug to an optimized mode to make it pass.

CROSS_BUILD_STEP=test
CROSS_BUILD_JOBS=4
CROSS_BUILD_TIMEOUT=7200
CROSS_TIMEOUT=1800