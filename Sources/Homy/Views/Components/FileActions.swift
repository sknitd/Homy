import AppKit
import SwiftUI

/// Shared file actions: open, reveal, copy text (Vision OCR), trash.
@MainActor
enum FileActions {
    static func open(_ item: FileItem) {
        NSWorkspace.shared.open(item.url)
    }

    static func reveal(_ items: [FileItem]) {
        NSWorkspace.shared.activateFileViewerSelecting(items.map(\.url))
    }

    static func copyPath(_ items: [FileItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(items.map(\.path).joined(separator: "\n"), forType: .string)
    }

    /// Recognizes text in the images, copies it, and shows the "Copied text" toast.
    static func copyText(from items: [FileItem], appState: AppState) async {
        let images = items.filter(\.isImage)
        guard !images.isEmpty else { return }
        let result = await TextRecognizer.text(from: images.map(\.url))
        guard result.imageCount > 0 else {
            appState.showToast(Toast(symbol: "text.viewfinder", title: "No text found", detail: "Homy couldn't find any text in \(images.count == 1 ? "this image" : "these images").", isError: true))
            return
        }
        copyToPasteboard(result.text)
        appState.showToast(copiedToast(text: result.text, imageCount: result.imageCount))
    }

    static func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func copiedToast(text: String, imageCount: Int) -> Toast {
        let preview = text.replacingOccurrences(of: "\n", with: " ")
        return Toast(
            title: "Copied text from \(Format.plural(imageCount, "image"))",
            detail: preview.count > 160 ? String(preview.prefix(160)) + "…" : preview
        )
    }

    static func trash(_ items: [FileItem], library: LibraryStore, appState: AppState) {
        let result = library.moveToTrash(items)
        if result.failures.isEmpty {
            appState.showToast(Toast(
                symbol: "trash.circle.fill",
                title: "Moved \(Format.plural(result.trashed.count, "item")) to the Trash",
                detail: "Freed \(Format.bytes(result.bytes)). You can restore them from the Trash."
            ))
        } else {
            let first = result.failures[0]
            appState.showToast(Toast(
                symbol: "exclamationmark.triangle.fill",
                title: "Couldn't move \(Format.plural(result.failures.count, "item")) to the Trash",
                detail: "\(first.0.name): \(first.1.localizedDescription)",
                isError: true
            ))
        }
    }
}

/// Presents a "Move to Trash?" confirmation whenever `pending` becomes non-empty
/// (or trashes right away if confirmations are turned off in Settings).
@MainActor
struct TrashConfirmationModifier: ViewModifier {
    @Binding var pending: [FileItem]
    var onTrashed: () -> Void = {}

    @Environment(LibraryStore.self) private var library
    @Environment(AppState.self) private var appState
    @AppStorage(SettingsKey.confirmBeforeTrash) private var confirm = true

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                title,
                isPresented: Binding(
                    get: { confirm && !pending.isEmpty },
                    set: { if !$0 { pending = [] } }
                ),
                titleVisibility: .visible
            ) {
                Button("Move to Trash", role: .destructive) { perform() }
                Button("Cancel", role: .cancel) { pending = [] }
            } message: {
                Text("\(Format.bytes(pending.reduce(0) { $0 + $1.size })) will be freed. Items can be restored from the Trash.")
            }
            .onChange(of: pending) { _, newValue in
                if !confirm && !newValue.isEmpty { perform() }
            }
    }

    private var title: String {
        pending.count == 1 ? "Move “\(pending[0].name)” to the Trash?" : "Move \(pending.count) items to the Trash?"
    }

    private func perform() {
        let items = pending
        pending = []
        guard !items.isEmpty else { return }
        FileActions.trash(items, library: library, appState: appState)
        onTrashed()
    }
}

extension View {
    func trashConfirmation(_ pending: Binding<[FileItem]>, onTrashed: @escaping () -> Void = {}) -> some View {
        modifier(TrashConfirmationModifier(pending: pending, onTrashed: onTrashed))
    }
}

/// Standard right-click menu for a file.
struct FileContextMenu: View {
    let item: FileItem
    let onQuickLook: () -> Void
    let onTrash: () -> Void
    var onCopyText: (() -> Void)?

    var body: some View {
        Button("Open") { FileActions.open(item) }
        Button("Quick Look") { onQuickLook() }
        Button("Show in Finder") { FileActions.reveal([item]) }
        if let onCopyText, item.isImage {
            Divider()
            Button("Copy Text from Image") { onCopyText() }
        }
        Button("Copy Path") { FileActions.copyPath([item]) }
        Divider()
        Button("Move to Trash", role: .destructive) { onTrash() }
    }
}
