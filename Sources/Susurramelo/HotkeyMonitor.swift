import AppKit

/// Watches a single modifier key (default: Right Option) globally and reports press/release.
/// Global monitoring of key events requires the Accessibility permission.
final class HotkeyMonitor {
    /// Right Option. Left Option is 58; Right Command is 54.
    static let rightOptionKeyCode: UInt16 = 61
    /// Device-specific flag for Right Option (`NX_DEVICERALTKEYMASK`), so Left Option does not mask a release.
    static let rightOptionDeviceMask: UInt = 0x40

    private let keyCode: UInt16
    private let deviceMask: UInt
    private var monitors: [Any] = []
    private var isDown = false

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    init(keyCode: UInt16 = HotkeyMonitor.rightOptionKeyCode, deviceMask: UInt = HotkeyMonitor.rightOptionDeviceMask) {
        self.keyCode = keyCode
        self.deviceMask = deviceMask
    }

    func start() {
        stop()
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] in self?.handle($0) }) {
            monitors.append(global)
        }
        // Global monitors do not see events sent to our own app, so watch locally too.
        if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handle(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    private func handle(_ event: NSEvent) {
        guard event.keyCode == keyCode else { return }
        let pressed = event.modifierFlags.rawValue & deviceMask != 0
        guard pressed != isDown else { return }
        isDown = pressed
        pressed ? onPress?() : onRelease?()
    }
}
