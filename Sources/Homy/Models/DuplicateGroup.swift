import Foundation

/// A set of files whose contents hash to the same SHA-256 digest.
struct DuplicateGroup: Identifiable, Hashable, Sendable {
    let hash: String
    var items: [FileItem]

    var id: String { hash }
    var fileSize: Int64 { items.first?.size ?? 0 }
    var extraCopies: Int { max(items.count - 1, 0) }
    var wastedBytes: Int64 { fileSize * Int64(extraCopies) }
    var shortHash: String { String(hash.prefix(8)) }

    /// The copy we suggest keeping: the oldest one, preferring paths outside Downloads.
    var suggestedKeep: FileItem? {
        items.min { lhs, rhs in
            if lhs.isInDownloads != rhs.isInDownloads { return !lhs.isInDownloads }
            let l = lhs.created ?? .distantFuture
            let r = rhs.created ?? .distantFuture
            if l != r { return l < r }
            return lhs.path.count < rhs.path.count
        }
    }
}
