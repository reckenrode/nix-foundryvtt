{
  description = ''
    Foundry VTT is a standalone application built for experiencing multiplayer tabletop RPGs using
    a feature-rich and modern self-hosted application where your players connect directly through
    the browser.
  '';

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;

      darwin = [ "x86_64-darwin" "aarch64-darwin" ];
      linux = [ "x86_64-linux" "aarch64-linux" ];

      forEachSystem = systems: f: lib.genAttrs systems (system: f system);
      forAllSystems = forEachSystem (darwin ++ linux);
    in
    {
      nixosModules.foundryvtt = import ./modules/foundryvtt self;
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          foundryvtt = pkgs.callPackage ./pkgs/foundryvtt { };
          default = self.packages.${system}.foundryvtt;
        });
    };
}
