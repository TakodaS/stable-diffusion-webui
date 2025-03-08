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

  nativeBuildInputs = with pkgs; [
    venv
    makeWrapper
    cacert
  ];
  buildInputs = with pkgs; [ git ];

  installPhase =
    let
      repoDir = "$out/src";
      getDeps = lib.attrsets.foldlAttrs (
        acc: name: value:
        acc + "ln -s ${value} ${repoDir}/repositories/${name} \n"
      ) "" self.packages.${system}.deps.passthru;
      dbg = builtins.trace "dbg: ${getDeps}" getDeps;
      script = pkgs.writeShellScriptBin "${name}" ''
          echo FOOBAR
          ls
        ${venv}/bin/python launch.py --skip-prepare-environment "$@"
      '';
    in
    ''
      mkdir -p ${repoDir}/repositories
      cp -r $src/* $out/src/
      ${dbg}
      cd ${repoDir} && ${lib.getExe script}

    '';
  # postFixup = ''
  #   wrapProgram $out/bin/${name} \
  #     --set PATH ${
  #       lib.makeBinPath [
  #         venv
  #         pkgs.coreutils
  #       ]
  #     }
  # '';
}
