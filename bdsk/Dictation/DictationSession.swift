import AVFoundation
import Foundation
import Speech

enum DictationSessionError: LocalizedError {
    case microphoneDenied
    case speechDenied
    case noAudioInput
    case localeUnsupported
    case formatUnavailable
    case notRunning

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: return "마이크 권한이 필요합니다."
        case .speechDenied: return "음성 인식 권한이 필요합니다."
        case .noAudioInput: return "마이크 입력 장치를 찾을 수 없습니다."
        case .localeUnsupported: return "한국어 받아쓰기 엔진을 찾을 수 없습니다."
        case .formatUnavailable: return "마이크와 전사 엔진의 오디오 형식을 맞출 수 없습니다."
        case .notRunning: return "받아쓰기가 시작되지 않았습니다."
        }
    }
}

@MainActor
protocol DictationBackend: AnyObject {
    var isRunning: Bool { get }
    var partialText: String { get }
    func start(
        hints: [String],
        onPartial: @escaping (String) -> Void,
        onLevel: (@Sendable (Double) -> Void)?
    ) async throws
    func stop() async throws -> String
    func cancel() async
}

@MainActor
final class DictationSession {
    private var backend: (any DictationBackend)?

    var partialText: String { backend?.partialText ?? "" }
    var isRunning: Bool { backend?.isRunning ?? false }

    func start(
        hints: [String],
        onPartial: @escaping (String) -> Void,
        onLevel: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        if isRunning {
            await cancel()
        }
        let selected: any DictationBackend
        if #available(macOS 26, *), SpeechAssets.usesModernEngine {
            selected = ModernDictationBackend()
        } else {
            selected = LegacyDictationBackend()
        }
        backend = selected
        try await selected.start(hints: hints, onPartial: onPartial, onLevel: onLevel)
    }

    func stop() async throws -> String {
        guard let backend else { throw DictationSessionError.notRunning }
        let text = try await backend.stop()
        self.backend = nil
        return text
    }

    func cancel() async {
        await backend?.cancel()
        backend = nil
    }

    static func requestPermissions() async throws {
        let mic = await AVCaptureDevice.requestAccess(for: .audio)
        guard mic else { throw DictationSessionError.microphoneDenied }

        let speech: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speech == .authorized else { throw DictationSessionError.speechDenied }
    }
}

enum AudioLevel {
    static func peak(of buffer: AVAudioPCMBuffer) -> Float {
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        let channels = Int(buffer.format.channelCount)
        var peak: Float = 0
        if let data = buffer.floatChannelData {
            for channel in 0..<channels {
                let samples = data[channel]
                for index in 0..<frames {
                    peak = max(peak, abs(samples[index]))
                }
            }
            return peak
        }
        if let data = buffer.int16ChannelData {
            for channel in 0..<channels {
                let samples = data[channel]
                for index in 0..<frames {
                    peak = max(peak, abs(Float(samples[index]) / 32768))
                }
            }
            return peak
        }
        return 0
    }

    static func normalized(_ peak: Float) -> Double {
        let noise: Float = 0.018
        let loud: Float = 0.32
        let clamped = max(0, min(1, (peak - noise) / (loud - noise)))
        return Double(pow(clamped, 0.62))
    }
}

final class LevelEnvelope: @unchecked Sendable {
    private var value: Float = 0
    private var lastEmit = 0.0
    private let lock = NSLock()

    func push(_ peak: Float) -> Float? {
        lock.lock()
        defer { lock.unlock() }
        let coeff: Float = peak > value ? 0.5 : 0.16
        value += (peak - value) * coeff
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastEmit >= 0.045 else { return nil }
        lastEmit = now
        return value
    }

    func reset() {
        lock.lock()
        value = 0
        lastEmit = 0
        lock.unlock()
    }
}
