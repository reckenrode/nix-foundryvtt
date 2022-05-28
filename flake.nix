{
  description = ''
    Foundry VTT is a standalone application built for experiencing multiplayer tabletop RPGs using
    a feature-rich and modern self-hosted application where your players connect directly through
    the browser.
  '';

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";
    utils.url = "github:gytis-ivaskevicius/flake-utils-plus/v1.3.1";
  };

  outputs = inputs@{ self, utils, nixpkgs, ... }:
    let
      packages = import ./pkgs;
    in
    utils.lib.mkFlake rec {
      inherit self inputs;

      nixosModules.foundryvtt = import ./modules/foundryvtt self;
      
      outputsBuilder = channels:
        let
          inherit (channels) nixpkgs;
        in
        {
          packages = rec {
            foundryvtt = nixpkgs.callPackage ./pkgs/foundryvtt { inherit foundryvtt-deps; };
            foundryvtt-deps = nixpkgs.callPackage ./pkgs/foundryvtt-deps {};
          };
        };
    };
}
