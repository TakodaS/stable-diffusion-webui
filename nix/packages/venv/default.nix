{
  lib,
  pkgs,
  system,
  self,
  pyproject-nix,
  pyproject-build-systems,
  uv2nix,
  uv2nix_hammer_overrides,

  ...
}:
let

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

  # Python sets grouped per system
  pythonSets =
    let
      inherit (pkgs) stdenv;

      # Base Python package set from pyproject.nix
      baseSet = pkgs.callPackage pyproject-nix.build.packages {
        python = pkgs.python312;
      };

      # An overlay of build fixups & test additions
      pyprojectOverrides = final: prev: {

        sgm = prev.sgm.overrideAttrs (old: {
          nativeBuildInputs =
            (old.nativeBuildInputs or [ ])
            ++ final.resolveBuildSystem {
              hatchling = [ ];
            };
        });
        cv-3 = prev.cv-3.overrideAttrs (old: {
          nativeBuildInputs =
            (old.nativeBuildInputs or [ ])
            ++ final.resolveBuildSystem {
              setuptools = [ ];
            };
        });
        # ${package-name} is the name of our example package
        ${package-name} = prev.${package-name}.overrideAttrs (old: {

          # Add tests to passthru.tests
          #
          # These attribute are used in Flake checks.
          passthru = old.passthru // {
            tests =
              (old.tests or { })
              // {

                # Run mypy checks
                mypy =
                  let
                    venv = final.mkVirtualEnv "${package-name}-typing-env" {
                      ${package-name} = [ "typing" ];
                    };
                  in
                  stdenv.mkDerivation {
                    name = "${final.${package-name}.name}-mypy";
                    inherit (final.${package-name}) src;
                    nativeBuildInputs = [
                      venv
                    ];
                    dontConfigure = true;
                    dontInstall = true;
                    buildPhase = ''
                      mkdir $out
                      mypy --strict . --junit-xml $out/junit.xml
                    '';
                  };

                # Run pytest with coverage reports installed into build output
                pytest =
                  let
                    venv = final.mkVirtualEnv "${package-name}-pytest-env" {
                      ${package-name} = [ "test" ];
                    };
                  in
                  stdenv.mkDerivation {
                    name = "${final.${package-name}.name}-pytest";
                    inherit (final.${package-name}) src;
                    nativeBuildInputs = [
                      venv
                    ];

                    dontConfigure = true;

                    buildPhase = ''
                      runHook preBuild
                      pytest --cov tests --cov-report html tests
                      runHook postBuild
                    '';

                    installPhase = ''
                      runHook preInstall
                      mv htmlcov $out
                      runHook postInstall
                    '';
                  };
              }
              // lib.optionalAttrs stdenv.isLinux {

                # NixOS module test
                nixos =
                  let
                    venv = final.mkVirtualEnv "${package-name}-nixos-test-env" {
                      ${package-name} = [ ];
                    };
                  in
                  pkgs.nixosTest {
                    name = "${package-name}-nixos-test";

                    nodes.machine =
                      { ... }:
                      {
                        imports = [
                          self.nixosModules.${package-name}
                        ];

                        services.${package-name} = {
                          enable = true;
                          inherit venv;
                        };

                        system.stateVersion = "24.11";
                      };

                    testScript = ''
                      machine.wait_for_unit("${package-name}.service")

                      with subtest("Web interface getting ready"):
                          machine.wait_until_succeeds("curl -fs localhost:8000")
                    '';
                  };

              };
          };
        });
      };

    in
    baseSet.overrideScope (
      lib.composeManyExtensions [
        pyproject-build-systems.overlays.default
        overlay
        (uv2nix_hammer_overrides.overrides pkgs)
        pyprojectOverrides
      ]
    );
  envs = lib.attrsets.genAttrs workspace.deps.all.stable-diffusion-webui (
    name: pythonSets.mkVirtualEnv "${package-name}-${name}-env" { ${package-name} = [ name ]; }
  );
in
(pythonSets.mkVirtualEnv "${package-name}-env" workspace.deps.default).overrideAttrs (
  self: super: {
    passthru = envs;
  }
)
