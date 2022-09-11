flake: { config, lib, pkgs, ... }:

let
  inherit (builtins) toJSON removeAttrs;
  inherit (lib) filterAttrs types mkEnableOption mkOption;
  inherit (lib.trivial) pipe;

  inherit (flake.packages.${pkgs.stdenv.hostPlatform.system}) foundryvtt;

  cfg = config.services.foundryvtt;
  dataDir = "/var/lib/foundryvtt";
  configFile = pkgs.writeText "options.json"
    (toJSON (pipe cfg [
      (lst: removeAttrs lst [ "enable" "package" ])
      (filterAttrs (attr: value: value != null))
    ]));
in
{
  options = {
    services.foundryvtt = {
      enable = mkEnableOption ''
        Foundry Virtual Tabletop: A standalone application for online tabletop role-playing games.
      '';

      awsConfig = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          A path to an AWS configuration file. This file is used to configure AWs connectivity for
          S3 assets and backups.
        '';
      };

      # dataPath = mkOption {
      #   type = types.path;
      #   default = dataDir;
      #   description = ''
      #     The path where Foundry keeps its config, data, and logs.
      #   '';
      # };

      hostname = mkOption {
        type = types.str;
        default = config.networking.hostname;
        description = ''
          A custom hostname to use in place of the host machine’s public IP address when displaying
          the address of the game session. This allows for reverse proxies or DNS servers to modify
          the public address.
        '';
      };

      port = mkOption {
        type = types.int;
        default = 30000;
        description = ''
          The port that Foundry bind to listen for connections.
        '';
      };

      language = mkOption {
        type = types.str;
        default = "en.core";
        description = ''
          The language module used by Foundry.
        '';
      };

      world = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          The default world to launch.
        '';
      };

      minifyStaticFiles = mkOption {
        type = types.bool;
        default = false;
        description = ''
          If true, Foundry will serve minified JavaScript and CSS. Enabling this option reduces
          network traffic.
        '';
      };

      proxyPort = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = ''
          The port on which the reverse proxy server is listening for connections. Foundry uses this
          to show the correct port in invitation links.
        '';
      };

      proxySSL = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Indicates that Foundry is running behind a reverse proxy that uses SSL. If true, Foundry
          will use “https” in invitation links and enable A/V functionality, which requires the
          server to be using SSL.
        '';
      };

      routePrefix = mkOption {
        type = types.str;
        default = "";
        description = ''
          A path that will be appended to the FQDN of the server.
        '';
      };

      sslCert = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          A path to a SSL certificate that will be used by Foundry to serve over SSL.
        '';
      };

      sslKey = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          A path to a SSL key file that will be used by Foundry to serve over SSL.
        '';
      };

      upnp = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Indicates whether UPnP should be used to set up uport forwarding.
        '';
      };

      # Disabled because Foundry logs the contents of options.json, which will leak the server
      # credentials to the system log.
      # turnConfigs = mkOption {
      #   default = null;
      #   description = "Custom relay server configurations";
      #   type = nullOr (listOf (submodule {
      #     options = {
      #       urls = mkOption {
      #         type = listOf str;
      #         default = [];
      #         description = "Addresses of the TURN servers";
      #       };

      #       username = mkOption {
      #         type = str;
      #         default = "";
      #         description = "The username to use for the TURN server";
      #       };

      #       credential = mkOption {
      #         type = str;
      #         default = "";
      #         description = ''
      #           The password to use for the TURN server. NOTE: Do not specify the credential
      #           directly here, or it will end up in the Nix store.
      #         '';
      #       };
      #     };
      #   }));
      # };

      package = mkOption {
        type = types.package;
        default = foundryvtt;
        description = ''
          The Foundry package to use with the service.
        '';
      };
    };
 };

  config = lib.mkIf cfg.enable {
    users.users.foundryvtt = {
      description = "Foundry VTT daemon user";
      isSystemUser = true;
      group = "foundryvtt";
    };

    users.groups.foundryvtt = {};

    systemd.services.foundryvtt = {
      description = "Foundry Virtual Tabletop";
      documentation = [ "https://foundryvtt.com/kb/" ];

      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = "foundryvtt";
        Group = "foundryvtt";
        Restart = "on-failure";
        ExecStart = "${lib.getBin cfg.package}/bin/foundryvtt --headless --noupdate --dataPath=\"${dataDir}\"";
        StateDirectory = "foundryvtt";
        StateDirectoryMode = "0750";

        # Hardening
        CapabilityBoundingSet = [ "AF_NETLINK" "AF_INET" "AF_INET6" ];
        DeviceAllow = [ "/dev/stdin r" ];
        DevicePolicy = "strict";
        IPAddressAllow = "localhost";
        LockPersonality = true;
        # MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        ReadOnlyPaths = [ "/" ];
        RemoveIPC = true;
        RestrictAddressFamilies = [ "AF_NETLINK" "AF_INET" "AF_INET6" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" "@pkey" ];
        UMask = "0027";
      };

      preStart = ''
        installedConfigFile="${dataDir}/Config/options.json"
        install -d -m750 ${dataDir}/Config
        rm -f "$installedConfigFile" && install -m640 ${configFile} "$installedConfigFile"
      '';
    };
  };
}
