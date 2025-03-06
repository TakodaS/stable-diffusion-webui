{
  package-name,
  lib,
  pkgs,
  system,
  self,
  ...
}:
let
  venv = self.packages.${system}.venv;
  package-name = venv.name;
in
lib.optionalAttrs pkgs.stdenv.isLinux
  # Expose Docker container in packages
  pkgs.dockerTools.buildLayeredImage
  {
    name = "${package-name}";
    contents = [ pkgs.cacert ];
    config = {
      Cmd = [
        "${venv}/bin/python"
      ];
      Env = [
        # "DJANGO_SETTINGS_MODULE=${settingsModules.prod}"
        # "DJANGO_STATIC_ROOT=${staticRoots.${system}}"
      ];
    };
  }
