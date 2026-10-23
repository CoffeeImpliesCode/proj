# Source-only PROJ package; `build.zig` owns compilation and installation.
# `flake.nix` and `devenv.nix` share this derivation.
# SPDX-License-Identifier: MIT
# See `FORK-LICENSE.md` for grant scope and `NOTICE.md` for third-party terms.

{ lib
, stdenv
, zig
, patchelf
  # Pass Zig's linkage option; an empty value leaves the build default unchanged.
, linkage ? "static"
, optimize ? "ReleaseSafe"
}:

let
  requestedLinkage =
    if builtins.elem linkage [ "" "static" "dynamic" ] then linkage
    else throw "package.nix: linkage must be \"\", \"static\" or \"dynamic\", not ${toString linkage}";

# Exclude version-control and generated development state from the source.
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

# `patchelf` is ELF-only; the install phase skips it for Darwin.
isElfTarget = !stdenv.hostPlatform.isDarwin;
in

# The derivation rejects cross builds; cross-targets use `build.zig`'s graph.
assert stdenv.buildPlatform.system == stdenv.hostPlatform.system;

stdenv.mkDerivation {
  pname = "proj";
  version = "9.9.0";

  inherit src;

  strictDeps = true;
  dontPatch = true;

  # Disable generic phases so `installPhase` runs the sole Zig build.
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ zig ] ++ lib.optional isElfTarget patchelf;

  # Propagate libc and C++ runtime; SQLite is bundled privately.
  propagatedBuildInputs = [ stdenv.cc.libc stdenv.cc.libcxx ];

  doCheck = false;
  dontUseZigCheck = true;

  installPhase = ''
    runHook preInstall

    export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"

    # Delegate compilation, generation, and installation to `build.zig`.
    zig build install \
      --prefix "$out" \
      -j"''${NIX_BUILD_CORES:-1}" \
      -Doptimize=${optimize} \
      -Dcpu=baseline \
      ${lib.optionalString (requestedLinkage != "") "-Dlinkage=${requestedLinkage}"}

    # Remove build-directory rpaths; keep dependency paths.
    # Resolve symlinks before patching the soname target.
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

  # `build.zig` defines the install tree; CLI tools, man pages, and standalone SQLite are omitted.

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