{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.services.inferno;
in {
  options.services.inferno = with lib; {
    enable = mkEnableOption "Inferno AoIP Dante-compatible virtual soundcard";

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open Dante/Inferno UDP ports in the firewall.";
    };

    interface = mkOption {
      type = types.str;
      example = "enp0s31f6";
      description = "Network interface for Statime PTP clock synchronisation.";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.inferno;
      defaultText = lib.literalExpression "pkgs.inferno";
      description = "The inferno-aoip package.";
    };

    statimedPackage = mkOption {
      type = types.package;
      default = pkgs.statime-inferno;
      defaultText = lib.literalExpression "pkgs.statime-inferno";
      description = "The statime-inferno PTP daemon package.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."statime-inferno/inferno-ptpv1.toml".text = ''
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

    systemd.user.services.pipewire.serviceConfig.SystemCallFilter = "@default @aio @io-event @network @process @file-system @basic-io @signal @timer @clock";

    sound.extraConfig = ''
      pcm_type.inferno {
        lib ${cfg.package}/lib/alsa-lib/libasound_module_pcm_inferno.so
      }
    '';

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
        AmbientCapabilities = ["CAP_NET_RAW" "CAP_SYS_TIME"];
        CapabilityBoundingSet = ["CAP_NET_RAW" "CAP_SYS_TIME"];
      };
    };

    networking.firewall.allowedUDPPorts = lib.mkIf cfg.openFirewall [4455 8700 4400 8800];
  };
}
