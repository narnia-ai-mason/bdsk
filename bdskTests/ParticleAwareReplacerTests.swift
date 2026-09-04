import XCTest
@testable import bdsk

final class ParticleAwareReplacerTests: XCTestCase {
    private let swiftdata = LexiconEntry(
        replacement: "SwiftData",
        aliases: ["스위프트 데이터"]
    )
    private let cta = LexiconEntry(
        replacement: "CTA",
        aliases: ["CTA"]
    )

    func testPreservesParticleAfterKoreanStem() {
        let text = ParticleAwareReplacer.apply("스위프트 데이터로", entries: [swiftdata])
        XCTAssertEqual(text, "SwiftData로")
    }

    func testMatchesSpacelessAlias() {
        let text = ParticleAwareReplacer.apply("스위프트데이터의", entries: [swiftdata])
        XCTAssertEqual(text, "SwiftData의")
    }

    func testDoesNotReplaceWhenHangulContinues() {
        let text = ParticleAwareReplacer.apply("스위프트 데이터링", entries: [swiftdata])
        XCTAssertEqual(text, "스위프트 데이터링")
    }

    func testPreservesParticleAfterLatinStem() {
        let text = ParticleAwareReplacer.apply("CTA가", entries: [cta])
        XCTAssertEqual(text, "CTA가")
    }

    func testLeavesAlreadyCanonicalForm() {
        let text = ParticleAwareReplacer.apply("SwiftData의", entries: [swiftdata])
        XCTAssertEqual(text, "SwiftData의")
    }

    func testLongestMatchWins() {
        let short = LexiconEntry(replacement: "SD", aliases: ["스위프트"])
        let text = ParticleAwareReplacer.apply(
            "스위프트 데이터만",
            entries: [short, swiftdata]
        )
        XCTAssertEqual(text, "SwiftData만")
    }

    func testPrefersLongerParticle() {
        let text = ParticleAwareReplacer.apply("스위프트 데이터으로", entries: [swiftdata])
        XCTAssertEqual(text, "SwiftData으로")
    }

    func testMultipleReplacementsInOneSentence() {
        let physics = LexiconEntry(replacement: "PhysicsX", aliases: ["피직스 엑스", "피직스엑스"])
        let text = ParticleAwareReplacer.apply(
            "피직스 엑스로 CTA를 눌러",
            entries: [physics, cta]
        )
        XCTAssertEqual(text, "PhysicsX로 CTA를 눌러")
    }

    func testAppleHintsCapAt100() {
        let entries = (1...120).map { index in
            LexiconEntry(
                replacement: "T\(index)",
                aliases: ["표제어\(index)"],
                usageCount: index
            )
        }
        let hints = ParticleAwareReplacer.appleHints(from: entries, limit: 100)
        XCTAssertEqual(hints.count, 100)
        XCTAssertEqual(hints.first, "표제어120")
    }

    func testStartBoundaryRejectsAttachedHangul() {
        let text = ParticleAwareReplacer.apply("내스위프트 데이터로", entries: [swiftdata])
        XCTAssertEqual(text, "내스위프트 데이터로")
    }

    func testPreservesStackedParticles() {
        XCTAssertEqual(
            ParticleAwareReplacer.apply("스위프트 데이터에서는 좀 불편했다", entries: [swiftdata]),
            "SwiftData에서는 좀 불편했다"
        )
        XCTAssertEqual(
            ParticleAwareReplacer.apply("스위프트 데이터에도", entries: [swiftdata]),
            "SwiftData에도"
        )
        XCTAssertEqual(
            ParticleAwareReplacer.apply("스위프트 데이터로는", entries: [swiftdata]),
            "SwiftData로는"
        )
        XCTAssertEqual(
            ParticleAwareReplacer.apply("스위프트 데이터만의", entries: [swiftdata]),
            "SwiftData만의"
        )
        XCTAssertEqual(
            ParticleAwareReplacer.apply("스위프트 데이터를 써서", entries: [swiftdata]),
            "SwiftData를 써서"
        )
    }

    func testUnknownAttachedHangulIsLeftAlone() {
        XCTAssertEqual(
            ParticleAwareReplacer.apply("스위프트 데이터만두", entries: [swiftdata]),
            "스위프트 데이터만두"
        )
        XCTAssertEqual(
            ParticleAwareReplacer.apply("스위프트 데이터링", entries: [swiftdata]),
            "스위프트 데이터링"
        )
        XCTAssertEqual(
            ParticleAwareReplacer.apply("스위프트 데이터아이콘", entries: [swiftdata]),
            "스위프트 데이터아이콘"
        )
    }

    func testPreservesCopulaIbNida() {
        let mason = LexiconEntry(replacement: "Mason", aliases: ["메이슨"])
        XCTAssertEqual(
            ParticleAwareReplacer.apply("안녕하세요 메이슨입니다.", entries: [mason]),
            "안녕하세요 Mason입니다."
        )
        XCTAssertEqual(
            ParticleAwareReplacer.apply("메이슨이에요.", entries: [mason]),
            "Mason이에요."
        )
        XCTAssertEqual(
            ParticleAwareReplacer.apply("메이슨인 것 같아", entries: [mason]),
            "Mason인 것 같아"
        )
    }

    func testPreservesCommonCopulaAttachments() {
        let mason = LexiconEntry(replacement: "Mason", aliases: ["메이슨"])
        XCTAssertEqual(
            ParticleAwareReplacer.apply("메이슨이라 했어", entries: [mason]),
            "Mason이라 했어"
        )
        XCTAssertEqual(
            ParticleAwareReplacer.apply("메이슨이니까", entries: [mason]),
            "Mason이니까"
        )
        XCTAssertEqual(
            ParticleAwareReplacer.apply("메이슨이었어요", entries: [mason]),
            "Mason이었어요"
        )
        XCTAssertEqual(
            ParticleAwareReplacer.apply("메이슨이세요?", entries: [mason]),
            "Mason이세요?"
        )
        XCTAssertEqual(
            ParticleAwareReplacer.apply("메이슨이네요", entries: [mason]),
            "Mason이네요"
        )
        XCTAssertEqual(
            ParticleAwareReplacer.apply("메이슨이잖아", entries: [mason]),
            "Mason이잖아"
        )
        XCTAssertEqual(
            ParticleAwareReplacer.apply("메이슨아", entries: [mason]),
            "Mason아"
        )
        XCTAssertEqual(
            ParticleAwareReplacer.apply("CTA들", entries: [cta]),
            "CTA들"
        )
    }

    func testLatinStemDoesNotMatchInsideLatinToken() {
        let text = ParticleAwareReplacer.apply("CTABC", entries: [cta])
        XCTAssertEqual(text, "CTABC")
    }
}
