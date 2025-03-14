args@{
  package-name,
  lib,
  pkgs,
  system,
  pythonSet,
  self,
  ...
}:
let
  inherit (pkgs) stdenv stdenvNoCC;
  inherit (self.packages.${system}) venv;
  src = lib.cleanSource "${self}";
  # Run mypy checks
  mypy =
    let
      venv = self.packages.${system}.venv.typing;
    in
    stdenv.mkDerivation {
      name = "${package-name}-test-mypy";
      inherit src;
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
      venv = self.packages.${system}.venv.test;
    in
    stdenv.mkDerivation {
      name = "${package-name}-test-pytest";
      inherit src;
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
  nixos =

    let
      venv = self.packages.${system}.venv.test;
    in
    lib.optionalAttrs stdenv.isLinux

      # NixOS module test
      pkgs.nixosTest
      {
        name = "${package-name}-nixos-test";

        nodes.machine =
          { ... }:
          {
            virtualisation.memorySize = 6000;
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
              machine.wait_until_succeeds("curl -fs localhost:7860")
        '';
      };

  testAttrs = {
    inherit
      mypy
      pytest
      nixos
      ;
  };
  tests = pkgs.symlinkJoin rec {
    name = "test";
    paths = builtins.attrValues passthru;
    passthru = testAttrs;
  };
in
pythonSet.${package-name}.overrideAttrs (old: {

  # Add tests to passthru.tests
  #
  # These attribute are used in Flake checks.
  passthru = old.passthru // {
    tests = (old.tests or { }) // tests;
    static = import ./static args;

  };
  src = lib.cleanSource old.src;
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
  # postBuild =
  #
  #   let
  #     getDeps = lib.attrsets.foldlAttrs (
  #       acc: name: value:
  #       acc + "ln -s ${value} repositories/${name} \n"
  #     ) "" self.packages.${system}.deps.passthru;
  #   in
  #   ''
  #     mkdir repositories
  #     ${getDeps}
  #   '';
  postInstall =
    let
      script = pkgs.writeShellScriptBin "${old.pname}" ''
        python ${src}/launch.py --skip-prepare-environment "$@"
      '';
    in
    ''
      mkdir -p $out/bin
      cp -r ${script}/bin/* $out/bin/
    '';
  postFixup = ''
    wrapProgram $out/bin/${old.pname} \
      --set PATH ${
        lib.makeBinPath [
          venv
        ]
      }
  '';

})
