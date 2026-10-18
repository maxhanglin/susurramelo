import AppKit

SelfTest.runIfRequested()
UsageReport.runIfRequested()
BatchTest.runIfRequested()
Snapshot.runIfRequested()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menu-bar only: no Dock icon or main window.
app.setActivationPolicy(.accessory)
app.run()
