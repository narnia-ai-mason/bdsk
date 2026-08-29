import Foundation

enum ParticleTable {
    /// Closed set of atomic particles, longest-first. Stacked forms like
    /// `에서는` / `으로는` are consumed by `attachedParticles(at:)` instead of
    /// listing every combination.
    static let particles: [String] = [
        "이라는", "이라고", "이라서", "이라면", "이라며",
        "라는", "라고", "라서", "라면", "라며",
        "으로서", "로서", "로써",
        "으로부터의", "으로부터", "로부터",
        "에게서", "한테서", "에서", "에게", "한테", "께",
        "으로", "로",
        "과", "와", "이랑", "랑", "하고",
        "이나", "나",
        "은", "는", "이", "가", "을", "를", "의", "에",
        "도", "만", "부터", "까지", "처럼", "같이", "보다", "만큼", "마다",
        "조차", "마저", "밖에", "대로",
        "이며", "이고", "인데", "이면", "인지",
    ].sorted { $0.count > $1.count }

    static func longestParticle(at remainder: Substring) -> String? {
        for particle in particles where remainder.hasPrefix(particle) {
            return particle
        }
        return nil
    }

    static func attachedParticles(at remainder: Substring) -> String? {
        var index = remainder.startIndex
        var consumed = ""
        while index < remainder.endIndex {
            guard let particle = longestParticle(at: remainder[index...]) else { break }
            consumed += particle
            index = remainder.index(index, offsetBy: particle.count)
        }
        return consumed.isEmpty ? nil : consumed
    }
}
