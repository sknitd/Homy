import QuickLook
import SwiftUI

/// Grid of file cards with selection, Quick Look, OCR "Copy Text", and trash.
/// Not scrollable by itself — embed it in a ScrollView.
@MainActor
struct FileGridView: View {
    let items: [FileItem]
    var emptyTitle = "Nothing here yet"
    var emptyMessage = "When Homy finds matching files in your folders, they'll show up here."
    var minimumCardWidth: CGFloat = 180

    @Environment(AppState.self) private var appState
    @State private var selection: Set<URL> = []
    @State private var quickLookURL: URL?
    @State private var detailItem: FileItem?
    @State private var pendingTrash: [FileItem] = []
    @State private var isCopying = false

    private var selectedItems: [FileItem] {
        items.filter { selection.contains($0.url) }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyStateView(title: emptyTitle, message: emptyMessage)
                    .frame(minHeight: 360)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    if !selection.isEmpty {
                        selectionBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: minimumCardWidth, maximum: minimumCardWidth + 70), spacing: 18)],
                        alignment: .leading,
                        spacing: 18
                    ) {
                        ForEach(items) { item in
                            FileCardView(item: item, isSelected: selection.contains(item.url))
                                .onTapGesture(count: 2) { openItem(item) }
                                .onTapGesture { select(item) }
                                .contextMenu {
                                    FileContextMenu(
                                        item: item,
                                        onQuickLook: { quickLookURL = item.url },
                                        onTrash: { pendingTrash = selection.contains(item.url) ? selectedItems : [item] },
                                        onCopyText: { copyText([item]) }
                                    )
                                }
                        }
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selection.isEmpty)
            }
        }
        .quickLookPreview($quickLookURL, in: items.map(\.url))
        .sheet(item: $detailItem) { item in
            ImageDetailView(item: item)
        }
        .trashConfirmation($pendingTrash) { selection.removeAll() }
        .onChange(of: items) { _, newItems in
            let alive = Set(newItems.map(\.url))
            selection = selection.filter { alive.contains($0) }
        }
    }

    private var selectionBar: some View {
        let selected = selectedItems
        let imageCount = selected.filter(\.isImage).count
        return HStack(spacing: 10) {
            Text("\(Format.plural(selected.count, "item")) selected · \(Format.bytes(selected.reduce(0) { $0 + $1.size }))")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Spacer()
            if imageCount > 0 {
                CopyTextButton(isWorking: isCopying) { copyText(selected) }
                    .keyboardShortcut("c", modifiers: .command)
            }
            Button {
                quickLookURL = selected.first?.url
            } label: {
                Label("Quick Look", systemImage: "eye")
            }
            Button {
                FileActions.reveal(selected)
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }
            Button(role: .destructive) {
                pendingTrash = selected
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
            .keyboardShortcut(.delete, modifiers: .command)
            Button {
                selection.removeAll()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.lightBlue)
        )
    }

    private func select(_ item: FileItem) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if selection.contains(item.url) { selection.remove(item.url) } else { selection.insert(item.url) }
        } else if flags.contains(.shift), let anchor = items.firstIndex(where: { selection.contains($0.url) }),
                  let target = items.firstIndex(of: item) {
            let range = min(anchor, target)...max(anchor, target)
            selection.formUnion(items[range].map(\.url))
        } else {
            selection = selection == [item.url] ? [] : [item.url]
        }
    }

    private func openItem(_ item: FileItem) {
        if item.isImage {
            detailItem = item
        } else {
            FileActions.open(item)
        }
    }

    private func copyText(_ targets: [FileItem]) {
        guard !isCopying else { return }
        isCopying = true
        Task {
            await FileActions.copyText(from: targets, appState: appState)
            isCopying = false
        }
    }
}
