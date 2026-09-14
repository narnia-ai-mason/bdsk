import AppKit
import Carbon.HIToolbox
import XCTest
@testable import bdsk

final class NumberReviewKeysTests: XCTestCase {
    func testInterceptsBareNavigationKeys() {
        let keys = [
            kVK_Escape, kVK_Return, kVK_ANSI_KeypadEnter,
            kVK_UpArrow, kVK_DownArrow, kVK_Tab,
            kVK_LeftArrow, kVK_RightArrow
        ]
        for key in keys {
            XCTAssertTrue(
                NumberReviewKeys.intercepts(keyCode: key, flags: []),
                "expected \(key) to be intercepted"
            )
        }
    }

    func testInterceptsShiftTab() {
        XCTAssertTrue(NumberReviewKeys.intercepts(keyCode: kVK_Tab, flags: .shift))
    }

    func testDoesNotStealCommandTab() {
        XCTAssertFalse(NumberReviewKeys.intercepts(keyCode: kVK_Tab, flags: .command))
    }

    func testDoesNotStealModifiedArrows() {
        XCTAssertFalse(NumberReviewKeys.intercepts(keyCode: kVK_LeftArrow, flags: .command))
        XCTAssertFalse(NumberReviewKeys.intercepts(keyCode: kVK_RightArrow, flags: .option))
    }

    func testDoesNotInterceptTypingKeys() {
        XCTAssertFalse(NumberReviewKeys.intercepts(keyCode: kVK_ANSI_A, flags: []))
        XCTAssertFalse(NumberReviewKeys.intercepts(keyCode: kVK_Space, flags: .control))
    }

    func testRepeatOnlyForArrows() {
        XCTAssertTrue(NumberReviewKeys.allowsRepeat(kVK_DownArrow))
        XCTAssertFalse(NumberReviewKeys.allowsRepeat(kVK_Return))
        XCTAssertFalse(NumberReviewKeys.allowsRepeat(kVK_Escape))
        XCTAssertFalse(NumberReviewKeys.allowsRepeat(kVK_Tab))
    }
}
