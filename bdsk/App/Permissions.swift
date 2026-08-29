import AppKit
import ApplicationServices
import AVFoundation
import Darwin
import Foundation
import Speech

enum ProcessDebugState {
    static var isAttached: Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, ProcessInfo.processInfo.processIdentifier]
        let ok = sysctl(&name, u_int(name.count), &info, &size, nil, 0) == 0
        return ok && (info.kp_proc.p_flag & P_TRACED) != 0
    }
}

enum PermissionKind: String, CaseIterable, Identifiable {
    case microphone
    case speech
    case accessibility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .microphone: return "마이크"
        case .speech: return "음성 인식"
        case .accessibility: return "손쉬운 사용"
        }
    }

    var summary: String {
        switch self {
        case .microphone: return "말하는 소리를 듣습니다."
        case .speech: return "기기 안에서 말을 글자로 바꿉니다."
        case .accessibility: return "핫키와 커서에 글 넣기에 필요합니다."
        }
    }
}

enum PermissionStatus: Equatable {
    case granted
    case denied
    case notDetermined

    var label: String {
        switch self {
        case .granted: return "허용됨"
        case .denied: return "거부됨"
        case .notDetermined: return "요청 전"
        }
    }
}

enum Permissions {
    static func microphoneStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    static func speechStatus() -> PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    static func accessibilityStatus() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    static func requestMicrophone() async {
        _ = await AVCaptureDevice.requestAccess(for: .audio)
    }

    static func requestSpeech() async {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { _ in
                continuation.resume()
            }
        }
    }

    static func requestAccessibility() {
        _ = TextInserter.requestAccessibility()
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
