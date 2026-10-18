import Carbon.HIToolbox
import Foundation

/// A system-wide shortcut registered with Carbon's hot key API. The key combination is consumed,
/// so the focused app does not receive it, and no Accessibility permission is needed.
final class GlobalShortcut {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var eventHandlerInstalled = false

    private var ref: EventHotKeyRef?
    private let id: UInt32

    /// `modifiers` uses Carbon masks (`cmdKey`, `controlKey`, `optionKey`, `shiftKey`).
    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        GlobalShortcut.installEventHandlerIfNeeded()
        id = GlobalShortcut.nextID
        GlobalShortcut.nextID += 1
        let hotKeyID = EventHotKeyID(signature: OSType(0x5355_5352), id: id) // "SUSR"
        guard RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref) == noErr else {
            return nil
        }
        GlobalShortcut.handlers[id] = action
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        GlobalShortcut.handlers[id] = nil
    }

    private static func installEventHandlerIfNeeded() {
        guard !eventHandlerInstalled else { return }
        eventHandlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let id = hotKeyID.id
            DispatchQueue.main.async { GlobalShortcut.handlers[id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
