import AppKit
import ApplicationServices
import Foundation
import Observation
import SwiftUI

enum DictationPhase: Equatable {
    case idle
    case starting
    case recordingToggle
    case recordingHold
    case finishing

    var isRecording: Bool {
        switch self {
        case .starting, .recordingToggle, .recordingHold: return true
        default: return false
        }
    }

    var menuLabel: String {
        switch self {
        case .idle: return "대기"
        case .starting: return "시작 중"
        case .recordingToggle: return "녹음 중 · 토글"
        case .recordingHold: return "녹음 중 · 누르는 중"
        case .finishing: return "넣는 중"
        }
    }
}

@MainActor
@Observable
final class AppModel: HybridHotkeyHandling {
    let lexicon = LexiconStore()
    var phase: DictationPhase = .idle
    var partialText = ""
    var lastMessage = ""
    var hotkeyMonitorFailed = false
    var debuggerAttached = ProcessDebugState.isAttached
    var runningAppPath = Bundle.main.bundlePath
    var speechAssetPhase: SpeechAssetPhase = .unknown
    var speechAssetProgress: Double = 0
    private(set) var dismissedSetupThisSession = false
    var holdThresholdMs: Double {
        didSet { UserDefaults.standard.set(holdThresholdMs, forKey: "holdThresholdMs") }
    }
    var hotkey: HotkeyBinding {
        didSet { persistHotkey() }
    }

    private let session = DictationSession()
    private var monitor: HybridHotkeyMonitor?
    private var capturedElement: AXUIElement?
    private var readyAt: Date?
    private var releasedBeforeReady = false
    private var stillHolding = false
    private var pendingFinish = false

    init() {
        if let data = UserDefaults.standard.data(forKey: "hotkey"),
           let decoded = try? JSONDecoder().decode(HotkeyBinding.self, from: data)
        {
            hotkey = decoded
        } else {
            hotkey = .default
        }
        let stored = UserDefaults.standard.double(forKey: "holdThresholdMs")
        holdThresholdMs = stored == 0 ? 300 : stored
        startMonitoring()
        Task { await considerFirstRun() }
    }

    var isSetupComplete: Bool {
        Permissions.microphoneStatus() == .granted
            && Permissions.speechStatus() == .granted
            && Permissions.accessibilityStatus() == .granted
            && speechAssetPhase == .ready
    }

    var shouldPresentSetup: Bool {
        if dismissedSetupThisSession { return false }
        if Permissions.microphoneStatus() == .notDetermined { return true }
        if Permissions.speechStatus() == .notDetermined { return true }
        if Permissions.accessibilityStatus() == .notDetermined { return true }
        switch speechAssetPhase {
        case .ready:
            return false
        case .downloading:
            return true
        case .unknown, .checking, .available, .unsupported, .failed:
            return true
        }
    }

    func considerFirstRun() async {
        await refreshSpeechAssets()
        if shouldPresentSetup {
            AppChrome.showSetup()
        }
    }

    func dismissSetupForSession() {
        dismissedSetupThisSession = true
    }

    func refreshSpeechAssets() async {
        if speechAssetPhase == .downloading { return }
        speechAssetPhase = .checking
        speechAssetPhase = await SpeechAssets.phase()
        if speechAssetPhase == .ready {
            speechAssetProgress = 1
        }
    }

    func installSpeechAssets() async {
        speechAssetPhase = .downloading
        speechAssetProgress = 0
        lastMessage = ""
        do {
            try await SpeechAssets.ensureInstalled { [weak self] value in
                self?.speechAssetProgress = value
            }
            speechAssetPhase = await SpeechAssets.phase()
            if speechAssetPhase != .ready {
                speechAssetPhase = .ready
            }
        } catch {
            speechAssetPhase = .failed
            lastMessage = "한국어 엔진을 받지 못했습니다. 네트워크를 확인한 뒤 다시 받아 주세요."
        }
    }

    func startMonitoring() {
        if monitor != nil { return }
        let created = HybridHotkeyMonitor(binding: hotkey)
        created.handler = self
        debuggerAttached = ProcessDebugState.isAttached
        runningAppPath = Bundle.main.bundlePath
        hotkeyMonitorFailed = !created.start()
        monitor = created
        if hotkeyMonitorFailed {
            if debuggerAttached {
                lastMessage = "Xcode 디버거가 붙어 있으면 전역 핫키가 막힙니다."
            } else {
                lastMessage = "전역 핫키를 쓰려면 손쉬운 사용 권한이 이 실행 파일에 적용되어야 합니다."
            }
        }
    }

    func refreshHotkeyMonitor() {
        monitor?.stop()
        monitor = nil
        startMonitoring()
    }

    func hotkeyPressed() {
        stillHolding = true
        switch phase {
        case .idle:
            Task { await beginRecording() }
        case .starting:
            pendingFinish = true
        case .recordingToggle:
            Task { await finishRecording() }
        case .recordingHold, .finishing:
            break
        }
    }

    func hotkeyReleased() {
        stillHolding = false
        switch phase {
        case .starting:
            releasedBeforeReady = true
        case .recordingHold:
            let readyAt = self.readyAt ?? Date()
            if Date().timeIntervalSince(readyAt) >= holdThresholdMs / 1000 {
                Task { await finishRecording() }
            } else {
                phase = .recordingToggle
            }
        default:
            break
        }
    }

    func toggleFromMenu() {
        if phase.isRecording {
            Task { await finishRecording() }
        } else {
            stillHolding = false
            Task { await beginRecording() }
        }
    }

    private func beginRecording() async {
        guard phase == .idle else { return }
        phase = .starting
        lastMessage = ""
        partialText = ""
        releasedBeforeReady = false
        pendingFinish = false
        capturedElement = TextInserter.focusedElement()
        do {
            if speechAssetPhase != .ready {
                lastMessage = "한국어 엔진을 준비하고 있습니다."
            }
            let hints = lexicon.appleHints()
            try await session.start(hints: hints) { [weak self] text in
                self?.partialText = text
            }
            await refreshSpeechAssets()
            readyAt = Date()
            if pendingFinish {
                phase = .recordingToggle
                await finishRecording()
                return
            }
            if releasedBeforeReady || !stillHolding {
                phase = .recordingToggle
            } else {
                phase = .recordingHold
            }
        } catch {
            pendingFinish = false
            phase = .idle
            lastMessage = error.localizedDescription
        }
    }

    private func finishRecording() async {
        if phase == .starting {
            pendingFinish = true
            return
        }
        guard phase.isRecording else { return }
        phase = .finishing
        do {
            let raw = try await session.stop()
            let corrected = lexicon.apply(to: raw)
            if raw != corrected {
                lexicon.markUsed(matching: raw, textAfter: corrected)
            }
            if corrected.isEmpty {
                lastMessage = "인식된 말이 없습니다."
            } else {
                let toInsert = corrected.hasSuffix(" ") ? corrected : corrected + " "
                switch TextInserter.insert(toInsert, into: capturedElement) {
                case .insertedViaAccessibility, .pasted:
                    lastMessage = corrected
                case .copiedToClipboard:
                    lastMessage = "텍스트 필드가 없어 클립보드에 복사했습니다."
                case .failed(let reason):
                    lastMessage = reason
                }
            }
        } catch {
            lastMessage = error.localizedDescription
            await session.cancel()
        }
        capturedElement = nil
        readyAt = nil
        releasedBeforeReady = false
        stillHolding = false
        pendingFinish = false
        partialText = ""
        phase = .idle
    }

    private func persistHotkey() {
        if let data = try? JSONEncoder().encode(hotkey) {
            UserDefaults.standard.set(data, forKey: "hotkey")
        }
        monitor?.update(binding: hotkey)
    }
}
