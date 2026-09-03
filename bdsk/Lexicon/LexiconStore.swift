import Foundation
import Observation

enum LexiconAddOutcome: Equatable {
    case added(LexiconEntry)
    case merged(LexiconEntry)
}

@MainActor
@Observable
final class LexiconStore {
    private(set) var entries: [LexiconEntry] = []

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil) {
        let url = fileURL ?? Self.defaultFileURL()
        self.fileURL = url
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        load()
    }

    func apply(to text: String) -> String {
        ParticleAwareReplacer.apply(text, entries: entries)
    }

    func appleHints(limit: Int = 100) -> [String] {
        ParticleAwareReplacer.appleHints(from: entries, limit: limit)
    }

    @discardableResult
    func add(replacement: String, aliases: [String]) -> LexiconAddOutcome? {
        let trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        let expanded = ParticleAwareReplacer.expandedAliases(aliases)
        guard !trimmedReplacement.isEmpty, !expanded.isEmpty else { return nil }
        let key = Self.replacementKey(trimmedReplacement)
        if let index = entries.firstIndex(where: { Self.replacementKey($0.replacement) == key }) {
            entries[index].aliases = ParticleAwareReplacer.expandedAliases(entries[index].aliases + expanded)
            entries[index].updatedAt = Date()
            save()
            return .merged(entries[index])
        }
        let entry = LexiconEntry(replacement: trimmedReplacement, aliases: expanded)
        entries.append(entry)
        save()
        return .added(entry)
    }

    func update(_ entry: LexiconEntry, replacement: String, aliases: [String]) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        let trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        let expanded = ParticleAwareReplacer.expandedAliases(aliases)
        guard !trimmedReplacement.isEmpty, !expanded.isEmpty else { return }
        entries[index].replacement = trimmedReplacement
        entries[index].aliases = expanded
        entries[index].updatedAt = Date()
        save()
    }

    func delete(_ entry: LexiconEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func markUsed(matching textBefore: String, textAfter: String) {
        guard textBefore != textAfter else { return }
        for index in entries.indices {
            let probe = ParticleAwareReplacer.apply(textBefore, entries: [entries[index]])
            if probe != textBefore {
                entries[index].usageCount += 1
                entries[index].updatedAt = Date()
            }
        }
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            entries = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            entries = try decoder.decode([LexiconEntry].self, from: data)
        } catch {
            entries = []
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Keep in-memory state even if disk write fails.
        }
    }

    static func replacementKey(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func matching(_ entries: [LexiconEntry], replacementQuery: String) -> [LexiconEntry] {
        let needle = replacementQuery
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !needle.isEmpty else { return entries }
        return entries.filter {
            $0.replacement.precomposedStringWithCanonicalMapping.lowercased().contains(needle)
        }
    }

    private static func defaultFileURL() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return root
            .appendingPathComponent("dev.bdsk.app", isDirectory: true)
            .appendingPathComponent("lexicon.json")
    }
}
