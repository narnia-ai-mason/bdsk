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

    static func insert(_ text: String, into storedElement: AXUIElement?) -> InsertionOutcome {
        guard !text.isEmpty else { return .failed("빈 텍스트") }

        if let element = storedElement ?? focusedElement() {
            if insertViaAccessibility(text, into: element) {
                return .insertedViaAccessibility
            }
        }

        if focusedElement() == nil {
            copyToClipboard(text)
            return .copiedToClipboard
        }

        if paste(text) {
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

    private static func paste(_ text: String) -> Bool {
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
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
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
