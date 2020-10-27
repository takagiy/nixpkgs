{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.xserver.windowManager.wmderland;
in

{
  options.services.xserver.windowManager.wmderland = {
    enable = mkEnableOption "wmderland";

    extraPackages = mkOption {
      type = with types; listOf package;
      default = with pkgs; [ rofi ];
      example = literalExample ''
        with pkgs; [
          rofi
          rxvt-unicode
        ]
      '';
      description = ''
        Extra packages to be installed system wide.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.xserver.windowManager.session = singleton {
      name = "wmderland";
      start = ''
        ${pkgs.wmderland}/bin/wmderland &
        waitPID=$!
      '';
    };
    environment.systemPackages = [
      pkgs.wmderland pkgs.wmderlandc
    ] ++ cfg.extraPackages;
  };
}
