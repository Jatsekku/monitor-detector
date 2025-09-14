{
  description = "DRM-based monitor attachment/detachment detector";

  inputs = {
    bash-logger = {
      url = "github:Jatsekku/bash-logger";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      bash-logger,
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          bash-logger-pkg = bash-logger.packages.${system}.default;
          monitor-detector-pkg = pkgs.callPackage ./package.nix { bash-logger = bash-logger-pkg; };
        in
        {
          monitor-detector = monitor-detector-pkg;
          default = monitor-detector-pkg;
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

      nixosModules.monitor-detector = ./module.nix;
      nixosModules.default = self.nixosModules.monitor-detector;
    };
}
