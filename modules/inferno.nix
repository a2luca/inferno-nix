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

    rxChannels = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8;
      description = "Number of Dante receive (capture) channels.";
    };

    txChannels = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8;
      description = "Number of Dante transmit (playback) channels.";
    };

    package = lib.mkPackageOption pkgs "inferno" {};

    statimedPackage = lib.mkPackageOption pkgs "statime-inferno" {};
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
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
            virtual-system-clock-base = "tai"
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

            pcm.inferno {
              type inferno
              @args.NAME { type string }
              @args.DEVICE_ID { type string }
              @args.BIND_IP { type string }
              @args.SAMPLE_RATE { type string }
              @args.PROCESS_ID { type string }
              @args.ALT_PORT { type string }
              @args.RX_CHANNELS { type string }
              @args.TX_CHANNELS { type string }
              @args.CLOCK_PATH { type string }
              @args.RX_LATENCY_NS { type string }
              @args.TX_LATENCY_NS { type string }
              NAME $NAME
              DEVICE_ID $DEVICE_ID
              BIND_IP $BIND_IP
              SAMPLE_RATE $SAMPLE_RATE
              PROCESS_ID $PROCESS_ID
              ALT_PORT $ALT_PORT
              RX_CHANNELS $RX_CHANNELS
              TX_CHANNELS $TX_CHANNELS
              CLOCK_PATH $CLOCK_PATH
              RX_LATENCY_NS $RX_LATENCY_NS
              TX_LATENCY_NS $TX_LATENCY_NS
              hint {
                show on
                description "Inferno AoIP Dante virtual soundcard"
              }
            }
          '';
        };
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
    }

    (lib.mkIf config.services.pipewire.enable {
      # inferno blocks on ALSA init until PTP clock is available, so nodes
      # must not be auto-loaded at boot. Use inferno-start/inferno-stop at the venue.
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "inferno-start" ''
          pw-cli create-node adapter '{
            object.linger=1
            factory.name=api.alsa.pcm.source
            node.name=Inferno
            media.class=Audio/Source
            api.alsa.path="inferno:RX_CHANNELS=${toString cfg.rxChannels},TX_CHANNELS=${toString cfg.txChannels},BIND_IP=${cfg.interface}"
            session.suspend-timeout-seconds=0
            node.pause-on-idle=false
            node.suspend-on-idle=false
            node.always-process=true
            api.alsa.headroom=128
            api.alsa.pcm.card=999
          }'
          pw-cli create-node adapter '{
            object.linger=1
            factory.name=api.alsa.pcm.sink
            node.name=Inferno
            media.class=Audio/Sink
            api.alsa.path="inferno:RX_CHANNELS=${toString cfg.rxChannels},TX_CHANNELS=${toString cfg.txChannels},BIND_IP=${cfg.interface}"
            session.suspend-timeout-seconds=0
            node.pause-on-idle=false
            node.suspend-on-idle=false
            node.always-process=true
            api.alsa.headroom=128
            api.alsa.pcm.card=999
          }'
        '')
        (pkgs.writeShellScriptBin "inferno-stop" ''
          pw-cli list-objects \
            | awk '/id [0-9]+, type PipeWire:Interface:Node/{id=$2; sub(/,$/,"",id)} /node\.name = "Inferno"/{print id}' \
            | xargs -r -I{} pw-cli destroy {}
        '')
      ];

      systemd.user.services.pipewire.serviceConfig.SystemCallFilter = lib.mkForce "@default @aio @io-event @network @process @file-system @basic-io @signal @timer @clock";
    })
  ]);
}
