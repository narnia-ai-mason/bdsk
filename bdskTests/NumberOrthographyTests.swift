import XCTest
@testable import bdsk

final class NumberOrthographyTests: XCTestCase {
    func testFindsDigitClassifierSpan() {
        let choices = NumberOrthography.findChoices(in: "1가지 사실을 말씀드리겠습니다.")
        XCTAssertEqual(choices.count, 1)
        XCTAssertEqual(choices[0].digitForm, "1가지")
        XCTAssertEqual(choices[0].nativeForm, "한 가지")
        XCTAssertFalse(choices[0].prefersNative)
    }

    func testNativeFormUsesConventionalSpace() {
        let choices = NumberOrthography.findChoices(in: "1분 손님이 있습니다.")
        XCTAssertEqual(choices.count, 1)
        XCTAssertEqual(choices[0].digitForm, "1분")
        XCTAssertEqual(choices[0].nativeForm, "한 분")
    }

    func testFindsSpacedDigitClassifier() {
        let choices = NumberOrthography.findChoices(in: "한 문장에 1 분이 있습니다.")
        XCTAssertEqual(choices.count, 1)
        XCTAssertEqual(choices[0].digitForm, "1 분")
        XCTAssertEqual(choices[0].nativeForm, "한 분")
    }

    func testApplyReplacesSelectedSpans() {
        let text = "1분 2분 손님이 있습니다."
        var choices = NumberOrthography.findChoices(in: text)
        XCTAssertEqual(choices.count, 2)
        choices[0].prefersNative = true
        choices[1].prefersNative = true
        XCTAssertEqual(
            NumberOrthography.apply(choices, to: text),
            "한 분 두 분 손님이 있습니다."
        )
    }

    func testApplyLeavesEngineOutputByDefault() {
        let text = "1가지 사실"
        let choices = NumberOrthography.findChoices(in: text)
        XCTAssertEqual(NumberOrthography.apply(choices, to: text), text)
    }

    func testIgnoresNumbersWithoutClassifier() {
        XCTAssertTrue(NumberOrthography.findChoices(in: "회의는 3층입니다.").isEmpty)
        XCTAssertTrue(NumberOrthography.findChoices(in: "버전 12 배포").isEmpty)
    }

    func testNativeAttributiveBasics() {
        XCTAssertEqual(NumberOrthography.nativeAttributive(1), "한")
        XCTAssertEqual(NumberOrthography.nativeAttributive(2), "두")
        XCTAssertEqual(NumberOrthography.nativeAttributive(20), "스무")
        XCTAssertEqual(NumberOrthography.nativeAttributive(21), "스물한")
    }
}
