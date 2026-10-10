import Foundation
import UniformTypeIdentifiers

/// Walks the granted folders with FileManager and builds `FileItem`s, enriched with
/// Spotlight / extended-attribute metadata. Runs synchronously; call it off the main actor.
struct FileScanner: Sendable {
    struct Options: Sendable {
        var includeHiddenFiles = false
        var maxItems = 250_000
    }

    let options: Options

    private static let resourceKeys: [URLResourceKey] = [
        .isRegularFileKey, .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey,
        .fileSizeKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
        .creationDateKey, .contentModificationDateKey, .contentAccessDateKey,
        .addedToDirectoryDateKey, .contentTypeKey
    ]

    /// Folders we never descend into: caches, build products, version control.
    private static let skippedDirectoryNames: Set<String> = [
        "node_modules", ".git", "DerivedData", ".build", "Caches", ".Trash", "Pods", "__pycache__"
    ]

    func scan(roots: [ScanRoot], progress: @escaping @Sendable (Int) -> Void) -> [FileItem] {
        var items: [FileItem] = []
        var seen = Set<String>()
        let downloadsPath = RealHome.folder("Downloads").path

        for root in roots {
            var enumOptions: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
            if !options.includeHiddenFiles { enumOptions.insert(.skipsHiddenFiles) }
            guard let enumerator = FileManager.default.enumerator(
                at: root.url,
                includingPropertiesForKeys: Self.resourceKeys,
                options: enumOptions,
                errorHandler: { _, _ in true }
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                if items.count >= options.maxItems { return items }
                guard let values = try? url.resourceValues(forKeys: Set(Self.resourceKeys)) else { continue }
                if values.isSymbolicLink == true { continue }

                let isDirectory = values.isDirectory == true
                let isPackage = values.isPackage == true
                if isDirectory && !isPackage {
                    if Self.skippedDirectoryNames.contains(url.lastPathComponent) {
                        enumerator.skipDescendants()
                    }
                    continue
                }
                if root.appsOnly && !(isPackage && url.pathExtension == "app") { continue }

                let path = url.path
                guard seen.insert(path).inserted else { continue }

                if let item = makeItem(url: url, values: values, isPackage: isPackage, root: root, downloadsPath: downloadsPath) {
                    items.append(item)
                    if items.count % 250 == 0 { progress(items.count) }
                }
            }
        }
        progress(items.count)
        return items
    }

    private func makeItem(url: URL, values: URLResourceValues, isPackage: Bool, root: ScanRoot, downloadsPath: String) -> FileItem? {
        let path = url.path
        let contentType = values.contentType
        let category = FileCategory.classify(url: url, contentType: contentType)

        let size: Int64
        if isPackage {
            size = FileMetadata.directorySize(url)
        } else {
            size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
        }

        let name = category == .apps ? url.deletingPathExtension().lastPathComponent : url.lastPathComponent
        let isInDownloads = path.hasPrefix(downloadsPath + "/")
        let whereFroms = FileMetadata.whereFroms(path: path)
        let agent = FileMetadata.quarantineAgent(path: path)
        let source = (whereFroms.isEmpty && agent == nil)
            ? nil
            : DownloadSource.resolve(whereFroms: whereFroms, quarantineAgent: agent)
        let isScreenshot = category == .images && FileMetadata.isScreenCapture(path: path, name: url.lastPathComponent)
        let lastUsed = category == .apps ? FileMetadata.lastUsedDate(path: path) : nil

        return FileItem(
            url: url,
            name: name,
            size: size,
            created: values.creationDate,
            modified: values.contentModificationDate,
            accessed: values.contentAccessDate,
            added: values.addedToDirectoryDate,
            category: category,
            contentTypeIdentifier: contentType?.identifier,
            rootName: root.name,
            isInDownloads: isInDownloads,
            isScreenshot: isScreenshot,
            downloadSource: source,
            whereFroms: whereFroms,
            lastUsed: lastUsed
        )
    }
}
