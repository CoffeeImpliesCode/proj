# Canonical development shell and tasks for the PROJ SDK.
# `package.nix` defines the derivation shared with `flake.nix`.
# SPDX-License-Identifier: MIT

{ pkgs, ... }:

let
  # Use one Zig version for the assertion and package list.
  zig = pkgs.zig_0_16;

  proj = linkage: pkgs.callPackage ./package.nix { inherit linkage; };

  # Resolve this checkout relative to the module, not the caller's directory.
  sdk_root = builtins.toString ./.;

  # Place Zig caches outside the checkout unless the caller sets their paths.
  zig_caches = ''
    if [ -z "''${ZIG_LOCAL_CACHE_DIR:-}" ]; then
      if [ -n "''${XDG_CACHE_HOME:-}" ]; then
        export ZIG_LOCAL_CACHE_DIR="$XDG_CACHE_HOME/proj/zig-local-cache"
      elif [ -n "''${TMPDIR:-}" ]; then
        export ZIG_LOCAL_CACHE_DIR="$TMPDIR/proj/zig-local-cache"
      fi
    fi
    if [ -z "''${ZIG_GLOBAL_CACHE_DIR:-}" ]; then
      if [ -n "''${XDG_CACHE_HOME:-}" ]; then
        export ZIG_GLOBAL_CACHE_DIR="$XDG_CACHE_HOME/proj/zig-global-cache"
      elif [ -n "''${TMPDIR:-}" ]; then
        export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/proj/zig-global-cache"
      fi
    fi
    if [ -n "''${ZIG_LOCAL_CACHE_DIR:-}" ]; then
      mkdir -p "$ZIG_LOCAL_CACHE_DIR"
    fi
    if [ -n "''${ZIG_GLOBAL_CACHE_DIR:-}" ]; then
      mkdir -p "$ZIG_GLOBAL_CACHE_DIR"
    fi
  '';

  # Tasks stop when no external build-output directory is available.
  require_external_output = ''
    if [ -z "''${ZIG_LOCAL_CACHE_DIR:-}" ]; then
      echo "proj devenv: ZIG_LOCAL_CACHE_DIR, XDG_CACHE_HOME and TMPDIR are all unset," >&2
      echo "so there is nowhere outside this checkout to put build output." >&2
      echo "Export one of them at approved scratch, then run the task again." >&2
      exit 1
    fi
  '';

  # Tasks enter this checkout before invoking Zig.
  in_sdk = ''
    ${zig_caches}
    ${require_external_output}
    cd "${sdk_root}" || exit 1
  '';

  native_flags = ''
    -j8 --summary all --cache-dir "$ZIG_LOCAL_CACHE_DIR/native" "''$@"
  '';

  # Keep consumer and SDK build caches separate.
  consumer_flags = ''
    -j8 --summary all --cache-dir "$ZIG_LOCAL_CACHE_DIR/consumer" "''$@"
  '';
in
{
  packages = [
    zig
    pkgs.gnumake
    pkgs.pkg-config
    pkgs.valgrind
  ];

  assertions = [
    {
      assertion = zig.version == "0.16.0";
      message = "The PROJ SDK requires Zig 0.16.0; nixpkgs resolved zig_0_16 to ${zig.version}";
    }
  ];

  # Apply the same cache policy to interactive shells.
  enterShell = ''
    ${zig_caches}
  '';

  # Outputs stay lazy until a task realizes them.
  outputs.static = proj "static";
  outputs.shared = proj "dynamic";
  outputs.default = proj "static";

  tasks = {
    # Install to an external prefix rather than `zig-out/` in the checkout.
    "sdk:build" = {
      description = ''
        Compile the 219-unit native library and the generated datum database
        (default step) and install the delivery tree -- library, four public
        headers, share/proj/, proj.pc and share/doc/proj/ -- under the external
        cache rather than in this checkout.
      '';
      exec = ''
        ${in_sdk}
        zig build --prefix "$ZIG_LOCAL_CACHE_DIR/prefix/static" ${native_flags}
      '';
    };

    "sdk:build:shared" = {
      description = ''
        Compile the same closure as a shared object instead of an archive --
        libproj.so.25 with VERSION 25.9.0, per CMakeLists.txt:170-171 -- and
        install it under its own external prefix.
      '';
      exec = ''
        ${in_sdk}
        zig build -Dlinkage=dynamic --prefix "$ZIG_LOCAL_CACHE_DIR/prefix/dynamic" ${native_flags}
      '';
    };

    # Run steps use the data and network settings from `build.zig`.
    "sdk:test" = {
      description = "Run the facade tests and the API exercise in Debug";
      exec = ''
        ${in_sdk}
        zig build test -Doptimize=Debug ${native_flags}
      '';
    };

    "sdk:test:release-safe" = {
      description = "Run the facade tests and the API exercise in ReleaseSafe";
      exec = ''
        ${in_sdk}
        zig build test -Doptimize=ReleaseSafe ${native_flags}
      '';
    };

    "sdk:smoke" = {
      description = "Run the example program against the generated datum data";
      exec = ''
        ${in_sdk}
        zig build smoke ${native_flags}
      '';
    };

    "sdk:check" = {
      description = ''
        Compile the core, the facade, the API exercise, the tests and the example
        for all six cross targets without running any of them. Each cell compiles
        roughly 220 C and C++ translation units, so this is the slowest task here.
      '';
      exec = ''
        ${in_sdk}
        zig build check ${native_flags}
      '';
    };

    # Exercise the dependency from a separate consumer package.
    "sdk:consumer" = {
      description = "Build and run the separate consumer package against this SDK";
      exec = ''
        ${in_sdk}
        cd consumer
        zig build run ${consumer_flags}
      '';
    };

    # Run the provenance checker from this checkout's source tree.
    "sdk:provenance" = {
      description = ''
        Check the 664 recorded upstream digests, the exact upstream file set, the
        preserved upstream README, PROJ's MIT-style grant and SQLite's
        public-domain notice. This is a source-integrity check, not a build gate.
      '';
      exec = ''
        cd "${sdk_root}" || exit 1
        bash tools/check-provenance.sh
      '';
    };

    # Keep nested builds in the caller's devenv project to use its lock.
    "sdk:package:static" = {
      description = ''
        Build the static Nix variant through devenv's own lazy output. No lock is
        needed by this path; `devenv build outputs.static` resolves the pinned
        input from devenv.lock, which the driver owns.
      '';
      exec = "devenv build outputs.static";
    };

    "sdk:package:shared" = {
      description = "Build the shared Nix variant through devenv's own lazy output";
      exec = "devenv build outputs.shared";
    };
  };
}