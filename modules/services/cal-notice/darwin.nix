# ⚠ TEMPORARY (added 2026-11-02) — delete this directory and its import in the
# root darwin.nix once the cal.com station booking moves to one link per slot.
#
# cal.com notice — keeps the 42 workstation booking link's same-day starts on
# the 09/11/13/15 grid by switching its Minimum notice between 0 and 60 min at
# 09:00–14:00 on weekdays (`cal-bookings notice`, 42admin skill). Fires at hh:59;
# `--wait` lands the change at hh:00:00. Work profile only (the always-on iMac);
# needs the cal.com API key in this Mac's Keychain (service cal.com, account api-key).
{ homeDir, ... }: let
    weekdays = [ 1 2 3 4 5 ];
    hours = [ 8 9 10 11 12 13 ]; # hh:59 → switch at 09:00 … 14:00
in
{
    launchd.user.agents.cal-notice = {
        serviceConfig = {
            Label = "com.darrenkuro.cal-notice";
            ProgramArguments = [
                "${homeDir}/.config/claude/skills/42admin/scripts/cal-bookings"
                "notice"
                "--wait"
            ];
            EnvironmentVariables = { PATH = "${homeDir}/.nix-profile/bin:/usr/bin:/bin"; };
            RunAtLoad = true;
            StartCalendarInterval = builtins.concatMap
            ( w: map ( h: { Weekday = w; Hour = h; Minute = 59; } ) hours ) weekdays;
            StandardOutPath = "${homeDir}/Library/Logs/cal-notice.log";
            StandardErrorPath = "${homeDir}/Library/Logs/cal-notice.log";
        };
    };
}
