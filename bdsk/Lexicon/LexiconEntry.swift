import Foundation

struct LexiconEntry: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var replacement: String
    var aliases: [String]
    var usageCount: Int
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        replacement: String,
        aliases: [String],
        usageCount: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.replacement = replacement
        self.aliases = aliases
        self.usageCount = usageCount
        self.updatedAt = updatedAt
    }

    var stems: [String] {
        aliases
    }
}
