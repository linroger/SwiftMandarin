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
            SecureField("API Key", text: apiKeyBinding(for: provider))
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #endif
            if let urlString = provider.apiKeyURL, let url = URL(string: urlString) {
                Link(destination: url) {
                    Label("Get an API key", systemImage: "key")
                }
            }
        } header: {
            Text("\(provider.displayName) API Key")
                .fitSingleLine()
        } footer: {
            Text("Stored securely in the Keychain. \(provider.description).")
        }

        Section {
            LabeledContent("Base URL") {
                TextField(provider.defaultBaseURL, text: baseURLBinding(for: provider))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)
                    #if os(iOS)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    #endif
            }

            Picker("API Format", selection: apiStyleBinding(for: provider)) {
                Text("Default (\(defaultStyleLabel(provider)))").tag(String?.none)
                Text("OpenAI-compatible").tag(String?.some("openai"))
                Text("Anthropic (e.g. Kimi coding)").tag(String?.some("anthropic"))
            }
        } header: {
            Text("Endpoint")
        } footer: {
            Text("Leave as default unless using a proxy, self-hosted gateway, or an Anthropic-compatible endpoint (such as a Kimi/Moonshot coding plan — set Base URL to …/anthropic and API Format to Anthropic).")
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

        if provider.supportsVision {
            Section {
                Label("Supports image input (vision) for photo cleanup", systemImage: "photo.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
