import Foundation

enum ParticleTable {
    /// Closed whitelist of hangul that may follow a stem without a space.
    /// Stacked forms like `에서는` / `으로는` are consumed by
    /// `attachedParticles(at:)` instead of listing every combination.
    ///
    /// Includes case/auxiliary particles and common copula attachments
    /// (`입니다`, `이니까`, `이었`). Unknown hangul (`링`) is not a match,
    /// so the stem is left unchanged.
    static let particles: [String] = [
        "이라는", "이라고", "이라서", "이라면", "이라며", "이란", "이라",
        "라는", "라고", "라서", "라면", "라며",
        "이십니다", "이십니까", "입니다", "입니까",
        "예요", "여요",
        "으로서", "로서", "로써", "으로써",
        "으로부터의", "으로부터", "로부터",
        "에게서", "한테서", "에서", "에게", "한테", "께서", "께",
        "으로", "로",
        "과", "와", "이랑", "랑", "하고",
        "이나마", "이나", "나마", "나",
        "은", "는", "이", "가", "을", "를", "의", "에",
        "도", "만", "부터", "까지", "처럼", "같이", "보다", "만큼", "마다",
        "조차", "마저", "밖에", "대로", "뿐", "라도", "커녕", "야말로",
        "에다가", "에다",
        "이며", "이고", "인데", "이면", "인지",
        "니까", "지만", "면서", "거나", "든지", "거든",
        "세요", "잖아", "지요",
        "습니다", "어요", "었", "였",
        "인", "일", "임",
        "들", "쯤", "더러", "보고",
        "요", "죠", "야", "아", "다", "네", "지", "까", "고",
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
