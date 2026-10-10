import SwiftUI
import UniformTypeIdentifiers

enum FileCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case images, videos, music, documents, archives, apps, other

    var id: String { rawValue }

    /// The six categories shown as folder cards in the Library.
    static let libraryCards: [FileCategory] = [.images, .videos, .music, .documents, .archives, .apps]

    var title: String {
        switch self {
        case .images: "Images"
        case .videos: "Videos"
        case .music: "Music"
        case .documents: "Documents"
        case .archives: "Archives"
        case .apps: "Apps"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .images: "photo"
        case .videos: "play.fill"
        case .music: "music.note"
        case .documents: "doc.fill"
        case .archives: "archivebox.fill"
        case .apps: "app.badge.fill"
        case .other: "questionmark.folder.fill"
        }
    }

    var tint: Color {
        switch self {
        case .images: Color(hex: 0x0070F5)
        case .videos: Color(hex: 0x7D54FA)
        case .music: Color(hex: 0xFF2D55)
        case .documents: Color(hex: 0x34C759)
        case .archives: Color(hex: 0xFF9500)
        case .apps: Color(hex: 0xFF3B30)
        case .other: Color(hex: 0x8E8E93)
        }
    }

    var background: Color {
        switch self {
        case .images: Color(hex: 0xEAF2FF)
        case .videos: Color(hex: 0xF2EBFF)
        case .music: Color(hex: 0xFFEBF2)
        case .documents: Color(hex: 0xEBF9F1)
        case .archives: Color(hex: 0xFFF0E5)
        case .apps: Color(hex: 0xFFEBEB)
        case .other: Color(hex: 0xF2F2F7)
        }
    }

    private static let documentExtensions: Set<String> = [
        "pdf", "doc", "docx", "rtf", "rtfd", "txt", "md", "markdown", "pages", "key", "numbers",
        "xls", "xlsx", "csv", "tsv", "ppt", "pptx", "odt", "ods", "odp", "epub", "json", "xml",
        "html", "htm", "tex", "log", "sketch", "fig", "psd", "ai", "eps", "indd"
    ]
    private static let archiveExtensions: Set<String> = [
        "zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "dmg", "iso", "pkg", "mpkg", "sit", "sitx", "cab", "jar", "xip"
    ]

    static func classify(url: URL, contentType: UTType?) -> FileCategory {
        let ext = url.pathExtension.lowercased()
        if let type = contentType {
            if type.conforms(to: .applicationBundle) || type.conforms(to: .application) { return .apps }
            if type.conforms(to: .image) { return .images }
            if type.conforms(to: .movie) || type.conforms(to: .video) { return .videos }
            if type.conforms(to: .audio) { return .music }
            if type.conforms(to: .archive) || type.conforms(to: .diskImage) { return .archives }
            if type.conforms(to: .pdf) || type.conforms(to: .presentation) || type.conforms(to: .spreadsheet)
                || type.conforms(to: .text) || type.conforms(to: .compositeContent) {
                return .documents
            }
        }
        if archiveExtensions.contains(ext) { return .archives }
        if documentExtensions.contains(ext) { return .documents }
        if ext == "app" { return .apps }
        return .other
    }
}
