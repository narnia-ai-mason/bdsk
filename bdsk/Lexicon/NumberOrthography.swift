import Foundation

/// Surface Arabic-digit + classifier spans that also have a native-Korean reading,
/// so the user can pick the orthography Apple's ITN may have collapsed.
enum NumberOrthography {
    struct Choice: Equatable, Identifiable {
        let id: Int
        /// UTF-16 range in the original (digit-form) text.
        let utf16Range: NSRange
        let digitForm: String
        let nativeForm: String
        /// `false` keeps the engine output; `true` writes the native Hangul form.
        var prefersNative: Bool
    }

    /// Classifiers that commonly take native Korean numerals (한/두/세…).
    /// `분` is included because it is the dangerous homograph (person vs minute).
    static let classifiers: [String] = [
        "가지", "분", "개", "명", "마리", "권", "장", "살", "번", "대", "잔", "시", "사람"
    ]

    static func findChoices(in text: String) -> [Choice] {
        let ns = text as NSString
        let pattern = #"(\d{1,2})\s*("# + classifiers.joined(separator: "|") + #")"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        var choices: [Choice] = []
        let full = NSRange(location: 0, length: ns.length)
        regex.enumerateMatches(in: text, options: [], range: full) { match, _, _ in
            guard let match,
                  match.numberOfRanges == 3,
                  let number = Int(ns.substring(with: match.range(at: 1))),
                  (1...99).contains(number),
                  let native = nativeAttributive(number)
            else { return }

            let classifier = ns.substring(with: match.range(at: 2))
            let digitForm = ns.substring(with: match.range)
            // Native attributive + classifier is conventionally spaced (한 분, 한 가지),
            // even when the engine glued the digit form (1분, 1가지).
            let nativeForm = native + " " + classifier
            guard digitForm != nativeForm else { return }

            choices.append(
                Choice(
                    id: choices.count,
                    utf16Range: match.range,
                    digitForm: digitForm,
                    nativeForm: nativeForm,
                    prefersNative: false
                )
            )
        }
        return choices
    }

    static func apply(_ choices: [Choice], to text: String) -> String {
        let active = choices.filter(\.prefersNative).sorted {
            $0.utf16Range.location > $1.utf16Range.location
        }
        guard !active.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for choice in active {
            let range = choice.utf16Range
            guard range.location + range.length <= mutable.length else { continue }
            let current = mutable.substring(with: range)
            guard current == choice.digitForm else { continue }
            mutable.replaceCharacters(in: range, with: choice.nativeForm)
        }
        return mutable as String
    }

    /// 관형사형 고유어 수사 (하나→한, 둘→두, 스물→스무 …).
    static func nativeAttributive(_ number: Int) -> String? {
        guard (1...99).contains(number) else { return nil }
        if number < 10 { return ones[number] }
        if number == 10 { return "열" }
        if number < 20 { return "열" + (ones[number - 10] ?? "") }

        let tens = number / 10
        let remainder = number % 10
        guard let tensWord = tensWords[tens] else { return nil }
        if remainder == 0 {
            return attributiveTens[tens] ?? tensWord
        }
        guard let onesWord = ones[remainder] else { return nil }
        return tensWord + onesWord
    }

    private static let ones: [Int: String] = [
        1: "한", 2: "두", 3: "세", 4: "네",
        5: "다섯", 6: "여섯", 7: "일곱", 8: "여덟", 9: "아홉"
    ]

    private static let tensWords: [Int: String] = [
        2: "스물", 3: "서른", 4: "마흔", 5: "쉰",
        6: "예순", 7: "일흔", 8: "여든", 9: "아흔"
    ]

    /// Before a classifier, 20 is usually 스무 (스무 개), not 스물.
    private static let attributiveTens: [Int: String] = [
        2: "스무"
    ]
}
