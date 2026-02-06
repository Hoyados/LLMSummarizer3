import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var settings: SettingsStore
    @Query private var items: [SummaryItem]
    @State private var searchText: String = ""
    @State private var pinFilter: HistoryPinFilter = .all
    @State private var dateFilter: HistoryDateFilter = .all
    @State private var selectedDomain: String = "All"

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredItems) { item in
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
                                if !item.tags.isEmpty {
                                    Text(item.tags.joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
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
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                EditButton()
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Pinned", selection: $pinFilter) {
                            ForEach(HistoryPinFilter.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        Picker("Date", selection: $dateFilter) {
                            ForEach(HistoryDateFilter.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        Picker("Domain", selection: $selectedDomain) {
                            Text("All").tag("All")
                            ForEach(availableDomains, id: \.self) { domain in
                                Text(domain).tag(domain)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }

    private var availableDomains: [String] {
        Array(Set(items.map(\.domain))).sorted()
    }

    private var filteredItems: [SummaryItem] {
        var result = items
        if pinFilter == .pinned {
            result = result.filter { $0.pinned }
        } else if pinFilter == .unpinned {
            result = result.filter { !$0.pinned }
        }
        if dateFilter != .all {
            let cutoff = Calendar.current.date(byAdding: .day, value: -dateFilter.days, to: Date()) ?? Date()
            result = result.filter { $0.createdAt >= cutoff }
        }
        if selectedDomain != "All" {
            result = result.filter { $0.domain == selectedDomain }
        }
        if !searchText.isEmpty {
            let term = searchText.lowercased()
            result = result.filter { item in
                item.title.lowercased().contains(term)
                    || item.domain.lowercased().contains(term)
                    || item.tags.joined(separator: " ").lowercased().contains(term)
            }
        }
        return result.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned && !b.pinned }
            return a.createdAt > b.createdAt
        }
    }

    private func deleteFromSorted(at offsets: IndexSet) {
        for index in offsets { context.delete(filteredItems[index]) }
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
    @State private var tagInput: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.title).font(.title3).bold()
                Text(item.summary)
                if !item.tags.isEmpty {
                    Text(item.tags.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tags").font(.caption).foregroundStyle(.secondary)
                    TextField("news, work, reading", text: $tagInput)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Save Tags") { saveTags() }
                        Spacer()
                    }
                }
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
            tagInput = item.tags.joined(separator: ", ")
        }
    }

    private func reSummarize() async {
        guard let url = URL(string: item.url.absoluteString) else { return }
        isSummarizing = true
        do {
            let useCase = try env.makeUseCase(context: context, settings: settings)
            let template = settings.promptTemplate()
            _ = try await useCase.execute(url: url, template: template)
            errorMsg = nil
        } catch {
            errorMsg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isSummarizing = false
    }

    private func saveTags() {
        let tags = tagInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        item.tags = Array(Set(tags)).sorted()
        try? context.save()
    }
}

enum HistoryPinFilter: String, CaseIterable, Identifiable {
    case all
    case pinned
    case unpinned

    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .pinned: return "Pinned"
        case .unpinned: return "Unpinned"
        }
    }
}

enum HistoryDateFilter: String, CaseIterable, Identifiable {
    case all
    case last7Days
    case last30Days

    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        }
    }

    var days: Int {
        switch self {
        case .all: return 0
        case .last7Days: return 7
        case .last30Days: return 30
        }
    }
}
