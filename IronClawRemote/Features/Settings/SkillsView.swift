import SwiftUI

struct SkillsView: View {
    @Environment(AppState.self) private var appState
    @State private var installedSkills: [ConsoleSkill] = []
    @State private var catalogSkills: [SkillCatalogEntry] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var isSearching = false
    @State private var actionTarget: String?
    @State private var errorMessage: String?
    @State private var catalogError: String?
    @State private var actionMessage: String?

    var body: some View {
        List {
            Section("搜索") {
                TextField("输入关键字搜索 skills", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(isSearching ? "搜索中…" : "搜索 ClawHub") {
                    Task { await search() }
                }
                .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
            }

            if let actionMessage {
                Section {
                    Text(actionMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                }
            }

            if let catalogError {
                Section("目录提示") {
                    Text(catalogError)
                        .font(.caption)
                        .foregroundStyle(ICColor.warning)
                }
            }

            Section("已安装") {
                if isLoading && installedSkills.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if installedSkills.isEmpty {
                    Text("当前没有已安装技能。")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                } else {
                    ForEach(installedSkills) { skill in
                        VStack(alignment: .leading, spacing: ICSpacing.xs) {
                            HStack {
                                VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                    Text(skill.name)
                                        .font(.headline)
                                    Text(skill.description)
                                        .font(.caption)
                                        .foregroundStyle(ICColor.textSecondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                ConsoleBadge(text: skill.trust, color: skill.trust.lowercased() == "trusted" ? ICColor.success : ICColor.warning)
                            }

                            HStack {
                                Text("版本 \(skill.version)")
                                Text(skill.source)
                            }
                            .font(.caption2)
                            .foregroundStyle(ICColor.textSecondary)

                            Button("移除", role: .destructive) {
                                Task { await removeSkill(skill) }
                            }
                            .buttonStyle(.bordered)
                            .disabled(actionTarget == skill.name)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if !catalogSkills.isEmpty {
                Section("目录结果") {
                    ForEach(catalogSkills) { item in
                        VStack(alignment: .leading, spacing: ICSpacing.xs) {
                            HStack(alignment: .top, spacing: ICSpacing.sm) {
                                VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                    Text(item.name)
                                        .font(.headline)
                                    Text(item.description)
                                        .font(.caption)
                                        .foregroundStyle(ICColor.textSecondary)
                                        .lineLimit(3)
                                }
                                Spacer()
                                if item.installed {
                                    ConsoleBadge(text: "已安装", color: ICColor.success)
                                }
                            }

                            HStack {
                                if let owner = item.owner {
                                    Text(owner)
                                }
                                if let stars = item.stars {
                                    Text("★ \(stars)")
                                }
                                if let downloads = item.downloads {
                                    Text("下载 \(downloads)")
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(ICColor.textSecondary)

                            Button(item.installed ? "已安装" : "安装") {
                                Task { await installSkill(item) }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(item.installed || actionTarget == item.slug)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("技能")
        .task {
            await loadInstalled()
        }
        .refreshable {
            await loadInstalled()
        }
    }

    private func loadInstalled() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if appState.gatewayConfiguration.isDemoMode {
            installedSkills = []
            return
        }

        do {
            let response = try await appState.gatewayClient.skills()
            installedSkills = response.skills.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        } catch {
            installedSkills = []
            errorMessage = error.localizedDescription
        }
    }

    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            let response = try await appState.gatewayClient.searchSkills(query: query)
            catalogSkills = response.catalog
            catalogError = response.catalogError
        } catch {
            catalogSkills = []
            catalogError = nil
            errorMessage = error.localizedDescription
        }
    }

    private func installSkill(_ item: SkillCatalogEntry) async {
        actionTarget = item.slug
        defer { actionTarget = nil }
        do {
            let response = try await appState.gatewayClient.installSkill(name: item.name, slug: item.slug)
            actionMessage = response.message
            await loadInstalled()
            await search()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeSkill(_ skill: ConsoleSkill) async {
        actionTarget = skill.name
        defer { actionTarget = nil }
        do {
            let response = try await appState.gatewayClient.removeSkill(name: skill.name)
            actionMessage = response.message
            await loadInstalled()
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await search()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

