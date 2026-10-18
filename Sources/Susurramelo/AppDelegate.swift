import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let statusLine = NSMenuItem(title: "Idle", action: nil, keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(title: "Grant Accessibility Permission…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
    private let dictation = DictationController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        buildMenu()
        dictation.onStatusChange = { [weak self] in self?.render($0) }
        render(.idle)

        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        promptForAccessibilityIfNeeded()
        dictation.start()

        if KeychainStore.load() == nil { setAPIKey() }
    }

    private func buildMenu() {
        let menu = NSMenu()
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(NSMenuItem(title: "Hold Right Option to dictate", action: nil, keyEquivalent: ""))
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
    }
}
