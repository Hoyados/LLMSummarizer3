import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var settings: SettingsStore
    @Query private var items: [SummaryItem]

    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedItems) { item in
                    NavigationLink(destination: HistoryDetailView(item: item)) {
                        HStack(alignment: .top, spacing: 8) {
                            if item.pinned { Image(systemName: "pin.fill").foregroundStyle(.yellow) }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    if item.isUnread { Image(systemName: "circle.fill").font(.system(size: 7)).foregroundStyle(.blue) }
                                    Text(item.title).font(.headline).lineLimit(2)
                                }
                                Text("\(item.domain) • \(item.createdAt.formatted(date: .numeric, time: .shortened))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                context.delete(item); try? context.save()
                            } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .onDelete(perform: deleteFromSorted)
            }
            .accessibilityIdentifier("aid.history.list")
            .navigationTitle("History")
            .toolbar { EditButton() }
        }
    }

    private var sortedItems: [SummaryItem] {
        items.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned && !b.pinned }
            return a.createdAt > b.createdAt
        }
    }

    private func deleteFromSorted(at offsets: IndexSet) {
        for index in offsets { context.delete(sortedItems[index]) }
        try? context.save()
    }
}

struct HistoryDetailView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State var item: SummaryItem
    @State private var isSummarizing = false
    @State private var errorMsg: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.title).font(.title3).bold()
                Text(item.summary)
                HStack {
                    Button(item.pinned ? "Unpin" : "Pin") {
                        item.pinned.toggle(); try? context.save()
                    }
                    Button("Re-Summarize") { Task { await reSummarize() } }
                    .disabled(isSummarizing)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("aid.history.detail")
                }
                if let errorMsg { Text(errorMsg).foregroundStyle(.red) }
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Source URL").font(.caption).foregroundStyle(.secondary)
                    Link(item.url.absoluteString, destination: item.url)
                        .font(.footnote)
                        .textSelection(.enabled)
                }
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        context.delete(item)
                        try? context.save()
                        dismiss()
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
            .padding()
        }
        .navigationTitle("Detail")
        .accessibilityIdentifier("aid.history.detail")
        .onAppear {
            if item.isUnread { item.isUnread = false; try? context.save() }
        }
    }

    private func reSummarize() async {
        guard let url = URL(string: item.url.absoluteString) else { return }
        isSummarizing = true
        do {
            let useCase = try env.makeUseCase(context: context, settings: settings)
            let template: PromptTemplate = settings.customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? .default
                : PromptTemplate(system: PromptTemplate.default.system, userBase: settings.customPrompt)
            _ = try await useCase.execute(url: url, template: template)
            errorMsg = nil
        } catch {
            errorMsg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isSummarizing = false
    }
}
