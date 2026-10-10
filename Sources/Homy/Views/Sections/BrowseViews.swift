import QuickLook
import SwiftUI

enum FileSort: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case oldest = "Oldest"
    case largest = "Largest"
    case name = "Name"

    var id: String { rawValue }

    func apply(_ items: [FileItem]) -> [FileItem] {
        switch self {
        case .newest: items.sorted { ($0.displayDate ?? .distantPast) > ($1.displayDate ?? .distantPast) }
        case .oldest: items.sorted { ($0.displayDate ?? .distantFuture) < ($1.displayDate ?? .distantFuture) }
        case .largest: items.sorted { $0.size > $1.size }
        case .name: items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }
}

struct SortMenu: View {
    @Binding var sort: FileSort

    var body: some View {
        Picker("Sort", selection: $sort) {
            ForEach(FileSort.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 280)
    }
}

/// Images / Videos / Music / Documents / Archives / Apps.
struct CategoryView: View {
    let category: FileCategory

    @Environment(LibraryStore.self) private var library
    @State private var sort: FileSort = .newest

    var body: some View {
        let items = sort.apply(library.items(in: category))
        let stat = library.stats[category] ?? CategoryStat()
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    symbol: category.symbol,
                    tint: category.tint,
                    title: category.title,
                    subtitle: "\(Format.plural(stat.count, "item")) · \(Format.bytes(stat.size))"
                ) {
                    SortMenu(sort: $sort)
                }
                FileGridView(
                    items: items,
                    emptyTitle: "No \(category.title.lowercased()) yet",
                    emptyMessage: "Homy didn't find any \(category.title.lowercased()) in the folders you shared. Add more folders in Settings."
                )
            }
            .padding(28)
        }
        .background(Color.white)
    }
}

/// Files downloaded from a single source, e.g. "WhatsApp".
struct SourceView: View {
    let source: String

    @Environment(LibraryStore.self) private var library

    var body: some View {
        let items = library.items(from: source)
        let style = DownloadSource.style(for: source)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    symbol: style.symbol,
                    tint: style.color,
                    title: "From \(source)",
                    subtitle: "\(Format.plural(items.count, "file")) · \(Format.bytes(items.reduce(0) { $0 + $1.size }))"
                )
                FileGridView(items: items, emptyTitle: "Nothing from \(source)")
            }
            .padding(28)
        }
        .background(Color.white)
    }
}

/// Everything in Downloads, filterable by where it came from.
struct DownloadsView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(FolderAccessManager.self) private var folders
    @State private var selectedSource: String?
    @State private var sort: FileSort = .newest

    var body: some View {
        let all = library.downloads
        let filtered = selectedSource.map { name in all.filter { $0.downloadSource == name } } ?? all
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    symbol: "arrow.down.circle",
                    tint: Theme.blue,
                    title: "Downloads",
                    subtitle: "\(Format.plural(all.count, "file")) · \(Format.bytes(all.reduce(0) { $0 + $1.size }))"
                ) {
                    SortMenu(sort: $sort)
                }
                if !library.sources.isEmpty {
                    FlowLayout(spacing: 10, lineSpacing: 10) {
                        Button {
                            selectedSource = nil
                        } label: {
                            Text("All")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(selectedSource == nil ? Color.white : Theme.navy)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(selectedSource == nil ? Theme.blue : Color.white))
                                .softShadow(radius: 8, y: 3, opacity: 0.08)
                        }
                        .buttonStyle(.plain)
                        ForEach(library.sources) { source in
                            SourcePill(source: source, isSelected: selectedSource == source.name) {
                                selectedSource = selectedSource == source.name ? nil : source.name
                            }
                        }
                    }
                }
                if !folders.isGranted(suggested: "Downloads") && all.isEmpty {
                    EmptyStateView(
                        title: "Downloads isn't shared yet",
                        message: "Give Homy access to your Downloads folder to see where your files came from."
                    ) {
                        Button("Grant Access to Downloads") {
                            folders.grantSuggested("Downloads")
                        }
                        .buttonStyle(CapsuleButtonStyle())
                    }
                } else {
                    FileGridView(items: sort.apply(filtered), emptyTitle: "No downloads here")
                }
            }
            .padding(28)
        }
        .background(Color.white)
    }
}

/// All screenshots, with OCR "Copy Text".
struct ScreenshotsView: View {
    @Environment(LibraryStore.self) private var library
    @State private var sort: FileSort = .newest

    var body: some View {
        let items = library.screenshots
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    symbol: "camera",
                    tint: Color(hex: 0x7D54FA),
                    title: "Screenshots",
                    subtitle: "\(Format.plural(items.count, "screenshot")) · \(Format.bytes(items.reduce(0) { $0 + $1.size })) · Select one and press ⌘C to copy its text"
                ) {
                    SortMenu(sort: $sort)
                }
                FileGridView(
                    items: sort.apply(items),
                    emptyTitle: "No screenshots",
                    emptyMessage: "Screenshots on your Desktop or in the folders you shared will show up here."
                )
            }
            .padding(28)
        }
        .background(Color.white)
    }
}

/// The biggest files, as a list with proportional bars.
@MainActor
struct LargeFilesView: View {
    @Environment(LibraryStore.self) private var library
    @AppStorage(SettingsKey.largeFileThresholdMB) private var thresholdMB = 500
    @State private var pendingTrash: [FileItem] = []
    @State private var quickLookURL: URL?

    var body: some View {
        let items = library.largeFiles
        let maxSize = max(items.first?.size ?? 1, 1)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    symbol: "dumbbell",
                    tint: Color(hex: 0xFF9500),
                    title: "Large Files",
                    subtitle: "\(Format.plural(items.count, "file")) over \(Format.bytes(Int64(thresholdMB) * 1_000_000)) · \(Format.bytes(items.reduce(0) { $0 + $1.size }))"
                ) {
                    Picker("Larger than", selection: $thresholdMB) {
                        Text("100 MB").tag(100)
                        Text("250 MB").tag(250)
                        Text("500 MB").tag(500)
                        Text("1 GB").tag(1000)
                        Text("5 GB").tag(5000)
                    }
                    .frame(width: 180)
                }
                if items.isEmpty {
                    EmptyStateView(title: "No large files", message: "Nothing over \(Format.bytes(Int64(thresholdMB) * 1_000_000)). Your Mac is travelling light!")
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { item in
                            LargeFileRow(item: item, fraction: Double(item.size) / Double(maxSize)) {
                                pendingTrash = [item]
                            }
                            .onTapGesture(count: 2) { FileActions.open(item) }
                            .contextMenu {
                                FileContextMenu(item: item, onQuickLook: { quickLookURL = item.url }, onTrash: { pendingTrash = [item] })
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
        .background(Color.white)
        .quickLookPreview($quickLookURL)
        .trashConfirmation($pendingTrash)
        .onChange(of: thresholdMB) { _, _ in library.rebuildIndexes() }
    }
}

struct LargeFileRow: View {
    let item: FileItem
    let fraction: Double
    let onTrash: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ThumbnailView(url: item.url, side: 80, contentMode: .fit)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text(Format.bytes(item.size))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(item.category.tint)
                        .monospacedDigit()
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.05))
                        Capsule().fill(item.category.tint.gradient)
                            .frame(width: max(proxy.size.width * fraction, 6))
                    }
                }
                .frame(height: 6)
                Text("\(item.displayFolder) · \(Format.date(item.displayDate))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
            Button {
                FileActions.reveal([item])
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Show in Finder")
            Button(action: onTrash) {
                Image(systemName: "trash")
                    .foregroundStyle(Theme.red)
            }
            .buttonStyle(.borderless)
            .help("Move to Trash")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
        .softShadow(radius: 10, y: 3, opacity: 0.06)
    }
}
