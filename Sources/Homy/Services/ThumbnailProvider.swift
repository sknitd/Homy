import AppKit
import QuickLookThumbnailing

/// QuickLook thumbnails with an in-memory cache.
@MainActor
final class ThumbnailProvider {
    static let shared = ThumbnailProvider()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 800
    }

    func cached(for url: URL, side: CGFloat) -> NSImage? {
        cache.object(forKey: key(url, side))
    }

    func thumbnail(for url: URL, side: CGFloat, scale: CGFloat = 2) async -> NSImage {
        let cacheKey = key(url, side)
        if let hit = cache.object(forKey: cacheKey) { return hit }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: side, height: side),
            scale: scale,
            representationTypes: .all
        )
        let image: NSImage? = await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation?.nsImage)
            }
        }
        let result = image ?? NSWorkspace.shared.icon(forFile: url.path)
        cache.setObject(result, forKey: cacheKey)
        return result
    }

    private func key(_ url: URL, _ side: CGFloat) -> NSString {
        "\(url.path)#\(Int(side))" as NSString
    }
}
