import Foundation

/// A chip shown under "Understood as".
struct QueryPill: Identifiable, Hashable {
    let symbol: String
    let label: String
    var id: String { symbol + label }
}

/// The structured meaning of a natural-language search such as "pdfs from last week".
struct ParsedQuery: Equatable {
    var terms: [String] = []
    var categories: Set<FileCategory> = []
    var extensions: Set<String> = []
    var dateRange: ClosedRange<Date>?
    var dateLabel: String?
    var minSize: Int64?
    var maxSize: Int64?
    var source: String?
    var folder: String?
    var screenshotsOnly = false

    var isEmpty: Bool {
        terms.isEmpty && categories.isEmpty && extensions.isEmpty && dateRange == nil
            && minSize == nil && maxSize == nil && source == nil && folder == nil && !screenshotsOnly
    }

    /// True when the query contains more than plain keywords.
    var hasStructure: Bool {
        !categories.isEmpty || !extensions.isEmpty || dateRange != nil || minSize != nil
            || maxSize != nil || source != nil || folder != nil || screenshotsOnly
    }

    var pills: [QueryPill] {
        var pills: [QueryPill] = []
        if screenshotsOnly {
            pills.append(QueryPill(symbol: "camera", label: "Screenshots"))
        }
        if !extensions.isEmpty {
            pills.append(QueryPill(symbol: "doc", label: extensions.sorted().map { $0.uppercased() }.joined(separator: ", ")))
        }
        for category in categories.sorted(by: { $0.rawValue < $1.rawValue }) where !(screenshotsOnly && category == .images) {
            pills.append(QueryPill(symbol: category.symbol, label: category.title))
        }
        if let dateLabel {
            pills.append(QueryPill(symbol: "calendar", label: dateLabel))
        }
        if let minSize {
            pills.append(QueryPill(symbol: "arrow.up.right", label: "Larger than \(Format.bytes(minSize))"))
        }
        if let maxSize {
            pills.append(QueryPill(symbol: "arrow.down.right", label: "Smaller than \(Format.bytes(maxSize))"))
        }
        if let source {
            pills.append(QueryPill(symbol: "arrow.down.circle", label: "From \(source)"))
        }
        if let folder {
            pills.append(QueryPill(symbol: "folder", label: "In \(folder)"))
        }
        for term in terms {
            pills.append(QueryPill(symbol: "textformat", label: "“\(term)”"))
        }
        return pills
    }

    func matches(_ item: FileItem, contentMatches: Set<String> = []) -> Bool {
        if screenshotsOnly && !item.isScreenshot { return false }
        if !categories.isEmpty || !extensions.isEmpty {
            let categoryHit = categories.contains(item.category)
            let extensionHit = extensions.contains(item.fileExtension)
            if !(categoryHit || extensionHit) { return false }
        }
        if let dateRange {
            guard let date = item.displayDate, dateRange.contains(date) else { return false }
        }
        if let minSize, item.size < minSize { return false }
        if let maxSize, item.size > maxSize { return false }
        if let source, item.downloadSource?.caseInsensitiveCompare(source) != .orderedSame { return false }
        if let folder {
            let lowerFolder = folder.lowercased()
            if item.rootName.lowercased() != lowerFolder && !item.path.lowercased().contains("/\(lowerFolder)/") {
                return false
            }
        }
        if !terms.isEmpty && !contentMatches.contains(item.path) {
            let haystack = (item.name + " " + item.displayFolder + " " + (item.downloadSource ?? "")).lowercased()
            for term in terms where !haystack.contains(term) {
                return false
            }
        }
        return true
    }
}

/// Turns everyday phrases into a `ParsedQuery`.
enum QueryParser {
    private static let kindWords: [String: (categories: Set<FileCategory>, extensions: Set<String>)] = [
        "pdf": ([], ["pdf"]),
        "image": ([.images], []), "photo": ([.images], []), "picture": ([.images], []),
        "pic": ([.images], []), "jpg": ([], ["jpg", "jpeg"]), "jpeg": ([], ["jpg", "jpeg"]),
        "png": ([], ["png"]), "heic": ([], ["heic"]), "gif": ([], ["gif"]), "svg": ([], ["svg"]),
        "video": ([.videos], []), "movie": ([.videos], []), "clip": ([.videos], []),
        "recording": ([.videos], []), "mov": ([], ["mov"]), "mp4": ([], ["mp4"]),
        "music": ([.music], []), "song": ([.music], []), "audio": ([.music], []),
        "track": ([.music], []), "podcast": ([.music], []), "mp3": ([], ["mp3"]), "wav": ([], ["wav"]),
        "document": ([.documents], []), "doc": ([], ["doc", "docx", "pages"]), "docx": ([], ["docx"]),
        "word": ([], ["doc", "docx"]), "text": ([], ["txt", "md", "rtf"]), "note": ([], ["txt", "md", "rtf"]),
        "spreadsheet": ([], ["xls", "xlsx", "csv", "numbers"]), "excel": ([], ["xls", "xlsx"]),
        "csv": ([], ["csv"]), "sheet": ([], ["xls", "xlsx", "csv", "numbers"]),
        "presentation": ([], ["key", "ppt", "pptx"]), "slide": ([], ["key", "ppt", "pptx"]),
        "deck": ([], ["key", "ppt", "pptx"]), "keynote": ([], ["key"]), "powerpoint": ([], ["ppt", "pptx"]),
        "archive": ([.archives], []), "zip": ([], ["zip"]), "dmg": ([], ["dmg"]),
        "installer": ([], ["dmg", "pkg"]), "compressed": ([.archives], []),
        "app": ([.apps], []), "application": ([.apps], []),
        "design": ([], ["fig", "sketch", "psd", "ai", "svg"]), "psd": ([], ["psd"]), "sketch": ([], ["sketch"]),
    ]

    private static let sourceNames = [
        "WhatsApp", "Figma", "Slack", "Gmail", "Mail", "Safari", "Chrome", "Arc", "Firefox", "Edge",
        "Brave", "AirDrop", "Messages", "Telegram", "Discord", "Dropbox", "Google Drive", "GitHub",
        "Notion", "Zoom", "Teams", "Outlook", "iCloud", "WeTransfer", "Canva", "LinkedIn", "X",
    ]

    private static let folderNames = ["Downloads", "Desktop", "Documents", "Pictures", "Movies", "Music"]

    private static let stopWords: Set<String> = [
        "a", "an", "the", "my", "all", "any", "some", "file", "files", "show", "me", "find", "get",
        "with", "of", "that", "i", "which", "were", "was", "is", "are", "and", "or", "for", "to",
        "downloaded", "saved", "created", "made", "modified", "edited", "received", "got", "sent",
        "ago", "please", "stuff", "things", "everything", "from", "in", "on", "at", "about",
    ]

    private static let numberWords: [String: Int] = [
        "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
        "seven": 7, "eight": 8, "nine": 9, "ten": 10, "couple": 2, "few": 3,
    ]

    static func parse(_ input: String, now: Date = .now, calendar: Calendar = .current) -> ParsedQuery {
        var query = ParsedQuery()
        let tokens = tokenize(input)
        var consumed = Array(repeating: false, count: tokens.count)

        func word(_ i: Int) -> String? { i >= 0 && i < tokens.count ? tokens[i] : nil }
        func consume(_ range: ClosedRange<Int>) { for i in range where i < tokens.count { consumed[i] = true } }

        // 1. Dates (handled first so "from last week" isn't read as a source).
        var i = 0
        while i < tokens.count {
            if consumed[i] { i += 1; continue }
            if let match = matchDate(tokens: tokens, at: i, now: now, calendar: calendar) {
                let length = match.length
                query.dateRange = match.range
                query.dateLabel = match.label
                consume(i...(i + length - 1))
                // Swallow a leading "from/in/since/during".
                if let prev = word(i - 1), ["from", "in", "since", "during", "of", "within", "over"].contains(prev) {
                    consumed[i - 1] = true
                }
                i += length
                continue
            }
            i += 1
        }

        // 2. Sizes.
        i = 0
        while i < tokens.count {
            if consumed[i] { i += 1; continue }
            let token = tokens[i]
            if ["large", "big", "huge", "biggest", "largest", "heavy"].contains(token) {
                query.minSize = 100_000_000
                consumed[i] = true
            } else if ["small", "tiny", "smallest", "little"].contains(token) {
                query.maxSize = 1_000_000
                consumed[i] = true
            } else if let match = matchSize(tokens: tokens, at: i) {
                let bytes = match.bytes
                let length = match.length
                let comparator = (word(i - 1) ?? "") + " " + (word(i - 2) ?? "")
                let isMax = ["under", "below", "less", "smaller", "<", "max", "up"].contains { comparator.contains($0) }
                if isMax { query.maxSize = bytes } else { query.minSize = bytes }
                consume(i...(i + length - 1))
                for back in 1...2 {
                    if let prev = word(i - back),
                       ["over", "above", "larger", "bigger", "more", "than", "under", "below", "less", "smaller", "at", "least", "max", "up", "to", ">", "<"].contains(prev) {
                        consumed[i - back] = true
                    }
                }
                i += length
                continue
            }
            i += 1
        }

        // 3. Sources ("from whatsapp", "slack files") and folders ("in downloads").
        for (index, token) in tokens.enumerated() where !consumed[index] {
            if let source = sourceNames.first(where: { $0.lowercased() == token }), token != "x" || word(index - 1) == "from" {
                query.source = source
                consumed[index] = true
                if word(index - 1) == "from" { consumed[index - 1] = true }
                continue
            }
            if token == "google", word(index + 1) == "drive" {
                query.source = "Google Drive"
                consume(index...(index + 1))
                continue
            }
            if let folder = folderNames.first(where: { $0.lowercased() == token }),
               let prev = word(index - 1), ["in", "on", "from", "inside"].contains(prev) {
                query.folder = folder
                consume((index - 1)...index)
            }
        }

        // 4. Kinds.
        for (index, token) in tokens.enumerated() where !consumed[index] {
            if ["screenshot", "screenshots", "screengrab", "screencap"].contains(token) {
                query.screenshotsOnly = true
                query.categories.insert(.images)
                consumed[index] = true
                continue
            }
            let singular = singularize(token)
            if let kind = kindWords[singular] {
                query.categories.formUnion(kind.categories)
                query.extensions.formUnion(kind.extensions)
                consumed[index] = true
            } else if token.count <= 5, FileCategory.classify(url: URL(fileURLWithPath: "x.\(token)"), contentType: nil) != .other,
                      word(index - 1) == "." {
                query.extensions.insert(token)
                consumed[index] = true
            }
        }

        // 5. Everything left is a keyword.
        for (index, token) in tokens.enumerated() where !consumed[index] {
            if stopWords.contains(token) || token == "." || token == ">" || token == "<" { continue }
            if !query.terms.contains(token) {
                query.terms.append(token)
            }
        }
        return query
    }

    // MARK: Tokenizing

    private static func tokenize(_ input: String) -> [String] {
        var raw: [String] = []
        var current = ""
        func flush() {
            if !current.isEmpty { raw.append(current) }
            current = ""
        }
        for ch in input.lowercased() {
            if ch.isLetter || ch.isNumber || ch == "-" || ch == "_" {
                current.append(ch)
            } else if ch == ".", let last = current.last, last.isNumber {
                current.append(ch) // decimal point, e.g. "1.5gb"
            } else {
                flush()
                if ch == "." || ch == ">" || ch == "<" { raw.append(String(ch)) }
            }
        }
        flush()

        // Split glued number+unit tokens such as "10mb" into "10", "mb".
        var tokens: [String] = []
        for token in raw {
            if let first = token.first, first.isNumber,
               let unitStart = token.firstIndex(where: { $0.isLetter }),
               token[unitStart...].allSatisfy({ $0.isLetter }) {
                tokens.append(String(token[..<unitStart]))
                tokens.append(String(token[unitStart...]))
            } else {
                tokens.append(token)
            }
        }
        return tokens
    }

    private static func singularize(_ word: String) -> String {
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("ses") || word.hasSuffix("xes") { return String(word.dropLast(2)) }
        if word.hasSuffix("s") && !word.hasSuffix("ss") && word.count > 3 { return String(word.dropLast()) }
        return word
    }

    // MARK: Sizes

    private static func matchSize(tokens: [String], at index: Int) -> (bytes: Int64, length: Int)? {
        guard let value = Double(tokens[index]) else { return nil }
        guard index + 1 < tokens.count else { return nil }
        let multiplier: Double
        switch tokens[index + 1] {
        case "kb", "k": multiplier = 1_000
        case "mb", "m", "meg", "megs", "megabytes", "megabyte": multiplier = 1_000_000
        case "gb", "g", "gig", "gigs", "gigabytes", "gigabyte": multiplier = 1_000_000_000
        case "tb": multiplier = 1_000_000_000_000
        default: return nil
        }
        return (Int64(value * multiplier), 2)
    }

    // MARK: Dates

    private static let months = [
        "january", "february", "march", "april", "may", "june",
        "july", "august", "september", "october", "november", "december"
    ]
    private static let shortMonths = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
    private static let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

    private static func matchDate(
        tokens: [String], at i: Int, now: Date, calendar: Calendar
    ) -> (range: ClosedRange<Date>, label: String, length: Int)? {
        let t0 = tokens[i]
        let t1 = i + 1 < tokens.count ? tokens[i + 1] : ""
        let t2 = i + 2 < tokens.count ? tokens[i + 2] : ""

        func startOf(_ component: Calendar.Component, _ date: Date) -> Date {
            calendar.dateInterval(of: component, for: date)?.start ?? date
        }
        func interval(_ component: Calendar.Component, offset: Int) -> ClosedRange<Date>? {
            guard let shifted = calendar.date(byAdding: component, value: offset, to: now),
                  let span = calendar.dateInterval(of: component, for: shifted) else { return nil }
            let end = offset == 0 ? now : span.end.addingTimeInterval(-1)
            return span.start...max(end, span.start)
        }
        func unit(_ word: String) -> Calendar.Component? {
            switch singularize(word) {
            case "day": return .day
            case "week": return .weekOfYear
            case "month": return .month
            case "year": return .year
            case "hour": return .hour
            default: return nil
            }
        }

        switch t0 {
        case "today":
            return (startOf(.day, now)...now, "Today", 1)
        case "yesterday":
            let start = calendar.date(byAdding: .day, value: -1, to: startOf(.day, now)) ?? now
            return (start...startOf(.day, now).addingTimeInterval(-1), "Yesterday", 1)
        case "recent", "recently", "latest", "new", "newest":
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start...now, "Recent", 1)
        case "this", "current":
            if let component = unit(t1), let range = interval(component, offset: 0) {
                return (range, "This \(singularize(t1))", 2)
            }
        case "last", "past", "previous":
            // "last 3 days" / "past two weeks"
            if let n = Int(t1) ?? numberWords[t1], let component = unit(t2),
               let start = calendar.date(byAdding: component, value: -n, to: now) {
                return (start...now, "Last \(n) \(n == 1 ? singularize(t2) : singularize(t2) + "s")", 3)
            }
            if let component = unit(t1), let range = interval(component, offset: -1) {
                return (range, "Last \(singularize(t1))", 2)
            }
            if let weekday = weekdays.firstIndex(of: t1) {
                return dayRange(weekday: weekday, now: now, calendar: calendar).map { ($0, "Last \(t1.capitalized)", 2) }
            }
        case "older", "before":
            // "older than 3 months"
            let offset = t1 == "than" ? 1 : 0
            let nTok = i + 1 + offset < tokens.count ? tokens[i + 1 + offset] : ""
            let uTok = i + 2 + offset < tokens.count ? tokens[i + 2 + offset] : ""
            if let n = Int(nTok) ?? numberWords[nTok], let component = unit(uTok),
               let end = calendar.date(byAdding: component, value: -n, to: now) {
                return (Date.distantPast...end, "Older than \(n) \(n == 1 ? singularize(uTok) : singularize(uTok) + "s")", 3 + offset)
            }
        case "old":
            let end = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            return (Date.distantPast...end, "Older than 6 months", 1)
        default:
            break
        }

        // "3 days ago", "2 weeks"
        if let n = Int(t0) ?? (t0.count > 2 ? numberWords[t0] : nil), let component = unit(t1),
           let start = calendar.date(byAdding: component, value: -n, to: now) {
            let length = t2 == "ago" ? 3 : 2
            let label = "Last \(n) \(n == 1 ? singularize(t1) : singularize(t1) + "s")"
            return (start...now, label, length)
        }

        // Month names: "in march", "march 2024"
        let previous = i > 0 ? tokens[i - 1] : ""
        let monthIndex = months.firstIndex(of: t0)
            ?? (["in", "from", "since", "during"].contains(previous) ? shortMonths.firstIndex(of: t0) : nil)
        if let month = monthIndex, t0 != "may" || ["in", "from", "since", "during"].contains(previous) {
            var year = calendar.component(.year, from: now)
            var length = 1
            if let y = Int(t1), (1990...2100).contains(y) {
                year = y
                length = 2
            } else if month + 1 > calendar.component(.month, from: now) {
                year -= 1 // "in november" means the most recent November
            }
            var comps = DateComponents()
            comps.year = year
            comps.month = month + 1
            comps.day = 1
            if let start = calendar.date(from: comps),
               let span = calendar.dateInterval(of: .month, for: start) {
                let label = months[month].capitalized + (length == 2 ? " \(year)" : "")
                return (span.start...span.end.addingTimeInterval(-1), label, length)
            }
        }

        // Bare year: "2024"
        if let year = Int(t0), (1990...2100).contains(year), t1 != "mb", t1 != "gb", t1 != "kb" {
            var comps = DateComponents()
            comps.year = year
            comps.month = 1
            comps.day = 1
            if let start = calendar.date(from: comps), let span = calendar.dateInterval(of: .year, for: start) {
                return (span.start...span.end.addingTimeInterval(-1), "In \(year)", 1)
            }
        }

        // Weekday: "on monday"
        if let weekday = weekdays.firstIndex(of: t0) {
            return dayRange(weekday: weekday, now: now, calendar: calendar).map { ($0, t0.capitalized, 1) }
        }
        return nil
    }

    /// The most recent occurrence of a weekday (0 = Sunday), as a full-day range.
    private static func dayRange(weekday: Int, now: Date, calendar: Calendar) -> ClosedRange<Date>? {
        let today = calendar.component(.weekday, from: now) - 1
        var delta = today - weekday
        if delta <= 0 { delta += 7 }
        guard let day = calendar.date(byAdding: .day, value: -delta, to: now),
              let span = calendar.dateInterval(of: .day, for: day) else { return nil }
        return span.start...span.end.addingTimeInterval(-1)
    }
}
