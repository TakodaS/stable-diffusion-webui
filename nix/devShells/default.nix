args@{
  lib,
  pkgs,
  self,
  system,
  package-name,
  ...
}:
let
  folders = lib.flake.getSubdirs ./.;
  folderAttrs = (
    name: {
      name = name;
      value = import ./${name} args; # You can replace this with any value
    }
  );
in
builtins.listToAttrs (map folderAttrs folders)
// {
  default = self.packages.${system}.${package-name};
}
