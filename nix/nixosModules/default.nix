{
  lib,
  self,
  nixpkgs,
  package-name,
  ...
}:
with lib;
let
  system = "x86_64-linux";
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
  config = self.nixosModules.options;
in
{
  "${package-name}" =
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

        stateDir = mkOption {
          default = "/var/lib/${package-name}";
          type = types.str;
          description = "${package-name} data directory.";
        };
        repositoryRoot = mkOption {
          type = types.str;
          default = "${cfg.stateDir}/repositories";
          description = "Path to the git repositories.";
        };

      };
      config = mkIf cfg.enable {
        # users.users.${package-name} = {
        #   description = "Uptimed daemon user";
        #   home = cfg.static-root;
        #   group = package-name;
        #   isSystemUser = true;
        # };
        # users.groups.${package-name} = { };
        systemd.services.${package-name} = {
          description = "${package-name} server";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          path = [

            pkgs.gitAndTools.git
          ];
          preStart = ''
            mkdir -p ${cfg.stateDir}
            mkdir -p ${cfg.repositoryRoot}
            cp -r ${self.packages.${system}.${package-name}.static}/* ${cfg.stateDir}
          '';

          serviceConfig = rec {
            # Run the pre-start script with full permissions (the "!" prefix) so it
            # can create the data directory if necessary.
            # ExecStart =
            #   let
            #     script =
            #       pkgs.runCommand "${package-name}-start"
            #         {
            #           buildInputs = with pkgs; [
            #             cacert
            #             git
            #           ];
            #         }
            #         ''
            #           ${cfg.venv}/bin/python ${cfg.stateDir}/launch.py --skip-prepare-environment --skip-install
            #         '';
            #   in
            #   script;
            ExecStart = ''
              ${cfg.venv}/bin/python ${cfg.stateDir}/launch.py --skip-prepare-environment --skip-install
            '';
            Restart = "on-failure";
            # User = package-name;

            DynamicUser = true;
            StateDirectory = "${cfg.stateDir}";
            StateDirectoryMode = 775;
            RuntimeDirectory = "${cfg.stateDir}";
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
            ];
          };

        };
      };

    };

}
