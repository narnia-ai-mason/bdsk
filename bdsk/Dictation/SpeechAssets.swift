import Foundation
import Speech

enum SpeechAssetPhase: Equatable {
    case unknown
    case checking
    case ready
    case available
    case downloading
    case unsupported
    case failed

    var label: String {
        switch self {
        case .unknown, .checking: return "확인 중"
        case .ready: return "준비됨"
        case .available: return "받기 전"
        case .downloading: return "받는 중"
        case .unsupported: return "이 맥에서 쓸 수 없음"
        case .failed: return "받지 못함"
        }
    }
}

enum SpeechAssets {
    static func resolvedKoreanLocale() async throws -> Locale {
        let requested = Locale(identifier: "ko-KR")
        if let resolved = await SpeechTranscriber.supportedLocale(equivalentTo: requested) {
            return resolved
        }
        if let korean = await SpeechTranscriber.supportedLocales.first(where: isKorean) {
            return korean
        }
        if let korean = await SpeechTranscriber.installedLocales.first(where: isKorean) {
            return korean
        }
        let probe = SpeechTranscriber(locale: requested, preset: .transcription)
        let status = await AssetInventory.status(forModules: [probe])
        if status != .unsupported {
            return requested
        }
        throw DictationSessionError.localeUnsupported
    }

    static func phase() async -> SpeechAssetPhase {
        guard SpeechTranscriber.isAvailable else { return .unsupported }
        let locale: Locale
        do {
            locale = try await resolvedKoreanLocale()
        } catch {
            return .unsupported
        }
        let module = SpeechTranscriber(locale: locale, preset: .transcription)
        switch await AssetInventory.status(forModules: [module]) {
        case .installed:
            return .ready
        case .downloading:
            return .downloading
        case .supported:
            return .available
        case .unsupported:
            return .unsupported
        @unknown default:
            return .available
        }
    }

    static func isInstalled() async -> Bool {
        await phase() == .ready
    }

    static func ensureInstalled(onProgress: @MainActor @escaping (Double) -> Void) async throws {
        let locale = try await resolvedKoreanLocale()
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
            await onProgress(1)
            return
        }
        let progress = request.progress
        let poll = Task {
            while !Task.isCancelled {
                let value = progress.fractionCompleted
                await onProgress(value.isFinite ? min(max(value, 0), 1) : 0)
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
        defer { poll.cancel() }
        try await request.downloadAndInstall()
        await onProgress(1)
    }

    private static func isKorean(_ locale: Locale) -> Bool {
        if locale.language.languageCode?.identifier == "ko" { return true }
        return locale.identifier.lowercased().hasPrefix("ko")
    }
}
