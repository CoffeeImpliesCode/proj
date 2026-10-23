// SPDX-License-Identifier: MIT
// Fork-authored build logic; see `FORK-LICENSE.md` for scope.

//! Zig 0.17.0 build graph for PROJ 9.9.0.
//! Generated inputs are produced by this graph.

const std = @import("std");

/// Runtime and linked routes share one loader-core module.
/// A second instance would create incompatible `LoadSource` and `LoadError` types.
const runtime_graph = @import("runtime/graph.zig");

const manifest = @import("build.zig.zon");

const manifest_version = std.SemanticVersion.parse(manifest.version) catch
    @panic("build.zig.zon: .version is not a semantic version");

/// Upstream PROJ version; build rejects a manifest version mismatch.
const upstream_version: std.SemanticVersion = .{ .major = 9, .minor = 9, .patch = 0 };

/// Shared release text for generated metadata and pkg-config.
const upstream_version_text = "9.9.0";

/// Upstream ABI version; Zig derives the ELF soname from its major.
const library_version: std.SemanticVersion = .{ .major = 25, .minor = 9, .patch = 0 };

const module_name = "proj";

const lib_name = "proj";

const pkg_config_name = "proj";

const facade_source = "zig/root.zig";

const exercise_source = "zig/api_exercise.zig";

const translate_header = "zig/translate.h";

const bridge_source = "zig/proj_abi.c";

const test_source = "tests.zig";

const example_source = "smoke.zig";

/// Vendored SQLite is compiled into the library and the host generator.
const sqlite_source = "vendor/sqlite3/sqlite3.c";

const sqlite_dir = "vendor/sqlite3";

const source_dir = "src";

const include_dir = "include";

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

/// Pin C99 and C++17 to match upstream.
const c_flags = [_][]const u8{"-std=c99"};
const cxx_flags = [_][]const u8{"-std=c++17"};

const data_dir = "data";

const expected_md5_file = "data/sql/proj.db.sql.expected.md5";

/// Explicit install list; a glob would include build inputs and tests.
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

/// Legal and fork-provenance records installed under `share/doc/proj`.
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

/// Compile-only target matrix; static linkage includes `wasm32-wasi`.
const check_targets = [_]std.Target.Query{
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .macos, .abi = .none },
    .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    .{ .cpu_arch = .riscv64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .wasm32, .os_tag = .wasi },
};

// Source groups copied from upstream's library target.

/// Upstream core source group, in its declared order.
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

/// Upstream conversion source group.
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

/// Upstream projection source group.
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

/// Upstream transformation source group.
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

/// Upstream ISO 19111 source group.
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

/// Shared application-support source included in the library target.
const apps_lib_source = [_][]const u8{
    "src/apps/projinfo_lib.cpp",
};

/// All native-library translation units in upstream order; `build()` checks the count.
const target_translation_unit_count = 219;

/// Flattened source groups, in upstream order.
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

/// SQL inputs in upstream concatenation order; generation checks their digest.
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

// Host-run generators.

/// Target-specific config generator; the executable runs on the build host.
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

/// Host generator that rebuilds `proj.db` from tracked SQL using vendored SQLite.
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
    \\    const terminated = try arena.dupeSentinel(u8, script.items, 0);
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

// Target-specific platform facts.

/// Facts written to `proj_config.h` for the resolved target.
/// `HAVE_LIBDL` follows the same target decision as the `dl` link dependency.
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

/// Separate `libm` dependency for targets whose libc does not provide it.
fn mathLibrary(target: std.Build.ResolvedTarget) ?[]const u8 {
    return switch (target.result.os.tag) {
        .linux, .freebsd, .netbsd, .openbsd, .dragonfly, .illumos => "m",
        else => null,
    };
}

/// Separate dynamic-loader dependency, when the target requires one.
fn dlLibrary(target: std.Build.ResolvedTarget) ?[]const u8 {
    return switch (target.result.os.tag) {
        .linux, .illumos => "dl",
        else => null,
    };
}

/// Separate pthread dependency for targets that need one.
fn pthreadLibrary(target: std.Build.ResolvedTarget) ?[]const u8 {
    return switch (target.result.os.tag) {
        .linux, .freebsd, .netbsd, .openbsd, .dragonfly => "pthread",
        else => null,
    };
}

/// Derive the macro from the same decision used for the pthread link.
fn hasPthreads(target: std.Build.ResolvedTarget) bool {
    return pthreadLibrary(target) != null;
}

/// Windows headers define `min` and `max`; `NOMINMAX` prevents collisions.
fn needsNomInmax(target: std.Build.ResolvedTarget) bool {
    return target.result.os.tag == .windows;
}

/// C++ runtime recorded for foreign C consumers in pkg-config.
fn cppRuntimeLibrary(target: std.Build.ResolvedTarget) ?[]const u8 {
    return switch (target.result.os.tag) {
        .linux, .windows => "stdc++",
        .macos, .freebsd, .netbsd, .openbsd, .dragonfly => "c++",
        else => null,
    };
}

/// Attach system dependencies to modules so static-library consumers inherit them.
fn linkSystemDependencies(module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    inline for (.{ mathLibrary, dlLibrary, pthreadLibrary }) |resolve| {
        if (resolve(target)) |lib| module.linkSystemLibrary(lib, .{});
    }
}

fn targetCanCarry(
    target: std.Build.ResolvedTarget,
    requested: std.lang.LinkMode,
) bool {
    return requested == .static or
        target.result.os.tag == .windows or
        std.Target.DynamicLinker.kind(target.result.os.tag) != .none;
}

fn unsupportedLinkageReason(b: *std.Build, target: std.Build.ResolvedTarget) []const u8 {
    return b.fmt(
        "proj: -Dlinkage=dynamic is unsupported for {s}: dynamic linker kind is {s}. " ++
            "No static archive is substituted. Use -Dlinkage=static for this target.",
        .{ @tagName(target.result.os.tag), @tagName(std.Target.DynamicLinker.kind(target.result.os.tag)) },
    );
}

fn requireSupportedLinkage(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    requested: std.lang.LinkMode,
) void {
    if (!targetCanCarry(target, requested)) {
        @panic(unsupportedLinkageReason(b, target));
    }
}

/// Name check artifacts per target; published artifacts keep the module name.
fn artifactName(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    public: bool,
) []const u8 {
    if (public) return lib_name;
    const triple = target.result.zigTriple(b.allocator) catch @panic("unspellable target");
    return b.fmt("{s}-{s}", .{ lib_name, triple });
}

// Generated inputs.

/// Generated header and its include directory.
const Generated = struct {
    header: std.Build.LazyPath,
    dir: std.Build.LazyPath,
};

/// Compile generators for the host; their arguments identify target inputs.
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
            .optimize = .safe,
            .link_libc = true,
        }),
    });
}

/// Generate a config header for this target.
fn addProjConfig(b: *std.Build, target: std.Build.ResolvedTarget) Generated {
    const run = b.addRunArtifact(addHostProgram(b, "proj-config-gen", proj_config_gen_source));
    run.has_side_effects = true;

    const facts = configFacts(target);
    const triple = target.result.zigTriple(b.allocator) catch @panic("unspellable target");

    run.addArg(b.fmt("--target={s}", .{triple}));
    run.addArg(b.fmt("--have-libdl={d}", .{@intFromBool(facts.have_libdl)}));
    run.addArg(b.fmt("--have-localeconv={d}", .{@intFromBool(facts.have_localeconv)}));
    run.addArg(b.fmt("--have-strerror={d}", .{@intFromBool(facts.have_strerror)}));
    const header = run.addOutputFileArg2("proj_config.h", .{ .prefix = "--out=" });

    return .{
        .header = header,
        .dir = header.dirname(),
    };
}

const ProjectDatabase = struct {
    db: std.Build.LazyPath,
    md5_header: std.Build.LazyPath,
    dir: std.Build.LazyPath,
};

/// Generate the target-independent datum database once per build.
fn addProjDb(b: *std.Build) ProjectDatabase {
    const translate = b.addTranslateC(.{
        .root_source_file = b.addWriteFiles().add("proj_sqlite_translate.h", sqlite_translate_header_source),
        .target = b.graph.host,
        .optimize = .safe,
        .link_libc = true,
    });
    // Translate against the vendored SQLite header.
    translate.addIncludePath(b.path(sqlite_dir));

    const files = b.addWriteFiles();
    const module = b.createModule(.{
        .root_source_file = files.add("proj-db-gen.zig", proj_db_gen_source),
        .target = b.graph.host,
        .optimize = .safe,
        .link_libc = true,
    });
    module.addImport("c", translate.createModule());
    // This host copy runs SQL; the library copy targets the requested platform.
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
    run.addFileArg2(b.path(expected_md5_file), .{ .prefix = "--expected-md5-file=" });
    for (sql_files) |file| run.addFileArg2(b.path(file), .{ .prefix = "--in=" });
    const md5_header = run.addOutputFileArg2("PROJ_DB_SQL_MD5.h", .{ .prefix = "--md5-header=" });
    const db = run.addOutputFileArg2("proj.db", .{ .prefix = "--db=" });

    return .{ .db = db, .md5_header = md5_header, .dir = md5_header.dirname() };
}

// Library and facade graph.
const Graph = struct {
    library: *std.Build.Step.Compile,
    module: *std.Build.Module,
    c_module: *std.Build.Module,
    /// Linked route's shared core module; runtime dispatch owns it otherwise.
    core_module: ?*std.Build.Module,
    config_dir: std.Build.LazyPath,
};

fn addCLibrary(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    linkage: std.lang.LinkMode,
    config: Generated,
    project_db: ProjectDatabase,
    name: []const u8,
) *std.Build.Step.Compile {
    const library = b.addLibrary(.{
        .name = name,
        .linkage = linkage,
        .version = library_version,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            // Link the C++ runtime so static-library consumers inherit it.
            .link_libcpp = true,
            .pic = if (linkage == .dynamic) true else null,
        }),
    });
    const module = library.root_module;

    module.addIncludePath(b.path(source_dir));
    module.addIncludePath(b.path(include_dir));
    module.addIncludePath(config.dir);
    module.addIncludePath(project_db.dir);
    module.addIncludePath(b.path(sqlite_dir));

    // Match upstream's empty `PROJ_DLL` definition.
    module.addCMacro("PROJ_DLL", "");

    if (needsNomInmax(target)) module.addCMacro("NOMINMAX", "1");

    if (hasPthreads(target)) module.addCMacro("PROJ_HAS_PTHREADS", "1");

    for (all_target_sources) |source| {
        module.addCSourceFile(.{
            .file = b.path(source),
            // Select the pinned C or C++ standard by source extension.
            .flags = if (std.mem.endsWith(u8, source, ".c")) &c_flags else &cxx_flags,
        });
    }

    // Bundle SQLite into libproj; do not publish a separate SQLite artifact.
    module.addCSourceFile(.{ .file = b.path(sqlite_source), .flags = &c_flags });

    // A C bridge keeps by-value `PJ_COORD` calls within one compiler ABI.
    // Keep it in the library so linked and runtime-loaded routes share the bridge.
    module.addCSourceFile(.{ .file = b.path(bridge_source), .flags = &c_flags });

    linkSystemDependencies(module, target);

    // Install PROJ's public headers, but not vendored `geodesic.h`.
    // Upstream does not include `geodesic.h` in its public install set.
    library.installHeader(b.path("src/proj.h"), "proj.h");
    library.installHeader(b.path("src/proj_constants.h"), "proj_constants.h");
    library.installHeader(b.path("src/proj_experimental.h"), "proj_experimental.h");
    library.installHeader(b.path("src/proj_symbol_rename.h"), "proj_symbol_rename.h");

    return library;
}

/// Keep matrix graphs private; register only the consumer graph's module.
fn addGraph(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    linkage: std.lang.LinkMode,
    runtime_loaded: bool,
    public: bool,
    project_db: ProjectDatabase,
) Graph {

    requireSupportedLinkage(b, target, linkage);
    const config = addProjConfig(b, target);

    const library = addCLibrary(b, target, optimize, linkage, config, project_db, artifactName(b, target, public));

    const translate = b.addTranslateC(.{
        .root_source_file = b.path(translate_header),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    // Use this graph's PROJ and generated headers, not host-installed headers.
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

    // Runtime dispatch reuses this translation and loader core, preserving public type identity.
    // Runtime mode changes the call path, not the library artifact delivered above.
    const c_module = if (runtime_loaded) blk: {
        // Runtime-loaded mode must not link the native provider.
        break :blk runtime_graph.createModule(b, translate, target, optimize);
    } else blk: {
        // Import C declarations here; do not publish them as an independent module.
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
        linkSystemDependencies(module, target);
        module.link_libcpp = true;
    }

    // Expose this graph's headers to facade consumers.
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

/// Compile callers with the facade's libc requirement.
fn facadeProgram(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
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

/// Compile the API exercise without running it; calls analyse each public facade body.
/// It uses the same C and loader modules as the facade.
fn addExercise(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
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
    // Reuse the facade's loader core to preserve public type identity.
    if (graph.core_module) |rt| module.addImport("rt", rt);
    if (!runtime_loaded) {
        module.linkLibrary(graph.library);
        linkSystemDependencies(module, target);
        module.link_libcpp = true;
    }
    return b.addTest(.{ .name = name, .root_module = module });
}

// Installation.

/// Write a relocatable pkg-config file whose prefix follows the installed `.pc` file.
/// SQLite is bundled, so `Requires.private` is empty; `Libs.private` lists target dependencies.
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
        "proj",
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

/// Install generated `proj.db` and datum data under `share/proj`.
/// Run steps depend on this directory before using `PROJ_DATA`.
fn addDataDirectory(
    b: *std.Build,
    project_db: ProjectDatabase,
) *std.Build.Step.InstallDir {
    const files = b.addWriteFiles();
    _ = files.addCopyFile(project_db.db, "proj.db");
    for (data_files) |file| {
        _ = files.addCopyFile(b.path(file), std.fs.path.basename(file));
    }

    const install = b.addInstallDirectory(.{
        .source_dir = files.getDirectory(),
        .install_dir = .prefix,
        .install_subdir = "share/proj",
    });
    b.getInstallStep().dependOn(&install.step);
    return install;
}

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

// Run steps.

/// Run from the installed data directory and disable network access.
fn applyProjEnvironment(run: *std.Build.Step.Run, data_install: *std.Build.Step) void {
    run.step.dependOn(data_install);
    run.setCwd(.{ .relative = .{ .base = .install_prefix, .sub_path = "share/proj" } });
    run.setEnvironmentVariable("PROJ_DATA", ".");
    run.setEnvironmentVariable("PROJ_NETWORK", "OFF");
}

// Build steps.

fn addTargetCheck(
    b: *std.Build,
    step: *std.Build.Step,
    query: std.Target.Query,
    optimize: std.lang.Optimize,
    linkage: std.lang.LinkMode,
    runtime_loaded: bool,
    project_db: ProjectDatabase,
) void {
    const cross_target = b.resolveTargetQuery(query);
    // Include the target triple in cross-artifact names.
    const triple = cross_target.result.zigTriple(b.allocator) catch @panic("unspellable target");

    // Never substitute a different linkage for an unsupported request.
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
    if (manifest_version.order(upstream_version) != .eq) {
        @panic("build.zig.zon .version does not match upstream's version read from " ++
            "src/proj.h:176-178 and CMakeLists.txt:169");
    }

    // Keep the explicit source list complete.
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

    const linkage = b.option(
        std.lang.LinkMode,
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

    // Runtime mode selects dispatch, not the native artifact delivered.
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

    const project_db = addProjDb(b);

    const graph = addGraph(b, target, optimize, linkage, runtime_loaded, true, project_db);

    b.installArtifact(graph.library);
    addPkgConfig(b, target);
    installRecords(b);
    const data_install = addDataDirectory(b, project_db);

    const example = b.addExecutable(.{
        .name = "proj-smoke",
        .root_module = facadeProgram(b, target, optimize, graph.module, example_source),
    });
    const run_example = b.addRunArtifact(example);
    run_example.has_side_effects = true;
    applyProjEnvironment(run_example, &data_install.step);
    run_example.addPassthruArgs();
    b.step("smoke", "Run the example program against the generated datum data").dependOn(&run_example.step);

    const consumer = b.addExecutable(.{
        .name = "proj-consumer",
        .root_module = facadeProgram(b, target, optimize, graph.module, "consumer/src/main.zig"),
    });
    const run_consumer = b.addRunArtifact(consumer);
    run_consumer.has_side_effects = true;
    applyProjEnvironment(run_consumer, &data_install.step);
    // Forward provider arguments to the runtime-loaded consumer.
    run_consumer.addPassthruArgs();
    b.step("consumer", "Run the module consumer").dependOn(&run_consumer.step);

    const unit_tests = b.addTest(.{
        .name = "proj-tests",
        .root_module = facadeProgram(b, target, optimize, graph.module, test_source),
    });
    const run_tests = b.addRunArtifact(unit_tests);
    run_tests.has_side_effects = true;
    applyProjEnvironment(run_tests, &data_install.step);
    const test_step = b.step("test", "Run the facade tests and every API operation");
    test_step.dependOn(&run_tests.step);

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

    const run_provenance = b.addSystemCommand(&.{ "bash", "tools/check-provenance.sh" });
    run_provenance.has_side_effects = true;
    b.step("provenance", "Check the recorded upstream digests, the exact native file set and the licences").dependOn(&run_provenance.step);

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
        "proj: datum data is {d} generated SQL files plus proj.db under share/proj; " ++
            "run steps use PROJ_DATA=. and PROJ_NETWORK=OFF\n",
        .{sql_files.len},
    );
    if (runtime_loaded) {
        std.debug.print(
            "proj: runtime-loaded dispatch (-Druntime=true); nothing native is linked " ++
                "into the module, and a provider is named by an explicit load(source)\n",
            .{},
        );
    }
}
