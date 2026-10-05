# modules/system/wallpaper.nix — declarative desktop picture (macOS).
#
# HM's programs.desktoppr writes the settings to desktoppr's defaults domain
# and runs `desktoppr manage` on every activation, as the user.
{ ... }: {
    programs.desktoppr = {
        enable = true;
        settings = {
            picture = ../../configs/wallpapers/one-piece-wallpaper-1.jpg;
            scale = "fill";
        };
    };
}
