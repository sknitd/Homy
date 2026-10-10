import SwiftUI

/// Full image preview with Vision OCR: "⌘C Copy Text" highlights every recognized
/// line with dark blue blocks, copies the text, and confirms with a toast.
@MainActor
struct ImageDetailView: View {
    let item: FileItem

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var image: NSImage?
    @State private var lines: [RecognizedLine] = []
    @State private var revealedCount = 0
    @State private var isRecognizing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            preview
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: 0xF6F7F9))
            footer
        }
        .frame(minWidth: 760, idealWidth: 920, minHeight: 560, idealHeight: 680)
        .background(.white)
        .overlay(alignment: .bottom) {
            if let toast = appState.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task(id: item.url) {
            image = NSImage(contentsOf: item.url)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(Format.bytes(item.size)) · \(Format.date(item.displayDate)) · \(item.displayFolder)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.black.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var preview: some View {
        GeometryReader { proxy in
            if let image {
                let fitted = fittedRect(imageSize: image.size, in: proxy.size)
                ZStack(alignment: .topLeading) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: fitted.width, height: fitted.height)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .softShadow(radius: 16, y: 6, opacity: 0.12)
                        .offset(x: fitted.minX, y: fitted.minY)

                    ForEach(Array(lines.prefix(revealedCount))) { line in
                        let box = line.boundingBox
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Theme.navy.opacity(0.55))
                            .frame(width: max(box.width * fitted.width + 4, 4), height: max(box.height * fitted.height + 4, 4))
                            .offset(
                                x: fitted.minX + box.minX * fitted.width - 2,
                                y: fitted.minY + (1 - box.maxY) * fitted.height - 2
                            )
                            .transition(.scale(scale: 0.6, anchor: .leading).combined(with: .opacity))
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            } else {
                ProgressView()
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if let errorMessage {
                Label(errorMessage, systemImage: "text.magnifyingglass")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            } else if !lines.isEmpty {
                Label("\(Format.plural(lines.count, "line")) of text found", systemImage: "text.viewfinder")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.navy)
            }
            Spacer()
            Button("Show in Finder") { FileActions.reveal([item]) }
                .buttonStyle(CapsuleButtonStyle(filled: false))
            Button("Open") { FileActions.open(item) }
                .buttonStyle(CapsuleButtonStyle(filled: false))
            CopyTextButton(isWorking: isRecognizing) { copyText() }
                .keyboardShortcut("c", modifiers: .command)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func fittedRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height, 1.5)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func copyText() {
        guard !isRecognizing else { return }
        if !lines.isEmpty {
            finishCopy()
            return
        }
        isRecognizing = true
        errorMessage = nil
        Task {
            do {
                let found = try await TextRecognizer.recognize(at: item.url)
                isRecognizing = false
                guard !found.isEmpty else {
                    errorMessage = TextRecognizer.Failure.noText.localizedDescription
                    return
                }
                lines = found
                revealedCount = 0
                // Sweep the highlight blocks in, line by line.
                for index in 1...found.count {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        revealedCount = index
                    }
                    try? await Task.sleep(for: .milliseconds(min(40, 600 / found.count)))
                }
                finishCopy()
            } catch {
                isRecognizing = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func finishCopy() {
        let text = lines.map(\.text).joined(separator: "\n")
        FileActions.copyToPasteboard(text)
        appState.showToast(FileActions.copiedToast(text: text, imageCount: 1))
    }
}
