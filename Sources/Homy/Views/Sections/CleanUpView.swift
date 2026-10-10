import QuickLook
import SwiftUI

/// Overview of every clean-up suggestion.
@MainActor
struct CleanUpView: View {
    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var library

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeader(
                    symbol: "sparkles",
                    tint: Theme.blue,
                    title: "Clean Up",
                    subtitle: "Free up to \(Format.gigabytes(library.reclaimableTotal)) · everything goes to the Trash, nothing is deleted for good"
                )

                ReclaimableBar()

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 14) {
                    ForEach(CleanupKind.allCases) { kind in
                        CleanUpPillCard(
                            kind: kind,
                            count: library.count(for: kind),
                            bytes: library.reclaimableBytes(for: kind),
                            isWorking: kind == .duplicates && library.isFindingDuplicates
                        ) {
                            switch kind {
                            case .duplicates: appState.go(.section(.duplicates))
                            case .largeFiles: appState.go(.section(.largeFiles))
                            default: appState.go(.cleanup(kind))
                            }
                        }
                    }
                }

                ForEach([CleanupKind.forgottenDownloads, .oldScreenshots, .unusedApps]) { kind in
                    let items = library.items(for: kind)
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: kind.title, subtitle: kind.explanation) {
                                SeeAllButton { appState.go(.cleanup(kind)) }
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(items.prefix(12)) { item in
                                        FileCardView(item: item)
                                            .frame(width: 190)
                                            .onTapGesture { appState.go(.cleanup(kind)) }
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
        .background(Color.white)
    }
}

/// Stacked bar showing how reclaimable space splits across suggestion types.
struct ReclaimableBar: View {
    @Environment(LibraryStore.self) private var library

    var body: some View {
        let kinds: [CleanupKind] = [.duplicates, .forgottenDownloads, .oldScreenshots, .unusedApps]
        let values = kinds.map { max(library.reclaimableBytes(for: $0), 0) }
        let total = max(values.reduce(0, +), 1)
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                HStack(spacing: 3) {
                    ForEach(Array(kinds.enumerated()), id: \.element) { pair in
                        let fraction = CGFloat(values[pair.offset]) / CGFloat(total)
                        if fraction > 0 {
                            Capsule()
                                .fill(pair.element.tint)
                                .frame(width: max(proxy.size.width * fraction - 3, 4))
                        }
                    }
                    if values.allSatisfy({ $0 == 0 }) {
                        Capsule().fill(Color.black.opacity(0.06))
                    }
                }
            }
            .frame(height: 12)
            HStack(spacing: 16) {
                ForEach(Array(kinds.enumerated()), id: \.element) { pair in
                    HStack(spacing: 6) {
                        Circle().fill(pair.element.tint).frame(width: 8, height: 8)
                        Text("\(pair.element.title) \(Format.bytes(values[pair.offset]))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: 0xF7F9FC)))
    }
}

/// Checklist of items for one clean-up suggestion, with "Move to Trash".
@MainActor
struct CleanupListView: View {
    let kind: CleanupKind

    @Environment(LibraryStore.self) private var library
    @State private var selection: Set<String> = []
    @State private var pendingTrash: [FileItem] = []
    @State private var quickLookURL: URL?
    @State private var initialized = false

    var body: some View {
        let items = library.items(for: kind)
        let selected = items.filter { selection.contains($0.path) }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    symbol: kind.symbol,
                    tint: kind.tint,
                    title: kind.title,
                    subtitle: "\(kind.explanation) \(Format.plural(items.count, "item")) · \(Format.bytes(items.reduce(0) { $0 + $1.size }))"
                )

                if items.isEmpty {
                    EmptyStateView(title: "All clean!", message: "Nothing to tidy up here right now.")
                } else {
                    HStack(spacing: 12) {
                        Button(selection.count == items.count ? "Deselect All" : "Select All") {
                            selection = selection.count == items.count ? [] : Set(items.map(\.path))
                        }
                        .buttonStyle(CapsuleButtonStyle(tint: Theme.blue, filled: false))
                        Spacer()
                        Text("\(Format.plural(selected.count, "item")) · \(Format.bytes(selected.reduce(0) { $0 + $1.size }))")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                        Button("Move to Trash") { pendingTrash = selected }
                            .buttonStyle(CapsuleButtonStyle(tint: Theme.red))
                            .disabled(selected.isEmpty)
                    }

                    LazyVStack(spacing: 8) {
                        ForEach(items) { item in
                            CleanupRow(item: item, kind: kind, isSelected: selection.contains(item.path)) {
                                if selection.contains(item.path) { selection.remove(item.path) } else { selection.insert(item.path) }
                            }
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
        .trashConfirmation($pendingTrash) { selection.removeAll() }
        .onAppear {
            guard !initialized else { return }
            initialized = true
            // Pre-select everything except apps (uninstalling deserves a deliberate choice).
            if kind != .unusedApps {
                selection = Set(items.map(\.path))
            }
        }
    }
}

struct CleanupRow: View {
    let item: FileItem
    let kind: CleanupKind
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? kind.tint : Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)

            ThumbnailView(url: item.url, side: 80, contentMode: item.isImage ? .fill : .fit)
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            if let source = item.downloadSource {
                Text(source)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.navy)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.lightBlue))
            }
            Text(Format.bytes(item.size))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? kind.background : Color(hex: 0xFAFBFC))
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { FileActions.open(item) }
        .onTapGesture(perform: onToggle)
    }

    private var detail: String {
        switch kind {
        case .unusedApps:
            if let used = item.lastUsed ?? item.accessed {
                return "Last opened \(used.formatted(.relative(presentation: .named)))"
            }
            return "Never opened"
        case .forgottenDownloads:
            let added = item.added ?? item.created
            return "\(item.displayFolder) · downloaded \(added.map { $0.formatted(.relative(presentation: .named)) } ?? "a while ago")"
        default:
            return "\(item.displayFolder) · \(Format.date(item.displayDate))"
        }
    }
}
