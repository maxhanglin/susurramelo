import AppKit
import AVFoundation
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let statusLine = NSMenuItem(title: "Idle", action: nil, keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(title: "Grant Accessibility Permission…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
    private let pasteLastItem = NSMenuItem(title: "Paste Last Transcript", action: #selector(pasteLast), keyEquivalent: "")
    private let lastPreviewItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let preferences = Preferences()
    lazy var history = HistoryController(preferences: preferences)
    private lazy var dictation = DictationController(preferences: preferences, history: history)
    private var pasteLastShortcut: GlobalShortcut?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        installEditMenu()
        buildMenu()
        dictation.onStatusChange = { [weak self] in self?.render($0) }
        render(.idle)

        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        promptForAccessibilityIfNeeded()
        dictation.start()
        pasteLastShortcut = GlobalShortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | controlKey)) { [weak self] in
            self?.dictation.pasteLast()
        }

        if KeychainStore.load() == nil { setAPIKey() }
    }

    /// Menu-bar apps have no main menu, so Cmd+V/C/X/A never reach text fields (e.g. the API key alert).
    /// A main menu with an Edit submenu routes those key equivalents; it stays hidden for an accessory app.
    private func installEditMenu() {
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = edit
        let main = NSMenu()
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    private func buildMenu() {
        let menu = NSMenu()
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(NSMenuItem(title: "Hold Right Option to dictate · double-tap for hands-free · Esc cancels", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        pasteLastItem.target = self
        pasteLastItem.keyEquivalent = "v"
        pasteLastItem.keyEquivalentModifierMask = [.command, .control]
        menu.addItem(pasteLastItem)
        lastPreviewItem.isEnabled = false
        menu.addItem(lastPreviewItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Set ElevenLabs API Key…", action: #selector(setAPIKey), keyEquivalent: "").target = self
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Susurramelo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.delegate = self
        statusItem.menu = menu
    }

    private func render(_ status: DictationController.Status) {
        let (symbol, text): (String, String) = switch status {
        case .idle: ("mic", "Idle")
        case .recording: ("mic.fill", "Listening…")
        case .handsFree: ("lock.fill", "Hands-free — press Right Option to finish, Esc to cancel")
        case .transcribing: ("ellipsis.circle", "Transcribing…")
        case let .error(message): ("exclamationmark.triangle", "Error: \(message)")
        }
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: text)
        statusLine.title = text
    }

    private func promptForAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @objc private func pasteLast() {
        // Let the menu close and focus return to the previous app before pasting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.dictation.pasteLast() }
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func setAPIKey() {
        let alert = NSAlert()
        alert.messageText = "ElevenLabs API Key"
        alert.informativeText = "Stored in your macOS Keychain. Create one at elevenlabs.io → Developers → API Keys."
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        if !KeychainStore.save(key) { render(.error("Could not save the API key to the Keychain")) }
        else { render(.idle) }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        accessibilityItem.isHidden = AXIsProcessTrusted()
        let last = history.history.last
        pasteLastItem.isEnabled = last != nil
        lastPreviewItem.title = last.map { "   “" + Self.preview($0.text) + "”" } ?? "   No dictations yet"
    }

    private static func preview(_ text: String) -> String {
        let line = text.replacingOccurrences(of: "\n", with: " ")
        return line.count > 48 ? String(line.prefix(48)) + "…" : line
    }
}
