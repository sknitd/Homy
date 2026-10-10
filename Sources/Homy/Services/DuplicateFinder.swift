import CryptoKit
import Foundation

/// Finds byte-identical files: groups candidates by size, then confirms with a
/// streaming SHA-256 digest (CryptoKit). Runs synchronously; call it off the main actor.
struct DuplicateFinder: Sendable {
    /// Files smaller than this are ignored (tiny files are rarely worth cleaning up).
    var minimumSize: Int64 = 4 * 1024
    var chunkSize = 1 << 20

    func findDuplicates(
        in items: [FileItem],
        progress: @escaping @Sendable (Double) -> Void
    ) -> [DuplicateGroup] {
        let candidates = items.filter { $0.size >= minimumSize && $0.category != .apps }
        let bySize = Dictionary(grouping: candidates, by: \.size).values.filter { $0.count > 1 }
        let total = bySize.reduce(0) { $0 + $1.count }
        guard total > 0 else {
            progress(1)
            return []
        }

        var groups: [DuplicateGroup] = []
        var hashed = 0
        for sameSize in bySize {
            var byHash: [String: [FileItem]] = [:]
            for item in sameSize {
                if let digest = sha256(of: item.url) {
                    byHash[digest, default: []].append(item)
                }
                hashed += 1
                if hashed % 8 == 0 || hashed == total {
                    progress(Double(hashed) / Double(total))
                }
            }
            for (hash, matches) in byHash where matches.count > 1 {
                groups.append(DuplicateGroup(hash: hash, items: matches.sorted { $0.path < $1.path }))
            }
        }
        return groups.sorted { $0.wastedBytes > $1.wastedBytes }
    }

    /// Streams the file through SHA-256 so large files never load fully into memory.
    func sha256(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk: Data
            do {
                guard let data = try handle.read(upToCount: chunkSize), !data.isEmpty else { break }
                chunk = data
            } catch {
                return nil
            }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
