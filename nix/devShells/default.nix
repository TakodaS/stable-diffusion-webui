args@{
  lib,
  self,
  package-name,
  nixpkgs,
  ...
}:
lib.flake.forAllSystems (
  system:
  let
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    folders = lib.flake.getSubdirs ./.;
    folderAttrs = (
      name: {
        name = name;
        value = import ./${name} (
          args
          // {
            inherit pkgs system;
          }
        ); # You can replace this with any value
      }
    );
  in
  builtins.listToAttrs (map folderAttrs folders)
  // {
    default = self.devShells.${system}.${package-name};
  }
)
