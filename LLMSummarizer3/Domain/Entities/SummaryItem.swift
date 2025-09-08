import Foundation
import SwiftData

@Model
final class SummaryItem {
    @Attribute(.unique) var id: UUID
    var url: URL
    var domain: String
    var title: String
    var summary: String
    var createdAt: Date
    var modelId: String
    var promptId: String?
    var lang: String?
    var pinned: Bool
    var isUnread: Bool
    @Attribute(.externalStorage) private var tagsBlob: Data = Data()
    @Transient var tags: [String] {
        get { (try? JSONDecoder().decode([String].self, from: tagsBlob)) ?? [] }
        set { tagsBlob = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    init(
        id: UUID = UUID(),
        url: URL,
        domain: String,
        title: String,
        summary: String,
        createdAt: Date = Date(),
        modelId: String,
        promptId: String? = nil,
        lang: String? = nil,
        pinned: Bool = false,
        isUnread: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.url = url
        self.domain = domain
        self.title = title
        self.summary = summary
        self.createdAt = createdAt
        self.modelId = modelId
        self.promptId = promptId
        self.lang = lang ?? Locale.preferredLanguages.first
        self.pinned = pinned
        self.isUnread = isUnread
        self.tags = tags
    }
}
