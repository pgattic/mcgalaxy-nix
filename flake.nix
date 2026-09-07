{
  description = "Source-built Nix packages and NixOS module for MCGalaxy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    mcgalaxy = {
      url = "github:ClassiCube/MCGalaxy";
      flake = false;
    };
  };

  outputs =
    {
      self,
      flake-parts,
      mcgalaxy,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      perSystem =
        { pkgs, ... }:
        let
          mcgalaxy-cli = pkgs.callPackage ./packages/mcgalaxy-cli.nix {
            src = mcgalaxy;
          };

          mcgalaxy-gui = pkgs.callPackage ./packages/mcgalaxy-gui.nix {
            src = mcgalaxy;
          };
        in
        {
          packages = {
            inherit mcgalaxy-cli mcgalaxy-gui;
            default = mcgalaxy-cli;
          };

          apps = {
            cli = {
              type = "app";
              program = "${mcgalaxy-cli}/bin/mcgalaxy-cli";
              meta.description = "Run the MCGalaxy CLI server";
            };

            gui = {
              type = "app";
              program = "${mcgalaxy-gui}/bin/mcgalaxy-gui";
              meta.description = "Run the MCGalaxy graphical server";
            };

            default = self.apps.${pkgs.stdenv.hostPlatform.system}.cli;
          };

          checks = {
            inherit mcgalaxy-cli mcgalaxy-gui;
          };

          formatter = pkgs.nixfmt;
        };

      flake.nixosModules = {
        mcgalaxy = import ./modules/mcgalaxy.nix self;
        default = self.nixosModules.mcgalaxy;
      };
    };
}
