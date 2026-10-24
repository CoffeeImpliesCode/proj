// SPDX-License-Identifier: MIT
//
// Fork-authored. `FORK-LICENSE.md` records the owner's authorization of that
// grant for this file, and `../COPYING` holds upstream's own MIT-style text.

//! PROJ runtime loader: requires 292 functions and `pj_release` from `src/proj.h`.
//! Validates provider ABI behavior and rejects `PROJ_RENAME_SYMBOLS` providers.
//! Strings and lists remain provider-owned; release owned results with PROJ destroy APIs.

const rt = @import("rt");
const std = @import("std");

/// Namespaced synchronization binding used by the generic loader.
/// Its `proj_rt` prefix must match `runtime/sync.c`.
pub const Sync = struct {
    extern fn proj_rt_lock() void;
    extern fn proj_rt_unlock() void;
    extern fn proj_rt_wait() void;
    extern fn proj_rt_broadcast() void;
    // Matches C `unsigned long long` on the supported targets.
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

/// Exact dyadic values for the provider-side `PJ_COORD` layout check.
const check_x: f64 = 1.5;
const check_y: f64 = 2.5;
const check_z: f64 = 3.5;
const check_t: f64 = 4.5;

/// Required function and data exports declared in `src/proj.h`.
/// `Config` checks this set against the generated dispatch.
/// Excludes `proj_get_crs_list`, mentioned only in a comment at `src/proj.h:1077`.
const header_symbols = [_][]const u8{
    "pj_release", // src/proj.h:195; exported data
    "proj_alter_id", // src/proj.h:1727
    "proj_alter_name", // src/proj.h:1725
    "proj_angular_input", // src/proj.h:623
    "proj_angular_output", // src/proj.h:624
    "proj_area_create", // src/proj.h:607
    "proj_area_destroy", // src/proj.h:613
    "proj_area_set_bbox", // src/proj.h:608
    "proj_area_set_name", // src/proj.h:612
    "proj_as_proj_string", // src/proj.h:1280
    "proj_as_projjson", // src/proj.h:1284
    "proj_as_wkt", // src/proj.h:1277
    "proj_assign_context", // src/proj.h:604
    "proj_celestial_body_list_destroy", // src/proj.h:1314
    "proj_cleanup", // src/proj.h:816
    "proj_clone", // src/proj.h:1226
    "proj_concatoperation_get_step", // src/proj.h:1547
    "proj_concatoperation_get_step_count", // src/proj.h:1544
    "proj_context_clone", // src/proj.h:406
    "proj_context_create", // src/proj.h:404
    "proj_context_destroy", // src/proj.h:405
    "proj_context_errno", // src/proj.h:769
    "proj_context_errno_string", // src/proj.h:776
    "proj_context_get_database_metadata", // src/proj.h:1198
    "proj_context_get_database_path", // src/proj.h:1196
    "proj_context_get_database_structure", // src/proj.h:1201
    "proj_context_get_url_endpoint", // src/proj.h:561
    "proj_context_get_use_proj4_init_rules", // src/proj.h:422
    "proj_context_get_user_writable_directory", // src/proj.h:563
    "proj_context_guess_wkt_dialect", // src/proj.h:1204
    "proj_context_is_network_enabled", // src/proj.h:557
    "proj_context_set_autoclose_database", // src/proj.h:1189
    "proj_context_set_ca_bundle_path", // src/proj.h:418
    "proj_context_set_database_path", // src/proj.h:1192
    "proj_context_set_enable_network", // src/proj.h:555
    "proj_context_set_file_finder", // src/proj.h:413
    "proj_context_set_fileapi", // src/proj.h:490
    "proj_context_set_network_callbacks", // src/proj.h:549
    "proj_context_set_search_paths", // src/proj.h:416
    "proj_context_set_sqlite3_vfs_name", // src/proj.h:494
    "proj_context_set_url_endpoint", // src/proj.h:559
    "proj_context_set_user_writable_directory", // src/proj.h:566
    "proj_context_use_proj4_init_rules", // src/proj.h:421
    "proj_convert_conversion_to_other_method", // src/proj.h:1829
    "proj_coord", // src/proj.h:656
    "proj_coordinate_metadata_create", // src/proj.h:1551
    "proj_coordinate_metadata_get_epoch", // src/proj.h:1554
    "proj_coordoperation_create_inverse", // src/proj.h:1542
    "proj_coordoperation_get_accuracy", // src/proj.h:1535
    "proj_coordoperation_get_grid_used", // src/proj.h:1529
    "proj_coordoperation_get_grid_used_count", // src/proj.h:1526
    "proj_coordoperation_get_method_info", // src/proj.h:1499
    "proj_coordoperation_get_param", // src/proj.h:1519
    "proj_coordoperation_get_param_count", // src/proj.h:1512
    "proj_coordoperation_get_param_index", // src/proj.h:1515
    "proj_coordoperation_get_towgs84_values", // src/proj.h:1538
    "proj_coordoperation_has_ballpark_transformation", // src/proj.h:1506
    "proj_coordoperation_is_instantiable", // src/proj.h:1503
    "proj_coordoperation_requires_per_coordinate_input_time", // src/proj.h:1509
    "proj_create", // src/proj.h:593
    "proj_create_argv", // src/proj.h:594
    "proj_create_cartesian_2D_cs", // src/proj.h:1673
    "proj_create_compound_crs", // src/proj.h:1776
    "proj_create_conversion", // src/proj.h:1779
    "proj_create_conversion_albers_equal_area", // src/proj.h:1900
    "proj_create_conversion_american_polyconic", // src/proj.h:2191
    "proj_create_conversion_azimuthal_equidistant", // src/proj.h:1945
    "proj_create_conversion_bonne", // src/proj.h:1957
    "proj_create_conversion_cassini_soldner", // src/proj.h:1975
    "proj_create_conversion_eckert_i", // src/proj.h:1988
    "proj_create_conversion_eckert_ii", // src/proj.h:1994
    "proj_create_conversion_eckert_iii", // src/proj.h:2000
    "proj_create_conversion_eckert_iv", // src/proj.h:2006
    "proj_create_conversion_eckert_v", // src/proj.h:2012
    "proj_create_conversion_eckert_vi", // src/proj.h:2018
    "proj_create_conversion_equal_earth", // src/proj.h:2287
    "proj_create_conversion_equidistant_conic", // src/proj.h:1981
    "proj_create_conversion_equidistant_cylindrical", // src/proj.h:2024
    "proj_create_conversion_equidistant_cylindrical_spherical", // src/proj.h:2030
    "proj_create_conversion_gall", // src/proj.h:2036
    "proj_create_conversion_gauss_schreiber_transverse_mercator", // src/proj.h:1869
    "proj_create_conversion_geostationary_satellite_sweep_x", // src/proj.h:2056
    "proj_create_conversion_geostationary_satellite_sweep_y", // src/proj.h:2062
    "proj_create_conversion_gnomonic", // src/proj.h:2068
    "proj_create_conversion_goode_homolosine", // src/proj.h:2044
    "proj_create_conversion_guam_projection", // src/proj.h:1951
    "proj_create_conversion_hotine_oblique_mercator_two_point_natural_origin", // src/proj.h:2091
    "proj_create_conversion_hotine_oblique_mercator_variant_a", // src/proj.h:2074
    "proj_create_conversion_hotine_oblique_mercator_variant_b", // src/proj.h:2082
    "proj_create_conversion_international_map_world_polyconic", // src/proj.h:2106
    "proj_create_conversion_interrupted_goode_homolosine", // src/proj.h:2050
    "proj_create_conversion_krovak", // src/proj.h:2122
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
    "proj_create_conversion_mollweide", // src/proj.h:2161
    "proj_create_conversion_new_zealand_mapping_grid", // src/proj.h:2167
    "proj_create_conversion_oblique_stereographic", // src/proj.h:2173
    "proj_create_conversion_orthographic", // src/proj.h:2179
    "proj_create_conversion_polar_stereographic_variant_a", // src/proj.h:2197
    "proj_create_conversion_polar_stereographic_variant_b", // src/proj.h:2203
    "proj_create_conversion_pole_rotation_grib_convention", // src/proj.h:2300
    "proj_create_conversion_pole_rotation_netcdf_cf_convention", // src/proj.h:2305
    "proj_create_conversion_popular_visualisation_pseudo_mercator", // src/proj.h:2155
    "proj_create_conversion_quadrilateralized_spherical_cube", // src/proj.h:2275
    "proj_create_conversion_robinson", // src/proj.h:2209
    "proj_create_conversion_sinusoidal", // src/proj.h:2215
    "proj_create_conversion_spherical_cross_track_height", // src/proj.h:2281
    "proj_create_conversion_stereographic", // src/proj.h:2221
    "proj_create_conversion_transverse_mercator", // src/proj.h:1863
    "proj_create_conversion_transverse_mercator_south_oriented", // src/proj.h:1875
    "proj_create_conversion_tunisia_mapping_grid", // src/proj.h:1888
    "proj_create_conversion_tunisia_mining_grid", // src/proj.h:1894
    "proj_create_conversion_two_point_equidistant", // src/proj.h:1881
    "proj_create_conversion_utm", // src/proj.h:1861
    "proj_create_conversion_van_der_grinten", // src/proj.h:2227
    "proj_create_conversion_vertical_perspective", // src/proj.h:2293
    "proj_create_conversion_wagner_i", // src/proj.h:2233
    "proj_create_conversion_wagner_ii", // src/proj.h:2239
    "proj_create_conversion_wagner_iii", // src/proj.h:2245
    "proj_create_conversion_wagner_iv", // src/proj.h:2251
    "proj_create_conversion_wagner_v", // src/proj.h:2257
    "proj_create_conversion_wagner_vi", // src/proj.h:2263
    "proj_create_conversion_wagner_vii", // src/proj.h:2269
    "proj_create_crs_to_crs", // src/proj.h:595
    "proj_create_crs_to_crs_from_pj", // src/proj.h:597
    "proj_create_cs", // src/proj.h:1670
    "proj_create_derived_geographic_crs", // src/proj.h:1717
    "proj_create_derived_projected_crs", // src/proj.h:1838
    "proj_create_ellipsoidal_2D_cs", // src/proj.h:1678
    "proj_create_ellipsoidal_3D_cs", // src/proj.h:1684
    "proj_create_engineering_crs", // src/proj.h:1761
    "proj_create_from_database", // src/proj.h:1212
    "proj_create_from_name", // src/proj.h:1229
    "proj_create_from_wkt", // src/proj.h:1207
    "proj_create_geocentric_crs", // src/proj.h:1706
    "proj_create_geocentric_crs_from_datum", // src/proj.h:1713
    "proj_create_geographic_crs", // src/proj.h:1694
    "proj_create_geographic_crs_from_datum", // src/proj.h:1702
    "proj_create_linear_3D_affine_parametric_conversion", // src/proj.h:1805
    "proj_create_linear_affine_parametric_conversion", // src/proj.h:1794
    "proj_create_operation_factory_context", // src/proj.h:1363
    "proj_create_operations", // src/proj.h:1415
    "proj_create_projected_crs", // src/proj.h:1833
    "proj_create_transformation", // src/proj.h:1821
    "proj_create_vertical_crs", // src/proj.h:1763
    "proj_create_vertical_crs_ex", // src/proj.h:1768
    "proj_crs_add_horizontal_derived_conversion", // src/proj.h:1844
    "proj_crs_alter_cs_angular_unit", // src/proj.h:1733
    "proj_crs_alter_cs_linear_unit", // src/proj.h:1739
    "proj_crs_alter_geodetic_crs", // src/proj.h:1730
    "proj_crs_alter_parameters_linear_unit", // src/proj.h:1745
    "proj_crs_create_bound_crs", // src/proj.h:1848
    "proj_crs_create_bound_crs_to_WGS84", // src/proj.h:1852
    "proj_crs_create_bound_vertical_crs", // src/proj.h:1855
    "proj_crs_create_projected_3D_crs_from_2D", // src/proj.h:1754
    "proj_crs_demote_to_2D", // src/proj.h:1758
    "proj_crs_get_coordinate_system", // src/proj.h:1465
    "proj_crs_get_coordoperation", // src/proj.h:1497
    "proj_crs_get_datum", // src/proj.h:1443
    "proj_crs_get_datum_ensemble", // src/proj.h:1445
    "proj_crs_get_datum_forced", // src/proj.h:1447
    "proj_crs_get_geodetic_crs", // src/proj.h:1437
    "proj_crs_get_horizontal_datum", // src/proj.h:1439
    "proj_crs_get_sub_crs", // src/proj.h:1441
    "proj_crs_has_point_motion_operation", // src/proj.h:1449
    "proj_crs_info_list_destroy", // src/proj.h:1326
    "proj_crs_is_derived", // src/proj.h:1433
    "proj_crs_is_dynamic", // src/proj.h:1435
    "proj_crs_promote_to_3D", // src/proj.h:1750
    "proj_cs_get_axis_count", // src/proj.h:1470
    "proj_cs_get_axis_info", // src/proj.h:1472
    "proj_cs_get_type", // src/proj.h:1467
    "proj_datum_ensemble_get_accuracy", // src/proj.h:1455
    "proj_datum_ensemble_get_member", // src/proj.h:1458
    "proj_datum_ensemble_get_member_count", // src/proj.h:1452
    "proj_degree_input", // src/proj.h:626
    "proj_degree_output", // src/proj.h:627
    "proj_destroy", // src/proj.h:605
    "proj_dmstor", // src/proj.h:810
    "proj_download_file", // src/proj.h:584
    "proj_dynamic_datum_get_frame_reference_epoch", // src/proj.h:1462
    "proj_ellipsoid_get_parameters", // src/proj.h:1480
    "proj_errno", // src/proj.h:770
    "proj_errno_reset", // src/proj.h:772
    "proj_errno_restore", // src/proj.h:773
    "proj_errno_set", // src/proj.h:771
    "proj_errno_string", // src/proj.h:775
    "proj_factors", // src/proj.h:783
    "proj_geod", // src/proj.h:676
    "proj_geod_direct", // src/proj.h:705
    "proj_get_area_of_use", // src/proj.h:1263
    "proj_get_area_of_use_ex", // src/proj.h:1270
    "proj_get_authorities_from_database", // src/proj.h:1304
    "proj_get_celestial_body_list_from_database", // src/proj.h:1311
    "proj_get_celestial_body_name", // src/proj.h:1486
    "proj_get_codes_from_database", // src/proj.h:1306
    "proj_get_crs_info_list_from_database", // src/proj.h:1322
    "proj_get_crs_list_parameters_create", // src/proj.h:1316
    "proj_get_crs_list_parameters_destroy", // src/proj.h:1319
    "proj_get_domain_count", // src/proj.h:1257
    "proj_get_ellipsoid", // src/proj.h:1478
    "proj_get_geoid_models_from_database", // src/proj.h:1296
    "proj_get_id_auth_name", // src/proj.h:1251
    "proj_get_id_code", // src/proj.h:1253
    "proj_get_insert_statements", // src/proj.h:1346
    "proj_get_name", // src/proj.h:1249
    "proj_get_non_deprecated", // src/proj.h:1238
    "proj_get_prime_meridian", // src/proj.h:1489
    "proj_get_remarks", // src/proj.h:1255
    "proj_get_scope", // src/proj.h:1259
    "proj_get_scope_ex", // src/proj.h:1261
    "proj_get_source_crs", // src/proj.h:1287
    "proj_get_suggested_operation", // src/proj.h:1426
    "proj_get_target_crs", // src/proj.h:1289
    "proj_get_type", // src/proj.h:1234
    "proj_get_units_from_database", // src/proj.h:1328
    "proj_grid_cache_clear", // src/proj.h:579
    "proj_grid_cache_set_enable", // src/proj.h:570
    "proj_grid_cache_set_filename", // src/proj.h:572
    "proj_grid_cache_set_max_size", // src/proj.h:575
    "proj_grid_cache_set_ttl", // src/proj.h:577
    "proj_grid_get_info_from_database", // src/proj.h:1221
    "proj_grid_info", // src/proj.h:788
    "proj_identify", // src/proj.h:1291
    "proj_info", // src/proj.h:786
    "proj_init_info", // src/proj.h:789
    "proj_insert_object_session_create", // src/proj.h:1341
    "proj_insert_object_session_destroy", // src/proj.h:1343
    "proj_int_list_destroy", // src/proj.h:1300
    "proj_is_crs", // src/proj.h:1247
    "proj_is_deprecated", // src/proj.h:1236
    "proj_is_derived_crs", // src/proj.h:1723
    "proj_is_download_needed", // src/proj.h:581
    "proj_is_equivalent_to", // src/proj.h:1240
    "proj_is_equivalent_to_with_ctx", // src/proj.h:1243
    "proj_list_angular_units", // src/proj.h:797
    "proj_list_destroy", // src/proj.h:1424
    "proj_list_ellps", // src/proj.h:794
    "proj_list_get", // src/proj.h:1421
    "proj_list_get_count", // src/proj.h:1419
    "proj_list_operations", // src/proj.h:793
    "proj_list_prime_meridians", // src/proj.h:799
    "proj_list_units", // src/proj.h:795
    "proj_log_func", // src/proj.h:779
    "proj_log_level", // src/proj.h:778
    "proj_lp_dist", // src/proj.h:663
    "proj_lpz_dist", // src/proj.h:666
    "proj_normalize_for_visualization", // src/proj.h:602
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
    "proj_pj_info", // src/proj.h:787
    "proj_prime_meridian_get_parameters", // src/proj.h:1491
    "proj_query_geodetic_crs_from_datum", // src/proj.h:1690
    "proj_roundtrip", // src/proj.h:659
    "proj_rtodms", // src/proj.h:811
    "proj_rtodms2", // src/proj.h:813
    "proj_string_destroy", // src/proj.h:1355
    "proj_string_list_destroy", // src/proj.h:1187
    "proj_suggests_code_for", // src/proj.h:1351
    "proj_todeg", // src/proj.h:808
    "proj_torad", // src/proj.h:807
    "proj_trans", // src/proj.h:629
    "proj_trans_array", // src/proj.h:631
    "proj_trans_bounds", // src/proj.h:638
    "proj_trans_bounds_3D", // src/proj.h:644
    "proj_trans_generic", // src/proj.h:633
    "proj_trans_get_last_used_operation", // src/proj.h:630
    "proj_unit_list_destroy", // src/proj.h:1334
    "proj_uom_get_info_from_database", // src/proj.h:1217
    "proj_xy_dist", // src/proj.h:669
    "proj_xyz_dist", // src/proj.h:672
};

/// Compares name bytes rather than pointer identity.
fn listHas(names: []const []const u8, name: []const u8) bool {
    for (names) |candidate| {
        if (std.mem.eql(u8, candidate, name)) return true;
    }
    return false;
}

/// Tests whether the generated table contains a required symbol.
fn tableHas(names: []const rt.Symbol, name: []const u8) bool {
    for (names) |symbol| {
        if (std.mem.eql(u8, symbol.name, name)) return true;
    }
    return false;
}

/// Binds PROJ metadata and ABI checks to the generated dispatch.
/// Compile-time checks match its symbols against `header_symbols`.
pub fn Config(comptime dispatch: type) type {
    return struct {
        /// Name shown by pre-load panics.
        pub const library_name = "proj";

        /// Dispatch table and required exports from the translated header.
        pub const table = dispatch.Table;
        pub const symbols = dispatch.symbols;
        pub const optional_symbols = dispatch.optional_symbols;

        /// Namespaced synchronization callbacks.
        pub const sync = Sync;

        // Rejects count, symbol-set, and symbol-kind mismatches at compile time.
        // Set comparison ignores declaration order; every header export is required.
        comptime {
            // Both symbol-set scans compare all 293 exports at comptime.
            @setEvalBranchQuota(100_000_000);
            if (symbols.len != header_symbols.len) {
                @compileError(std.fmt.comptimePrint(
                    "runtime/library.zig: the dispatch routes {d} symbols and " ++
                        "src/proj.h declares {d} required exports (292 proj_* " ++
                        "functions and pj_release data)",
                    .{ symbols.len, header_symbols.len },
                ));
            }
            for (symbols) |symbol| {
                const expected_kind: rt.SymbolKind = if (std.mem.eql(u8, symbol.name, "pj_release"))
                    .data
                else
                    .function;
                if (symbol.kind != expected_kind) {
                    @compileError(std.fmt.comptimePrint(
                        "runtime/library.zig: {s} is routed as {s}; " ++
                            "src/proj.h declares it as {s}",
                        .{ symbol.name, @tagName(symbol.kind), @tagName(expected_kind) },
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
                        "point at this pin and every declared export is required",
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

        /// Assigns one optional export; this configuration has none.
        pub inline fn assignOptional(comptime index: usize, dst: *table, address: *const anyopaque) void {
            dispatch.assignOptional(index, dst, address);
        }

        pub inline fn assignMissing(comptime index: usize, dst: *table) void {
            dispatch.assignMissing(index, dst);
        }

        /// Checks provider behavior before publishing the resolved table.
        /// Returns a diagnostic if context, `PJ_COORD`, or CRS validation fails.
        pub fn validate(dst: *const table) ?[]const u8 {
            // The provider creates the context with its allocator, without opening a database.
            // Translation may produce `*T` or `?*T`; `@intFromPtr` tests either for null.
            const ctx = dst.proj_context_create();
            if (@intFromPtr(ctx) == 0) {
                return "proj_context_create() answered null, so this provider " ++
                    "could not satisfy one fresh context at all";
            }
            // LIFO defer order releases the CRS before its owning context.
            defer _ = dst.proj_context_destroy(ctx);

            // `proj_coord` writes four values (src/coordinates.cpp:38-45); representative views check layout.
            // Dyadic values are exact in binary64, so comparisons need no tolerance.
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

            // This `+proj=` definition avoids `proj.db` access (src/iso19111/c_api.cpp:624-627).
            const crs = dst.proj_create(ctx, "+proj=longlat +ellps=WGS84 +type=crs");
            if (@intFromPtr(crs) == 0) {
                return "proj_create(\"+proj=longlat +ellps=WGS84 +type=crs\") " ++
                    "answered null, so this provider could not build a CRS from " ++
                    "a PROJ string with no proj.db available";
            }
            defer _ = dst.proj_destroy(crs);

            const kind = dst.proj_get_type(crs);
            // Compare the translated enum value, not a hard-coded ordinal.
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
