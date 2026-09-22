import Foundation

struct Note: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var body: String
    var richTextData: Data?
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        title: String = "Untitled",
        body: String = "",
        richTextData: Data? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.richTextData = richTextData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
    }

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty { return trimmedTitle }
        let firstLine = body.split(separator: "\n").first.map(String.init) ?? ""
        return firstLine.isEmpty ? "Untitled" : String(firstLine.prefix(48))
    }

    var preview: String {
        let flattened = body
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"[#*_>`~-]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return flattened.isEmpty ? "No additional text" : flattened
    }
}
