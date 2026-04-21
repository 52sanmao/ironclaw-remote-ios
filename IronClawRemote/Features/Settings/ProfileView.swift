import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var profile: GatewayProfile?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var editDisplayName = ""
    @State private var showEditSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: ICSpacing.lg) {
                if let actionMessage {
                    statusBanner(message: actionMessage, color: ICColor.success, icon: "checkmark.circle.fill")
                }

                if let errorMessage {
                    statusBanner(message: errorMessage, color: ICColor.danger, icon: "exclamationmark.triangle.fill")
                }

                if let profile {
                    profileCard(profile)
                    metadataCard(profile)
                    actionsCard
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(ICSpacing.xl)
                } else {
                    ContentUnavailableView("暂无资料", systemImage: "person.crop.circle.badge.questionmark")
                        .padding(.top, ICSpacing.xl)
                }
            }
            .padding(ICSpacing.md)
        }
        .background(ICColor.background)
        .navigationTitle("个人资料")
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                Form {
                    Section("显示名称") {
                        TextField("名称", text: $editDisplayName)
                            .textInputAutocapitalization(.never)
                    }
                }
                .navigationTitle("编辑资料")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showEditSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            Task { await saveDisplayName() }
                        }
                        .disabled(editDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    }
                }
            }
        }
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func profileCard(_ profile: GatewayProfile) -> some View {
        VStack(spacing: ICSpacing.md) {
            HStack(spacing: ICSpacing.md) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(ICColor.accent)

                VStack(alignment: .leading, spacing: ICSpacing.xs) {
                    Text(profile.displayName)
                        .font(.title3.bold())
                        .foregroundStyle(ICColor.textPrimary)

                    HStack(spacing: ICSpacing.xs) {
                        if let role = profile.role, !role.isEmpty {
                            ConsoleBadge(text: role, color: role.lowercased() == "admin" ? ICColor.accent : ICColor.textSecondary)
                        }
                        if let status = profile.status, !status.isEmpty {
                            ConsoleBadge(text: status, color: status.lowercased() == "active" ? ICColor.success : ICColor.warning)
                        }
                    }
                }
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: ICSpacing.sm) {
                infoRow(icon: "envelope", label: "邮箱", value: profile.email)
                infoRow(icon: "briefcase", label: "角色", value: profile.role)
                infoRow(icon: "checkmark.shield", label: "状态", value: profile.status)
            }
        }
        .padding(ICSpacing.md)
        .background(ICColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func metadataCard(_ profile: GatewayProfile) -> some View {
        VStack(alignment: .leading, spacing: ICSpacing.md) {
            Text("元信息")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ICColor.textSecondary)

            VStack(alignment: .leading, spacing: ICSpacing.sm) {
                infoRow(icon: "calendar", label: "创建时间", value: profile.createdAt)
                infoRow(icon: "clock.arrow.circlepath", label: "最近登录", value: profile.lastLoginAt)
            }
        }
        .padding(ICSpacing.md)
        .background(ICColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var actionsCard: some View {
        VStack(spacing: ICSpacing.sm) {
            Button {
                editDisplayName = profile?.displayName ?? ""
                showEditSheet = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                        .foregroundStyle(ICColor.accent)
                    Text("编辑显示名称")
                        .foregroundStyle(ICColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                }
                .padding(ICSpacing.md)
                .background(ICColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func infoRow(icon: String, label: String, value: String?) -> some View {
        HStack(spacing: ICSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(ICColor.textSecondary)
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .foregroundStyle(ICColor.textSecondary)
            Spacer()
            Text(value ?? "—")
                .font(.subheadline)
                .foregroundStyle(ICColor.textPrimary)
        }
    }

    private func statusBanner(message: String, color: Color, icon: String) -> some View {
        HStack(spacing: ICSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(message)
                .font(.caption)
                .foregroundStyle(color)
            Spacer()
        }
        .padding(ICSpacing.md)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if appState.gatewayConfiguration.isDemoMode {
            profile = GatewayProfile(displayName: "演示用户", role: "admin", status: "active")
            return
        }

        do {
            profile = try await appState.gatewayClient.profile()
            if let p = profile {
                appState.session.profile = p
            }
        } catch {
            profile = nil
            errorMessage = error.localizedDescription
        }
    }

    private func saveDisplayName() async {
        let name = editDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let response = try await appState.gatewayClient.updateProfile(displayName: name)
            actionMessage = "已更新为 \(response.displayName)"
            showEditSheet = false
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
