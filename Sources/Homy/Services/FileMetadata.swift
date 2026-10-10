import CoreServices
import Darwin
import Foundation

/// Low-level metadata helpers: extended attributes and Spotlight (MDItem) attributes.
enum FileMetadata {
    /// Reads an extended attribute's raw bytes.
    static func xattr(_ name: String, path: String) -> Data? {
        let length = getxattr(path, name, nil, 0, 0, 0)
        guard length > 0 else { return nil }
        var data = Data(count: length)
        let read = data.withUnsafeMutableBytes { buffer -> Int in
            getxattr(path, name, buffer.baseAddress, length, 0, 0)
        }
        guard read > 0 else { return nil }
        return data.prefix(read)
    }

    static func hasXattr(_ name: String, path: String) -> Bool {
        getxattr(path, name, nil, 0, 0, 0) >= 0
    }

    /// URLs a file was downloaded from (kMDItemWhereFroms). Tries the xattr first,
    /// then falls back to the Spotlight index.
    static func whereFroms(path: String) -> [String] {
        if let data = xattr("com.apple.metadata:kMDItemWhereFroms", path: path),
           let list = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String] {
            return list.filter { !$0.isEmpty }
        }
        if let value = spotlightAttribute(kMDItemWhereFroms, path: path) as? [String] {
            return value.filter { !$0.isEmpty }
        }
        return []
    }

    /// The agent (app) that downloaded a file, from the `com.apple.quarantine` xattr:
    /// "flags;hex-timestamp;AgentName;UUID".
    static func quarantineAgent(path: String) -> String? {
        guard let data = xattr("com.apple.quarantine", path: path),
              let string = String(data: data, encoding: .utf8) else { return nil }
        let parts = string.split(separator: ";", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return nil }
        let agent = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
        return agent.isEmpty ? nil : agent
    }

    static func isScreenCapture(path: String, name: String) -> Bool {
        if hasXattr("com.apple.metadata:kMDItemIsScreenCapture", path: path) { return true }
        let lower = name.lowercased()
        return lower.hasPrefix("screenshot") || lower.hasPrefix("screen shot")
            || lower.hasPrefix("cleanshot") || lower.hasPrefix("schermata")
            || lower.hasPrefix("bildschirmfoto") || lower.hasPrefix("capture d")
    }

    /// When an app bundle was last opened (kMDItemLastUsedDate).
    static func lastUsedDate(path: String) -> Date? {
        spotlightAttribute(kMDItemLastUsedDate, path: path) as? Date
    }

    static func spotlightAttribute(_ attribute: CFString, path: String) -> Any? {
        guard let item = MDItemCreate(kCFAllocatorDefault, path as CFString) else { return nil }
        return MDItemCopyAttribute(item, attribute)
    }

    /// Total allocated size of a directory (used for app bundles and other packages).
    static func directorySize(_ url: URL, limit: Int = 60_000) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }
        var total: Int64 = 0
        var visited = 0
        while let next = enumerator.nextObject() as? URL {
            visited += 1
            if visited > limit { break }
            guard let values = try? next.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }
}
