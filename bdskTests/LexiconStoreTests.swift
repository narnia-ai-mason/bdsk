import XCTest
@testable import bdsk

@MainActor
final class LexiconStoreTests: XCTestCase {
    private var fileURL: URL!
    private var store: LexiconStore!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lexicon-\(UUID().uuidString).json")
        store = LexiconStore(fileURL: fileURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    func testAddCreatesNewEntry() {
        let outcome = store.add(replacement: "GitHub", aliases: ["깃허브"])
        guard case .added(let entry) = outcome else {
            return XCTFail("expected a new entry")
        }
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(entry.replacement, "GitHub")
        XCTAssertTrue(entry.aliases.contains("깃허브"))
    }

    func testAddMergesAliasesForSameReplacement() {
        _ = store.add(replacement: "GitHub", aliases: ["깃허브"])
        let outcome = store.add(replacement: "GitHub", aliases: ["기터브"])
        guard case .merged(let entry) = outcome else {
            return XCTFail("expected aliases to merge")
        }
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(entry.replacement, "GitHub")
        XCTAssertTrue(entry.aliases.contains("깃허브"))
        XCTAssertTrue(entry.aliases.contains("기터브"))
    }

    func testAddMergesCaseInsensitiveReplacementAndKeepsOriginalSpelling() {
        _ = store.add(replacement: "GitHub", aliases: ["깃허브"])
        let outcome = store.add(replacement: "github", aliases: ["깃헙"])
        guard case .merged(let entry) = outcome else {
            return XCTFail("expected case-insensitive merge")
        }
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(entry.replacement, "GitHub")
        XCTAssertTrue(entry.aliases.contains("깃헙"))
    }

    func testAddDoesNotDuplicateExistingAlias() {
        _ = store.add(replacement: "GitHub", aliases: ["깃허브"])
        let outcome = store.add(replacement: "GitHub", aliases: ["깃허브", "기터브"])
        guard case .merged(let entry) = outcome else {
            return XCTFail("expected merge")
        }
        XCTAssertEqual(entry.aliases.filter { $0 == "깃허브" }.count, 1)
        XCTAssertTrue(entry.aliases.contains("기터브"))
    }

    func testAddKeepsDistinctReplacementsSeparate() {
        _ = store.add(replacement: "GitHub", aliases: ["깃허브"])
        let outcome = store.add(replacement: "PR", aliases: ["피알"])
        guard case .added = outcome else {
            return XCTFail("expected a second entry")
        }
        XCTAssertEqual(store.entries.count, 2)
    }

    func testMatchingFiltersByReplacementSubstring() {
        _ = store.add(replacement: "GitHub", aliases: ["깃허브"])
        _ = store.add(replacement: "Notion", aliases: ["노션"])
        _ = store.add(replacement: "PR", aliases: ["피알"])
        let hits = LexiconStore.matching(store.entries, replacementQuery: "not")
        XCTAssertEqual(hits.map(\.replacement), ["Notion"])
    }

    func testMatchingBlankQueryReturnsAll() {
        _ = store.add(replacement: "GitHub", aliases: ["깃허브"])
        _ = store.add(replacement: "PR", aliases: ["피알"])
        let hits = LexiconStore.matching(store.entries, replacementQuery: "  ")
        XCTAssertEqual(hits.count, 2)
    }

    func testMatchingDoesNotSearchAliases() {
        _ = store.add(replacement: "GitHub", aliases: ["깃허브"])
        let hits = LexiconStore.matching(store.entries, replacementQuery: "깃허브")
        XCTAssertTrue(hits.isEmpty)
    }

    func testMergePersistsToDisk() {
        _ = store.add(replacement: "GitHub", aliases: ["깃허브"])
        _ = store.add(replacement: "GitHub", aliases: ["기터브"])
        let reloaded = LexiconStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.entries.count, 1)
        XCTAssertEqual(reloaded.entries[0].replacement, "GitHub")
        XCTAssertTrue(reloaded.entries[0].aliases.contains("깃허브"))
        XCTAssertTrue(reloaded.entries[0].aliases.contains("기터브"))
    }
}
