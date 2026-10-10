import SwiftUI

/// Shows a QuickLook thumbnail for a file, falling back to its Finder icon.
struct ThumbnailView: View {
    let url: URL
    var side: CGFloat = 220
    var contentMode: ContentMode = .fill

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                Rectangle()
                    .fill(Color(hex: 0xF2F4F7))
                    .overlay {
                        Image(systemName: "doc")
                            .font(.system(size: 22))
                            .foregroundStyle(.tertiary)
                    }
            }
        }
        .task(id: url) {
            if let cached = ThumbnailProvider.shared.cached(for: url, side: side) {
                image = cached
                return
            }
            let result = await ThumbnailProvider.shared.thumbnail(for: url, side: side)
            withAnimation(.easeOut(duration: 0.2)) {
                image = result
            }
        }
    }
}
