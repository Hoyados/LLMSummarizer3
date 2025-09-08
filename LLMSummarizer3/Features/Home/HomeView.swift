import SwiftUI
import SwiftData
import UIKit

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var settings: SettingsStore

    @State private var urlInputs: [String] = Array(repeating: "", count: 5)
    @State private var isRunning = false
    @State private var status: String = ""
    @State private var showSettingsAlert = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(0..<5, id: \.self) { idx in
                    HStack(spacing: 8) {
                        TextField("https://example.com/article", text: $urlInputs[idx])
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier(idx == 0 ? "aid.home.urlField" : (idx == 1 ? "aid.home.urlField2" : "aid.home.urlField3"))
                        if idx == 0 {
                            Button("Paste") {
                                if let s = UIPasteboard.general.string { urlInputs[idx] = s }
                            }
                            .accessibilityIdentifier("aid.home.pasteButton")
                        } else {
                            Button("Paste") {
                                if let s = UIPasteboard.general.string { urlInputs[idx] = s }
                            }
                        }
                        Button("Summarize") { summarizeSingle(idx) }
                            .buttonStyle(.borderedProminent)
                    }
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
        let targets = urlInputs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !targets.isEmpty else { return }
        summarize(urls: targets)
        urlInputs = Array(repeating: "", count: 5)
    }

    private func summarize(urls: [String]) {
        guard let key = try? settings.getAPIKey(for: .gemini), !key.isEmpty else {
            showSettingsAlert = true
            return
        }
        isRunning = true
        status = "Processing \(urls.count) URL(s)..."
        Task {
            var ok = 0, ng = 0
            for s in urls {
                guard let url = URL(string: s), url.scheme?.hasPrefix("http") == true else { ng += 1; continue }
                do {
                    let useCase = try env.makeUseCase(context: context, settings: settings)
                    let template: PromptTemplate = settings.customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? .default
                        : PromptTemplate(system: PromptTemplate.default.system, userBase: settings.customPrompt)
                    let item = try await useCase.execute(url: url, template: template)
                    item.isUnread = true
                    try? context.save()
                    ok += 1
                } catch {
                    ng += 1
                }
            }
            isRunning = false
            status = "Done: \(ok) success, \(ng) failed"
        }
    }
}
