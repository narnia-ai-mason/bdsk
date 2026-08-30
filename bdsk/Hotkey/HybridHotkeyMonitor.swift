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
    private let lock = NSLock()
    private var running = false
    private var threadExited: DispatchSemaphore?

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
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }
        let exited = DispatchSemaphore(value: 0)
        lock.lock()
        self.tap = tap
        runLoopSource = source
        running = true
        threadExited = exited
        lock.unlock()

        let thread = Thread { [weak self] in
            defer { exited.signal() }
            self?.runHotkeyLoop(tap: tap, source: source)
        }
        thread.name = "bdsk.hotkey"
        thread.start()
        lock.lock()
        self.thread = thread
        lock.unlock()
        return true
    }

    func stop() {
        lock.lock()
        running = false
        let loop = runLoop
        let exited = threadExited
        let existingThread = thread
        lock.unlock()

        if let loop {
            CFRunLoopStop(loop)
        }
        if let existingThread, existingThread !== Thread.current {
            _ = exited?.wait(timeout: .now() + 2)
        }

        // The hotkey thread may still be inside SLEventTapEnable if we
        // invalidate the port first. Tear the port down only after it exits.
        lock.lock()
        let tap = self.tap
        let source = runLoopSource
        self.tap = nil
        runLoopSource = nil
        runLoop = nil
        thread = nil
        threadExited = nil
        pressed = false
        lock.unlock()

        if let tap, CFMachPortIsValid(tap) {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopSourceInvalidate(source)
        }
    }

    private func runHotkeyLoop(tap: CFMachPort, source: CFRunLoopSource) {
        let loop = CFRunLoopGetCurrent()
        lock.lock()
        guard running else {
            lock.unlock()
            return
        }
        runLoop = loop
        lock.unlock()

        CFRunLoopAddSource(loop, source, .defaultMode)
        CFRunLoopAddSource(loop, source, .commonModes)
        lock.lock()
        let shouldEnable = running && CFMachPortIsValid(tap)
        lock.unlock()
        guard shouldEnable else { return }
        CGEvent.tapEnable(tap: tap, enable: true)

        while true {
            lock.lock()
            let keep = running
            lock.unlock()
            guard keep else { break }
            let result = CFRunLoopRunInMode(.defaultMode, 0.5, false)
            if result == .stopped || result == .finished { break }
        }
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
