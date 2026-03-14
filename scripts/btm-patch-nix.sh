#!/bin/bash
# Patch Nix daemon plists with AssociatedBundleIdentifiers for BTM grouping.
# Run after darwin-rebuild since nix-darwin doesn't support this key natively.
#
# This script is idempotent - it checks if plists are already patched and only
# makes changes if needed.

set -euo pipefail

# Get real user info (not root when running via sudo)
real_user="${SUDO_USER:-$(whoami)}"
real_home=$(eval echo "~$real_user")

BUNDLE_ID="com.local.nix.stub"
STUBS_DIR="$real_home/.local/share/app-stubs"
NIX_APP="$STUBS_DIR/Nix.app"
CODESIGN_ID="Apple Development: odon5ht@gmail.com (497TM5HK44)"
ACTIVATE_PLIST="/Library/LaunchDaemons/org.nixos.activate-system.plist"

# Plists that need AssociatedBundleIdentifiers
PLISTS=(
  "/Library/LaunchDaemons/org.nixos.nix-daemon.plist"
  "/Library/LaunchDaemons/org.nixos.darwin-store.plist"
)

echo "BTM: checking Nix daemon plists..."

# Helper: Check if plist has our bundle ID
is_patched() {
  local plist=$1
  /usr/libexec/PlistBuddy -c "Print :AssociatedBundleIdentifiers:0" "$plist" 2>/dev/null | grep -q "$BUNDLE_ID"
}

# Helper: Check if ProgramArguments points to our wrapper
uses_wrapper() {
  local plist=$1
  /usr/libexec/PlistBuddy -c "Print :ProgramArguments:0" "$plist" 2>/dev/null | grep -q "$NIX_APP"
}

# Patch AssociatedBundleIdentifiers for standard plists
for plist in "${PLISTS[@]}" "$ACTIVATE_PLIST"; do
  if [[ -f "$plist" ]]; then
    if ! is_patched "$plist"; then
      /usr/libexec/PlistBuddy \
        -c "Add :AssociatedBundleIdentifiers array" \
        -c "Add :AssociatedBundleIdentifiers:0 string $BUNDLE_ID" \
        "$plist" 2>/dev/null && echo "  patched AssociatedBundleIdentifiers: $(basename "$plist")"
    else
      echo "  already patched: $(basename "$plist")"
    fi
  fi
done

# Special handling for activate-system: create wrapper if needed
if [[ -f "$ACTIVATE_PLIST" ]] && ! uses_wrapper "$ACTIVATE_PLIST"; then
  echo "  patching activate-system wrapper..."

  # Extract the activate-system-start path from the plist
  # Could be in ProgramArguments:0 (direct) or ProgramArguments:2 (via /bin/sh)
  activate_path=""
  for idx in 0 1 2; do
    cmd=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:$idx" "$ACTIVATE_PLIST" 2>/dev/null || true)
    if [[ "$cmd" == *"activate-system"* ]]; then
      # Extract store path, handling both direct paths and shell commands
      activate_path=$(echo "$cmd" | grep -o '/nix/store/[^[:space:]"]*activate-system[^[:space:]"]*' | head -1)
      break
    fi
  done

  if [[ -z "$activate_path" ]]; then
    echo "  error: could not find activate-system path in plist" >&2
    exit 1
  fi

  wrapper="$NIX_APP/Contents/MacOS/NixActivateSystem"

  # Create wrapper script
  cat > "$wrapper" << 'WRAPPER_EOF'
#!/bin/bash
set -euo pipefail
/bin/wait4path /nix/store &>/dev/null
WRAPPER_EOF
  echo "exec $activate_path" >> "$wrapper"
  chmod +x "$wrapper"
  chown "$real_user:staff" "$wrapper"

  # Update plist to use wrapper
  /usr/libexec/PlistBuddy \
    -c "Delete :ProgramArguments" \
    -c "Add :ProgramArguments array" \
    -c "Add :ProgramArguments:0 string $wrapper" \
    "$ACTIVATE_PLIST" && echo "  updated ProgramArguments: $(basename "$ACTIVATE_PLIST")"

  # Refresh LaunchServices registration
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$NIX_APP" 2>/dev/null
else
  echo "  activate-system already uses wrapper"
fi

# Sign all app stubs with real Apple Development identity
# This must run as the real user to access keychain
echo "BTM: signing app stubs..."
if [[ -d "$STUBS_DIR" ]]; then
  for app in "$STUBS_DIR"/*.app; do
    [[ -d "$app" ]] || continue
    app_name=$(basename "$app")
    if sudo -u "$real_user" codesign -fs "$CODESIGN_ID" --deep "$app"; then
      echo "  signed: $app_name"
    else
      echo "  error: codesign failed for $app_name (exit code: $?)" >&2
    fi
  done
else
  echo "  no stubs directory found: $STUBS_DIR"
fi

echo "BTM: done"
