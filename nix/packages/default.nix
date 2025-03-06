args@{ lib, pkgs, ... }:
let
  dirContents = builtins.readDir ./.; # Reads the current directory
  folders = builtins.attrNames (lib.attrsets.filterAttrs (_: type: type == "directory") dirContents);
  folderAttrs = (
    name: {
      name = name;
      value = import ./${name} args; # You can replace this with any value
    }
  );
in
builtins.listToAttrs (map folderAttrs folders)
