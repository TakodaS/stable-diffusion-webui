{
  pkgs,
  lib,
  self,
  system,
  ...
}:
let
  venv = self.packages.${system}.venv;
in
pkgs.mkShell {
  packages = [
    venv
    pkgs.uv
  ];
  env = {
    UV_NO_SYNC = "1";
    UV_PYTHON = "${venv}/bin/python";
    UV_PYTHON_DOWNLOADS = "never";
  };
  shellHook =
    let
      getModels = lib.attrsets.foldlAttrs (
        acc: name: value:
        acc + "mkdir -p ./repositories/${name} && cp -r ${value}/* ./repositories/${name} \n"
      ) "" self.packages.${system}.deps;
    in
    ''
      unset PYTHONPATH
      export REPO_ROOT=$(git rev-parse --show-toplevel)
    '';
}
