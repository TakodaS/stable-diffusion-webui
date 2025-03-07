{
  lib,
  self,
  package-name,
  ...
}:
lib.flake.forAllSystems (system: self.packages.${system}.${package-name}.passthru)
