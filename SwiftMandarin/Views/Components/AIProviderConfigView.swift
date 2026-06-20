//
//  AIProviderConfigView.swift
//  SwiftMandarin
//
//  Shared, cross-platform configuration UI for the selected AI provider.
//  Embedded inside the Form of both the macOS Settings tab and the iOS AI
//  settings screen so the two stay in sync. Renders the right controls for
//  Apple Intelligence, Ollama, or any cloud provider (API key, base URL,
//  model picker with API-fetched lists).
//

import SwiftUI

struct AIProviderConfigView: View {
    @Bindable var settings: AIModelSettings

    @State private var ollamaService = OllamaService.shared
    @State private var cloudService = CloudAIService.shared
    @State private var isRefreshing = false

    /// Result of the cloud "Test Connection" round-trip.
    private enum ConnectionTestState: Equatable {
        case idle
        case testing
        case success(model: String)
        case failure(message: String)
    }
    @State private var connectionTest: ConnectionTestState = .idle

    var body: some View {
        Group {
            switch settings.provider {
            case .appleIntelligence:
                appleSection
            case .ollama:
                ollamaSections
            default:
                cloudSections
            }
        }
        .task(id: settings.provider) {
            connectionTest = .idle
            await settings.refreshConnection()
        }
    }

    // MARK: - Apple Intelligence

    private var appleSection: some View {
        Section {
            if settings.isAppleIntelligenceAvailable {
                Label("Apple Intelligence is ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label {
                    Text(AIWordExplanationService.shared.unavailabilityReason ?? "Apple Intelligence is not available")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Apple Intelligence")
        } footer: {
            Text("Uses on-device Foundation Models for privacy-focused AI.")
        }
    }

    // MARK: - Ollama

    @ViewBuilder
    private var ollamaSections: some View {
        Section {
            LabeledContent("Server URL") {
                TextField("http://localhost:11434", text: $settings.ollamaHost)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                    #if os(iOS)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    #endif
            }
            refreshButton(title: "Test Connection") {
                await settings.refreshConnection()
            }
        } header: {
            Text("Ollama Server")
        }

        Section {
            if ollamaService.availableModels.isEmpty {
                if ollamaService.isLoadingModels {
                    HStack { ProgressView(); Text("Loading models…").foregroundStyle(.secondary) }
                } else if !ollamaService.isConnected {
                    Label("Not connected to Ollama", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                } else {
                    Text("No models found").foregroundStyle(.secondary)
                }
            } else {
                Picker("Model", selection: $settings.ollamaModel) {
                    ForEach(ollamaService.availableModels) { model in
                        Text("\(model.name) · \(model.parameterSize)").tag(model.name)
                    }
                }
                #if os(iOS)
                .pickerStyle(.navigationLink)
                #endif
            }
            Button {
                Task { await ollamaService.refreshModels() }
            } label: {
                Label("Refresh Models", systemImage: "arrow.clockwise")
            }
            .disabled(ollamaService.isLoadingModels || !ollamaService.isConnected)
        } header: {
            Text("Model")
        } footer: {
            Text("Recommended: gpt-oss:20b for best quality.")
        }

        Section {
            Toggle("Enable Reasoning", isOn: $settings.enableThinking)
            Picker("Context Length", selection: $settings.contextLength) {
                Text("8K").tag(8000)
                Text("32K").tag(32000)
                Text("64K").tag(64000)
                Text("128K").tag(128000)
            }
        } header: {
            Text("Advanced")
        }
    }

    // MARK: - Cloud Providers

    @ViewBuilder
    private var cloudSections: some View {
        let provider = settings.provider

        Section {
            // `.id(provider)` forces a fresh field per provider so the editor
            // always shows (and writes to) the selected provider's own key,
            // which is persisted separately in the Keychain.
            SecureField("API Key", text: apiKeyBinding(for: provider))
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #endif
                .id(provider)
            if let urlString = provider.apiKeyURL, let url = URL(string: urlString) {
                Link(destination: url) {
                    Label("Get an API key", systemImage: "key")
                }
            }
        } header: {
            Text("\(provider.displayName) API Key")
                .fitSingleLine()
        } footer: {
            Text("Stored securely in the Keychain, separately for each provider. \(provider.description).")
        }

        Section {
            // Label above a full-width field so long URLs render on one line
            // instead of wrapping inside a narrow trailing column.
            VStack(alignment: .leading, spacing: 6) {
                Text("Base URL")
                TextField(provider.defaultBaseURL, text: baseURLBinding(for: provider))
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    #if os(iOS)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    #endif
            }
            .id(provider)

            Picker("API Format", selection: apiStyleBinding(for: provider)) {
                Text("Default (\(defaultStyleLabel(provider)))").tag(String?.none)
                Text("OpenAI-compatible").tag(String?.some("openai"))
                Text("Anthropic (e.g. Kimi coding)").tag(String?.some("anthropic"))
            }
        } header: {
            Text("Endpoint")
        } footer: {
            Text("Leave as default unless using a proxy, self-hosted gateway, or an Anthropic-compatible endpoint (e.g. DeepSeek/GLM at …/anthropic, or a Kimi coding plan at …/coding — then set API Format to Anthropic).")
        }

        Section {
            Picker("Model", selection: modelBinding(for: provider)) {
                ForEach(cloudModelOptions(for: provider), id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            #if os(iOS)
            .pickerStyle(.navigationLink)
            #endif

            TextField("Custom model ID", text: modelBinding(for: provider))
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #endif

            Button {
                Task {
                    isRefreshing = true
                    await cloudService.refreshModels(for: provider)
                    isRefreshing = false
                }
            } label: {
                HStack {
                    Label("Refresh Models", systemImage: "arrow.clockwise")
                    if isRefreshing { Spacer(); ProgressView().controlSize(.small) }
                }
            }
            .disabled(settings.apiKey(for: provider).isEmpty || isRefreshing)
        } header: {
            Text("Model")
        } footer: {
            if let error = cloudService.error(for: provider) {
                Text(error).foregroundStyle(.red)
            } else if provider.modelsPath == nil {
                Text("This provider has no model-list endpoint; showing curated defaults. Enter a custom model ID if needed.")
            } else {
                Text("Tap Refresh Models to fetch the live model list from the provider.")
            }
        }

        Section {
            Button {
                Task { await testConnection(provider) }
            } label: {
                HStack {
                    Label("Test Connection", systemImage: "bolt.horizontal")
                    if connectionTest == .testing {
                        Spacer()
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(settings.apiKey(for: provider).isEmpty || connectionTest == .testing)

            switch connectionTest {
            case .success(let model):
                Label {
                    Text("Connected — \(model) responded")
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
                .font(.caption)
            case .failure(let message):
                Label {
                    Text(message)
                } icon: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                }
                .font(.caption)
            case .idle, .testing:
                EmptyView()
            }

            // Capability overview so users learn BEFORE a failed workbook
            // grading whether this provider can read images.
            HStack(spacing: 12) {
                capabilityBadge("Vision", available: provider.supportsVision, icon: "photo")
                capabilityBadge("JSON mode", available: provider.supportsJSONResponseFormat, icon: "curlybraces")
            }
        } header: {
            Text("Connection & Capabilities")
        } footer: {
            if !provider.supportsVision {
                Text("This provider cannot read images, so photo cleanup against the image and workbook grading will use a different vision-capable provider if one is configured.")
            }
        }
    }

    /// Send a minimal round-trip request to verify key, endpoint, and model.
    private func testConnection(_ provider: AIProvider) async {
        connectionTest = .testing
        let model = settings.selectedModel(for: provider)
        do {
            _ = try await CloudAIService.shared.chat(
                provider: provider,
                model: model,
                system: "You are a connectivity check.",
                user: "Reply with the single word: OK",
                maxTokens: 32
            )
            connectionTest = .success(model: model)
        } catch {
            connectionTest = .failure(message: error.localizedDescription)
        }
    }

    private func capabilityBadge(_ titleKey: LocalizedStringKey, available: Bool, icon: String) -> some View {
        Label {
            Text(titleKey)
        } icon: {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(available ? .green : .secondary)
        }
        .font(.caption)
        .foregroundStyle(available ? .primary : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(available ? Color.green.opacity(0.1) : Color.secondary.opacity(0.08)))
        .accessibilityLabel(Text(available ? "Supported" : "Not supported"))
    }

    // MARK: - Helpers

    private func refreshButton(title: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { isRefreshing = true; await action(); isRefreshing = false }
        } label: {
            HStack {
                Label(title, systemImage: "arrow.clockwise")
                if isRefreshing { Spacer(); ProgressView().controlSize(.small) }
            }
        }
        .disabled(isRefreshing)
    }

    private func cloudModelOptions(for provider: AIProvider) -> [String] {
        var ids = cloudService.models(for: provider).map { $0.id }
        let selected = settings.selectedModel(for: provider)
        if !selected.isEmpty, !ids.contains(selected) {
            ids.insert(selected, at: 0)
        }
        return ids
    }

    private func apiKeyBinding(for provider: AIProvider) -> Binding<String> {
        Binding(
            get: { settings.apiKey(for: provider) },
            set: { settings.setAPIKey($0, for: provider) }
        )
    }

    private func baseURLBinding(for provider: AIProvider) -> Binding<String> {
        Binding(
            get: { settings.baseURL(for: provider) },
            set: { settings.setBaseURLOverride($0, for: provider) }
        )
    }

    private func modelBinding(for provider: AIProvider) -> Binding<String> {
        Binding(
            get: { settings.selectedModel(for: provider) },
            set: { settings.setSelectedModel($0, for: provider) }
        )
    }

    private func defaultStyleLabel(_ provider: AIProvider) -> String {
        provider.apiStyle == .anthropic ? "Anthropic" : "OpenAI"
    }

    private func apiStyleBinding(for provider: AIProvider) -> Binding<String?> {
        Binding(
            get: {
                switch settings.apiStyleOverride(for: provider) {
                case .anthropic: return "anthropic"
                case .openAICompatible: return "openai"
                case nil: return nil
                }
            },
            set: { raw in
                switch raw {
                case "anthropic": settings.setAPIStyleOverride(.anthropic, for: provider)
                case "openai": settings.setAPIStyleOverride(.openAICompatible, for: provider)
                default: settings.setAPIStyleOverride(nil, for: provider)
                }
            }
        )
    }
}
