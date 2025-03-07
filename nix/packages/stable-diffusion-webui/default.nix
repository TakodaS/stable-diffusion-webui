{
  package-name,
  lib,
  pkgs,
  system,
  self,
  ...
}:
let
  inherit (pkgs) stdenv stdenvNoCC;
  inherit (self.packages.${system}) venv;
  src = lib.cleanSource "${self}";
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

  testAttrs = {
    inherit
      # mypy
      # pytest
      nixos
      ;
  };
  tests = pkgs.srcOnly {
    name = "tests";
    stdenv = stdenvNoCC;
    srcs = builtins.attrValues testAttrs;
    sourceRoot = ".";
    passthru = testAttrs;
  };
in
stdenv.mkDerivation rec {
  name = "${package-name}-static";
  inherit src;

  dontConfigure = true;

  nativeBuildInputs = with pkgs; [
    venv
    makeWrapper
    git
  ];
  passthru = { inherit tests; };

  buildPhase =

    let
      getDeps = lib.attrsets.foldlAttrs (
        acc: name: value:
        acc + "ln -s ${value} repositories/${name} \n"
      ) "" self.packages.${system}.deps.passthru;
      dbg = builtins.trace "getDeps: ${getDeps}" getDeps;
    in
    ''
      mkdir repositories
      ${dbg}
    '';
  installPhase =
    let
      script = pkgs.writeShellScriptBin "${name}" ''
        python launch.py --skip-prepare-environment "$@"
      '';
    in
    ''
      # env DJANGO_STATIC_ROOT="$out" python manage.py collectstatic
      mkdir -p $out/bin
      cp -r ${script}/bin/* $out/bin/
    '';
  postFixup = ''
    wrapProgram $out/bin/${name} \
      --set PATH ${
        lib.makeBinPath (
          with pkgs;
          [
            venv
            git
          ]
        )
      }
  '';
}
