{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.services.inferno;
in {
  options.services.inferno = {
    enable = lib.mkEnableOption "Inferno AoIP Dante-compatible virtual soundcard";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open Dante/Inferno UDP ports in the firewall.";
    };

    interface = lib.mkOption {
      type = lib.types.nonEmptyStr;
      example = "enp0s31f6";
      description = "Network interface for Statime PTP clock synchronisation.";
    };

    package = lib.mkPackageOption pkgs "inferno" {};

    statimedPackage = lib.mkPackageOption pkgs "statime-inferno" {};
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.interface != "";
        message = "services.inferno.interface must be set to a network interface name.";
      }
    ];

    environment = {
      systemPackages = [cfg.package];
      etc = {
        "statime-inferno/inferno-ptpv1.toml".text = ''
          loglevel = "warn"
          sdo-id = 0
          domain = 0
          priority1 = 251
          virtual-system-clock = true
          virtual-system-clock-base = "monotonic_raw"
          usrvclock-export = true

          [[port]]
          interface = "${cfg.interface}"
          network-mode = "ipv4"
          hardware-clock = "auto"
          protocol-version = "PTPv1"
        '';
        "asound.conf".text = ''
          pcm_type.inferno {
            lib ${cfg.package}/lib/alsa-lib/libasound_module_pcm_inferno.so
          }
        '';
      };
    };

    systemd.user.services.pipewire = lib.mkIf config.services.pipewire.enable {
      serviceConfig.SystemCallFilter = lib.mkForce "@default @aio @io-event @network @process @file-system @basic-io @signal @timer @clock";
    };

    systemd.services.statime-inferno = {
      description = "Statime PTP daemon for Inferno AoIP";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.statimedPackage}/bin/statime -c /etc/statime-inferno/inferno-ptpv1.toml";
        Restart = "on-failure";
        RestartSec = 5;
        AmbientCapabilities = ["CAP_NET_RAW" "CAP_NET_BIND_SERVICE" "CAP_SYS_TIME"];
        CapabilityBoundingSet = ["CAP_NET_RAW" "CAP_NET_BIND_SERVICE" "CAP_SYS_TIME"];
      };
    };

    networking.firewall.allowedUDPPorts = lib.optionals cfg.openFirewall [4455 8700 4400 8800];
  };
}
