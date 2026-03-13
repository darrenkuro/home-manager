# Nix BTM stub — DISABLED
#
# This module was intended to group Nix system daemons (nix-daemon, darwin-store)
# under a friendly "Nix" icon in macOS Login Items via BTM app stubs.
#
# However, nix-darwin resets the LaunchDaemon plists on every activation,
# so any patching to point at our custom wrappers gets overwritten.
#
# The Nix daemon appears as generic "nix-daemon" in BTM Login Items.
# Keeping this file as a placeholder; remove if BTM grouping isn't needed.
{ ... }: {
  # No-op — plist patching cannot persist with nix-darwin
}
