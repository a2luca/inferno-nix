{
  description = "Inferno AoIP — unofficial Dante protocol implementation for NixOS";

  inputs.nixpkgs.url = "nixpkgs/nixos-26.05";

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [self.overlays.default];
    };
  in {
    overlays.default = final: _prev: {
      statime-inferno = final.callPackage ./pkgs/statime-inferno {};
      inferno = final.callPackage ./pkgs/inferno {};
    };

    nixosModules.inferno = import ./modules/inferno.nix;

    packages.${system} = {
      inherit (pkgs) statime-inferno inferno;
      default = pkgs.inferno;
    };

    formatter.${system} = pkgs.alejandra;
  };
}
