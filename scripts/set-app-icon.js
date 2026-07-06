// Apply a custom Finder icon to a file/bundle via NSWorkspace (no deps beyond osascript).
// Usage: osascript -l JavaScript set-app-icon.js <targetPath> <icnsPath>
// This writes the same "custom icon" state as pasting into Finder's Get Info panel:
// an Icon\r resource + the kHasCustomIcon FinderInfo bit. Non-destructive — it does
// not touch the bundle's Info.plist or code signature.
function run(argv) {
  ObjC.import("Cocoa");
  var targetPath = argv[0];
  var icnsPath = argv[1];

  var fm = $.NSFileManager.defaultManager;
  if (!fm.fileExistsAtPath(targetPath)) {
    throw new Error("target does not exist: " + targetPath);
  }
  if (!fm.fileExistsAtPath(icnsPath)) {
    throw new Error("icns does not exist: " + icnsPath);
  }

  var img = $.NSImage.alloc.initByReferencingFile(icnsPath);
  if (!img || !img.isValid) {
    throw new Error("could not load a valid image from: " + icnsPath);
  }

  var ok = $.NSWorkspace.sharedWorkspace.setIconForFileOptions(img, targetPath, 0);
  if (!ok) {
    // Usually a permissions problem (e.g. a /Applications app under a non-sudo `re`).
    throw new Error("setIcon returned false for: " + targetPath);
  }
}
