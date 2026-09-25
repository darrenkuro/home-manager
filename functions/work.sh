INSTALL_TAG=(MAC)
REQUIRED_TOOLS=()
_check_preamble || return 0

work() {
    # Clear clipboard
    pbcopy < /dev/null

    # Hide Finder dotfiles
    defaults write com.apple.finder AppleShowAllFiles -bool false
    killall Finder

    # Close personal browsers
    osascript -e 'tell application "Safari" to quit'
    osascript -e 'tell application "Brave Browser" to quit'
    osascript -e 'tell application "QuickTime Player" to quit'

    # Wait until both have actually exited
    while pgrep -x "Safari" > /dev/null || pgrep -x "Brave Browser" > /dev/null; do
        sleep 0.2
    done

    # Launch Brave Work profile
    open -a "Brave Browser.app" --args --profile-directory="Profile 1"
}
