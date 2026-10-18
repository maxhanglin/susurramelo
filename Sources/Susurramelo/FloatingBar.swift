import AppKit
import SusurrameloCore
import SwiftUI

/// What the floating bar shows. Updated on the main thread.
final class FloatingBarModel: ObservableObject {
    enum State: Equatable {
        case recording
        case handsFree
        case transcribing
        case error(String)
    }

    static let barCount = 14

    @Published var state: State = .recording
    @Published private(set) var levels = LevelHistory(capacity: FloatingBarModel.barCount)

    func push(level: Float) {
        levels.append(level)
    }

    func resetLevels() {
        levels = LevelHistory(capacity: Self.barCount)
    }
}

/// A non-activating, click-through pill at the bottom center of the screen under the cursor.
final class FloatingBar {
    private let model = FloatingBarModel()
    private let panel: NSPanel
    private var hideWork: DispatchWorkItem?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: BarView(model: model))
    }

    func show(_ state: FloatingBarModel.State) {
        hideWork?.cancel()
        if !panel.isVisible { model.resetLevels() }
        model.state = state
        guard !panel.isVisible else { return }
        position()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; panel.animator().alphaValue = 1 }
    }

    func push(level: Float) {
        model.push(level: level)
    }

    /// Shows an error briefly, then hides.
    func flashError(_ message: String) {
        show(.error(message))
        hide(after: 3)
    }

    func hide(after delay: TimeInterval = 0) {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let panel = self?.panel else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.2; panel.animator().alphaValue = 0 }) {
                panel.orderOut(nil)
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 20))
    }
}

// MARK: - View

private let accent = LinearGradient(
    colors: [
        Color(red: 0.36, green: 0.42, blue: 0.98),
        Color(red: 0.66, green: 0.40, blue: 0.96),
        Color(red: 0.98, green: 0.52, blue: 0.70),
    ],
    startPoint: .leading,
    endPoint: .trailing
)

private struct BarView: View {
    @ObservedObject var model: FloatingBarModel

    var body: some View {
        HStack(spacing: 10) {
            leading
            content
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(
            Capsule()
                .fill(.black.opacity(0.82))
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.2), value: model.state)
    }

    @ViewBuilder private var leading: some View {
        switch model.state {
        case .recording:
            PulsingDot()
        case .handsFree:
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accent)
        case .transcribing:
            EmptyView()
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.yellow)
        }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .recording, .handsFree:
            Waveform(levels: model.levels.values)
        case .transcribing:
            ThinkingDots()
        case let .error(message):
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 240)
        }
    }
}

/// Bars mirrored around the center: the newest level sits in the middle and older levels flow outward.
private struct Waveform: View {
    let levels: [Float]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(mirrored.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(accent)
                    .frame(width: 3, height: 4 + CGFloat(level) * 20)
            }
        }
        .frame(height: 24)
        .animation(.easeOut(duration: 0.08), value: levels)
    }

    private var mirrored: [Float] {
        let half = levels.suffix(levels.count / 2)
        return Array(half) + half.reversed()
    }
}

private struct PulsingDot: View {
    @State private var on = false

    var body: some View {
        Circle()
            .fill(Color(red: 1, green: 0.35, blue: 0.4))
            .frame(width: 8, height: 8)
            .opacity(on ? 1 : 0.35)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever()) { on = true }
            }
    }
}

private struct ThinkingDots: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(accent)
                        .frame(width: 6, height: 6)
                        .offset(y: -4 * CGFloat(max(0, sin((t * 2 * .pi * 1.2) - Double(i) * 0.6))))
                }
            }
            .frame(width: 60, height: 24)
        }
    }
}
