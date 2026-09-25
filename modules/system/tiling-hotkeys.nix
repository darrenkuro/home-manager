# modules/system/tiling-hotkeys.nix — declarative window-tiling shortcuts (macOS).
#
# System Settings stores every keyboard shortcut in com.apple.symbolichotkeys
# under one AppleSymbolicHotKeys dict, keyed by undocumented numeric ids.
# Writing the whole dict would clobber unrelated shortcuts, so each id is
# merged individually with `defaults write -dict-add`, and only when its
# current value differs (checked via plutil against a one-shot export).
#
# Sequoia tiling ids (discovered empirically by diffing the plist):
#   237 Fill, 240/241/242/243 tile left/right/top/bottom half
#   (candidates for later: 238 Center, 239 Return to Previous, 244-247 Quarters)
# parameters = [ ascii keycode modifiers ]; 786432 = ⌃⌥, and arrow-key combos
# carry the implicit fn bit (8388608) on top: 9175040.
{ lib, ... }: let
    hotkeys = [
        { id = 237; desc = "Fill"; params = [ 92 42 786432 ]; }
        { id = 240; desc = "Tile Left Half"; params = [ 65535 123 9175040 ]; }
        { id = 241; desc = "Tile Right Half"; params = [ 65535 124 9175040 ]; }
        { id = 242; desc = "Tile Top Half"; params = [ 65535 126 9175040 ]; }
        { id = 243; desc = "Tile Bottom Half"; params = [ 65535 125 9175040 ]; }
    ];
    mkJson = params: "[" + lib.concatMapStringsSep "," toString params + "]";
    mkXml = params:
    "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array>" +
    lib.concatMapStrings ( p: "<integer>${toString p}</integer>" ) params +
    "</array><key>type</key><string>standard</string></dict></dict>";
    checkAndSet = hk: ''
        _cur=$(/usr/bin/plutil -extract "AppleSymbolicHotKeys.${toString
    hk.id}.value.parameters" json -o - "$_shk" 2>/dev/null || true)
        _en=$(/usr/bin/plutil -extract "AppleSymbolicHotKeys.${toString
    hk.id}.enabled" raw -o - "$_shk" 2>/dev/null || true)
        if [[ "$_cur" != "${mkJson hk.params}" || ( "$_en" != "1" && "$_en" != "true" ) ]]; then
          echo "tiling-hotkeys: setting ${hk.desc}"
          /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
            -dict-add "${toString hk.id}" '${mkXml hk.params}'
          _changed=1
        fi
    '';
in
{
    home.activation.tilingHotkeys = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _changed=0
        _shk=$(mktemp)
        /usr/bin/defaults export com.apple.symbolichotkeys - > "$_shk" 2>/dev/null || true
        ${lib.concatMapStrings checkAndSet hotkeys}
        rm -f "$_shk"
        if [[ "$_changed" == 1 ]]; then
          /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null \
            || echo "tiling-hotkeys: log out/in to apply"
        fi
    '';
}
