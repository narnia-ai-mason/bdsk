import Foundation

enum ScriptClass: Equatable {
    case hangul
    case latinOrNumber
    case other
}

enum ParticleAwareReplacer {
    static func apply(_ text: String, entries: [LexiconEntry]) -> String {
        let source = text.precomposedStringWithCanonicalMapping
        let aliases = compiledAliases(from: entries)
        guard !aliases.isEmpty else { return source }

        var output = ""
        var index = source.startIndex

        while index < source.endIndex {
            if let hit = firstMatch(in: source, at: index, aliases: aliases) {
                output += source[index..<hit.range.lowerBound]
                output += hit.replacement
                if let particle = hit.particle {
                    output += particle
                }
                index = hit.range.upperBound
            } else {
                output.append(source[index])
                index = source.index(after: index)
            }
        }

        return output
    }

    static func appleHints(from entries: [LexiconEntry], limit: Int = 100) -> [String] {
        var seen = Set<String>()
        var hints: [String] = []
        let ranked = entries.sorted {
            if $0.usageCount != $1.usageCount { return $0.usageCount > $1.usageCount }
            return $0.updatedAt > $1.updatedAt
        }
        for entry in ranked {
            for stem in entry.stems {
                let key = stem.precomposedStringWithCanonicalMapping
                guard !key.isEmpty, seen.insert(normalizedKey(key)).inserted else { continue }
                hints.append(key)
                if hints.count >= limit { return hints }
            }
        }
        return hints
    }

    private struct CompiledAlias {
        let surface: String
        let replacement: String
        let startClass: ScriptClass
    }

    private struct Hit {
        let range: Range<String.Index>
        let replacement: String
        let particle: String?
    }

    private static func compiledAliases(from entries: [LexiconEntry]) -> [CompiledAlias] {
        var items: [CompiledAlias] = []
        for entry in entries {
            let replacement = entry.replacement.precomposedStringWithCanonicalMapping
            guard !replacement.isEmpty else { continue }
            for raw in expandedAliases(entry.aliases) {
                let surface = raw.precomposedStringWithCanonicalMapping
                guard !surface.isEmpty else { continue }
                items.append(
                    CompiledAlias(
                        surface: surface,
                        replacement: replacement,
                        startClass: scriptClass(surface[surface.startIndex])
                    )
                )
            }
        }
        return items.sorted { $0.surface.count > $1.surface.count }
    }

    static func expandedAliases(_ aliases: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for alias in aliases {
            let nfc = alias.precomposedStringWithCanonicalMapping
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !nfc.isEmpty, seen.insert(normalizedKey(nfc)).inserted else { continue }
            result.append(nfc)
            let collapsed = nfc.replacingOccurrences(of: " ", with: "")
            if collapsed != nfc, seen.insert(normalizedKey(collapsed)).inserted {
                result.append(collapsed)
            }
        }
        return result
    }

    private static func firstMatch(
        in text: String,
        at index: String.Index,
        aliases: [CompiledAlias]
    ) -> Hit? {
        for alias in aliases {
            guard hasPrefix(text, at: index, prefix: alias.surface) else { continue }
            guard isStartBoundary(in: text, at: index, matchClass: alias.startClass) else { continue }
            let matchEnd = text.index(index, offsetBy: alias.surface.count)
            let remainder = text[matchEnd...]
            let particle = ParticleTable.attachedParticles(at: remainder)
            let afterParticle: String.Index
            if let particle {
                afterParticle = remainder.index(remainder.startIndex, offsetBy: particle.count)
            } else {
                afterParticle = matchEnd
            }
            guard isEndBoundary(in: text, at: afterParticle, matchClass: alias.startClass) else { continue }
            return Hit(
                range: index..<afterParticle,
                replacement: alias.replacement,
                particle: particle
            )
        }
        return nil
    }

    private static func hasPrefix(_ text: String, at index: String.Index, prefix: String) -> Bool {
        var textIndex = index
        var prefixIndex = prefix.startIndex
        while prefixIndex < prefix.endIndex {
            guard textIndex < text.endIndex else { return false }
            if !charactersMatch(text[textIndex], prefix[prefixIndex]) {
                return false
            }
            textIndex = text.index(after: textIndex)
            prefixIndex = prefix.index(after: prefixIndex)
        }
        return true
    }

    private static func charactersMatch(_ a: Character, _ b: Character) -> Bool {
        if a == b { return true }
        if scriptClass(a) == .latinOrNumber || scriptClass(b) == .latinOrNumber {
            return String(a).compare(String(b), options: [.caseInsensitive, .diacriticInsensitive])
                == .orderedSame
        }
        return false
    }

    private static func isStartBoundary(in text: String, at index: String.Index, matchClass: ScriptClass) -> Bool {
        if index == text.startIndex { return true }
        let previous = text[text.index(before: index)]
        if previous.isWhitespace || previous.isPunctuation { return true }
        return scriptClass(previous) != matchClass
    }

    /// After consuming whitelist attachments, leftover hangul means the stem
    /// was inside a longer word (`데이터링`). Latin/number stems also cannot
    /// be a prefix of a longer latin token (`CTA` in `CTABC`).
    private static func isEndBoundary(
        in text: String,
        at index: String.Index,
        matchClass: ScriptClass
    ) -> Bool {
        if index == text.endIndex { return true }
        let next = text[index]
        if next.isWhitespace || next.isPunctuation { return true }
        let nextClass = scriptClass(next)
        if nextClass == .hangul { return false }
        return nextClass != matchClass
    }

    static func scriptClass(_ character: Character) -> ScriptClass {
        if character.unicodeScalars.allSatisfy(isHangulScalar) {
            return .hangul
        }
        if character.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) && $0.value < 0x3000 }) {
            return .latinOrNumber
        }
        return .other
    }

    private static func isHangulScalar(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        return (0x1100...0x11FF).contains(value)
            || (0x3130...0x318F).contains(value)
            || (0xA960...0xA97F).contains(value)
            || (0xAC00...0xD7A3).contains(value)
            || (0xD7B0...0xD7FF).contains(value)
    }

    private static func normalizedKey(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping.lowercased()
    }
}
