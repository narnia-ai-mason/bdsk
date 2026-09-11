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
    /// Tahoe SpeechTranscriber when the device has it. Otherwise the Sonoma-era recognizer.
    static var usesModernEngine: Bool {
        if #available(macOS 26, *) {
            return SpeechTranscriber.isAvailable
        }
        return false
    }

    static func resolvedKoreanLocale() async throws -> Locale {
        if #available(macOS 26, *), usesModernEngine {
            return try await resolvedModernKoreanLocale()
        }
        return try resolvedLegacyKoreanLocale()
    }

    static func retainKoreanReservation() async {
        guard #available(macOS 26, *), usesModernEngine else { return }
        guard let locale = try? await resolvedModernKoreanLocale() else { return }
        _ = try? await AssetInventory.reserve(locale: locale)
    }

    static func phase() async -> SpeechAssetPhase {
        if #available(macOS 26, *), usesModernEngine {
            return await modernPhase()
        }
        return legacyPhase()
    }

    static func isInstalled() async -> Bool {
        await phase() == .ready
    }

    static func ensureInstalled(onProgress: @MainActor @escaping (Double) -> Void) async throws {
        if #available(macOS 26, *), usesModernEngine {
            try await ensureModernInstalled(onProgress: onProgress)
            return
        }
        await onProgress(1)
    }

    @available(macOS 26, *)
    static func transcriber(locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
    }

    @available(macOS 26, *)
    private static func resolvedModernKoreanLocale() async throws -> Locale {
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
        let probe = transcriber(locale: requested)
        let status = await AssetInventory.status(forModules: [probe])
        if status != .unsupported {
            return requested
        }
        throw DictationSessionError.localeUnsupported
    }

    private static func resolvedLegacyKoreanLocale() throws -> Locale {
        let requested = Locale(identifier: "ko-KR")
        if SFSpeechRecognizer(locale: requested) != nil {
            return requested
        }
        throw DictationSessionError.localeUnsupported
    }

    @available(macOS 26, *)
    private static func modernPhase() async -> SpeechAssetPhase {
        let locale: Locale
        do {
            locale = try await resolvedModernKoreanLocale()
        } catch {
            return .unsupported
        }
        let module = transcriber(locale: locale)
        switch await AssetInventory.status(forModules: [module]) {
        case .installed:
            return .ready
        case .downloading:
            return .downloading
        case .unsupported:
            return .unsupported
        case .supported:
            return await isKoreanOnDisk() ? .ready : .available
        @unknown default:
            return await isKoreanOnDisk() ? .ready : .available
        }
    }

    private static func legacyPhase() -> SpeechAssetPhase {
        SFSpeechRecognizer(locale: Locale(identifier: "ko-KR")) == nil ? .unsupported : .ready
    }

    @available(macOS 26, *)
    private static func ensureModernInstalled(onProgress: @MainActor @escaping (Double) -> Void) async throws {
        let locale = try await resolvedModernKoreanLocale()
        _ = try? await AssetInventory.reserve(locale: locale)
        let transcriber = transcriber(locale: locale)
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

    @available(macOS 26, *)
    private static func isKoreanOnDisk() async -> Bool {
        await SpeechTranscriber.installedLocales.contains(where: isKorean)
    }

    private static func isKorean(_ locale: Locale) -> Bool {
        if locale.language.languageCode?.identifier == "ko" { return true }
        return locale.identifier.lowercased().hasPrefix("ko")
    }
}
