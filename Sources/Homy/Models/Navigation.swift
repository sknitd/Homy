import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case library, images, videos, music, documents
    case largeFiles, downloads, duplicates, screenshots, cleanUp
    case settings

    var id: String { rawValue }

    static let mediaGroup: [SidebarItem] = [.library, .images, .videos, .music, .documents]
    static let toolsGroup: [SidebarItem] = [.largeFiles, .downloads, .duplicates, .screenshots, .cleanUp]

    var title: String {
        switch self {
        case .library: "Library"
        case .images: "Images"
        case .videos: "Videos"
        case .music: "Music"
        case .documents: "Documents"
        case .largeFiles: "Large Files"
        case .downloads: "Downloads"
        case .duplicates: "Duplicates"
        case .screenshots: "Screenshots"
        case .cleanUp: "Clean Up"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .library: "house"
        case .images: "photo"
        case .videos: "play"
        case .music: "music.note"
        case .documents: "doc"
        case .largeFiles: "dumbbell"
        case .downloads: "arrow.down.circle"
        case .duplicates: "square.on.square"
        case .screenshots: "camera"
        case .cleanUp: "sparkles"
        case .settings: "gear"
        }
    }

    var category: FileCategory? {
        switch self {
        case .images: .images
        case .videos: .videos
        case .music: .music
        case .documents: .documents
        default: nil
        }
    }
}

enum CleanupKind: String, CaseIterable, Identifiable, Hashable {
    case duplicates, forgottenDownloads, oldScreenshots, unusedApps, largeFiles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .duplicates: "Duplicates"
        case .forgottenDownloads: "Forgotten Downloads"
        case .oldScreenshots: "Old Screenshots"
        case .unusedApps: "Unused Apps"
        case .largeFiles: "Large Files"
        }
    }

    var symbol: String {
        switch self {
        case .duplicates: "square.on.square.fill"
        case .forgottenDownloads: "arrow.down.circle.fill"
        case .oldScreenshots: "camera.fill"
        case .unusedApps: "app.dashed"
        case .largeFiles: "dumbbell.fill"
        }
    }

    var tint: Color {
        switch self {
        case .duplicates: Color(hex: 0xFF3B30)
        case .forgottenDownloads: Color(hex: 0x0070F5)
        case .oldScreenshots: Color(hex: 0x7D54FA)
        case .unusedApps: Color(hex: 0x34C759)
        case .largeFiles: Color(hex: 0xFF9500)
        }
    }

    var background: Color {
        switch self {
        case .duplicates: Color(hex: 0xFFF0F0)
        case .forgottenDownloads: Color(hex: 0xF0F5FF)
        case .oldScreenshots: Color(hex: 0xF5F0FF)
        case .unusedApps: Color(hex: 0xF0F9F4)
        case .largeFiles: Color(hex: 0xFFF5EB)
        }
    }

    func actionLabel(count: Int) -> String {
        switch self {
        case .duplicates: Format.plural(count, "extra copy", "extra copies")
        case .forgottenDownloads: Format.plural(count, "file")
        case .oldScreenshots: Format.plural(count, "screenshot")
        case .unusedApps: Format.plural(count, "app")
        case .largeFiles: Format.plural(count, "large file")
        }
    }

    var explanation: String {
        switch self {
        case .duplicates: "Identical files, matched byte-for-byte with SHA-256."
        case .forgottenDownloads: "Downloads you haven't opened in a while."
        case .oldScreenshots: "Screenshots that have been sitting around for weeks."
        case .unusedApps: "Apps you haven't launched in months."
        case .largeFiles: "The biggest files taking up space."
        }
    }
}

/// Everything the detail column can show.
enum Route: Hashable {
    case section(SidebarItem)
    case category(FileCategory)
    case source(String)
    case cleanup(CleanupKind)

    var sidebarItem: SidebarItem? {
        switch self {
        case .section(let item):
            return item
        case .category(let category):
            switch category {
            case .images: return .images
            case .videos: return .videos
            case .music: return .music
            case .documents: return .documents
            default: return .library
            }
        case .source:
            return .downloads
        case .cleanup(let kind):
            switch kind {
            case .duplicates: return .duplicates
            case .largeFiles: return .largeFiles
            default: return .cleanUp
            }
        }
    }
}
