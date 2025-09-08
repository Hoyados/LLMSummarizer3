import Foundation
import SwiftData

protocol SummaryRepository {
    @discardableResult
    func save(url: URL, title: String, summary: String, modelId: String, promptId: String?, isUnread: Bool) async throws -> SummaryItem
    func list() async throws -> [SummaryItem]
    func delete(_ item: SummaryItem) async throws
    func togglePin(_ item: SummaryItem) async throws
    func markRead(_ item: SummaryItem) async throws
}

final class SwiftDataSummaryRepository: SummaryRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(url: URL, title: String, summary: String, modelId: String, promptId: String?, isUnread: Bool = false) async throws -> SummaryItem {
        let domain = url.host ?? url.absoluteString
        let item = SummaryItem(url: url, domain: domain, title: title, summary: summary, modelId: modelId, promptId: promptId, isUnread: isUnread)
        context.insert(item)
        try context.save()
        return item
    }

    func list() async throws -> [SummaryItem] {
        let descriptor = FetchDescriptor<SummaryItem>()
        let fetched = (try? context.fetch(descriptor)) ?? []
        return fetched.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned && !rhs.pinned }
            return lhs.createdAt > rhs.createdAt
        }
    }

    func delete(_ item: SummaryItem) async throws {
        context.delete(item)
        try context.save()
    }

    func togglePin(_ item: SummaryItem) async throws {
        item.pinned.toggle()
        try context.save()
    }

    func markRead(_ item: SummaryItem) async throws {
        item.isUnread = false
        try context.save()
    }
}
