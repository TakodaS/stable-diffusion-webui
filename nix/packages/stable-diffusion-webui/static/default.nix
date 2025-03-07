{
  lib,
  pkgs,
  system,
  package-name,
  pythonSet,
  self,
  ...
}:
let
  venv = self.packages.${system}.venv;
in
pkgs.stdenv.mkDerivation rec {
  name = "${package-name}-static";
  inherit (pythonSet.${package-name}) src;

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [
    venv
    pkgs.makeWrapper
  ];

  installPhase =
    let
      script = pkgs.writeShellScriptBin "${name}" ''
        python ${src}/launch.py --skip-prepare-environment "$@"
      '';
    in
    ''
      mkdir -p $out/bin
      cp -r ${script}/bin/* $out/bin/
    '';
  postFixup = ''
    wrapProgram $out/bin/${name} \
      --set PATH ${
        lib.makeBinPath [
          venv
        ]
      }
  '';
}
