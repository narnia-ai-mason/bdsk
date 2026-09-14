import AppKit
import Carbon.HIToolbox
import QuartzCore
import SwiftUI

/// Keys the number-review HUD claims while it is visible.
/// Matched on the hotkey tap thread so Tab/Return never reach the original field
/// and the HUD never has to become key.
enum NumberReviewKeys {
    static func intercepts(keyCode: Int, flags: NSEvent.ModifierFlags) -> Bool {
        let mods = flags.intersection(.deviceIndependentFlagsMask)
        let withoutShift = mods.subtracting([.shift, .capsLock, .numericPad, .function, .help])
        guard withoutShift.isEmpty else { return false }
        switch keyCode {
        case kVK_Escape, kVK_Return, kVK_ANSI_KeypadEnter,
             kVK_UpArrow, kVK_DownArrow, kVK_Tab,
             kVK_LeftArrow, kVK_RightArrow:
            return true
        default:
            return false
        }
    }

    static func allowsRepeat(_ keyCode: Int) -> Bool {
        switch keyCode {
        case kVK_UpArrow, kVK_DownArrow, kVK_LeftArrow, kVK_RightArrow:
            return true
        default:
            return false
        }
    }
}

@MainActor
@Observable
final class NumberReviewModel {
    var baseText: String
    var choices: [NumberOrthography.Choice]
    var focusedIndex: Int = 0

    init(baseText: String, choices: [NumberOrthography.Choice]) {
        self.baseText = baseText
        self.choices = choices
        self.focusedIndex = 0
    }

    var preview: String {
        NumberOrthography.apply(choices, to: baseText)
    }

    func toggle(id: Int) {
        guard let index = choices.firstIndex(where: { $0.id == id }) else { return }
        choices[index].prefersNative.toggle()
        focusedIndex = index
    }

    func moveFocus(_ delta: Int) {
        guard !choices.isEmpty else { return }
        let count = choices.count
        focusedIndex = (focusedIndex + delta % count + count) % count
    }

    func setFocusedPrefersNative(_ native: Bool) {
        guard choices.indices.contains(focusedIndex) else { return }
        choices[focusedIndex].prefersNative = native
    }
}

@MainActor
final class NumberReviewHUDController {
    private var panel: NumberReviewHUDPanel?
    private var hostingView: NumberReviewHostingView?
    private var screenObserver: NSObjectProtocol?
    private var keyMonitor: Any?
    private var hideGeneration = 0
    private var model: NumberReviewModel?

    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?

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

    func show(baseText: String, choices: [NumberOrthography.Choice]) {
        hideGeneration += 1
        let model = NumberReviewModel(baseText: baseText, choices: choices)
        self.model = model
        let view = NumberReviewHUDView(
            model: model,
            onCommit: { [weak self] in self?.onCommit?() },
            onCancel: { [weak self] in self?.onCancel?() }
        )

        if let hostingView, let panel {
            hostingView.rootView = view
            layout(panel: panel, hosting: hostingView)
            present(panel)
            return
        }

        let panel = self.panel ?? NumberReviewHUDPanel()
        panel.keyHandler = { [weak self] event in
            self?.handleKey(event) ?? false
        }
        panel.focusMover = { [weak self] delta in
            self?.model?.moveFocus(delta)
        }
        self.panel = panel
        let hosting = NumberReviewHostingView(rootView: view)
        hosting.sizingOptions = .intrinsicContentSize
        hosting.safeAreaRegions = []
        panel.contentView = hosting
        hostingView = hosting
        layout(panel: panel, hosting: hosting)
        present(panel)
    }

    func currentChoices() -> [NumberOrthography.Choice]? {
        model?.choices
    }

    func hide() {
        removeKeyMonitor()
        model = nil
        guard let panel, panel.isVisible else { return }
        hideGeneration += 1
        let generation = hideGeneration
        if panel.isKeyWindow {
            panel.resignKey()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
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

    /// Handle a review key already identified by `NumberReviewKeys`.
    @discardableResult
    func handleKey(keyCode: Int, flags: NSEvent.ModifierFlags) -> Bool {
        guard let model else { return false }

        switch keyCode {
        case kVK_Escape:
            onCancel?()
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            onCommit?()
            return true
        case kVK_UpArrow:
            model.moveFocus(-1)
            return true
        case kVK_DownArrow:
            model.moveFocus(1)
            return true
        case kVK_Tab:
            model.moveFocus(flags.contains(.shift) ? -1 : 1)
            return true
        case kVK_LeftArrow:
            model.setFocusedPrefersNative(false)
            return true
        case kVK_RightArrow:
            model.setFocusedPrefersNative(true)
            return true
        default:
            return false
        }
    }

    private func present(_ panel: NumberReviewHUDPanel) {
        panel.alphaValue = 0
        // Do not become key. The original field must keep focus so insert/paste
        // land where recording started. Review keys are swallowed by the session tap.
        panel.orderFrontRegardless()
        installKeyMonitor()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1)
            panel.animator().alphaValue = 1
        }
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.model != nil else { return event }
            return self.handleKey(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    /// Returns `true` when the event was consumed by the review HUD.
    @discardableResult
    private func handleKey(_ event: NSEvent) -> Bool {
        handleKey(
            keyCode: Int(event.keyCode),
            flags: event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        )
    }

    private func repositionIfVisible() {
        guard let panel, let hostingView, panel.isVisible else { return }
        layout(panel: panel, hosting: hostingView)
    }

    private func layout(panel: NSPanel, hosting: NSHostingView<NumberReviewHUDView>) {
        hosting.layoutSubtreeIfNeeded()
        var size = hosting.fittingSize
        if size.width < 8 || size.height < 8 {
            size = NSSize(width: 320, height: 140)
        }
        size.width = min(max(size.width, 280), 520)
        guard let screen = preferredScreen() else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.minY + 20
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func preferredScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
}

private final class NumberReviewHostingView: NSHostingView<NumberReviewHUDView> {
    override var acceptsFirstResponder: Bool { false }
    override var canBecomeKeyView: Bool { false }
}

private final class NumberReviewHUDPanel: NSPanel {
    var keyHandler: ((NSEvent) -> Bool)?
    var focusMover: ((Int) -> Void)?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 140),
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
        ignoresMouseEvents = false
        sharingType = .readOnly
    }

    /// Block AppKit’s Tab key-view loop. Row movement is handled by `focusMover` / key monitor.
    override func selectNextKeyView(_ sender: Any?) {
        focusMover?(1)
    }

    override func selectPreviousKeyView(_ sender: Any?) {
        focusMover?(-1)
    }

    override func keyDown(with event: NSEvent) {
        if keyHandler?(event) == true { return }
        // Swallow rather than letting Tab recurse into the default key-view loop.
        if Int(event.keyCode) == kVK_Tab { return }
        super.keyDown(with: event)
    }
}

private struct NumberReviewHUDView: View {
    @Bindable var model: NumberReviewModel
    let onCommit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("숫자 표기")
                .font(BdskTheme.captionFont())
                .foregroundStyle(BdskTheme.pearlMuted)

            Text(model.preview)
                .font(BdskTheme.bodyFont())
                .foregroundStyle(BdskTheme.pearl)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(model.choices.enumerated()), id: \.element.id) { index, choice in
                    choiceRow(choice, focused: index == model.focusedIndex)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                Text("↑↓/Tab 이동 · ←→ 선택 · ESC 취소")
                    .font(BdskTheme.captionFont())
                    .foregroundStyle(BdskTheme.pearlMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                BdskGhostButton(title: "취소", action: onCancel)
                    .focusable(false)
                BdskPrimaryButton(title: "넣기", action: onCommit)
                    .focusable(false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: 480, alignment: .leading)
        .background(BdskTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: BdskTheme.shadow, radius: 12, x: 0, y: 6)
        .padding(20)
        .preferredColorScheme(.dark)
        .focusable(false)
    }

    private func choiceRow(_ choice: NumberOrthography.Choice, focused: Bool) -> some View {
        HStack(spacing: 8) {
            BdskChoiceChip(
                title: choice.digitForm,
                selected: !choice.prefersNative
            ) {
                if choice.prefersNative { model.toggle(id: choice.id) }
                else { model.focusedIndex = model.choices.firstIndex(where: { $0.id == choice.id }) ?? 0 }
            }
            .focusable(false)
            Text("⇄")
                .font(BdskTheme.captionFont())
                .foregroundStyle(BdskTheme.pearlMuted)
            BdskChoiceChip(
                title: choice.nativeForm,
                selected: choice.prefersNative
            ) {
                if !choice.prefersNative { model.toggle(id: choice.id) }
                else { model.focusedIndex = model.choices.firstIndex(where: { $0.id == choice.id }) ?? 0 }
            }
            .focusable(false)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(focused ? BdskTheme.surfaceRaised : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(focused ? BdskTheme.lavender : Color.clear, lineWidth: 1.5)
        )
    }
}
