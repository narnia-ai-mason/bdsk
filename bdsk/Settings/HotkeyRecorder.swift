import AppKit
import Carbon.HIToolbox
import SwiftUI

struct HotkeyRecorder: View {
    @Binding var binding: HotkeyBinding
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 12) {
            Text(binding.displayName)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(BdskTheme.pearl)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(isRecording ? BdskTheme.lavender.opacity(0.22) : BdskTheme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: BdskTheme.radiusChip, style: .continuous))
            BdskGhostButton(title: isRecording ? "키를 누르세요" : "다시 지정") {
                isRecording.toggle()
            }
        }
        .onChange(of: isRecording) { _, recording in
            if recording {
                startCapture()
            } else {
                stopCapture()
            }
        }
        .onDisappear {
            isRecording = false
            stopCapture()
        }
    }

    private func startCapture() {
        stopCapture()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .flagsChanged {
                if let only = modifierOnlyBinding(from: event) {
                    binding = only
                    DispatchQueue.main.async { isRecording = false }
                    return nil
                }
                return event
            }
            if event.keyCode == UInt16(kVK_Escape) {
                DispatchQueue.main.async { isRecording = false }
                return nil
            }
            let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
            binding = HotkeyBinding(
                keyCode: event.keyCode,
                modifiers: flags.rawValue,
                isModifierOnly: false
            )
            DispatchQueue.main.async { isRecording = false }
            return nil
        }
    }

    private func stopCapture() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func modifierOnlyBinding(from event: NSEvent) -> HotkeyBinding? {
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command, .function])
        guard flags.rawValue != 0 else { return nil }
        let code = Int(event.keyCode)
        let modifierCodes = [
            kVK_RightOption, kVK_Option, kVK_RightCommand, kVK_Command,
            kVK_RightShift, kVK_Shift, kVK_RightControl, kVK_Control, kVK_Function,
        ]
        guard modifierCodes.contains(code) else { return nil }
        return HotkeyBinding(keyCode: event.keyCode, modifiers: flags.rawValue, isModifierOnly: true)
    }
}
