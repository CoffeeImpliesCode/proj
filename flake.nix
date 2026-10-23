# Flake packaging for PROJ; both package entry points use `package.nix`.
# The development shell provides tools without building the library.
# SPDX-License-Identifier: MIT

{
  description = "PROJ 9.9.0, the coordinate transformation library, packaged for Zig 0.16";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/c7def046b9a883d46974757852106483d741586f";
  };

  outputs = { self, nixpkgs }:
    let
      # These are the native systems supported by `package.nix`.
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
          # Default static variant of the package.
          static = mk "static";

          # Dynamic variant of the same derivation.
          shared = mk "dynamic";

          default = mk "static";
        });

      # Provide build tools without building the SDK when entering the shell.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.zig_0_16 pkgs.gnumake pkgs.pkg-config ];
        };
      });
    };
}