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

    # Hide Finder dotfiles and quit Finder gently (killall would abort
    # in-flight copies/moves). Left closed — this also blanks the Desktop; the
    # setting applies whenever Finder is next opened.
    defaults write com.apple.finder AppleShowAllFiles -bool false
    osascript -e 'tell application "Finder" to quit'

    # Close personal browsers
    osascript -e 'tell application "Safari" to quit'
    osascript -e 'tell application "Brave Browser" to quit'
    osascript -e 'tell application "QuickTime Player" to quit'

    # Wait until both have actually exited
    _work_wait_quit Safari "Brave Browser" || return 1

    # Launch Brave Work profile
    open -a "Brave Browser.app" --args --profile-directory="Profile 1"
}
