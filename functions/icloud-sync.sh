INSTALL_TAG=(MAC)
REQUIRED_TOOLS=(swift)
_check_preamble || return 0

# Force-download a file (or every file under a directory) from iCloud,
# so it's materialized locally instead of evicted/"online-only".
sync-local() {
  swift -e '
    import Foundation
    let p = CommandLine.arguments[1]
    let u = URL(fileURLWithPath: p)
    var d: ObjCBool = false
    FileManager.default.fileExists(atPath: p, isDirectory: &d)
    if d.boolValue {
      if let e = FileManager.default.enumerator(at: u, includingPropertiesForKeys: nil) {
        for case let f as URL in e {
          try FileManager.default.startDownloadingUbiquitousItem(at: f)
        }
      }
    } else {
      try FileManager.default.startDownloadingUbiquitousItem(at: u)
    }
  ' "$1"
}

# Evict the local copy of an iCloud file (keep it cloud-only).
sync-cloud() {
  swift -e '
    import Foundation
    try FileManager.default.evictUbiquitousItem(at: URL(fileURLWithPath: CommandLine.arguments[1]))
  ' "$1"
}
