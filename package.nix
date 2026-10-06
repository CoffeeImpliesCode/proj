# Source-only package derivation for the OSGeo/PROJ SDK.
#
# One file, consumed by both flake.nix and devenv.nix, so the two entry points
# cannot describe different packages. It builds nothing but this repository: the
# native source is upstream's `src/`, `include/` and `data/`, which is the
# complete PROJ 9.9.0 closure that `src/lib_proj.cmake` and
# `src/apps/lib_projapps.cmake` put in the `proj` target together with the
# vendored `vendor/sqlite3/`, and build.zig owns every compile flag, both
# generated inputs and the whole installed layout. Nothing here restates a C or
# C++ flag, fetches a tarball, reaches into a sibling checkout, runs CMake, or
# installs an artifact of its own. The one edit it makes is the rpath of the ELF
# files the build installed: Zig records its own build cache there, and that
# directory does not exist once a binary is installed.
#
# No lock file is written here. `flake.lock` is this fork's own input and lives
# in the tree; `devenv.lock` belongs to the driver.
#
# SPDX-License-Identifier: MIT
# See FORK-LICENSE.md for what that identifier covers, and NOTICE.md for the
# terms that cover everything in src/, include/, data/ and vendor/:

{ lib
, stdenv
, zig
, patchelf
  # Zig's own `std.builtin.LinkMode` spelling, passed straight through as
  # `-Dlinkage`. "static" and "dynamic" are two variants of one derivation, and
  # `""` passes nothing at all so the SDK's own default policy runs unchanged.
  # Static is this fork's default and `.shared` is the separate variant; the
  # default is a fork decision and not upstream's, which is why `outputs.static`
  # in flake.nix says so too.
, linkage ? "static"
, optimize ? "ReleaseSafe"
}:

let
  requestedLinkage =
    if builtins.elem linkage [ "" "static" "dynamic" ] then linkage
    else throw "package.nix: linkage must be \"\", \"static\" or \"dynamic\", not ${toString linkage}";

# Everything except build outputs, version control and developer-tool state.
# Filtering by directory name rather than by an allow list means a file added
# here later is packaged without editing this file, while `.zig-cache/`,
# `zig-out/`, `.devenv/`, `.direnv/` and `result` stay out of a published output
# at any depth, including under consumer/.
#
# The upstream manuals, man pages, tests, examples, Python scripts and both
# upstream build systems are deliberately kept: they are upstream material with
# digests in UPSTREAM.sha256, and the audit surface is the whole upstream tree.
# `tools/check-provenance.sh` runs against the working tree and not against this
# filtered copy, so nothing here can narrow what that gate sees.
src = lib.cleanSourceWith {
  src = ./.;
  filter = path: _type:
    let name = builtins.baseNameOf (toString path); in
    !(lib.elem name [
      ".git"
      ".direnv"
      ".devenv"
      ".zig-cache"
      "zig-cache"
      "zig-pkg"
      "zig-out"
      "result"
    ]);
};

# patchelf rewrites ELF rpaths and does not read Mach-O, so the rpath
# normalisation in the install phase exists for ELF targets only, and the tool is
# a build input exactly where that code runs.
isElfTarget = !stdenv.hostPlatform.isDarwin;
in

# These packages build for the compiler's own native target. A cross build here
# would mean hand-building a libc-suffixed triple that has to track nixpkgs, so
# this derivation refuses one instead of silently producing a host-architecture
# library under a foreign name. The comparison is against stdenv's own
# platforms, which are pure values; `builtins.currentSystem` is not evaluable
# in a sandbox and is not used. A remote builder is unaffected: this compares
# build against host, not against any particular machine.
#
# That refusal does not narrow the SDK's own cross-target gate: `zig build check`
# walks `x86_64-linux-gnu`, `aarch64-linux-gnu`, `aarch64-macos-none`,
# `x86_64-windows-gnu`, `riscv64-linux-gnu` and `wasm32-wasi` from a source tree
# with no Nix involvement at all, and the driver's cross-test matrix runs the
# `test` step over the published 53 platforms. A limitation of *this packaging
# route* is recorded as such and is not a claim about the library.
assert stdenv.buildPlatform.system == stdenv.hostPlatform.system;

stdenv.mkDerivation {
  pname = "proj";
  version = "9.9.0";

  inherit src;

  strictDeps = true;
  dontPatch = true;

  # The real work is one `zig build install` in installPhase below. Disabling
  # configure and build phases keeps the Zig setup hook from running a first,
  # differently-flagged build of its own; `dontInstall` is deliberately NOT set,
  # because that is what would disable the real install phase.
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ zig ] ++ lib.optional isElfTarget patchelf;

  # PROJ links against the C library, the C++ runtime, the C math library,
  # `libdl` where it is separate, and pthreads where they exist -- see
  # `build.zig`'s `mathLibrary`, `dlLibrary` and `pthreadLibrary`. On Linux the
  # vendored SQLite3 amalgamation is compiled into the archive and needs nothing
  # else: it is built with its own defaults, which use the platform's threads
  # implementation and no zlib. That is the whole of the native dependency
  # closure, and it is why there is no `sqlite3` in this list and no
  # `Requires.private: sqlite3` in the installed `proj.pc`.
  propagatedBuildInputs = [ stdenv.cc.libc stdenv.cc.libcxx ];

  # The driver owns every gate for this SDK, and a Nix build is not a
  # verification receipt. No check phase is declared here rather than a check
  # phase that runs something smaller than the real gates; the commands that do
  # verify this package are `zig build`, `zig build test` in Debug and
  # ReleaseSafe, `zig build smoke`, `zig build check`,
  # `tools/check-provenance.sh` and `zig build run` in `consumer/`, and they are
  # in README.md and CHANGELOG.md.
  doCheck = false;
  dontUseZigCheck = true;

  installPhase = ''
    runHook preInstall

    # Both caches go under the Nix-provided TMPDIR, outside the unpacked source
    # tree, so a build cannot write into $src and so two parallel derivations
    # cannot share state. Any caller-supplied cache variables are left alone:
    # they are the caller's scratch, not this file's to clear.
    export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"

    # build.zig owns the source list, the compile settings, the per-target
    # `proj_config.h`, the `proj.db` generator and its assertion against
    # `data/sql/proj.db.sql.expected.md5`, the generated pkg-config file and
    # every installed path. Declaring any of them here as well would create a
    # second place where they can disagree with the build graph.
    zig build install \
      --prefix "$out" \
      -j"''${NIX_BUILD_CORES:-1}" \
      -Doptimize=${optimize} \
      -Dcpu=baseline \
      ${lib.optionalString (requestedLinkage != "") "-Dlinkage=${requestedLinkage}"}

    # Zig records the build cache in the rpath of anything that links a dynamic
    # artifact it has just built (lib/std/Build/Step/Compile.zig:1192-1199), so
    # an installed binary names a directory that is gone, and Nix rejects an
    # installed file that names its build directory at all. Both Zig caches above
    # are under $TMPDIR, so dropping those entries and no other removes it: the
    # $ORIGIN/../lib build.zig adds, and every store path a real dependency
    # needs, stay. Symlinks are resolved first so the libproj.so.25 soname link is
    # rewritten through to the object and never replaced by a copy of it.
    ${lib.optionalString isElfTarget ''
      for elf in "$out"/bin/* "$out"/lib/*.so*; do
        [ -f "$elf" ] || continue
        elf=$(readlink -f "$elf")
        rpath=$(patchelf --print-rpath "$elf") || rpath=""
        kept=""
        rest=$rpath
        while [ -n "$rest" ]; do
          entry="''${rest%%:*}"
          case "$entry" in
            "$TMPDIR"/*) ;;
            *) if [ -z "$kept" ]; then kept=$entry; else kept=$kept:$entry; fi ;;
          esac
          if [ "$entry" = "$rest" ]; then rest=""; else rest="''${rest#*:}"; fi
        done
        [ "$kept" = "$rpath" ] || patchelf --set-rpath "$kept" "$elf"
      done
    ''}

    runHook postInstall
  '';

  # The layout this derivation produces is the build graph's, not this file's:
  # $out/lib/libproj.a (or libproj.so.25.9.0 with the libproj.so.25 and
  # libproj.so links),
  # $out/include/{proj.h,proj_constants.h,proj_experimental.h,proj_symbol_rename.h},
  # $out/share/proj/{proj.db,proj.ini,three *.schema.json, nad.lst,
  # other.extra and the nine +init definition files},
  # $out/lib/pkgconfig/proj.pc, and $out/share/doc/proj/ with upstream's COPYING
  # and this fork's records. Both variants keep it; only the artifact kind
  # differs. Nothing is copied or generated by hand here, so
  # `zig build install --prefix $out` and `nix build` produce one layout by
  # construction rather than two that have to be kept in agreement.
  #
  # What is deliberately absent, and is an upstream build-setting question rather
  # than an omission: no `share/man`, because this package's installed layout has
  # none even though `man/` travels in `build.zig.zon .paths`; no `bin/`, because
  # the seven command-line applications are not part of the `proj` target and are
  # not compiled; and no `lib/libsqlite3.*`, because the amalgamation is a private
  # dependency compiled into the archive.

  enableParallelBuilding = true;

  meta = {
    description = "PROJ 9.9.0, the coordinate transformation library, built from the official release sources";
    longDescription = ''
      The complete PROJ 9.9.0 release source -- the 218 translation units that
      upstream's src/lib_proj.cmake and src/apps/lib_projapps.cmake put in the
      `proj` target, plus the vendored SQLite3 3.53.4 amalgamation as a private
      dependency -- compiled from the tarball's own src/, include/ and vendor/
      directories with Zig, with no CMake, no autotools and no build-time
      download. Ships the library, the four public headers, the datum database
      generated from data/sql/, the data files, and a pkg-config file.
    '';
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}