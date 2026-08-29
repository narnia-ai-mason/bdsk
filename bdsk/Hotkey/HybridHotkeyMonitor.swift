import AppKit
import Foundation

@MainActor
protocol HybridHotkeyHandling: AnyObject {
    func hotkeyPressed()
    func hotkeyReleased()
}

final class HybridHotkeyMonitor: @unchecked Sendable {
    weak var handler: HybridHotkeyHandling?
    private var binding: HotkeyBinding
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private var thread: Thread?
    private var pressed = false

    init(binding: HotkeyBinding) {
        self.binding = binding
    }

    func update(binding: HotkeyBinding) {
        self.binding = binding
        pressed = false
    }

    @discardableResult
    func start() -> Bool {
        stop()
        let mask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HybridHotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            },
            userInfo: context
        ) else {
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        let thread = Thread { [weak self] in
            guard let self, let source = self.runLoopSource else { return }
            let loop = CFRunLoopGetCurrent()
            self.runLoop = loop
            CFRunLoopAddSource(loop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        thread.name = "bdsk.hotkey"
        thread.start()
        self.thread = thread
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopSourceInvalidate(source)
        }
        if let runLoop {
            CFRunLoopStop(runLoop)
        }
        tap = nil
        runLoopSource = nil
        runLoop = nil
        thread = nil
        pressed = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput, let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return Unmanaged.passUnretained(event)
        }
        guard binding.matches(event: event) else {
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 1 {
            return nil
        }
        let down = binding.isKeyDown(event: event)
        if down {
            guard !pressed else { return nil }
            pressed = true
            DispatchQueue.main.async { [weak self] in
                self?.handler?.hotkeyPressed()
            }
        } else {
            guard pressed else { return nil }
            pressed = false
            DispatchQueue.main.async { [weak self] in
                self?.handler?.hotkeyReleased()
            }
        }
        return nil
    }

    deinit {
        stop()
    }
}
