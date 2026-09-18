import AVFoundation
import Foundation
import Speech

@available(macOS 26, *)
@MainActor
final class ModernDictationBackend: DictationBackend {
    private(set) var partialText = ""
    private var capture: AudioInputCapture?
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultTask: Task<Void, Never>?
    private var finals: [String] = []
    private var volatile = ""
    private var onPartial: ((String) -> Void)?
    private var onLevel: (@Sendable (Double) -> Void)?
    private let levelEnvelope = LevelEnvelope()

    var isRunning: Bool { analyzer != nil }

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
        try await SpeechAssets.ensureInstalled { _ in }
        try await AssetInventory.reserve(locale: locale)

        let transcriber = SpeechAssets.transcriber(locale: locale)
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

        let capture = try AudioInput.startCapture()
        let micFormat = capture.format
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber],
            considering: micFormat
        ) else {
            capture.stop()
            throw DictationSessionError.formatUnavailable
        }

        let streamParts = AsyncStream<AnalyzerInput>.makeStream()
        self.continuation = streamParts.continuation
        self.analyzer = analyzer
        self.transcriber = transcriber
        self.capture = capture
        self.onPartial = onPartial
        self.onLevel = onLevel
        levelEnvelope.reset()
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
        let envelope = levelEnvelope
        let reportLevel = onLevel
        capture.installTap { buffer in
            if let converted = converter.convert(buffer, to: analyzerFormat) {
                continuation.yield(AnalyzerInput(buffer: converted))
            }
            guard let reportLevel, let peak = envelope.push(AudioLevel.peak(of: buffer)) else { return }
            let value = AudioLevel.normalized(peak)
            Task { @MainActor in
                reportLevel(value)
            }
        }
    }

    func stop() async throws -> String {
        guard analyzer != nil else { throw DictationSessionError.notRunning }
        capture?.stop()
        continuation?.finish()
        if let analyzer {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        }
        _ = await resultTask?.value
        let text = (finals.joined() + volatile)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        await teardown()
        return text
    }

    func cancel() async {
        capture?.stop()
        continuation?.finish()
        if let analyzer {
            await analyzer.cancelAndFinishNow()
        }
        resultTask?.cancel()
        await teardown()
    }

    private func teardown() async {
        capture?.stop()
        capture = nil
        analyzer = nil
        transcriber = nil
        continuation = nil
        resultTask = nil
        onPartial = nil
        onLevel = nil
        levelEnvelope.reset()
        finals = []
        volatile = ""
        partialText = ""
    }
}
