import SwiftUI

/// Resolves and styles the "Downloaded From" source of a file.
enum DownloadSource {
    struct Style {
        let symbol: String
        let color: Color
    }

    /// Known website domains (from kMDItemWhereFroms) mapped to friendly names.
    private static let domainRules: [(needle: String, name: String)] = [
        ("whatsapp", "WhatsApp"),
        ("figma", "Figma"),
        ("slack", "Slack"),
        ("mail.google", "Gmail"),
        ("gmail", "Gmail"),
        ("drive.google", "Google Drive"),
        ("docs.google", "Google Drive"),
        ("googleusercontent", "Google Drive"),
        ("dropbox", "Dropbox"),
        ("github", "GitHub"),
        ("notion", "Notion"),
        ("discord", "Discord"),
        ("telegram", "Telegram"),
        ("t.me", "Telegram"),
        ("zoom.us", "Zoom"),
        ("icloud", "iCloud"),
        ("apple.com", "Apple"),
        ("outlook", "Outlook"),
        ("live.com", "Outlook"),
        ("office", "Microsoft 365"),
        ("sharepoint", "Microsoft 365"),
        ("onedrive", "OneDrive"),
        ("wetransfer", "WeTransfer"),
        ("canva", "Canva"),
        ("linkedin", "LinkedIn"),
        ("twitter", "X"),
        ("x.com", "X"),
        ("twimg", "X"),
        ("instagram", "Instagram"),
        ("cdninstagram", "Instagram"),
        ("facebook", "Facebook"),
        ("fbcdn", "Facebook"),
        ("youtube", "YouTube"),
        ("unsplash", "Unsplash"),
        ("pinterest", "Pinterest"),
        ("reddit", "Reddit"),
        ("amazonaws", "Web"),
    ]

    /// Quarantine agent names (com.apple.quarantine) mapped to friendly names.
    private static let agentRules: [(needle: String, name: String)] = [
        ("whatsapp", "WhatsApp"),
        ("slack", "Slack"),
        ("figma", "Figma"),
        ("telegram", "Telegram"),
        ("discord", "Discord"),
        ("safari", "Safari"),
        ("chrome", "Chrome"),
        ("arc", "Arc"),
        ("firefox", "Firefox"),
        ("edge", "Edge"),
        ("brave", "Brave"),
        ("opera", "Opera"),
        ("mail", "Mail"),
        ("messages", "Messages"),
        ("sharingd", "AirDrop"),
        ("airdrop", "AirDrop"),
        ("zoom", "Zoom"),
        ("teams", "Teams"),
    ]

    static func resolve(whereFroms: [String], quarantineAgent: String?) -> String? {
        // Websites tell us more than the browser that fetched them.
        for entry in whereFroms {
            let lower = entry.lowercased()
            for rule in domainRules where lower.contains(rule.needle) && rule.name != "Web" {
                return rule.name
            }
        }
        if let agent = quarantineAgent?.lowercased(), !agent.isEmpty {
            for rule in agentRules where agent.contains(rule.needle) {
                return rule.name
            }
            return quarantineAgent
        }
        if let first = whereFroms.first, let host = URL(string: first)?.host {
            return prettyHost(host)
        }
        return nil
    }

    private static func prettyHost(_ host: String) -> String {
        var parts = host.split(separator: ".").map(String.init)
        if parts.first == "www" { parts.removeFirst() }
        guard parts.count >= 2 else { return host }
        let name = parts[parts.count - 2]
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    static func style(for name: String) -> Style {
        switch name {
        case "WhatsApp": Style(symbol: "phone.bubble.fill", color: Color(hex: 0x25D366))
        case "Figma": Style(symbol: "pencil.and.outline", color: Color(hex: 0xA259FF))
        case "Slack": Style(symbol: "number", color: Color(hex: 0x4A154B))
        case "Gmail", "Mail", "Outlook": Style(symbol: "envelope.fill", color: Color(hex: 0xEA4335))
        case "Safari": Style(symbol: "safari.fill", color: Color(hex: 0x0A84FF))
        case "Chrome": Style(symbol: "globe", color: Color(hex: 0xFBBC04))
        case "Arc", "Firefox", "Edge", "Brave", "Opera": Style(symbol: "globe", color: Color(hex: 0xFF7139))
        case "Google Drive", "Dropbox", "iCloud", "OneDrive": Style(symbol: "icloud.fill", color: Color(hex: 0x0061FF))
        case "AirDrop": Style(symbol: "airplayaudio", color: Color(hex: 0x0A84FF))
        case "Messages", "Telegram", "Discord": Style(symbol: "message.fill", color: Color(hex: 0x34C759))
        case "GitHub": Style(symbol: "chevron.left.forwardslash.chevron.right", color: Color(hex: 0x24292F))
        case "Notion": Style(symbol: "doc.text.fill", color: Color(hex: 0x37352F))
        case "Zoom", "Teams": Style(symbol: "video.fill", color: Color(hex: 0x2D8CFF))
        default: Style(symbol: "arrow.down.circle.fill", color: Color(hex: 0x8E8E93))
        }
    }
}

struct SourceStat: Identifiable, Hashable {
    let name: String
    let count: Int
    let size: Int64
    var id: String { name }
}
