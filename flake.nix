{
  description = "Django application using uv2nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix_hammer_overrides = {
      url = "github:TyberiusPrime/uv2nix_hammer_overrides";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      uv2nix,
      ...
    }:
    let
      lib = nixpkgs.lib.extend (
        self: _: {
          flake =
            import ./nix/lib {
              lib = self;
            }
            // inputs;
        }
      );
      inherit (lib.flake) forAllSystems getSubdirs;

      asgiApp = "django_webapp.asgi:application";
      settingsModules = {
        prod = "django_webapp.settings";
      };

      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = "${self}"; };

      overlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };
      package-name = "stable-diffusion-webui";

      editableOverlay = workspace.mkEditablePyprojectOverlay {
        root = "$REPO_ROOT";
      };

      nixDirs = lib.flake.getSubdirs ./nix;
      importFolder = (
        name: {
          name = name;
          value = forAllSystems (
            system:
            let
              pkgs = import nixpkgs {
                inherit system;
                config.allowUnfree = true;
              };
            in

            (import ./nix/${name} (
              {
                inherit
                  lib
                  pkgs
                  system
                  package-name
                  ;
              }
              // inputs
            ))
          );
        }
      );
    in
    builtins.listToAttrs (map importFolder nixDirs);
}
#       {
#
#         # checks = forAllSystems (
#         #   system:
#         #   let
#         #     pythonSet = pythonSets.${system};
#         #   in
#         #   # Inherit tests from passthru.tests into flake checks
#         #   pythonSet.${package-name}.passthru.tests
#         # );
#
#         # nixosModules = {
#         #   ${package-name} =
#         #     {
#         #       config,
#         #       lib,
#         #       pkgs,
#         #       ...
#         #     }:
#         #
#         #     let
#         #       cfg = config.services.${package-name};
#         #       inherit (pkgs) system;
#         #
#         #       pythonSet = pythonSets.${system};
#         #
#         #       inherit (lib.options) mkOption;
#         #       inherit (lib.modules) mkIf;
#         #     in
#         #     {
#         #       options.services.${package-name} = {
#         #         enable = mkOption {
#         #           type = lib.types.bool;
#         #           default = false;
#         #           description = ''
#         #             Enable ${package-name}
#         #           '';
#         #         };
#         #
#         #         settings-module = mkOption {
#         #           type = lib.types.string;
#         #           default = settingsModules.prod;
#         #           description = ''
#         #             Django settings module
#         #           '';
#         #         };
#         #
#         #         venv = mkOption {
#         #           type = lib.types.package;
#         #           default = pythonSet.mkVirtualEnv "${package-name}-env" workspace.deps.default;
#         #           description = ''
#         #             ${package-name} virtual environment package
#         #           '';
#         #         };
#         #
#         #         static-root = mkOption {
#         #           type = lib.types.package;
#         #           default = staticRoots.${system};
#         #           description = ''
#         #             ${package-name} static root
#         #           '';
#         #         };
#         #       };
#         #
#         #       config = mkIf cfg.enable {
#         #         systemd.services.${package-name} = {
#         #           description = "Django Webapp server";
#         #
#         #           environment.DJANGO_STATIC_ROOT = cfg.static-root;
#         #
#         #           serviceConfig = {
#         #             ExecStart = ''
#         #               ${cfg.venv}/bin/daphne django_webapp.asgi:application
#         #             '';
#         #             Restart = "on-failure";
#         #
#         #             DynamicUser = true;
#         #             StateDirectory = "${package-name}";
#         #             RuntimeDirectory = "${package-name}";
#         #
#         #             BindReadOnlyPaths = [
#         #               "${
#         #                 config.environment.etc."ssl/certs/ca-certificates.crt".source
#         #               }:/etc/ssl/certs/ca-certificates.crt"
#         #               builtins.storeDir
#         #               "-/etc/resolv.conf"
#         #               "-/etc/nsswitch.conf"
#         #               "-/etc/hosts"
#         #               "-/etc/localtime"
#         #             ];
#         #           };
#         #
#         #           wantedBy = [ "multi-user.target" ];
#         #         };
#         #       };
#         #
#         #     };
#         #
#         # };
#
#         apps = forAllSystems (
#           system:
#
#           let
#             pkgs = import nixpkgs {
#               inherit system;
#               config.allowUnfree = true;
#             };
#             inherit (self.packages.${system}) venv;
#             program = pkgs.writeScriptBin "${package-name}-run" ''
#               "${venv}/bin/python launch.py --skip-prepare-environment --skip-python-version-check"
#             '';
#           in
#           {
#             default = {
#               inherit program;
#               type = "app";
#             };
#           }
#         );
#         packages = forAllSystems (
#           system:
#           let
#             pkgs = import nixpkgs {
#               inherit system;
#               config.allowUnfree = true;
#             };
#           in
#
#           (import ./nix/packages (
#             {
#               inherit
#                 lib
#                 pkgs
#                 system
#                 package-name
#                 ;
#             }
#             // inputs
#           ))
#         );
#
#         # # Use an editable Python set for development.
#         # devShells = forAllSystems (
#         #   system:
#         #   let
#         #     pkgs = nixpkgs.legacyPackages.${system};
#         #
#         #     editablePythonSet = pythonSets.${system}.overrideScope (
#         #       lib.composeManyExtensions [
#         #         editableOverlay
#         #
#         #         (final: prev: {
#         #           ${package-name} = prev.${package-name}.overrideAttrs (old: {
#         #             src = lib.cleanSource ./.;
#         #             nativeBuildInputs =
#         #               old.nativeBuildInputs
#         #               ++ final.resolveBuildSystem {
#         #                 editables = [ ];
#         #               };
#         #           });
#         #         })
#         #       ]
#         #     );
#         #
#         #     venv = self.packages.${system}.venv;
#         #   in
#         #   {
#         #     default = pkgs.mkShell {
#         #       packages = [
#         #         venv
#         #         pkgs.uv
#         #       ];
#         #       env = {
#         #         UV_NO_SYNC = "1";
#         #         UV_PYTHON = "${venv}/bin/python";
#         #         UV_PYTHON_DOWNLOADS = "never";
#         #       };
#         #       shellHook =
#         #         let
#         #           getModels = lib.attrsets.foldlAttrs (
#         #             acc: name: value:
#         #             acc + "mkdir -p ./repositories/${name} && cp -r ${value}/* ./repositories/${name} \n"
#         #           ) "" self.packages.${system}.deps;
#         #         in
#         #         ''
#         #           unset PYTHONPATH
#         #           export REPO_ROOT=$(git rev-parse --show-toplevel)
#         #         '';
#         #     };
#         #     init = pkgs.mkShell {
#         #       packages = [
#         #         pkgs.uv
#         #         pkgs.python312
#         #       ];
#         #       env = {
#         #         UV_NO_SYNC = "1";
#         #         UV_PYTHON = "${venv}/bin/python";
#         #         UV_PYTHON_DOWNLOADS = "never";
#         #       };
#         #       shellHook = ''
#         #         unset PYTHONPATH
#         #         export REPO_ROOT=$(git rev-parse --show-toplevel)
#         #       '';
#         #     };
#         #   });
#       };
# }
