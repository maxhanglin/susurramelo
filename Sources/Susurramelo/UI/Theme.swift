import AppKit
import SwiftUI

/// Design tokens for the main window: warm off-white "paper" surfaces with near-black ink,
/// thin borders instead of shadows, and the brand gradient from the app icon as accent.
enum Theme {
    // MARK: Colors (light / dark)

    static let canvas = dynamic(light: 0xF5F4F0, dark: 0x202020) // window + sidebar
    static let panel = dynamic(light: 0xFCFCFB, dark: 0x1A1A1A) // content panel
    static let fill = dynamic(light: 0xEEEBE3, dark: 0x30302F) // hover / selected / secondary
    static let card = dynamic(light: 0xFFFFFF, dark: 0x111111)
    static let border = dynamic(light: 0xEEEBE3, dark: 0x30302F)
    static let ink = dynamic(light: 0x1A1A1A, dark: 0xE9E8E1)
    static let inkSecondary = dynamic(light: 0x4D4A42, dark: 0xDEDDD7)
    static let inkTertiary = dynamic(light: 0x71716E, dark: 0x9D9C98)
    static let iconMuted = dynamic(light: 0xB3B2AD, dark: 0x6F6E6A)
    static let success = Color(hex: 0x4FBF78)
    static let warning = Color(hex: 0xEFA249)
    static let danger = Color(hex: 0xE5484D)

    /// Soft tint of the brand violet used for badges and highlights.
    static let brandTint = dynamic(light: 0xEEE8FF, dark: 0x2E2747)
    static let brandInk = dynamic(light: 0x5B45C9, dark: 0xC2B5FF)
    static let brandGradient = LinearGradient(
        colors: [Color(hex: 0x3B3DC7), Color(hex: 0x8545DB), Color(hex: 0xED6B9E)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: Metrics

    static let sidebarWidth: CGFloat = 236
    static let titlebarHeight: CGFloat = 52
    static let panelGap: CGFloat = 8
    static let cardRadius: CGFloat = 16
    static let rowRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8
    static let navRadius: CGFloat = 6

    // MARK: Type

    static let pageTitle = Font.system(size: 24, weight: .semibold)
    static let sectionTitle = Font.system(size: 20, weight: .semibold)
    static let body = Font.system(size: 15)
    static let bodyMedium = Font.system(size: 15, weight: .medium)
    static let caption = Font.system(size: 13)
    static let label = Font.system(size: 12, weight: .semibold)
    /// Serif display numbers for stats.
    static let statNumber = Font.system(size: 28, design: .serif)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        })
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(nsColor: NSColor(hex: hex))
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Shared components

/// Uppercase, tracked section label ("TODAY", "DICTATION").
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(Theme.label)
            .tracking(0.9)
            .foregroundStyle(Theme.inkTertiary)
    }
}

/// Small rounded badge, e.g. "Upcoming".
struct Badge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(Theme.brandTint, in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(Theme.brandInk)
    }
}

/// Keyboard key drawn as a keycap.
struct Keycap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 7)
            .frame(minWidth: 24, minHeight: 22)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 0, y: 1)
            .foregroundStyle(Theme.ink)
    }
}

/// Bordered container with the canvas fill used for grouped content.
struct CardContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).strokeBorder(Theme.border, lineWidth: 1))
    }
}

/// Plain icon button that darkens on hover.
struct HoverIconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 26, height: 26)
                .foregroundStyle(hovering ? Theme.ink : Theme.iconMuted)
                .background(hovering ? Theme.fill : .clear, in: RoundedRectangle(cornerRadius: Theme.navRadius))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
    }
}

/// Text button styles: primary ink fill, secondary sand fill.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger }
    var kind: Kind = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.bodyMedium)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(background, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
            .foregroundStyle(foreground)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }

    private var background: Color {
        switch kind {
        case .primary: Theme.ink
        case .secondary: Theme.fill
        case .danger: Theme.danger.opacity(0.12)
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: Theme.panel
        case .secondary: Theme.ink
        case .danger: Theme.danger
        }
    }
}
