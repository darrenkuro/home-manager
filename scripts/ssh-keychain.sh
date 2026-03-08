# Unlock macOS Keychain in SSH sessions
# The Keychain is only auto-unlocked during GUI login, so tools like
# gh/claude that store credentials in the Keychain fail over SSH.
if [ -n "$SSH_CONNECTION" ]; then
  _ensure_keychain() {
    if [ -z "$KEYCHAIN_UNLOCKED" ]; then
      security unlock-keychain ~/Library/Keychains/login.keychain-db && \
        export KEYCHAIN_UNLOCKED=true
    fi
  }
  gh() { _ensure_keychain; command gh "$@"; }
  claude() { _ensure_keychain; command claude "$@"; }
fi
