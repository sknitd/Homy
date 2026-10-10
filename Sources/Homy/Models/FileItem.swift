import Foundation
import UniformTypeIdentifiers

/// A single file (or app bundle) discovered by the scanner.
struct FileItem: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String
    let size: Int64
    let created: Date?
    let modified: Date?
    let accessed: Date?
    let added: Date?
    let category: FileCategory
    let contentTypeIdentifier: String?
    /// Display name of the granted folder this file was found in ("Downloads", "Desktop", …).
    let rootName: String
    /// True when the file lives inside the user's Downloads folder.
    let isInDownloads: Bool
    let isScreenshot: Bool
    /// The app/website the file was downloaded from (via kMDItemWhereFroms / quarantine data).
    let downloadSource: String?
    let whereFroms: [String]
    /// Last time an app bundle was launched (kMDItemLastUsedDate), apps only.
    let lastUsed: Date?

    var id: URL { url }
    var path: String { url.path }
    var fileExtension: String { url.pathExtension.lowercased() }

    var contentType: UTType? {
        contentTypeIdentifier.flatMap { UTType($0) }
    }

    /// Most meaningful date for display and date-based searching.
    var displayDate: Date? { modified ?? created ?? added }

    /// Most recent sign of the user touching the file.
    var lastInteraction: Date? {
        [accessed, added, modified, lastUsed].compactMap { $0 }.max()
    }

    var isImage: Bool { category == .images }

    /// The folder path relative to the user's home, e.g. "~/Downloads/Invoices".
    var displayFolder: String {
        let folder = url.deletingLastPathComponent().path
        let home = RealHome.path
        if folder.hasPrefix(home) {
            return "~" + String(folder.dropFirst(home.count))
        }
        return folder
    }
}

/// The real home directory (FileManager returns the sandbox container when sandboxed).
enum RealHome {
    static let path: String = {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }()

    static var url: URL { URL(fileURLWithPath: path, isDirectory: true) }

    static func folder(_ name: String) -> URL {
        url.appendingPathComponent(name, isDirectory: true)
    }
}
