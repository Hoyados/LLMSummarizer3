import Foundation
import SwiftUI
import SwiftData
import UIKit

struct HomeView: View {
    private static let maxInputs = 5

    @Environment(\.modelContext) private var context
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var urlInputs: [String] = Array(repeating: "", count: Self.maxInputs)
    @State private var status: String = ""
    @State private var showSettingsAlert = false
    @State private var clipboardSuggestion: String?
    @State private var stageDurations: [SummarizeStage: TimeInterval] = [:]
    @State private var activeStage: SummarizeStage?
    @State private var stageStart: Date?
    @State private var activeURL: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let clipboardSuggestion {
                    Button {
                        urlInputs[0] = clipboardSuggestion
                        self.clipboardSuggestion = nil
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.clipboard")
                            Text("Paste \(clipboardSuggestion)")
                                .lineLimit(1)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                }

                ForEach(urlInputs.indices, id: \.self) { idx in
                    URLInputRow(
                        text: $urlInputs[idx],
                        textFieldIdentifier: Self.urlFieldIdentifier(for: idx),
                        pasteIdentifier: idx == 0 ? "aid.home.pasteButton" : nil,
                        onPaste: { pasteFromClipboard(into: idx) },
                        onSummarize: { summarizeSingle(idx) }
                    )
                }

                HStack {
                    Spacer()
                    Button("Summarize All") { summarizeAll() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("aid.home.summarizeButton")
                }

                if !status.isEmpty { Text(status).foregroundStyle(.secondary) }
                if let progressText {
                    Text(progressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("URL要約AI")
            .alert("設定が必要です", isPresented: $showSettingsAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Gemini APIキーを設定してください。")
            }
        }
        .onAppear { refreshClipboardSuggestion() }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active { refreshClipboardSuggestion() }
        }
    }

    private func summarizeSingle(_ idx: Int) {
        let str = urlInputs[idx].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !str.isEmpty else { return }
        summarize(urls: [str])
        urlInputs[idx] = ""
    }

    private func summarizeAll() {
        let targets = urlInputs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !targets.isEmpty else { return }
        summarize(urls: targets)
        urlInputs = Array(repeating: "", count: Self.maxInputs)
    }

    private func summarize(urls: [String]) {
        guard let key = try? settings.getAPIKey(for: .gemini), !key.isEmpty else {
            showSettingsAlert = true
            return
        }
        status = "Processing \(urls.count) URL(s)..."
        Task {
            var ok = 0
            var ng = 0
            let template = settings.promptTemplate()
            do {
                let useCase = try env.makeUseCase(context: context, settings: settings)
                for s in urls {
                    guard let url = validURL(from: s) else {
                        ng += 1
                        continue
                    }
                    await MainActor.run {
                        resetProgress(for: s)
                    }
                    do {
                        let handler: SummarizeProgressHandler = { progress in
                            Task { @MainActor in
                                recordProgress(progress)
                            }
                        }
                        let item = try await useCase.execute(url: url, template: template, progress: handler)
                        item.isUnread = true
                        try? context.save()
                        ok += 1
                    } catch {
                        ng += 1
                    }
                }
            } catch {
                ng = urls.count
            }
            status = "Done: \(ok) success, \(ng) failed"
        }
    }

    private func validURL(from string: String) -> URL? {
        guard let url = URL(string: string), url.scheme?.hasPrefix("http") == true else { return nil }
        return url
    }

    private func pasteFromClipboard(into index: Int) {
        if let s = UIPasteboard.general.string {
            urlInputs[index] = s
            clipboardSuggestion = nil
        }
    }

    private func refreshClipboardSuggestion() {
        guard let s = UIPasteboard.general.string, validURL(from: s) != nil else {
            clipboardSuggestion = nil
            return
        }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clipboardSuggestion = nil
            return
        }
        if urlInputs.contains(trimmed) {
            clipboardSuggestion = nil
        } else {
            clipboardSuggestion = trimmed
        }
    }

    private func resetProgress(for url: String) {
        stageDurations = [:]
        activeStage = nil
        stageStart = nil
        activeURL = url
    }

    private func recordProgress(_ progress: SummarizeProgress) {
        if let activeStage, let stageStart {
            stageDurations[activeStage] = progress.timestamp.timeIntervalSince(stageStart)
        }
        activeStage = progress.stage
        stageStart = progress.timestamp
        if progress.stage == .completed {
            activeURL = nil
        }
    }

    private var progressText: String? {
        guard !stageDurations.isEmpty || activeStage != nil else { return nil }
        var parts: [String] = []
        if let fetch = stageDurations[.fetching] {
            parts.append("Fetch \(format(fetch))")
        }
        if let parse = stageDurations[.parsing] {
            parts.append("Parse \(format(parse))")
        }
        if let summarize = stageDurations[.summarizing] {
            parts.append("Summarize \(format(summarize))")
        }
        if let activeStage, activeStage != .completed, let stageStart {
            let running = Date().timeIntervalSince(stageStart)
            parts.append("\(activeStage.rawValue.capitalized) \(format(running))")
        }
        if let activeURL, let host = URL(string: activeURL)?.host {
            parts.append("URL \(host)")
        }
        return parts.joined(separator: " • ")
    }

    private func format(_ duration: TimeInterval) -> String {
        String(format: "%.1fs", duration)
    }

    private static func urlFieldIdentifier(for index: Int) -> String {
        if index == 0 { return "aid.home.urlField" }
        if index == 1 { return "aid.home.urlField2" }
        return "aid.home.urlField3"
    }
}

private struct URLInputRow: View {
    @Binding var text: String
    let textFieldIdentifier: String
    let pasteIdentifier: String?
    let onPaste: () -> Void
    let onSummarize: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("https://example.com/article", text: $text)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(textFieldIdentifier)
            Button("Paste", action: onPaste)
                .applyAccessibilityIdentifier(pasteIdentifier)
            Button("Summarize", action: onSummarize)
                .buttonStyle(.borderedProminent)
        }
    }
}

private extension View {
    @ViewBuilder
    func applyAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            self.accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}
