{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.myNixOS.monitor-detector;

  bash-logger-pkg = inputs.bash-logger.packages.${pkgs.system}.default;
  monitor-detector = import ./package.nix {
    inherit pkgs;
    bash-logger = bash-logger-pkg;
  };
in
{
  options.myNixOS.monitor-detector = {
    enable = lib.mkEnableOption "Enable monitor-detector DRM hook";

    rules = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            event = lib.mkOption {
              type = lib.types.enum [
                "attached"
                "detached"
              ];
              description = "Event type triggering the rule.";
            };

            pattern = lib.mkOption {
              type = lib.types.str;
              description = "EDID pattern to match.";
            };

            callback = lib.mkOption {
              type = lib.types.str;
              description = "Command or script to execute.";
            };
          };
        }
      );
      default = [ ];
      description = "List of monitor-detector match rules.";
    };
  };

  config = lib.mkIf cfg.enable {

    # Write rules for script as JSON
    environment.etc."monitor-detector/rules.json".text = builtins.toJSON cfg.rules;

    # Bind monitor-detector script to DRM subsystem
    services.udev.extraRules = ''
      SUBSYSTEM=="drm", ACTION=="change", ENV{HOTPLUG}=="1", RUN+="${lib.getExe monitor-detector}"
    '';
  };
}
