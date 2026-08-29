import AVFoundation
import Foundation
import Speech

struct FileResult: Encodable {
    let id: String
    let path: String
    let text: String
    let sec: Double
    let audio_sec: Double
}

struct BenchResult: Encodable {
    let model: String
    let locale: String
    let load_sec: Double
    let warmup_sec: Double
    let files: [FileResult]
}

func audioDuration(url: URL) -> Double {
    if let file = try? AVAudioFile(forReading: url) {
        return Double(file.length) / file.fileFormat.sampleRate
    }
    return 0
}

func transcribeFile(url: URL, locale: Locale) async throws -> String {
    let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
    let analyzer = SpeechAnalyzer(modules: [transcriber])
    let audioFile = try AVAudioFile(forReading: url)

    async let collected: String = {
        var parts: [String] = []
        for try await result in transcriber.results {
            parts.append(String(result.text.characters))
        }
        return parts.joined()
    }()

    if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
        try await analyzer.finalizeAndFinish(through: lastSample)
    } else {
        await analyzer.cancelAndFinishNow()
    }
    return try await collected
}

func ensureAssets(locale: Locale) async throws {
    let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
    if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
        try await request.downloadAndInstall()
    }
}

func main() async throws {
    var localeId = "ko-KR"
    var paths: [String] = []
    var args = Array(CommandLine.arguments.dropFirst())
    while !args.isEmpty {
        let arg = args.removeFirst()
        if arg == "--locale" {
            localeId = args.removeFirst()
        } else {
            paths.append(arg)
        }
    }
    guard !paths.isEmpty else {
        fputs("usage: AppleASR [--locale ko-KR] audio.m4a...\n", stderr)
        exit(2)
    }

    let locale = Locale(identifier: localeId)
    let supported = await SpeechTranscriber.supportedLocales
    let resolved =
        await SpeechTranscriber.supportedLocale(equivalentTo: locale)
        ?? supported.first(where: { $0.identifier.lowercased().hasPrefix("ko") })
        ?? locale

    let loadStart = ContinuousClock.now
    try await ensureAssets(locale: resolved)
    let loadSec = elapsed(from: loadStart)

    let firstURL = URL(fileURLWithPath: paths[0])
    let warmupStart = ContinuousClock.now
    _ = try await transcribeFile(url: firstURL, locale: resolved)
    let warmupSec = elapsed(from: warmupStart)

    var files: [FileResult] = []
    for path in paths {
        let url = URL(fileURLWithPath: path)
        let id = url.deletingPathExtension().lastPathComponent
        fputs("AppleASR transcribing \(id)...\n", stderr)
        let start = ContinuousClock.now
        let text = try await transcribeFile(url: url, locale: resolved)
        files.append(
            FileResult(
                id: id,
                path: path,
                text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                sec: elapsed(from: start),
                audio_sec: audioDuration(url: url)
            )
        )
    }

    let result = BenchResult(
        model: "Apple SpeechAnalyzer",
        locale: resolved.identifier,
        load_sec: loadSec,
        warmup_sec: warmupSec,
        files: files
    )
    fputs("AppleASR locale=\(resolved.identifier) load=\(String(format: "%.2f", loadSec))s warmup=\(String(format: "%.2f", warmupSec))s\n", stderr)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(result)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func elapsed(from start: ContinuousClock.Instant) -> Double {
    let duration = ContinuousClock.now - start
    let parts = duration.components
    return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
}

do {
    try await main()
} catch {
    fputs("AppleASR error: \(error)\n", stderr)
    exit(1)
}
