import SwiftUI

extension Color {
    /// Creates a color from a 0xRRGGBB literal.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Theme {
    static let blue = Color(hex: 0x0070F5)
    static let lightBlue = Color(hex: 0xEAF2FF)
    static let navy = Color(hex: 0x12306B)
    static let green = Color(hex: 0x34C759)
    static let red = Color(hex: 0xFF3B30)
    static let secondaryText = Color(hex: 0x8A8F98)
    static let windowBackground = Color.white
    static let sidebarSelection = Color(hex: 0xE8EDF5)
    static let pillShadow = Color.black.opacity(0.07)

    static let cardRadius: CGFloat = 18
    static let smallCardRadius: CGFloat = 16
    static let sidebarRadius: CGFloat = 8

    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
}

extension View {
    /// Soft, diffuse shadow used by cards and pills.
    func softShadow(radius: CGFloat = 14, y: CGFloat = 6, opacity: Double = 0.08) -> some View {
        shadow(color: .black.opacity(opacity), radius: radius, x: 0, y: y)
    }
}

enum Format {
    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return f
    }()

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    static func bytes(_ value: Int64) -> String {
        byteFormatter.string(fromByteCount: value)
    }

    /// "30.17 GB" style with two decimals, used for the library size label.
    static func gigabytes(_ value: Int64) -> String {
        let gb = Double(value) / 1_000_000_000
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        }
        return bytes(value)
    }

    static func count(_ value: Int) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func date(_ date: Date?) -> String {
        guard let date else { return "—" }
        if Calendar.current.isDateInToday(date) || Calendar.current.isDateInYesterday(date) {
            return relativeFormatter.localizedString(for: date, relativeTo: .now)
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    static func plural(_ count: Int, _ singular: String, _ plural: String? = nil) -> String {
        "\(Format.count(count)) \(count == 1 ? singular : (plural ?? singular + "s"))"
    }
}
