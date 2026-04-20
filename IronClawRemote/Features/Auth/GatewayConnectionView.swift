import SwiftUI

struct GatewayConnectionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var baseURL = ""
    @State private var token = ""
    @State private var isTesting = false
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Gateway") {
                    TextField("Display name", text: $name)
                    TextField("Base URL", text: $baseURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    SecureField("Token", text: $token)
                }

                Section {
                    Button("Save Connection") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)

                    Button(isTesting ? "Testing…" : "Test Connection") {
                        Task { await testConnection() }
                    }
                    .disabled(isTesting)
                }

                if let validationMessage {
                    Section("Status") {
                        Text(validationMessage)
                            .foregroundStyle(ICColor.danger)
                    }
                } else if let error = appState.session.lastErrorMessage {
                    Section("Status") {
                        Text(error)
                            .foregroundStyle(ICColor.danger)
                    }
                } else if let profile = appState.session.profile {
                    Section("Connected") {
                        LabeledContent("Name", value: profile.displayName)
                        if let email = profile.email {
                            LabeledContent("Email", value: email)
                        }
                    }
                }
            }
            .navigationTitle("Connect")
            .onAppear {
                name = appState.gatewayConfiguration.name
                baseURL = appState.gatewayConfiguration.baseURL.absoluteString
                token = appState.gatewayConfiguration.token
            }
        }
    }

    private func save() {
        guard let configuration = validatedConfiguration() else { return }
        validationMessage = nil
        appState.gatewayConfiguration = configuration
        dismiss()
    }

    private func testConnection() async {
        guard let configuration = validatedConfiguration() else { return }
        validationMessage = nil
        isTesting = true
        appState.gatewayConfiguration = configuration
        await appState.refreshProfile()
        isTesting = false
    }

    private func validatedConfiguration() -> GatewayConfiguration? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedBaseURL.isEmpty else {
            validationMessage = "Enter a gateway URL."
            return nil
        }

        guard let url = URL(string: trimmedBaseURL), let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) else {
            validationMessage = "Enter a valid http or https gateway URL."
            return nil
        }

        if trimmedToken.isEmpty, GatewayConfiguration.isDemoURL(url) {
            return GatewayConfiguration(
                name: trimmedName.isEmpty ? "IronClaw Demo" : trimmedName,
                baseURL: url,
                token: ""
            )
        }

        guard !trimmedToken.isEmpty else {
            validationMessage = "Enter a gateway token."
            return nil
        }

        return GatewayConfiguration(
            name: trimmedName.isEmpty ? "IronClaw Gateway" : trimmedName,
            baseURL: url,
            token: trimmedToken
        )
    }
}
