# Locations archive — copies the 42 Tirana login/logout log from the infra.42.school
# Locations API into the "Workstation Events" sheet (`locations archive`, 42admin skill),
# because the API keeps only a few days of a shared multi-campus stream. Each run replays
# what the API still serves and appends unseen events, so runs can be missed safely;
# every 3 h plus at login keeps far inside the retention. Its Runs tab records how far back
# the API still serves. Work profile only (the always-on iMac); needs the campus token in
# this Mac's Keychain (service infra-locations, account token) and the Sheets SA key at
# ~/.config/google/gsheets-sa.json.
{ homeDir, ... }: {
    launchd.user.agents.locations-archive = {
        serviceConfig = {
            Label = "com.darrenkuro.locations-archive";
            ProgramArguments = [
                "${homeDir}/.config/claude/skills/42admin/scripts/locations"
                "archive"
                "--sheet"
                "1EJ5v65BzKh-P1KipXdWdBGHbIEcIT-nL-7TN6QTwtVw"
            ];
            EnvironmentVariables = { PATH = "${homeDir}/.nix-profile/bin:/usr/bin:/bin"; };
            RunAtLoad = true;
            StartInterval = 10800;
            StandardOutPath = "${homeDir}/Library/Logs/locations-archive.log";
            StandardErrorPath = "${homeDir}/Library/Logs/locations-archive.log";
        };
    };
}
