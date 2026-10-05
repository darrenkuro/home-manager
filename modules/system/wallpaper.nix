# modules/system/wallpaper.nix — declarative desktop picture (macOS).
#
# HM's programs.desktoppr writes the settings to desktoppr's defaults domain
# and runs `desktoppr manage` on every activation, as the user.
#
# desktoppr 0.5 bug: `manage` re-applies the fill color to the *current*
# picture (a `try!`) before switching, so it crashes when that file has been
# deleted. Bootstrap by setting the picture directly in that case.
{ config, lib, ... }: let
    cfg = config.programs.desktoppr;
    exe = lib.getExe cfg.package;
in
{
    programs.desktoppr = {
        enable = true;
        settings = {
            picture = ../../configs/wallpapers/one-piece-wallpaper-1.jpg;
            scale = "fill";
        };
    };

    home.activation.desktopprBootstrap = lib.hm.dag.entryBetween [ "desktoppr" ] [
        "setDarwinDefaults"
    ] ''
        _cur=$("${exe}" 0 2>/dev/null || true)
        if [ ! -e "$_cur" ]; then
            run "${exe}" all "${cfg.settings.picture}"
        fi
    '';
}
