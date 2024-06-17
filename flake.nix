{
  description = ''
    Foundry VTT is a standalone application built for experiencing multiplayer tabletop RPGs using
    a feature-rich and modern self-hosted application where your players connect directly through
    the browser.
  '';

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;

      darwin = [
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      linux = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forEachSystem = systems: f: lib.genAttrs systems (system: f system);
      forAllSystems = forEachSystem (darwin ++ linux);
    in
    {
      nixosModules.foundryvtt = import ./modules/foundryvtt self;
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "pngout" ];
          };

          mkFoundry =
            attrs:
            (pkgs.callPackage ./pkgs/foundryvtt {
              pngout =
                if pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64 then pkgs.pkgsx86_64Darwin.pngout else pkgs.pngout;
            }).overrideAttrs
              (old: old // attrs);
        in
        {
          foundryvtt = mkFoundry { };
          foundryvtt_9 = mkFoundry {
            majorVersion = "9";
            releaseType = "stable";
          };
          foundryvtt_10 = mkFoundry {
            majorVersion = "10";
            releaseType = "stable";
          };
          foundryvtt_11 = mkFoundry {
            majorVersion = "11";
            releaseType = "stable";
          };
          foundryvtt_12 = mkFoundry {
            majorVersion = "12";
            releaseType = "development";
          };
          foundryvtt_latest = self.packages.${system}.foundryvtt_12;
          default = self.packages.${system}.foundryvtt;
        }
      );
    };
}
