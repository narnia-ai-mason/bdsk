import AppKit
import Carbon.HIToolbox
import Foundation

struct HotkeyBinding: Codable, Equatable, Sendable {
    var keyCode: UInt16
    var modifiers: UInt
    var isModifierOnly: Bool

    static let `default` = HotkeyBinding(
        keyCode: UInt16(kVK_Space),
        modifiers: NSEvent.ModifierFlags.control.rawValue,
        isModifierOnly: false
    )

    var displayName: String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        if isModifierOnly {
            parts.append(modifierKeyName)
        } else {
            parts.append(keyName)
        }
        return parts.joined()
    }

    private var keyName: String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Esc"
        default:
            return Self.glyph(for: keyCode) ?? "Key \(keyCode)"
        }
    }

    private var modifierKeyName: String {
        switch Int(keyCode) {
        case kVK_RightOption: return "Right Option"
        case kVK_Option: return "Option"
        case kVK_RightCommand: return "Right Command"
        case kVK_Command: return "Command"
        case kVK_RightShift: return "Right Shift"
        case kVK_Shift: return "Shift"
        case kVK_RightControl: return "Right Control"
        case kVK_Control: return "Control"
        case kVK_Function: return "Fn"
        default: return keyName
        }
    }

    func matches(event: CGEvent) -> Bool {
        let type = event.type
        if isModifierOnly {
            guard type == .flagsChanged else { return false }
            return event.getIntegerValueField(.keyboardEventKeycode) == Int64(keyCode)
        }
        guard type == .keyDown || type == .keyUp else { return false }
        guard event.getIntegerValueField(.keyboardEventKeycode) == Int64(keyCode) else { return false }
        let eventFlags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
            .intersection([.control, .option, .shift, .command])
        let expected = NSEvent.ModifierFlags(rawValue: modifiers)
            .intersection([.control, .option, .shift, .command])
        return eventFlags == expected
    }

    func isKeyDown(event: CGEvent) -> Bool {
        if isModifierOnly {
            let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
            switch Int(keyCode) {
            case kVK_RightOption, kVK_Option: return flags.contains(.option)
            case kVK_RightCommand, kVK_Command: return flags.contains(.command)
            case kVK_RightShift, kVK_Shift: return flags.contains(.shift)
            case kVK_RightControl, kVK_Control: return flags.contains(.control)
            case kVK_Function: return flags.contains(.function)
            default: return false
            }
        }
        return event.type == .keyDown
    }

    private static func glyph(for keyCode: UInt16) -> String? {
        let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeRetainedValue()
        guard let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        return data.withUnsafeBytes { pointer -> String? in
            guard let layout = pointer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return nil
            }
            var deadKeyState: UInt32 = 0
            var chars: [UniChar] = Array(repeating: 0, count: 4)
            var length: Int = 0
            let status = UCKeyTranslate(
                layout,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
    }
}
