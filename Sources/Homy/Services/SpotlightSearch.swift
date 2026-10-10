import Foundation

/// Searches file *contents* and names with Spotlight (NSMetadataQuery), scoped to the
/// folders the user granted. Complements the in-memory index built by `FileScanner`.
@MainActor
final class SpotlightSearch {
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var continuation: CheckedContinuation<Set<String>, Never>?

    /// Returns the paths of files whose name or text content contains every term.
    func search(terms: [String], scopes: [URL], limit: Int = 500) async -> Set<String> {
        cancel()
        let cleaned = terms.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty, !scopes.isEmpty else { return [] }

        let termPredicates = cleaned.map { term in
            NSPredicate(
                format: "(%K CONTAINS[cd] %@) OR (kMDItemTextContent CONTAINS[cd] %@)",
                NSMetadataItemFSNameKey, term, term
            )
        }

        let query = NSMetadataQuery()
        query.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: termPredicates)
        query.searchScopes = scopes
        self.query = query

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let center = NotificationCenter.default
            observers.append(center.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: query,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.finish(limit: limit)
                }
            })
            if !query.start() {
                finish(limit: limit)
            }
        }
    }

    func cancel() {
        query?.stop()
        query = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        continuation?.resume(returning: [])
        continuation = nil
    }

    private func finish(limit: Int) {
        guard let query else { return }
        query.disableUpdates()
        var paths = Set<String>()
        let count = min(query.resultCount, limit)
        for index in 0..<count {
            if let item = query.result(at: index) as? NSMetadataItem,
               let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
                paths.insert(path)
            }
        }
        query.stop()
        self.query = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        continuation?.resume(returning: paths)
        continuation = nil
    }
}
