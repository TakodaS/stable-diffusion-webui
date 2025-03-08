{
  lib,
  self,
  nixpkgs,
  package-name,
  ...
}:
let
  system = "x86_64-linux";
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
  config = self.nixosModules.options;
in
{
  ${package-name} =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      cfg = config.services.${package-name};
      inherit (pkgs) system;

      inherit (lib.options) mkOption;
      inherit (lib.modules) mkIf;
    in
    {
      options.services.${package-name} = {
        enable = mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable ${package-name}
          '';
        };

        venv = mkOption {
          type = lib.types.package;
          default = self.packages.${system}.venv;
          description = ''
            ${package-name} virtual environment package
          '';
        };

        static-root = mkOption {
          type = lib.types.package;
          default = self.packages.${system}.${package-name}.static;
          description = ''
            ${package-name} static root
          '';
        };
      };

      config = mkIf cfg.enable {
        systemd.services.${package-name} = {
          description = "${package-name} server";

          serviceConfig = rec {
            ExecStart = ''
              ${lib.getExe self.packages.${system}.${package-name}.static}
            '';
            Restart = "on-failure";

            DynamicUser = true;
            StateDirectory = "${package-name}";
            RuntimeDirectory = "${package-name}";
            RuntimeDirectoryMode = 775;
            PermissionsStartOnly = true;

            BindReadOnlyPaths = [
              "${
                config.environment.etc."ssl/certs/ca-certificates.crt".source
              }:/etc/ssl/certs/ca-certificates.crt"
              builtins.storeDir
              "-/etc/resolv.conf"
              "-/etc/nsswitch.conf"
              "-/etc/hosts"
              "-/etc/localtime"
              "${RuntimeDirectory}:${self.packages.${system}.deps}"
            ];
          };

          wantedBy = [ "multi-user.target" ];
        };
      };

    };

}
