INSTALL_TAG=(MAC)
REQUIRED_TOOLS=()
_check_preamble || return 0

# _work_wait_quit <app>... — wait up to 10s for the apps to exit. A cancelled
# quit dialog (unsaved work, active download) would otherwise hang forever.
_work_wait_quit() {
    local deadline=$((SECONDS + 10)) app
    for app in "$@"; do
        while pgrep -x "$app" > /dev/null; do
            if ((SECONDS >= deadline)); then
                echo "work: $app didn't quit (cancelled?)" >&2
                return 1
            fi
            sleep 0.2
        done
    done
}

work() {
    # Clear clipboard
    pbcopy < /dev/null

    # Hide Finder dotfiles — quit Finder gently (killall would abort in-flight
    # copies/moves), then relaunch it so the setting takes effect. The relaunch
    # can race LaunchServices still deregistering the old process (open fails
    # with -600, procNotFound), so retry briefly.
    defaults write com.apple.finder AppleShowAllFiles -bool false
    osascript -e 'tell application "Finder" to quit'
    if _work_wait_quit Finder; then
        local i
        for i in 1 2 3 4 5; do
            open -a Finder 2> /dev/null && break
            sleep 0.5
        done
    fi

    # Close personal browsers
    osascript -e 'tell application "Safari" to quit'
    osascript -e 'tell application "Brave Browser" to quit'
    osascript -e 'tell application "QuickTime Player" to quit'

    # Wait until both have actually exited
    _work_wait_quit Safari "Brave Browser" || return 1

    # Launch Brave Work profile
    open -a "Brave Browser.app" --args --profile-directory="Profile 1"
}
