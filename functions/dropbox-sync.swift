// dbx-sync — make Dropbox files online-only or available offline from the command line.
// Built and invoked by functions/dropbox-sync.sh (dbx-status / dbx-cloud / dbx-local).
//
//   dbx-sync status            <path>...   one line per path:  <state><TAB><path>
//   dbx-sync online  [-w] [-t secs] <path>...   make online-only (Finder: "Make online-only")
//   dbx-sync offline [-w] [-t secs] <path>...   download again and keep (Finder: "Download now")
//
// WHAT IT RELIES ON
// The Dropbox desktop app (the File Provider build, macOS 12.3+) runs a small Mach-port server
// for its own Finder extension, registered with launchd as
//   G7HH3F8CAK.com.getdropbox.dropbox.sync.<uid>.finder_server      (G7HH3F8CAK = Dropbox's team id)
// The Finder extension asks it for badge status and context-menu items, and sends back the menu
// action the user clicked. This tool speaks that same protocol, so it can do exactly what the
// Finder menu can do and nothing more. Wire format: NSPortMessage over that port, msgid = request
// type, components = [int64 request id, NSKeyedArchiver-encoded dictionary]; the reply comes back
// on our receive port with the same request id, acknowledgements carry an empty payload.
//   0x00 hello        {version}                      handshake; version = Dropbox.app CFBundleVersion
//   0x65 status       {url}                          -> {status: Int}, codes below
//   0x66 context_menu {pathlist}                     -> {menu: String} "title~…~verb-instance|…",
//                                                      submenus nested, percent-encoded
//   0x68 action       {action, host_int, pathlist}   perform a menu verb; ack only
// Verbs: "dod_evict" = Make online-only, "dod_recall" = Make available offline; the instance after
// the dash names the signed-in account and must be echoed back as host_int.
// Status codes (what the Finder badge shows): 0 none (not managed by Dropbox), 1 offline
// (downloaded and kept), 2 syncing, 3 error, 4 ignored, 5 online-only (0-byte placeholder),
// 6 mixed (folder), 8 local (downloaded, Dropbox may reclaim it), 99 locked.
//
// Restoring a file: the Dropbox app seen here (Nov 2026, File Provider build) never lists
// "dod_recall" in that menu, not even for a placeholder: it still lists "Make online-only" and
// leaves the download to Finder's generic File Provider item. So `offline` sends dod_recall when
// Dropbox happens to offer it and otherwise simply opens the file and reads it to the end, which
// makes File Provider materialize it (an all-or-nothing download; Dropbox then reports it as
// "offline" = downloaded and kept). That path is plain POSIX I/O, so it survives protocol changes.
//
// Debugging protocol drift: DBX_SYNC_DEBUG=1 prints the raw menu string Dropbox returns.
//
// None of this is documented by Dropbox. It was reverse-engineered by github.com/Zamua/onlineonly
// (MIT), whose wire format this follows; the Objective-C there is ~1,400 lines with a JSON/MCP
// layer, this keeps the ~150 that matter. A Dropbox update could change the protocol. The failure
// mode is safe: "Dropbox app not reachable" or "not offered", never a wrong action, because an
// action is only sent when Dropbox itself lists that verb in the menu for that exact path.
//
// Why not something official: there is nothing. NSFileProviderManager.evictItem only works from
// the provider's own app (anyone else gets NSFileProviderErrorDomain -2014), `fileproviderctl` on
// macOS 26 has no evict command, the Dropbox web API knows nothing about local placeholders, and
// hm's `sync-cloud` (FileManager.evictUbiquitousItem) is iCloud only.
//
// Swift notes: NSMachBootstrapServer is hidden from Swift, so the named port is looked up through
// the Mach bootstrap API (bootstrap_look_up) and wrapped in NSMachPort. PortMessage / NSMachPort
// are deprecated but remain the only Foundation API for named Mach ports, and the Finder
// extension uses them on the other end.
//
// LIMITS
// * Needs the Dropbox app running and signed in (exit 69 otherwise).
// * Folders apply recursively, exactly like the Finder menu (the read fallback walks the tree).
// * Dropbox refuses to evict a file it is still uploading: "not offered" while status is syncing.
// * An online-only placeholder reads as an empty file: never evict what a running program needs.
// * -w polls status once a second until the target state is reached, up to -t seconds (600).
//   For `offline` the download itself is synchronous, so -w only matters when dod_recall was used.
//
// EXIT: 0 done; 1 some path failed, was not offered, or timed out; 2 usage; 69 Dropbox unreachable.

import Foundation

@_silgen_name("bootstrap_look_up")
func bootstrap_look_up(
  _ bp: mach_port_t, _ name: UnsafePointer<CChar>, _ sp: UnsafeMutablePointer<mach_port_t>
) -> kern_return_t

func lookUpPort(_ name: String) -> Port? {
  var bootstrap: mach_port_t = 0
  guard task_get_special_port(mach_task_self_, TASK_BOOTSTRAP_PORT, &bootstrap) == KERN_SUCCESS
  else { return nil }
  var port: mach_port_t = 0
  guard bootstrap_look_up(bootstrap, name, &port) == KERN_SUCCESS, port != 0 else { return nil }
  return NSMachPort(machPort: port)
}

enum Status: Int {
  case none = 0
  case offline = 1
  case syncing = 2
  case error = 3
  case ignored = 4
  case onlineOnly = 5
  case mixed = 6
  case local = 8
  case locked = 99

  var name: String {
    switch self {
    case .none: return "none"
    case .offline: return "offline"
    case .syncing: return "syncing"
    case .error: return "error"
    case .ignored: return "ignored"
    case .onlineOnly: return "online-only"
    case .mixed: return "mixed"
    case .local: return "local"
    case .locked: return "locked"
    }
  }

  static func name(_ code: Int?) -> String {
    guard let code = code else { return "unreachable" }
    return Status(rawValue: code)?.name ?? "unknown(\(code))"
  }
}

final class Dropbox: NSObject, NSMachPortDelegate {
  private let remote: Port
  private let local = NSMachPort()
  private var nextId: Int64 = 1
  private var waitingFor: Int64 = 0
  private var reply: Data?
  private let timeout: TimeInterval = 10

  init?(uid: uid_t) {
    let name = "G7HH3F8CAK.com.getdropbox.dropbox.sync.\(uid).finder_server"
    guard let port = lookUpPort(name) else { return nil }
    remote = port
    super.init()
    local.setDelegate(self)
    RunLoop.current.add(local, forMode: .default)
    let version =
      Bundle(path: "/Applications/Dropbox.app")?.infoDictionary?["CFBundleVersion"] as? String
      ?? ""
    if send(0x00, ["version": version]) == nil { return nil }
  }

  func handle(_ message: PortMessage) {
    guard let parts = message.components, parts.count >= 2,
      let idData = parts[0] as? Data, idData.count == 8, let payload = parts[1] as? Data
    else { return }
    if idData.withUnsafeBytes({ $0.load(as: Int64.self) }) == waitingFor { reply = payload }
  }

  /// Reply payload (empty for acknowledgements), nil when Dropbox did not answer in time.
  private func send(_ type: UInt32, _ payload: [String: Any]) -> Data? {
    let archiver = NSKeyedArchiver(requiringSecureCoding: false)
    for (key, value) in payload { archiver.encode(value, forKey: key) }
    archiver.finishEncoding()
    var requestId = nextId
    nextId += 1
    waitingFor = requestId
    reply = nil
    let message = PortMessage(
      send: remote, receive: local,
      components: [Data(bytes: &requestId, count: 8), archiver.encodedData])
    message.msgid = type
    guard message.send(before: Date(timeIntervalSinceNow: timeout)) else { return nil }
    let deadline = Date(timeIntervalSinceNow: timeout)
    while reply == nil && deadline.timeIntervalSinceNow > 0 {
      RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
    }
    return reply
  }

  private func unarchive(_ data: Data?) -> NSKeyedUnarchiver? {
    guard let data = data, !data.isEmpty,
      let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data)
    else { return nil }
    unarchiver.requiresSecureCoding = false
    return unarchiver
  }

  /// Dropbox's status code for a path; nil when it did not answer.
  func status(_ path: String) -> Int? {
    guard let u = unarchive(send(0x65, ["url": URL(fileURLWithPath: path)])),
      u.containsValue(forKey: "status")
    else { return nil }
    return Int(u.decodeInt32(forKey: "status"))
  }

  /// Verbs the Finder menu offers for a path, mapped to the account instance to send back.
  func verbs(_ path: String) -> [String: String] {
    guard let u = unarchive(send(0x66, ["pathlist": [URL(fileURLWithPath: path)]])),
      let menu = u.decodeObject(forKey: "menu") as? String
    else { return [:] }
    if ProcessInfo.processInfo.environment["DBX_SYNC_DEBUG"] != nil {
      FileHandle.standardError.write("menu: \(menu)\n".data(using: .utf8)!)
    }
    var found: [String: String] = [:]
    func parse(_ text: String) {
      for item in text.components(separatedBy: "|") {
        let parts = item.components(separatedBy: "~")
        guard parts.count >= 3 else { continue }
        if parts.contains("submenu") {
          if let inner = parts.last?.removingPercentEncoding { parse(inner) }
          continue
        }
        let action = parts[2]
        guard let dash = action.range(of: "-", options: .backwards),
          dash.lowerBound != action.startIndex, dash.upperBound != action.endIndex
        else { continue }
        found[String(action[..<dash.lowerBound])] = String(action[dash.upperBound...])
      }
    }
    parse(menu)
    return found
  }

  /// Send a menu verb for a path. False when Dropbox does not offer it (or did not answer).
  func perform(_ verb: String, on path: String) -> Bool {
    guard let instance = verbs(path)[verb] else { return false }
    let payload: [String: Any] = [
      "action": verb, "host_int": instance, "pathlist": [URL(fileURLWithPath: path)],
    ]
    return send(0x68, payload) != nil
  }
}

/// Download a placeholder (or every file under a folder) by reading it to the end: File Provider
/// materializes a dataless file on first open. False if any file could not be opened or read.
func materialize(_ path: String) -> Bool {
  let fm = FileManager.default
  var isDir: ObjCBool = false
  guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return false }
  var files = [path]
  if isDir.boolValue {
    files = []
    let keys: [URLResourceKey] = [.isRegularFileKey]
    guard let walk = fm.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: keys)
    else { return false }
    for case let url as URL in walk
    where (try? url.resourceValues(forKeys: Set(keys)))?.isRegularFile == true {
      files.append(url.path)
    }
  }
  for file in files {
    guard let handle = FileHandle(forReadingAtPath: file) else { return false }
    defer { handle.closeFile() }
    while let chunk = try? handle.read(upToCount: 4 << 20), !chunk.isEmpty {}
  }
  return true
}

// MARK: - CLI

func usage() -> Never {
  FileHandle.standardError.write(
    """
    usage: dbx-sync status <path>...
           dbx-sync online  [-w] [-t secs] <path>...   make online-only
           dbx-sync offline [-w] [-t secs] <path>...   make available offline

    """.data(using: .utf8)!)
  exit(2)
}

var arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first, ["status", "online", "offline"].contains(command) else {
  usage()
}
arguments.removeFirst()

var wait = false
var waitLimit: TimeInterval = 600
var paths: [String] = []
while let arg = arguments.first {
  arguments.removeFirst()
  switch arg {
  case "-w": wait = true
  case "-t":
    guard let value = arguments.first, let secs = TimeInterval(value) else { usage() }
    arguments.removeFirst()
    waitLimit = secs
  case "--":
    paths += arguments
    arguments = []
  default: paths.append(arg)
  }
}
guard !paths.isEmpty else { usage() }

guard let dropbox = Dropbox(uid: getuid()) else {
  FileHandle.standardError.write(
    "dbx-sync: Dropbox app not reachable (is it running and signed in?)\n".data(using: .utf8)!)
  exit(69)
}

var failed = false
for raw in paths {
  let path = URL(fileURLWithPath: raw).standardizedFileURL.path
  let code = dropbox.status(path)

  if command == "status" {
    print("\(Status.name(code))\t\(path)")
    continue
  }

  // online: only the placeholder state counts. offline: "offline" (kept) or "local" (downloaded).
  let (verb, targets, label) =
    command == "online"
    ? ("dod_evict", [Status.onlineOnly.rawValue], "online-only")
    : ("dod_recall", [Status.offline.rawValue, Status.local.rawValue], "offline")

  guard let code = code, code != Status.none.rawValue else {
    print("not in Dropbox: \(path)")
    failed = true
    continue
  }
  if targets.contains(code) {
    print("already \(label): \(path)")
    continue
  }
  var requested = dropbox.perform(verb, on: path)
  if !requested && command == "offline" {
    // No recall verb in the menu (the normal case, see header): download by reading.
    requested = materialize(path)
    if !requested {
      print("could not read for download: \(path)")
      failed = true
      continue
    }
  } else if !requested {
    print("not offered (\(Status.name(code))): \(path)")
    failed = true
    continue
  }
  guard wait || command == "offline" else {
    print("requested \(label): \(path)")
    continue
  }
  // After a synchronous download Dropbox still reports "syncing" for a few seconds while it
  // reconciles, so `offline` always waits a little for the badge to settle.
  let deadline = Date(timeIntervalSinceNow: wait ? waitLimit : 30)
  var current = dropbox.status(path) ?? code
  while !targets.contains(current) && deadline.timeIntervalSinceNow > 0 {
    Thread.sleep(forTimeInterval: 1)
    current = dropbox.status(path) ?? current
  }
  if targets.contains(current) {
    print("\(label): \(path)")
  } else {
    print("timed out, still \(Status.name(current)): \(path)")
    failed = true
  }
}
exit(failed ? 1 : 0)
