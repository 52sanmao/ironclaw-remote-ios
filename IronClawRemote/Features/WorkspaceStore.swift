import Foundation
import Observation

@MainActor
@Observable
final class WorkspaceStore {
    var entries: [MemoryTreeEntry] = []
    var selectedEntry: MemoryTreeEntry?
    var content = ""
    var searchQuery = ""
    var searchResults: [MemoryListEntry] = []
    var isLoading = false
    var lastErrorMessage: String?

    @MainActor
    func load(using client: GatewayClient) async {
        isLoading = true
        lastErrorMessage = nil
        defer { isLoading = false }
        do {
            let tree = try await client.memoryTree()
            entries = tree.entries
            if let file = tree.entries.first(where: { !$0.isDir }) {
                await select(entry: file, using: client)
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    func select(entry: MemoryTreeEntry, using client: GatewayClient) async {
        selectedEntry = entry
        guard !entry.isDir else {
            content = ""
            return
        }
        do {
            let file = try await client.readMemory(path: entry.path)
            content = file.content
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    func search(using client: GatewayClient) async {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        do {
            searchResults = try await client.searchMemory(query: searchQuery)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
