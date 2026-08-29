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
final class DictationSession {
    private(set) var partialText = ""
    private var engine: AVAudioEngine?
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultTask: Task<Void, Never>?
    private var reservedLocale: Locale?
    private var finals: [String] = []
    private var volatile = ""
    private var onPartial: ((String) -> Void)?

    var isRunning: Bool { analyzer != nil }

    func start(hints: [String], onPartial: @escaping (String) -> Void) async throws {
        if isRunning {
            await cancel()
        }
        try await Self.requestPermissions()
        let locale = try await SpeechAssets.resolvedKoreanLocale()
        try await SpeechAssets.ensureInstalled { _ in }
        try await AssetInventory.reserve(locale: locale)
        reservedLocale = locale

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        let analyzer = SpeechAnalyzer(
            modules: [transcriber],
            options: .init(priority: .userInitiated, modelRetention: .lingering)
        )
        let context = AnalysisContext()
        let limited = Array(hints.prefix(100))
        if !limited.isEmpty {
            context.contextualStrings[.general] = limited
        }
        try await analyzer.setContext(context)

        guard AVCaptureDevice.default(for: .audio) != nil else {
            throw DictationSessionError.noAudioInput
        }

        // Access inputNode before prepare/start. Otherwise AVAudioEngine raises
        // "inputNode != nullptr || outputNode != nullptr" on macOS.
        let engine = AVAudioEngine()
        let input = engine.inputNode
        engine.prepare()
        try engine.start()
        var micFormat = input.outputFormat(forBus: 0)
        if micFormat.sampleRate <= 0 || micFormat.channelCount <= 0 {
            try await Task.sleep(for: .milliseconds(80))
            micFormat = input.outputFormat(forBus: 0)
        }
        guard micFormat.sampleRate > 0, micFormat.channelCount > 0 else {
            engine.stop()
            throw DictationSessionError.formatUnavailable
        }
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber],
            considering: micFormat
        ) else {
            engine.stop()
            throw DictationSessionError.formatUnavailable
        }

        let streamParts = AsyncStream<AnalyzerInput>.makeStream()
        self.continuation = streamParts.continuation
        self.analyzer = analyzer
        self.transcriber = transcriber
        self.engine = engine
        self.onPartial = onPartial
        finals = []
        volatile = ""
        partialText = ""

        resultTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await result in transcriber.results {
                    let piece = String(result.text.characters)
                    await MainActor.run {
                        if result.isFinal {
                            self.finals.append(piece)
                            self.volatile = ""
                        } else {
                            self.volatile = piece
                        }
                        let combined = (self.finals.joined() + self.volatile)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        self.partialText = combined
                        self.onPartial?(combined)
                    }
                }
            } catch {
                // Result stream ends on finalize/cancel.
            }
        }

        try await analyzer.prepareToAnalyze(in: analyzerFormat)
        try await analyzer.start(inputSequence: streamParts.stream)

        let converter = AudioBufferConverter()
        let continuation = streamParts.continuation
        input.installTap(onBus: 0, bufferSize: 4096, format: micFormat) { buffer, _ in
            guard let converted = converter.convert(buffer, to: analyzerFormat) else { return }
            continuation.yield(AnalyzerInput(buffer: converted))
        }
    }

    func stop() async throws -> String {
        guard analyzer != nil else { throw DictationSessionError.notRunning }
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        continuation?.finish()
        if let analyzer {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        }
        _ = await resultTask?.value
        let text = (finals.joined() + volatile)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        await teardown(releaseLocale: true)
        return text
    }

    func cancel() async {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        continuation?.finish()
        if let analyzer {
            await analyzer.cancelAndFinishNow()
        }
        resultTask?.cancel()
        await teardown(releaseLocale: true)
    }

    private func teardown(releaseLocale: Bool) async {
        engine = nil
        analyzer = nil
        transcriber = nil
        continuation = nil
        resultTask = nil
        onPartial = nil
        finals = []
        volatile = ""
        partialText = ""
        if releaseLocale, let locale = reservedLocale {
            await AssetInventory.release(reservedLocale: locale)
            reservedLocale = nil
        }
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
