{
  description = "ReRune CLI: prebuilt rerune binaries from the official release mirror";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-x86_64-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-x86_64-darwin,
    }:
    let
      inherit (nixpkgs) lib;
      pkgsBySystem = {
        x86_64-linux = nixpkgs.legacyPackages.x86_64-linux;
        aarch64-linux = nixpkgs.legacyPackages.aarch64-linux;
        aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin;
        x86_64-darwin = import nixpkgs-x86_64-darwin {
          system = "x86_64-darwin";
          config.allowDeprecatedx86_64Darwin = true;
        };
      };
    in
    {
      packages = lib.mapAttrs (
        _system: pkgs:
        let
          rerune = pkgs.callPackage ./pkgs/rerune { };
        in
        {
          inherit rerune;
          default = rerune;
        }
      ) pkgsBySystem;

      apps = lib.mapAttrs (_system: packages: {
        default = {
          type = "app";
          program = lib.getExe packages.rerune;
          meta.description = packages.rerune.meta.description;
        };
      }) self.packages;

      checks = lib.mapAttrs (_system: packages: { inherit (packages) rerune; }) self.packages;

      overlays.default = final: _prev: { rerune = final.callPackage ./pkgs/rerune { }; };
    };
}
