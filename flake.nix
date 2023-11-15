{
  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/release-23.05;
    flake-utils.url = github:numtide/flake-utils;

    zig-overlay = {
      url = github:mitchellh/zig-overlay;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        name = "twodee";
        pkgs = (import nixpkgs){
          inherit system;
          overlays = [
            zig-overlay.overlays.default
          ];
        };

        make = args:
          let
            argsStr = pkgs.lib.strings.concatStringsSep " " args;
          in
          pkgs.stdenv.mkDerivation {
            pname = name;
            version = "0.0.1";
            src = self;

            dontConfigure = true;

            nativeBuildInputs = with pkgs; [
              zigpkgs."0.11.0"
              libepoxy
              SDL2
              xorg.libX11
            ];

            propagatedBuildInputs = with pkgs; [
              autoPatchelfHook # MWAH I LOVE YOU NIX!
            ];

            patchPhase = ''
              # fix since homeless-shelter is read-only in nix build
              export HOME="$TMP/home"
              mkdir -p "$HOME"
            '';

            buildPhase = ''
              zig build ${argsStr}
            '';

            installPhase = ''
              mkdir -p $out/bin
              install -t $out/bin ./zig-out/bin/${name}
            '';
          };

        outPkgs = {
          debug = make ["-Doptimize=Debug"];
          release = make ["-Doptimize=ReleaseFast"];
        };
      in
      {
        packages = {
          default = outPkgs.debug;
          inherit (outPkgs) debug release;
        };
      });
}
