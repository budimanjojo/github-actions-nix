{inputs, ...}: {
  imports = [
    inputs.files.flakeModules.default
  ];

  perSystem = {
    config,
    system,
    pkgs,
    lib,
    ...
  }: {
    devShells.default = pkgs.mkShell {
      packages = let
        hk = inputs.hk.packages.${system}.hk.overrideAttrs (_old: {
          doCheck = false;
        });
      in
        with pkgs; [
          # Core tools
          yq-go
          hk

          # Nix formatters and linters
          alejandra
          deadnix
          statix

          # GitHub Actions linter
          actionlint

          # Configuration formatters
          pkl

          # Commit message linters
          gitlint
        ];

      shellHook = ''
        # Ensure git hooks are installed (skip in worktrees)
        if [ -d .git ]; then
          if ! output=$(hk install 2>&1); then
            exit_code=$?
            echo "$output" >&2
            exit $exit_code
          fi
        fi
      '';
    };

    # Configure files module to sync generated workflows to .github/workflows/
    files.files =
      lib.mapAttrsToList (name: drv: {
        path_ = ".github/workflows/${name}";
        inherit drv;
      })
      config.githubActions.workflowFiles;

    # Expose the files writer as an app
    apps.write-files = {
      type = "app";
      program = lib.getExe config.files.writer.drv;
      meta.description = "Write generated files to the repository";
    };

    # CI workflow configuration - dogfooding the github-actions-nix module
    githubActions = {
      enable = true;

      workflows = {
        ci = {
          name = "CI";

          on = {
            pullRequest = {};
            workflowDispatch = {};
            push = {
              branches = ["master"];
              tags = ["v?[0-9]+.[0-9]+.[0-9]+*"];
            };
          };

          concurrency = {
            group = "\${{ github.workflow }}-\${{ github.event.pull_request.number || github.ref }}";
            cancelInProgress = true;
          };

          jobs = {
            nix-ci = {
              uses = "DeterminateSystems/ci/.github/workflows/workflow.yml@main";
              permissions = {
                id-token = "write";
                contents = "read";
              };
              with_ = {
                visibility = "public";
              };
            };
          };
        };
      };
    };
  };
}
