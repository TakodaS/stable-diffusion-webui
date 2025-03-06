args@{ lib, pkgs, ... }:
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
