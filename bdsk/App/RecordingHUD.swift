import AppKit
import QuartzCore
import SwiftUI

@MainActor
@Observable
final class ListeningLevel {
    var amplitude: Double = 0
}

@MainActor
final class RecordingHUDController {
    private let level = ListeningLevel()
    private var panel: RecordingHUDPanel?
    private var hostingView: NSHostingView<RecordingHUDView>?
    private var screenObserver: NSObjectProtocol?
    private var hideGeneration = 0

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let controller = self
            Task { @MainActor in
                controller?.repositionIfVisible()
            }
        }
    }

    func update(phase: DictationPhase, enabled: Bool) {
        if enabled, let label = phase.listeningHUDLabel {
            show(label: label, live: phase != .finishing)
        } else {
            hide()
        }
    }

    func setAmplitude(_ value: Double) {
        guard panel?.isVisible == true else { return }
        level.amplitude = min(1, max(0, value))
    }

    private func show(label: String, live: Bool) {
        hideGeneration += 1
        let view = RecordingHUDView(label: label, live: live, level: level)

        if let hostingView, let panel, panel.isVisible {
            hostingView.rootView = view
            layout(panel: panel, hosting: hostingView)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1)
                panel.animator().alphaValue = 1
            }
            return
        }

        let panel = self.panel ?? RecordingHUDPanel()
        self.panel = panel
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = .intrinsicContentSize
        hosting.safeAreaRegions = []
        panel.contentView = hosting
        hostingView = hosting
        layout(panel: panel, hosting: hosting)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.38
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1)
            panel.animator().alphaValue = 1
        }
    }

    private func hide() {
        guard let panel, panel.isVisible else { return }
        level.amplitude = 0
        hideGeneration += 1
        let generation = hideGeneration
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1)
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in
                guard generation == self.hideGeneration else { return }
                panel.orderOut(nil)
                panel.alphaValue = 1
            }
        }
    }

    private func repositionIfVisible() {
        guard let panel, let hostingView, panel.isVisible else { return }
        layout(panel: panel, hosting: hostingView)
    }

    private func layout(panel: NSPanel, hosting: NSHostingView<RecordingHUDView>) {
        hosting.layoutSubtreeIfNeeded()
        var size = hosting.fittingSize
        if size.width < 8 || size.height < 8 {
            size = NSSize(width: 168, height: 72)
        }
        guard let screen = Self.preferredScreen() else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.minY + 20
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private static func preferredScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
}

private final class RecordingHUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 168, height: 72),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .transient, .ignoresCycle]
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        animationBehavior = .none
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        sharingType = .readOnly
    }
}

private struct RecordingHUDView: View {
    let label: String
    let live: Bool
    @Bindable var level: ListeningLevel

    var body: some View {
        HStack(spacing: 10) {
            glassPebble
            Text(label)
                .font(BdskTheme.labelFont())
                .foregroundStyle(BdskTheme.pearl)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .padding(.vertical, 6)
        .background(BdskTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: BdskTheme.shadow, radius: 12, x: 0, y: 6)
        .padding(20)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var glassPebble: some View {
        let energy = live ? level.amplitude : 1
        return ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(BdskTheme.lavender.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(BdskTheme.cursorGlow.opacity(0.05 + 0.22 * energy))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            ListeningCursor(live: live, amplitude: energy)
        }
        .frame(width: 32, height: 32)
    }
}

private struct ListeningCursor: View {
    let live: Bool
    let amplitude: Double

    var body: some View {
        let energy = live ? amplitude : 1
        let core = live ? 0.7 + 0.3 * energy : 1
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            BdskTheme.cursorGlow.opacity(0.28 + 0.52 * energy),
                            BdskTheme.cursorGlow.opacity(0.1 + 0.2 * energy),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 12 + 6 * energy
                    )
                )
                .frame(width: 28, height: 28)
            Capsule()
                .fill(BdskTheme.cursorGlow.opacity(0.4 + 0.5 * energy))
                .frame(width: 8 + 4 * energy, height: 18 + 3 * energy)
                .blur(radius: 4 + 3 * energy)
            Capsule()
                .fill(BdskTheme.cursorGlow.opacity(core))
                .frame(width: 3, height: 14)
        }
    }
}
