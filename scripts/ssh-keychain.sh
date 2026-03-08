# Unlock macOS Keychain in SSH sessions
# The Keychain is only auto-unlocked during GUI login, so tools like
# gh/claude that store credentials in the Keychain fail over SSH.
# Blocks shell access if unlock fails (wrong password = session closed).
if [ -n "$SSH_CONNECTION" ]; then
  if ! security unlock-keychain ~/Library/Keychains/login.keychain-db; then
    echo "Keychain unlock failed. Closing session."
    exit 1
  fi
fi
