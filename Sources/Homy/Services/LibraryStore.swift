import AppKit
import Observation

struct CategoryStat: Hashable {
    var count = 0
    var size: Int64 = 0
    /// The three most recent items, used for the stacked thumbnails on library cards.
    var recent: [FileItem] = []
}

/// The in-memory index of every scanned file plus everything derived from it
/// (category stats, sources, clean-up suggestions, duplicates).
@Observable
@MainActor
final class LibraryStore {
    private(set) var items: [FileItem] = []
    private(set) var isScanning = false
    private(set) var scannedCount = 0
    private(set) var lastScan: Date?

    private(set) var isFindingDuplicates = false
    private(set) var duplicateProgress: Double = 0
    private(set) var duplicateGroups: [DuplicateGroup] = []
    private(set) var hasScannedDuplicates = false

    // Derived indexes, rebuilt after each scan or change.
    private(set) var stats: [FileCategory: CategoryStat] = [:]
    private(set) var totalSize: Int64 = 0
    private(set) var sources: [SourceStat] = []
    private(set) var downloads: [FileItem] = []
    private(set) var screenshots: [FileItem] = []
    private(set) var largeFiles: [FileItem] = []
    private(set) var forgottenDownloads: [FileItem] = []
    private(set) var oldScreenshots: [FileItem] = []
    private(set) var unusedApps: [FileItem] = []

    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var duplicateTask: Task<Void, Never>?
    @ObservationIgnored private var scanRoots: [ScanRoot] = []

    var hasScanned: Bool { lastScan != nil }

    // MARK: Scanning

    func rescan(roots: [ScanRoot]) {
        scanRoots = roots
        scanTask?.cancel()
        duplicateTask?.cancel()
        isScanning = true
        isFindingDuplicates = false
        scannedCount = 0

        let defaults = SettingsKey.defaults
        let scanner = FileScanner(options: .init(includeHiddenFiles: defaults.bool(forKey: SettingsKey.includeHiddenFiles)))
        let report: @Sendable (Int) -> Void = { [weak self] count in
            Task { @MainActor in self?.scannedCount = count }
        }
        scanTask = Task { [weak self] in
            let found = await Task.detached(priority: .userInitiated) {
                scanner.scan(roots: roots, progress: report)
            }.value
            guard let self, !Task.isCancelled else { return }
            self.items = found
            self.lastScan = .now
            self.isScanning = false
            self.duplicateGroups = []
            self.hasScannedDuplicates = false
            self.rebuildIndexes()
            if defaults.bool(forKey: SettingsKey.autoFindDuplicates) {
                self.findDuplicates()
            }
        }
    }

    func findDuplicates() {
        duplicateTask?.cancel()
        isFindingDuplicates = true
        duplicateProgress = 0
        let snapshot = items
        let report: @Sendable (Double) -> Void = { [weak self] fraction in
            Task { @MainActor in self?.duplicateProgress = fraction }
        }
        duplicateTask = Task { [weak self] in
            let finder = DuplicateFinder()
            let groups = await Task.detached(priority: .utility) {
                finder.findDuplicates(in: snapshot, progress: report)
            }.value
            guard let self, !Task.isCancelled else { return }
            let alive = Set(self.items.map(\.path))
            self.duplicateGroups = groups.compactMap { group in
                var group = group
                group.items = group.items.filter { alive.contains($0.path) }
                return group.items.count > 1 ? group : nil
            }
            self.isFindingDuplicates = false
            self.hasScannedDuplicates = true
            self.duplicateProgress = 1
        }
    }

    var scopeURLs: [URL] { scanRoots.filter { !$0.appsOnly }.map(\.url) }

    // MARK: Queries

    func items(in category: FileCategory) -> [FileItem] {
        items.filter { $0.category == category }
    }

    func items(from source: String) -> [FileItem] {
        items.filter { $0.downloadSource == source }
            .sorted { ($0.added ?? $0.displayDate ?? .distantPast) > ($1.added ?? $1.displayDate ?? .distantPast) }
    }

    func items(for kind: CleanupKind) -> [FileItem] {
        switch kind {
        case .duplicates: duplicateGroups.flatMap(\.items)
        case .forgottenDownloads: forgottenDownloads
        case .oldScreenshots: oldScreenshots
        case .unusedApps: unusedApps
        case .largeFiles: largeFiles
        }
    }

    func count(for kind: CleanupKind) -> Int {
        kind == .duplicates ? duplicateGroups.reduce(0) { $0 + $1.extraCopies } : items(for: kind).count
    }

    func reclaimableBytes(for kind: CleanupKind) -> Int64 {
        kind == .duplicates
            ? duplicateGroups.reduce(0) { $0 + $1.wastedBytes }
            : items(for: kind).reduce(0) { $0 + $1.size }
    }

    /// "Free up to X GB": every clean-up suggestion, counting each file once.
    var reclaimableTotal: Int64 {
        var seen = Set<String>()
        var total: Int64 = 0
        for group in duplicateGroups {
            let keep = group.suggestedKeep?.path
            for item in group.items where item.path != keep && seen.insert(item.path).inserted {
                total += item.size
            }
        }
        for item in forgottenDownloads + oldScreenshots + unusedApps where seen.insert(item.path).inserted {
            total += item.size
        }
        return total
    }

    func search(_ query: ParsedQuery, contentMatches: Set<String>) -> [FileItem] {
        items.filter { query.matches($0, contentMatches: contentMatches) }
            .sorted { ($0.displayDate ?? .distantPast) > ($1.displayDate ?? .distantPast) }
    }

    // MARK: Trash

    struct TrashResult {
        var trashed: [FileItem] = []
        var failures: [(FileItem, Error)] = []
        var bytes: Int64 { trashed.reduce(0) { $0 + $1.size } }
    }

    /// Moves files to the Trash (recoverable) and updates every index.
    @discardableResult
    func moveToTrash(_ targets: [FileItem]) -> TrashResult {
        var result = TrashResult()
        for item in targets {
            do {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                result.trashed.append(item)
            } catch {
                result.failures.append((item, error))
            }
        }
        let removed = Set(result.trashed.map(\.path))
        if !removed.isEmpty {
            items.removeAll { removed.contains($0.path) }
            duplicateGroups = duplicateGroups.compactMap { group in
                var group = group
                group.items.removeAll { removed.contains($0.path) }
                return group.items.count > 1 ? group : nil
            }
            rebuildIndexes()
        }
        return result
    }

    // MARK: Indexes

    func rebuildIndexes() {
        let defaults = SettingsKey.defaults
        let now = Date.now
        let day: TimeInterval = 86_400

        var stats: [FileCategory: CategoryStat] = [:]
        var total: Int64 = 0
        for item in items {
            stats[item.category, default: CategoryStat()].count += 1
            stats[item.category, default: CategoryStat()].size += item.size
            total += item.size
        }
        for category in FileCategory.allCases {
            let recent = items.lazy
                .filter { $0.category == category }
                .sorted { ($0.displayDate ?? .distantPast) > ($1.displayDate ?? .distantPast) }
                .prefix(3)
            stats[category, default: CategoryStat()].recent = Array(recent)
        }
        self.stats = stats
        self.totalSize = total

        var sourceCounts: [String: (Int, Int64)] = [:]
        for item in items {
            guard let source = item.downloadSource else { continue }
            let current = sourceCounts[source] ?? (0, 0)
            sourceCounts[source] = (current.0 + 1, current.1 + item.size)
        }
        sources = sourceCounts
            .map { SourceStat(name: $0.key, count: $0.value.0, size: $0.value.1) }
            .sorted { $0.count == $1.count ? $0.name < $1.name : $0.count > $1.count }

        downloads = items.filter(\.isInDownloads)
            .sorted { ($0.added ?? $0.displayDate ?? .distantPast) > ($1.added ?? $1.displayDate ?? .distantPast) }
        screenshots = items.filter(\.isScreenshot)
            .sorted { ($0.created ?? .distantPast) > ($1.created ?? .distantPast) }

        let largeThreshold = Int64(max(defaults.integer(forKey: SettingsKey.largeFileThresholdMB), 1)) * 1_000_000
        largeFiles = items.filter { $0.size >= largeThreshold }.sorted { $0.size > $1.size }

        let downloadCutoff = now.addingTimeInterval(-Double(defaults.integer(forKey: SettingsKey.forgottenDownloadDays)) * day)
        forgottenDownloads = downloads.filter { item in
            guard let last = item.lastInteraction else { return true }
            return last < downloadCutoff
        }.sorted { $0.size > $1.size }

        let screenshotCutoff = now.addingTimeInterval(-Double(defaults.integer(forKey: SettingsKey.oldScreenshotDays)) * day)
        oldScreenshots = screenshots.filter { ($0.created ?? $0.displayDate ?? now) < screenshotCutoff }

        let appCutoff = now.addingTimeInterval(-Double(defaults.integer(forKey: SettingsKey.unusedAppDays)) * day)
        unusedApps = items.filter { item in
            guard item.category == .apps, item.url.pathExtension == "app" else { return false }
            guard !item.path.hasPrefix("/System") else { return false }
            let last = item.lastUsed ?? item.accessed ?? item.added
            return (last ?? .distantPast) < appCutoff
        }.sorted { $0.size > $1.size }
    }
}
