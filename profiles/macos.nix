# macOS profile catalogue.
#
# Keep all GUI application choices in one place.  The profile selected by the
# flake determines the casks, App Store apps, Dock, Finder start folder, and
# opt-in services.  This file intentionally contains no credentials or app
# preferences: those stay in the app-specific Home Manager modules.
{
    personal = {
        casks = [
            "alfred"
            "anki"
            "brave-browser"
            "claude"
            "dropbox"
            "font-carlito"
            "ghostty"
            "notion"
            "obsidian"
            "pearcleaner"
            "sf-symbols"
            "spotify"
            "steam"
            "visual-studio-code"
            "slack"
        ];

        masApps = {
            "CleanMyMac" = 1339170533;
            "Developer" = 640199958;
            "Final Cut Pro" = 424389933;
            "iA Writer" = 775737590;
            "Mirror Magnet" = 1563698880;
            "Numbers" = 361304891;
            "OmniFocus 3" = 1346203938;
            "Pages" = 361309726;
            "Trello" = 1278508951;
            "Xcode" = 497799835;
            "Yoink" = 457622435;
        };

        dockApps = [
            "/System/Applications/Mail.app"
            "/System/Applications/Calendar.app"
            "/System/Cryptexes/App/System/Applications/Safari.app"
            "/Applications/Brave Browser.app"
            "/Applications/Obsidian.app"
            "/Applications/Ghostty.app"
            "/Applications/Visual Studio Code.app"
            "/System/Applications/Utilities/Activity Monitor.app"
            "/System/Applications/System Settings.app"
        ];

        finderStartFolder = "Dropbox";
        enablePostgresql = true;
    };

    # A deliberately small work desktop.  It includes the configured terminal,
    # editor, browser, communication and knowledge apps, but excludes personal
    # media, study, gaming, cloud-sync and consumer App Store software.
    work = {
        casks = [
            "alfred"
            "brave-browser"
            "claude"
            "ghostty"
            "notion"
            "slack"
            "visual-studio-code"
        ];

        # No App Store apps are needed on the deliberately minimal work machine.
        masApps = { };

        dockApps = [
            "/Applications/Brave Browser.app"
            "/Applications/Notion.app"
            "/Applications/Slack.app"
            "/Applications/Ghostty.app"
            "/Applications/Visual Studio Code.app"
            "/System/Applications/Utilities/Activity Monitor.app"
            "/System/Applications/System Settings.app"
        ];

        finderStartFolder = "Documents/Work";
        enablePostgresql = false;
    };
}
