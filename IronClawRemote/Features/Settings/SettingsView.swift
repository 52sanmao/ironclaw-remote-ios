import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showingConnectionSheet = false
    @State private var path: [ConsoleRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                profileSection
                consoleSection(
                    title: "资源",
                    routes: [.workspace]
                )
                consoleSection(
                    title: "运行",
                    routes: [.activity]
                )
                consoleSection(
                    title: "能力",
                    routes: [.extensions, .skills]
                )
                consoleSection(
                    title: "账户与网关",
                    routes: [.tokens, .gatewayStatus, .settings]
                )
                if isAdmin {
                    consoleSection(
                        title: "管理员",
                        routes: [.adminUsers, .adminUsage]
                    )
                }
            }
            .navigationTitle("控制台")
            .sheet(isPresented: $showingConnectionSheet) {
                GatewayConnectionView()
            }
            .navigationDestination(for: ConsoleRoute.self) { route in
                destination(for: route)
            }
            .onChange(of: appState.pendingConsoleRoute) { _, newValue in
                guard let newValue else { return }
                path = [newValue]
                appState.pendingConsoleRoute = nil
            }
        }
    }

    private var isAdmin: Bool {
        (appState.session.profile?.role ?? "").lowercased() == "admin"
    }

    private var profileSection: some View {
        Section("当前连接") {
            VStack(alignment: .leading, spacing: ICSpacing.xs) {
                Text(appState.gatewayConfiguration.name)
                    .font(.headline)
                Text(appState.gatewayConfiguration.baseURL.absoluteString)
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
                    .textSelection(.enabled)
                if let profile = appState.session.profile {
                    Divider()
                    Text(profile.displayName)
                        .font(.subheadline.weight(.medium))
                    if let role = profile.role, !role.isEmpty {
                        Label(role, systemImage: "briefcase")
                            .font(.caption)
                            .foregroundStyle(ICColor.textSecondary)
                    }
                    if let email = profile.email, !email.isEmpty {
                        Label(email, systemImage: "envelope")
                            .font(.caption)
                            .foregroundStyle(ICColor.textSecondary)
                    }
                } else if let error = appState.session.lastErrorMessage {
                    Divider()
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                }
            }
            Button("编辑连接") {
                showingConnectionSheet = true
            }
            Button("刷新资料") {
                Task { await appState.refreshProfile() }
            }
        }
    }

    private func consoleSection(title: String, routes: [ConsoleRoute]) -> some View {
        Section(title) {
            ForEach(routes) { route in
                NavigationLink(value: route) {
                    Label(route.title, systemImage: route.systemImage)
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for route: ConsoleRoute) -> some View {
        switch route {
        case .workspace:
            WorkspaceView()
        case .activity:
            ActivityHomeView()
        case .extensions:
            ExtensionsView()
        case .skills:
            SkillsView()
        case .tokens:
            TokensView()
        case .gatewayStatus:
            GatewayStatusView()
        case .settings:
            ConsolePreferencesView(showingConnectionSheet: $showingConnectionSheet)
        case .adminUsers:
            AdminUsersView()
        case .adminUsage:
            AdminUsageView()
        }
    }
}

private struct ConsolePreferencesView: View {
    @Environment(AppState.self) private var appState
    @State private var settings: [RemoteSetting] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Binding var showingConnectionSheet: Bool

    var body: some View {
        Form {
            Section("连接") {
                LabeledContent("名称", value: appState.gatewayConfiguration.name)
                LabeledContent("基础地址", value: appState.gatewayConfiguration.baseURL.absoluteString)
                Button("编辑连接") {
                    showingConnectionSheet = true
                }
            }

            Section("外观") {
                Picker("主题", selection: Binding(
                    get: { appState.preferredTheme },
                    set: { appState.preferredTheme = $0 }
                )) {
                    ForEach(ThemePreference.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
            }

            Section("远端设置") {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                } else if settings.isEmpty {
                    Text("当前没有可展示的远端设置。")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                } else {
                    ForEach(settings.prefix(12)) { setting in
                        VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                            Text(setting.key)
                                .font(.subheadline.weight(.medium))
                            Text(setting.value.compactText)
                                .font(.caption)
                                .foregroundStyle(ICColor.textSecondary)
                                .lineLimit(3)
                            Text(setting.updatedAt)
                                .font(.caption2)
                                .foregroundStyle(ICColor.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("设置")
        .task {
            await loadSettings()
        }
        .refreshable {
            await loadSettings()
        }
    }

    private func loadSettings() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if appState.gatewayConfiguration.isDemoMode {
            settings = []
            return
        }

        do {
            let fetchedSettings = try await appState.gatewayClient.settings()
            settings = fetchedSettings.sorted {
                $0.key.localizedStandardCompare($1.key) == .orderedAscending
            }
        } catch {
            settings = []
            errorMessage = error.localizedDescription
        }
    }
}

private struct ExtensionsView: View {
    @Environment(AppState.self) private var appState
    @State private var extensions: [ConsoleExtension] = []
    @State private var tools: [ConsoleToolInfo] = []
    @State private var isLoading = false
    @State private var busyExtensionName: String?
    @State private var errorMessage: String?
    @State private var actionMessage: String?

    var body: some View {
        List {
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

            Section("已安装扩展") {
                if isLoading && extensions.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if extensions.isEmpty {
                    Text("当前没有已安装扩展。")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                } else {
                    ForEach(extensions) { item in
                        VStack(alignment: .leading, spacing: ICSpacing.xs) {
                            HStack(alignment: .top, spacing: ICSpacing.sm) {
                                VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                    Text(item.displayName ?? item.name)
                                        .font(.headline)
                                    Text(item.kind)
                                        .font(.caption)
                                        .foregroundStyle(ICColor.textSecondary)
                                }
                                Spacer()
                                ConsoleBadge(text: extensionStatusText(item), color: extensionStatusColor(item))
                            }

                            if let description = item.description, !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(ICColor.textSecondary)
                            }

                            if !item.tools.isEmpty {
                                Text("工具：\(item.tools.prefix(4).joined(separator: ", "))")
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                            }

                            if let error = item.activationError, !error.isEmpty {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(ICColor.danger)
                            }

                            HStack {
                                Button(item.active ? "已激活" : "激活") {
                                    Task { await activateExtension(item) }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(item.active || busyExtensionName == item.name)

                                Button("移除", role: .destructive) {
                                    Task { await removeExtension(item) }
                                }
                                .buttonStyle(.bordered)
                                .disabled(busyExtensionName == item.name)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("当前已注册工具") {
                if isLoading && tools.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if tools.isEmpty {
                    Text("当前没有可展示的工具。")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                } else {
                    ForEach(tools.prefix(20)) { tool in
                        VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                            Text(tool.name)
                                .font(.subheadline.weight(.medium))
                            Text(tool.description)
                                .font(.caption)
                                .foregroundStyle(ICColor.textSecondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("扩展")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if appState.gatewayConfiguration.isDemoMode {
            extensions = []
            tools = []
            return
        }

        do {
            async let extensionsRequest = appState.gatewayClient.extensions()
            async let toolsRequest = appState.gatewayClient.extensionTools()
            let fetchedExtensions = try await extensionsRequest
            let fetchedTools = try await toolsRequest
            extensions = fetchedExtensions.sorted {
                ($0.displayName ?? $0.name).localizedStandardCompare($1.displayName ?? $1.name) == .orderedAscending
            }
            tools = fetchedTools.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        } catch {
            extensions = []
            tools = []
            errorMessage = error.localizedDescription
        }
    }

    private func activateExtension(_ item: ConsoleExtension) async {
        busyExtensionName = item.name
        defer { busyExtensionName = nil }
        do {
            let response = try await appState.gatewayClient.activateExtension(name: item.name)
            actionMessage = response.message
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeExtension(_ item: ConsoleExtension) async {
        busyExtensionName = item.name
        defer { busyExtensionName = nil }
        do {
            let response = try await appState.gatewayClient.removeExtension(name: item.name)
            actionMessage = response.message
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func extensionStatusText(_ item: ConsoleExtension) -> String {
        if let activationStatus = item.activationStatus, !activationStatus.isEmpty {
            switch activationStatus {
            case "active": return "已激活"
            case "configured": return "已配置"
            case "pairing": return "待配对"
            case "failed": return "失败"
            default: return activationStatus
            }
        }
        return item.active ? "已激活" : "未激活"
    }

    private func extensionStatusColor(_ item: ConsoleExtension) -> Color {
        if item.activationError != nil {
            return ICColor.danger
        }
        if item.active {
            return ICColor.success
        }
        if item.authenticated {
            return ICColor.warning
        }
        return ICColor.textSecondary
    }
}

private struct SkillsView: View {
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

private struct TokensView: View {
    @Environment(AppState.self) private var appState
    @State private var tokens: [APITokenRecord] = []
    @State private var newTokenName = ""
    @State private var createdToken: APITokenCreateResult?
    @State private var isLoading = false
    @State private var actionTarget: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("创建令牌") {
                TextField("令牌名称", text: $newTokenName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("创建") {
                    Task { await createToken() }
                }
                .disabled(newTokenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let createdToken {
                    VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                        Text("新令牌")
                            .font(.subheadline.weight(.medium))
                        Text(createdToken.token)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                        Text("请立即保存，网关只会展示一次。")
                            .font(.caption2)
                            .foregroundStyle(ICColor.warning)
                    }
                    .padding(.vertical, 4)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                }
            }

            Section("现有令牌") {
                if isLoading && tokens.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if tokens.isEmpty {
                    Text("当前没有 API 令牌。")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                } else {
                    ForEach(tokens) { token in
                        VStack(alignment: .leading, spacing: ICSpacing.xs) {
                            HStack {
                                VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                    Text(token.name)
                                        .font(.headline)
                                    Text(token.tokenPrefix)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(ICColor.textSecondary)
                                }
                                Spacer()
                                if token.revokedAt != nil {
                                    ConsoleBadge(text: "已撤销", color: ICColor.danger)
                                }
                            }

                            Text("创建于 \(token.createdAt)")
                                .font(.caption)
                                .foregroundStyle(ICColor.textSecondary)

                            if let lastUsedAt = token.lastUsedAt {
                                Text("最近使用 \(lastUsedAt)")
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                            }

                            if let expiresAt = token.expiresAt {
                                Text("过期时间 \(expiresAt)")
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                            }

                            if token.revokedAt == nil {
                                Button("撤销", role: .destructive) {
                                    Task { await revokeToken(token) }
                                }
                                .buttonStyle(.bordered)
                                .disabled(actionTarget == token.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("令牌")
        .task {
            await loadTokens()
        }
        .refreshable {
            await loadTokens()
        }
    }

    private func loadTokens() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if appState.gatewayConfiguration.isDemoMode {
            tokens = []
            return
        }

        do {
            let fetchedTokens = try await appState.gatewayClient.tokens()
            tokens = fetchedTokens.sorted {
                $0.createdAt.localizedStandardCompare($1.createdAt) == .orderedDescending
            }
        } catch {
            tokens = []
            errorMessage = error.localizedDescription
        }
    }

    private func createToken() async {
        let name = newTokenName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            createdToken = try await appState.gatewayClient.createToken(name: name)
            newTokenName = ""
            await loadTokens()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func revokeToken(_ token: APITokenRecord) async {
        actionTarget = token.id
        defer { actionTarget = nil }
        do {
            _ = try await appState.gatewayClient.revokeToken(id: token.id)
            await loadTokens()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct GatewayStatusView: View {
    @Environment(AppState.self) private var appState
    @State private var status: GatewayStatusInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading && status == nil {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                }
            }

            if let status {
                Section("网关") {
                    LabeledContent("版本", value: status.version)
                    LabeledContent("运行时长", value: formattedDuration(status.uptimeSecs))
                    LabeledContent("重启支持", value: status.restartEnabled ? "是" : "否")
                    LabeledContent("日成本", value: status.dailyCost ?? "—")
                    LabeledContent("小时动作数", value: status.actionsThisHour.map(String.init) ?? "—")
                }

                Section("连接") {
                    LabeledContent("SSE", value: "\(status.sseConnections)")
                    LabeledContent("WebSocket", value: "\(status.wsConnections)")
                    LabeledContent("总连接", value: "\(status.totalConnections)")
                }

                Section("模型") {
                    LabeledContent("后端", value: status.llmBackend)
                    LabeledContent("模型", value: status.llmModel)
                    if !status.enabledChannels.isEmpty {
                        LabeledContent("已启用通道", value: status.enabledChannels.joined(separator: ", "))
                    }
                }

                if let modelUsage = status.modelUsage, !modelUsage.isEmpty {
                    Section("模型用量") {
                        ForEach(modelUsage) { item in
                            VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                Text(item.model)
                                    .font(.subheadline.weight(.medium))
                                Text("输入 \(item.inputTokens) / 输出 \(item.outputTokens) / 成本 \(item.cost)")
                                    .font(.caption)
                                    .foregroundStyle(ICColor.textSecondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle("网关状态")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if appState.gatewayConfiguration.isDemoMode {
            status = nil
            return
        }

        do {
            status = try await appState.gatewayClient.gatewayStatus()
        } catch {
            status = nil
            errorMessage = error.localizedDescription
        }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        if hours > 0 {
            return "\(hours)小时\(minutes)分"
        }
        if minutes > 0 {
            return "\(minutes)分\(remainingSeconds)秒"
        }
        return "\(remainingSeconds)秒"
    }
}

private struct AdminUsersView: View {
    @Environment(AppState.self) private var appState
    @State private var users: [AdminConsoleUser] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading && users.isEmpty {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                }
            }

            Section("用户列表") {
                if users.isEmpty {
                    Text("当前没有可展示的用户。")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                } else {
                    ForEach(users) { user in
                        VStack(alignment: .leading, spacing: ICSpacing.xs) {
                            HStack(alignment: .top, spacing: ICSpacing.sm) {
                                VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                    Text(user.displayName)
                                        .font(.headline)
                                    if let email = user.email {
                                        Text(email)
                                            .font(.caption)
                                            .foregroundStyle(ICColor.textSecondary)
                                    }
                                }
                                Spacer()
                                ConsoleBadge(text: user.role, color: user.role.lowercased() == "admin" ? ICColor.accent : ICColor.textSecondary)
                            }

                            HStack {
                                Text(user.status)
                                Text("任务 \(user.jobCount)")
                                Text("成本 \(user.totalCost)")
                            }
                            .font(.caption)
                            .foregroundStyle(ICColor.textSecondary)

                            if let lastActiveAt = user.lastActiveAt {
                                Text("最近活跃 \(lastActiveAt)")
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("用户管理")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if appState.gatewayConfiguration.isDemoMode {
            users = []
            return
        }

        do {
            let fetchedUsers = try await appState.gatewayClient.adminUsers()
            users = fetchedUsers.sorted {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
        } catch {
            users = []
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdminUsageView: View {
    @Environment(AppState.self) private var appState
    @State private var summary: AdminUsageSummary?
    @State private var usage: [AdminUsageEntry] = []
    @State private var selectedPeriod = "day"
    @State private var isLoading = false
    @State private var errorMessage: String?


    var body: some View {
        List {
            Section("时间范围") {
                Picker("统计窗口", selection: $selectedPeriod) {
                    Text("日").tag("day")
                    Text("周").tag("week")
                    Text("月").tag("month")
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedPeriod) { _, _ in
                    Task { await load() }
                }
            }

            if isLoading && summary == nil && usage.isEmpty {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                }
            }

            if let summary {
                Section("系统总览") {
                    LabeledContent("用户总数", value: "\(summary.users.total)")
                    LabeledContent("活跃用户", value: "\(summary.users.active)")
                    LabeledContent("管理员", value: "\(summary.users.admins)")
                    LabeledContent("已挂起", value: "\(summary.users.suspended)")
                    LabeledContent("任务总数", value: "\(summary.jobs.total)")
                    LabeledContent("近 30 天调用", value: "\(summary.usage30d.llmCalls)")
                    LabeledContent("近 30 天成本", value: summary.usage30d.totalCost)
                    LabeledContent("运行时长", value: "\(summary.uptimeSeconds) 秒")
                }
            }

            Section("模型用量") {
                if usage.isEmpty {
                    Text("当前窗口没有用量数据。")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                } else {
                    ForEach(usage) { item in
                        VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                            Text(item.userID)
                                .font(.subheadline.weight(.medium))
                            Text(item.model)
                                .font(.caption)
                                .foregroundStyle(ICColor.textSecondary)
                            Text("调用 \(item.callCount) · 输入 \(item.inputTokens) · 输出 \(item.outputTokens) · 成本 \(item.totalCost)")
                                .font(.caption2)
                                .foregroundStyle(ICColor.textSecondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("用量总览")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if appState.gatewayConfiguration.isDemoMode {
            summary = nil
            usage = []
            return
        }

        do {
            async let summaryRequest = appState.gatewayClient.adminUsageSummary()
            async let usageRequest = appState.gatewayClient.adminUsage(period: selectedPeriod)
            let fetchedSummary = try await summaryRequest
            let fetchedUsage = try await usageRequest
            summary = fetchedSummary
            usage = fetchedUsage.usage.sorted {
                if $0.totalCost == $1.totalCost {
                    return $0.userID.localizedStandardCompare($1.userID) == .orderedAscending
                }
                return $0.totalCost > $1.totalCost
            }
        } catch {
            summary = nil
            usage = []
            errorMessage = error.localizedDescription
        }
    }
}

private struct ConsoleBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
