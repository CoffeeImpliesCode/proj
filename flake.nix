# Flake interface for the OSGeo/PROJ SDK.
#
# Portable counterpart to devenv.nix. Both call ./package.nix, so the package a
# flake builds and the package devenv builds are the same derivation; this file
# only decides which systems are exposed and which variants of that derivation
# they get.
#
# Canonical development is `devenv shell` (see devenv.nix and .envrc). This
# flake exists so the SDK can be built and consumed off this host. `nix develop`
# here is parity, not the canonical entry point, and it deliberately does not
# build the SDK: entering a shell must not require building a library.
#
# flake.lock pins the nixpkgs revision named in `inputs` below, and the driver
# owns it: the revision here and the one in devenv.yaml are the same value
# because they were written together, and neither file derives it from the other.
#
# SPDX-License-Identifier: MIT

{
  description = "PROJ 9.9.0, the coordinate transformation library, packaged for Zig 0.16";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/c7def046b9a883d46974757852106483d741586f";
  };

  outputs = { self, nixpkgs }:
    let
      # PROJ itself is Unix-only at this pin in the sense that matters for this
      # package's own delivery: `src/filemanager.cpp:62-71` reaches
      # `<windows.h>` on Windows and `<dlfcn.h>` only under `HAVE_LIBDL`, and
      # the vendored SQLite3 amalgamation compiles everywhere. These are the
      # systems package.nix builds on, which is a property of that derivation
      # (it refuses a cross build) and not a claim that PROJ cannot be built for
      # Windows -- `zig build check` walks `x86_64-windows-gnu`, and the
      # compile-only matrix there is a separate gate with its own receipt.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
        "x86_64-freebsd"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs:
        let
          mk = linkage: pkgs.callPackage ./package.nix {
            inherit linkage;
            zig = pkgs.zig_0_16;
          };
        in
        {
          # The default delivery is `static`, and it is a fork decision rather
          # than upstream's: `build.zig` chooses it, while
          # `src/lib_proj.cmake:554` sets only `OUTPUT_NAME` and leaves the
          # archive-versus-shared choice to CMake's `BUILD_SHARED_LIBS`, which
          # defaults OFF here in any case because this package has no CMake at
          # all.
          static = mk "static";

          # A separate variant of the same derivation, not a second SDK.
          # "shared" names the artefact; the flag it passes is Zig's own
          # `-Dlinkage=dynamic`, which produces `libproj.so.25` with `VERSION`
          # `25.9.0` because `CMakeLists.txt:170-171` says so.
          shared = mk "dynamic";

          default = mk "static";
        });

      # Parity only. The canonical development environment is devenv.nix. The
      # shell here carries the tools the gates in `.github/workflows/verify.yml`
      # need and nothing else: the SDK is not a package in this shell, because
      # `zig build` is how it is built and entering a shell must not do that.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.zig_0_16 pkgs.gnumake pkgs.pkg-config ];
        };
      });
    };
}