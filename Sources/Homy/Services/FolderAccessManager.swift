import AppKit
import Observation

/// A folder the user granted Homy access to, persisted as a security-scoped bookmark.
struct GrantedFolder: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var path: String
    var bookmark: Data?

    var name: String { URL(fileURLWithPath: path).lastPathComponent }
    var url: URL { URL(fileURLWithPath: path, isDirectory: true) }
}

/// A resolved, accessible folder handed to the scanner.
struct ScanRoot: Hashable, Sendable {
    let url: URL
    let name: String
    let appsOnly: Bool
}

/// Owns the user-granted folders: NSOpenPanel picking, security-scoped bookmarks,
/// and keeping access alive while the app runs.
@Observable
@MainActor
final class FolderAccessManager {
    static let suggestedFolderNames = ["Pictures", "Movies", "Music", "Documents", "Downloads", "Desktop"]

    private(set) var folders: [GrantedFolder] = []

    @ObservationIgnored private var accessing: [String: URL] = [:]
    private let defaultsKey = "grantedFolders.v1"

    init() {
        load()
        resolveAll()
    }

    var hasAnyFolder: Bool { !folders.isEmpty }

    func isGranted(path: String) -> Bool {
        folders.contains { $0.path == path }
    }

    func isGranted(suggested name: String) -> Bool {
        isGranted(path: RealHome.folder(name).path)
    }

    // MARK: Picking

    /// Presents an open panel starting at `startingAt` and stores bookmarks for every chosen folder.
    @discardableResult
    func pickFolders(startingAt directory: URL? = nil, message: String? = nil, multiple: Bool = true) -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = multiple
        panel.prompt = "Grant Access"
        panel.message = message ?? "Choose the folders Homy should keep tidy. Everything stays on your Mac."
        panel.directoryURL = directory ?? RealHome.url
        guard panel.runModal() == .OK else { return [] }
        for url in panel.urls {
            add(url)
        }
        return panel.urls
    }

    /// Grants one of the standard home folders (Pictures, Downloads, …).
    @discardableResult
    func grantSuggested(_ name: String) -> Bool {
        let target = RealHome.folder(name)
        let picked = pickFolders(
            startingAt: target,
            message: "Click “Grant Access” to let Homy see your \(name) folder.",
            multiple: false
        )
        return !picked.isEmpty
    }

    func add(_ url: URL) {
        let standardized = url.standardizedFileURL
        let bookmark = try? standardized.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        if let index = folders.firstIndex(where: { $0.path == standardized.path }) {
            folders[index].bookmark = bookmark ?? folders[index].bookmark
        } else {
            folders.append(GrantedFolder(path: standardized.path, bookmark: bookmark))
        }
        startAccess(standardized)
        save()
    }

    func remove(_ folder: GrantedFolder) {
        if let url = accessing.removeValue(forKey: folder.path) {
            url.stopAccessingSecurityScopedResource()
        }
        folders.removeAll { $0.id == folder.id }
        save()
    }

    // MARK: Scanning roots

    func scanRoots(includeApplications: Bool) -> [ScanRoot] {
        var roots: [ScanRoot] = []
        for folder in folders {
            let url = accessing[folder.path] ?? folder.url
            guard FileManager.default.isReadableFile(atPath: url.path) else { continue }
            roots.append(ScanRoot(url: url, name: folder.name, appsOnly: false))
        }
        if includeApplications {
            let apps = URL(fileURLWithPath: "/Applications", isDirectory: true)
            if !roots.contains(where: { $0.url.path == apps.path }) {
                roots.append(ScanRoot(url: apps, name: "Applications", appsOnly: true))
            }
        }
        return roots
    }

    var downloadsPath: String { RealHome.folder("Downloads").path }

    // MARK: Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([GrantedFolder].self, from: data) else { return }
        folders = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func resolveAll() {
        var changed = false
        for index in folders.indices {
            guard let bookmark = folders[index].bookmark else {
                startAccess(folders[index].url)
                continue
            }
            var stale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else { continue }
            if stale, let fresh = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
                folders[index].bookmark = fresh
                changed = true
            }
            if url.path != folders[index].path {
                folders[index].path = url.path
                changed = true
            }
            startAccess(url)
        }
        if changed { save() }
    }

    private func startAccess(_ url: URL) {
        guard accessing[url.path] == nil else { return }
        _ = url.startAccessingSecurityScopedResource()
        accessing[url.path] = url
    }
}
