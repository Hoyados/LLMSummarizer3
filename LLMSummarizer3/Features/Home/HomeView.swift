import SwiftUI
import SwiftData
import UIKit

struct HomeView: View {
    private static let maxInputs = 5

    @Environment(\.modelContext) private var context
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var settings: SettingsStore

    @State private var urlInputs: [String] = Array(repeating: "", count: Self.maxInputs)
    @State private var status: String = ""
    @State private var showSettingsAlert = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
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
                    do {
                        let item = try await useCase.execute(url: url, template: template)
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
        if let s = UIPasteboard.general.string { urlInputs[index] = s }
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
