import AVFoundation
import Foundation
import Speech

@MainActor
final class LegacyDictationBackend: DictationBackend {
    private(set) var partialText = ""
    private var capture: AudioInputCapture?
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var latest = ""
    private var sawFinal = false
    private var stopWaiter: CheckedContinuation<Void, Never>?
    private var onPartial: ((String) -> Void)?
    private var onLevel: (@Sendable (Double) -> Void)?
    private let levelEnvelope = LevelEnvelope()

    var isRunning: Bool { task != nil }

    func start(
        hints: [String],
        onPartial: @escaping (String) -> Void,
        onLevel: (@Sendable (Double) -> Void)?
    ) async throws {
        if isRunning {
            await cancel()
        }
        try await DictationSession.requestPermissions()
        let locale = try await SpeechAssets.resolvedKoreanLocale()
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw DictationSessionError.localeUnsupported
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        let limited = Array(hints.prefix(100))
        if !limited.isEmpty {
            request.contextualStrings = limited
        }

        let capture = try AudioInput.startCapture()

        self.recognizer = recognizer
        self.request = request
        self.capture = capture
        self.onPartial = onPartial
        self.onLevel = onLevel
        latest = ""
        sawFinal = false
        partialText = ""
        levelEnvelope.reset()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognition(result: result, error: error)
            }
        }

        let envelope = levelEnvelope
        let reportLevel = onLevel
        capture.installTap { buffer in
            request.append(buffer)
            guard let reportLevel, let peak = envelope.push(AudioLevel.peak(of: buffer)) else { return }
            let value = AudioLevel.normalized(peak)
            Task { @MainActor in
                reportLevel(value)
            }
        }
    }

    func stop() async throws -> String {
        guard isRunning else { throw DictationSessionError.notRunning }
        stopCapture()
        request?.endAudio()
        await waitForFinalResult()
        let text = latest.trimmingCharacters(in: .whitespacesAndNewlines)
        await teardown()
        return text
    }

    func cancel() async {
        task?.cancel()
        stopCapture()
        request?.endAudio()
        finishWaiting()
        await teardown()
    }

    private func handleRecognition(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            latest = result.bestTranscription.formattedString
            partialText = latest
            onPartial?(latest)
            if result.isFinal {
                sawFinal = true
                finishWaiting()
            }
        }
        if error != nil {
            finishWaiting()
        }
    }

    private func waitForFinalResult() async {
        if sawFinal { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            if sawFinal {
                continuation.resume()
                return
            }
            stopWaiter = continuation
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(2.5))
                await MainActor.run {
                    self?.finishWaiting()
                }
            }
        }
    }

    private func finishWaiting() {
        guard let stopWaiter else { return }
        self.stopWaiter = nil
        stopWaiter.resume()
    }

    private func stopCapture() {
        capture?.stop()
    }

    private func teardown() async {
        stopCapture()
        capture = nil
        recognizer = nil
        request = nil
        task = nil
        onPartial = nil
        onLevel = nil
        stopWaiter = nil
        levelEnvelope.reset()
        partialText = ""
    }
}
