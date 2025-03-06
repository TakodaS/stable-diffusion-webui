{
  package-name,
  lib,
  pkgs,
  system,
  self,
  ...
}:
let
  inherit (pkgs) stdenv;
  inherit (self.packages.${system}) venv;

in
stdenv.mkDerivation {
  name = "${package-name}-static";
  inherit (pythonSet.${package-name}) src;

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [
    venv
  ];

  installPhase = ''
    # env DJANGO_STATIC_ROOT="$out" python manage.py collectstatic
  '';
}
