import SwiftUI

struct ExtensionSetupView: View {
    let extensionName: String

    @Environment(AppState.self) private var appState
    @State private var setup: ExtensionSetupResponseDTO?
    @State private var secretValues: [String: String] = [:]
    @State private var fieldValues: [String: String] = [:]
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if let actionMessage {
                Section {
                    Text(actionMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.success)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                }
            }

            if let setup {
                if !setup.secrets.isEmpty {
                    Section("Secrets") {
                        ForEach(setup.secrets) { secret in
                            VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                Text(secret.prompt)
                                    .font(.subheadline.weight(.medium))
                                if secret.provided {
                                    Text("已提供")
                                        .font(.caption)
                                        .foregroundStyle(ICColor.success)
                                } else {
                                    if secret.autoGenerate {
                                        Text("将自动生成")
                                            .font(.caption)
                                            .foregroundStyle(ICColor.textSecondary)
                                    } else {
                                        SecureField("输入值", text: secretBinding(for: secret.name))
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                    }
                                }
                                if secret.optional {
                                    Text("可选")
                                        .font(.caption2)
                                        .foregroundStyle(ICColor.textSecondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                if !setup.fields.isEmpty {
                    Section("配置项") {
                        ForEach(setup.fields) { field in
                            VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                Text(field.prompt)
                                    .font(.subheadline.weight(.medium))
                                if field.provided {
                                    Text("已提供")
                                        .font(.caption)
                                        .foregroundStyle(ICColor.success)
                                } else {
                                    if field.inputType == .password {
                                        SecureField("输入值", text: fieldBinding(for: field.name))
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                    } else {
                                        TextField("输入值", text: fieldBinding(for: field.name))
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                    }
                                }
                                if field.optional {
                                    Text("可选")
                                        .font(.caption2)
                                        .foregroundStyle(ICColor.textSecondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section {
                    Button(isSubmitting ? "提交中…" : "提交配置") {
                        Task { await submit() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting)
                }
            } else if isLoading {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                Section {
                    Text("无可配置的项")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                }
            }
        }
        .navigationTitle("\(extensionName) 配置")
        .task {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if appState.gatewayConfiguration.isDemoMode {
            setup = nil
            return
        }

        do {
            setup = try await appState.gatewayClient.extensionSetup(name: extensionName)
        } catch {
            setup = nil
            errorMessage = error.localizedDescription
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let response = try await appState.gatewayClient.submitExtensionSetup(
                name: extensionName,
                secrets: secretValues,
                fields: fieldValues
            )
            actionMessage = response.message
            if response.success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    dismiss()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func secretBinding(for key: String) -> Binding<String> {
        Binding(
            get: { secretValues[key, default: ""] },
            set: { secretValues[key] = $0 }
        )
    }

    private func fieldBinding(for key: String) -> Binding<String> {
        Binding(
            get: { fieldValues[key, default: ""] },
            set: { fieldValues[key] = $0 }
        )
    }
}
