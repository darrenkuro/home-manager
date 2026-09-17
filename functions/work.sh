INSTALL_TAG=(MAC)
REQUIRED_TOOLS=()
_check_preamble || return 0

work() {
    pbcopy < /dev/null
    defaults write com.apple.finder AppleShowAllFiles -bool false
    killall Finder

    osascript -e 'tell application "Safari" to quit'
    osascript -e 'tell application "Brave Browser" to quit'

    while pgrep -x "Brave Browser" >/dev/null; do
        sleep 0.2
    done

    open -a "Brave Browser.app" --args --profile-directory="Profile 1"
}
