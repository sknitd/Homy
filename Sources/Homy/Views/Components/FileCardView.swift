import SwiftUI

/// White rounded card: QuickLook preview on top (~70%), then title, date and size.
struct FileCardView: View {
    let item: FileItem
    var isSelected = false

    @State private var hovering = false

    private let shape = RoundedRectangle(cornerRadius: Theme.smallCardRadius, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ThumbnailView(url: item.url, side: 260, contentMode: item.category == .images || item.category == .videos ? .fill : .fit)
                .padding(item.category == .images || item.category == .videos ? 0 : 18)
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(Color(hex: 0xF6F7F9))
                .clipped()
                .overlay(alignment: .topLeading) { badges }
                .overlay(alignment: .bottomTrailing) {
                    if item.category == .videos {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.35))
                            .padding(8)
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    Text(Format.date(item.displayDate))
                    Spacer(minLength: 4)
                    Text(Format.bytes(item.size))
                        .monospacedDigit()
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(shape.fill(.white))
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(isSelected ? Theme.blue : Color.black.opacity(0.06), lineWidth: isSelected ? 2.5 : 1)
        )
        .softShadow(radius: hovering ? 18 : 12, y: hovering ? 8 : 5, opacity: hovering ? 0.12 : 0.07)
        .scaleEffect(hovering ? 1.015 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: hovering)
        .onHover { hovering = $0 }
        .contentShape(shape)
        .help(item.displayFolder)
    }

    @ViewBuilder
    private var badges: some View {
        HStack(spacing: 4) {
            if item.isScreenshot {
                badge("camera.fill", "Screenshot")
            }
            if let source = item.downloadSource {
                badge(DownloadSource.style(for: source).symbol, source)
            }
        }
        .padding(8)
    }

    private func badge(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundStyle(Theme.navy)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(.white.opacity(0.92)))
    }
}
