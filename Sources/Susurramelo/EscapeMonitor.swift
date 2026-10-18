import AppKit

/// Reports Esc presses anywhere. Global monitors cannot consume events,
/// so the focused app also receives the Esc.
final class EscapeMonitor {
    private static let escapeKeyCode: UInt16 = 53
    private var monitors: [Any] = []

    var onEscape: (() -> Void)?

    func start() {
        stop()
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] in self?.handle($0) }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
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
        guard event.keyCode == Self.escapeKeyCode, !event.isARepeat else { return }
        onEscape?()
    }
}
