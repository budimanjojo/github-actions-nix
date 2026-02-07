{
  description = "Generate GitHub Actions workflows from Nix configuration";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
    flake-parts.url = "https://flakehub.com/f/hercules-ci/flake-parts/0.1";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      imports = [
        inputs.flake-parts.flakeModules.partitions
        # Dogfood: use our own module for CI
        ./modules/github-ci.nix
      ];

      # Partition development tools to avoid polluting consumers' lockfiles
      partitionedAttrs = {
        devShells = "dev";
        apps = "dev";
        checks = "dev";
      };

      partitions.dev = {
        extraInputsFlake = ./dev;
        module.imports = [
          ./dev/flake-module.nix
        ];
      };

      flake = rec {
        flakeModule = flakeModules.default;
        flakeModules = rec {
          default = githubActions;
          githubActions = ./modules/github-ci.nix;
        };
      };
    };
}
