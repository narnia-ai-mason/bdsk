import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

enum InsertionOutcome: Equatable {
    case insertedViaAccessibility
    case pasted
    case copiedToClipboard
    case failed(String)
}

enum TextInserter {
    @discardableResult
    static func requestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused
        else {
            return nil
        }
        return (element as! AXUIElement)
    }

    /// Bring the element’s app forward and focus the field so paste/AX insert lands correctly.
    @discardableResult
    static func focus(_ element: AXUIElement?) -> Bool {
        guard let element else { return false }
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success,
              let app = NSRunningApplication(processIdentifier: pid)
        else {
            return false
        }
        app.activate(options: [.activateIgnoringOtherApps])
        let focused = AXUIElementSetAttributeValue(
            element,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )
        return focused == .success
    }

    /// No-op when the captured app is already frontmost. Otherwise activate and wait
    /// briefly so AX insert / Cmd+V are not posted into the void.
    static func ensureReady(_ element: AXUIElement?, timeoutMs: Int = 400) async {
        guard let element else { return }
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success,
              let app = NSRunningApplication(processIdentifier: pid)
        else {
            return
        }
        if app.isActive {
            _ = AXUIElementSetAttributeValue(
                element,
                kAXFocusedAttribute as CFString,
                kCFBooleanTrue
            )
            return
        }
        app.activate(options: [.activateIgnoringOtherApps])
        let deadline = ContinuousClock.now + .milliseconds(timeoutMs)
        while ContinuousClock.now < deadline {
            if let current = NSRunningApplication(processIdentifier: pid), current.isActive {
                _ = AXUIElementSetAttributeValue(
                    element,
                    kAXFocusedAttribute as CFString,
                    kCFBooleanTrue
                )
                return
            }
            try? await Task.sleep(for: .milliseconds(16))
            if !app.isActive {
                app.activate(options: [.activateIgnoringOtherApps])
            }
        }
        _ = AXUIElementSetAttributeValue(
            element,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )
    }

    static func insert(_ text: String, into storedElement: AXUIElement?) -> InsertionOutcome {
        guard !text.isEmpty else { return .failed("빈 텍스트") }

        if let element = storedElement, insertViaAccessibility(text, into: element) {
            return .insertedViaAccessibility
        }
        if let live = focusedElement(), insertViaAccessibility(text, into: live) {
            return .insertedViaAccessibility
        }

        if focusedElement() == nil {
            copyToClipboard(text)
            return .copiedToClipboard
        }

        if paste(text, into: storedElement ?? focusedElement()) {
            return .pasted
        }
        copyToClipboard(text)
        return .copiedToClipboard
    }

    private static func insertViaAccessibility(_ text: String, into element: AXUIElement) -> Bool {
        let before = stringAttribute(kAXValueAttribute as CFString, from: element)
            ?? stringAttribute(kAXSelectedTextAttribute as CFString, from: element)
        let error = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        guard error == .success else { return false }

        let after = stringAttribute(kAXValueAttribute as CFString, from: element)
            ?? stringAttribute(kAXSelectedTextAttribute as CFString, from: element)
        if let before, let after, after != before {
            return true
        }
        if before == nil, after?.contains(text) == true {
            return true
        }
        if after == text {
            return true
        }
        return false
    }

    private static func paste(_ text: String, into element: AXUIElement?) -> Bool {
        let pasteboard = NSPasteboard.general
        let snapshot = snapshotClipboard(pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand

        var pid: pid_t = 0
        if let element, AXUIElementGetPid(element, &pid) == .success {
            down?.postToPid(pid)
            up?.postToPid(pid)
        } else {
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            restoreClipboard(snapshot, to: pasteboard)
        }
        return true
    }

    private static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func stringAttribute(_ name: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
        return value as? String
    }

    private struct ClipboardItem {
        let types: [NSPasteboard.PasteboardType]
        let values: [NSPasteboard.PasteboardType: Data]
    }

    private static func snapshotClipboard(_ pasteboard: NSPasteboard) -> [ClipboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let types = item.types
            var values: [NSPasteboard.PasteboardType: Data] = [:]
            for type in types {
                if let data = item.data(forType: type) {
                    values[type] = data
                }
            }
            return ClipboardItem(types: types, values: values)
        }
    }

    private static func restoreClipboard(_ items: [ClipboardItem], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restored = items.map { item -> NSPasteboardItem in
            let pasteItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.values[type] {
                    pasteItem.setData(data, forType: type)
                }
            }
            return pasteItem
        }
        if !restored.isEmpty {
            pasteboard.writeObjects(restored)
        }
    }
}
