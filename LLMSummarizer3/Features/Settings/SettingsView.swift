import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var apiKeyInput: String = ""
    @State private var showSavedToast = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Provider") {
                    HStack {
                        Text("Provider")
                        Spacer()
                        Text("Gemini").foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("aid.settings.provider")

                    Picker("Model", selection: $settings.model) {
                        ForEach(SettingsStore.geminiModels, id: \.self) { m in
                            Text(m).tag(m)
                        }
                    }
                    .accessibilityIdentifier("aid.settings.model")
                }

                Section("Summary Format") {
                    Picker("Format", selection: $settings.promptPreset) {
                        ForEach(PromptPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .accessibilityIdentifier("aid.settings.promptFormat")
                    Text("カスタムプロンプトが空の場合、この形式が使用されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("") {
                    Text("Gemini API Key")
                    SecureField("AIza...", text: $apiKeyInput)
                        .accessibilityIdentifier("aid.settings.apiKey")
                        .focused($focused)
                    HStack {
                        if !settings.apiKeyMasked.isEmpty { Text("保存済み: \(settings.apiKeyMasked)").foregroundStyle(.secondary) }
                        Spacer()
                        Button("Save") { saveKey() }.disabled(apiKeyInput.isEmpty)
                    }
                }

                Section("Custom Prompt") {
                    TextEditor(text: $settings.customPrompt)
                        .frame(minHeight: 120)
                        .accessibilityIdentifier("aid.settings.prompt")
                    HStack {
                        Spacer()
                        Button("デフォルトに戻す") {
                            settings.resetPromptToDefault()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar { if focused { ToolbarItem(placement: .keyboard) { Button("Done") { focused = false } } } }
        }
    }

    private func saveKey() {
        do {
            try settings.setAPIKey(apiKeyInput, for: .gemini)
            apiKeyInput = ""
        } catch { /* surface via UI if needed */ }
    }
}
