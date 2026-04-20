import Foundation
import SwiftUI

@MainActor
@Observable
final class WorkspaceViewModel {
    var entries: [MemoryTreeEntry] = []
    var selectedFile: MemoryReadResponse?
    var selectedEntryPath: String?
    var selectedEntryIsDirectory = false
    var searchQuery = ""
    var searchResults: [MemoryListEntry] = []
    var loadErrorMessage: String?
    var searchErrorMessage: String?
    var previewErrorMessage: String?
    var infoMessage: String?
    var isLoading = false
    var isSearching = false
    var isOpeningFile = false
    var hasSearched = false

    func load(using configuration: GatewayConfiguration) async {
        isLoading = true
        loadErrorMessage = nil
        defer { isLoading = false }

        if configuration.isDemoMode {
            entries = sortTreeEntries(DemoContent.memoryEntries)

            if let selectedEntryPath,
               let matchingEntry = entries.first(where: { $0.path == selectedEntryPath }) {
                await select(matchingEntry, configuration: configuration)
                return
            }

            if let firstFile = entries.first(where: { !$0.isDir }) {
                await openFile(at: firstFile.path, configuration: configuration)
            } else if let firstEntry = entries.first {
                selectedEntryPath = firstEntry.path
                selectedEntryIsDirectory = true
                selectedFile = nil
                previewErrorMessage = nil
                infoMessage = directoryMessage(for: firstEntry.path)
            } else {
                selectedEntryPath = nil
                selectedEntryIsDirectory = false
                selectedFile = nil
                previewErrorMessage = nil
                infoMessage = "暂时没有可用的记忆文件。"
            }
            return
        }

        do {
            let client = GatewayClient(configuration: configuration)
            entries = sortTreeEntries(try await client.memoryTree().entries)

            if let selectedEntryPath,
               let matchingEntry = entries.first(where: { $0.path == selectedEntryPath }) {
                await select(matchingEntry, configuration: configuration)
                return
            }

            if let firstFile = entries.first(where: { !$0.isDir }) {
                await openFile(at: firstFile.path, configuration: configuration)
            } else if let firstEntry = entries.first {
                selectedEntryPath = firstEntry.path
                selectedEntryIsDirectory = true
                selectedFile = nil
                previewErrorMessage = nil
                infoMessage = directoryMessage(for: firstEntry.path)
            } else {
                selectedEntryPath = nil
                selectedEntryIsDirectory = false
                selectedFile = nil
                previewErrorMessage = nil
                infoMessage = "暂时没有可用的记忆文件。"
            }
        } catch {
            entries = []
            selectedFile = nil
            selectedEntryPath = nil
            selectedEntryIsDirectory = false
            loadErrorMessage = error.localizedDescription
            previewErrorMessage = nil
            infoMessage = nil
        }
    }

    func select(_ entry: MemoryTreeEntry, configuration: GatewayConfiguration) async {
        selectedEntryPath = entry.path
        selectedEntryIsDirectory = entry.isDir
        guard !entry.isDir else {
            selectedFile = nil
            previewErrorMessage = nil
            infoMessage = directoryMessage(for: entry.path)
            return
        }
        await openFile(at: entry.path, configuration: configuration)
    }

    func selectSearchResult(_ entry: MemoryListEntry, configuration: GatewayConfiguration) async {
        selectedEntryPath = entry.path
        selectedEntryIsDirectory = entry.isDir
        guard !entry.isDir else {
            selectedFile = nil
            previewErrorMessage = nil
            infoMessage = directoryMessage(for: entry.path)
            return
        }
        await openFile(at: entry.path, configuration: configuration)
    }

    func search(using configuration: GatewayConfiguration) async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        searchErrorMessage = nil

        guard !query.isEmpty else {
            hasSearched = false
            searchResults = []
            return
        }

        hasSearched = true
        isSearching = true
        defer { isSearching = false }

        if configuration.isDemoMode {
            searchResults = sortSearchResults(DemoContent.searchResults(for: query))
            return
        }

        do {
            let client = GatewayClient(configuration: configuration)
            searchResults = sortSearchResults(try await client.searchMemory(query: query))
        } catch {
            searchResults = []
            searchErrorMessage = error.localizedDescription
        }
    }

    private func openFile(at path: String, configuration: GatewayConfiguration) async {
        isOpeningFile = true
        selectedEntryPath = path
        selectedEntryIsDirectory = false
        selectedFile = nil
        previewErrorMessage = nil
        infoMessage = nil
        defer { isOpeningFile = false }

        if configuration.isDemoMode {
            if let file = DemoContent.memoryFiles[path] {
                selectedFile = file
            } else {
                previewErrorMessage = "未找到演示文件。"
            }
            return
        }

        do {
            let client = GatewayClient(configuration: configuration)
            selectedFile = try await client.readMemory(path: path)
        } catch {
            previewErrorMessage = error.localizedDescription
        }
    }

    private func directoryMessage(for path: String) -> String {
        "\(path) 是一个目录。请选择文件以预览其内容。"
    }

    private func sortTreeEntries(_ entries: [MemoryTreeEntry]) -> [MemoryTreeEntry] {
        entries.sorted { lhs, rhs in
            if lhs.isDir != rhs.isDir {
                return lhs.isDir && !rhs.isDir
            }
            return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
    }

    private func sortSearchResults(_ entries: [MemoryListEntry]) -> [MemoryListEntry] {
        entries.sorted { lhs, rhs in
            if lhs.isDir != rhs.isDir {
                return lhs.isDir && !rhs.isDir
            }
            let lhsKey = lhs.name.isEmpty ? lhs.path : lhs.name
            let rhsKey = rhs.name.isEmpty ? rhs.path : rhs.name
            return lhsKey.localizedStandardCompare(rhsKey) == .orderedAscending
        }
    }
}
