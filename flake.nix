{
  description = ''
    Foundry VTT is a standalone application built for experiencing multiplayer tabletop RPGs using
    a feature-rich and modern self-hosted application where your players connect directly through
    the browser.
  '';

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-20.09";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in rec {
        packages.foundryvtt = pkgs.callPackage (import ./pkgs/foundryvtt.nix) {};
        defaultPackage = packages.foundryvtt;
      }) // {
        overlay = final: prev: { foundryvtt = self.packages.${final.system}.foundryvtt; };
        nixosModules.foundryvtt = import ./modules/foundryvtt.nix self.packages;
      };
}
