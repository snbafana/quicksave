import Foundation

public struct ObsidianDailyNotes {
    public static let defaultDailyNotesPath = "~/Documents/Obsidian-Vault/Zettelkatsen"

    private let dailyNotesDirectory: URL
    private let fileManager: FileManager

    public init(dailyNotesDirectory: URL, fileManager: FileManager = .default) {
        self.dailyNotesDirectory = dailyNotesDirectory
        self.fileManager = fileManager
    }

    public func append(captureURL: URL, note: String? = nil, date: Date = Date()) throws -> URL {
        try fileManager.createDirectory(at: dailyNotesDirectory, withIntermediateDirectories: true)

        let dailyNoteURL = dailyNotesDirectory.appendingPathComponent("\(Self.dailyNoteName(for: date)).md")
        try ensureDailyNote(at: dailyNoteURL, date: date)

        let entry = try markdownEntry(captureURL: captureURL, note: note, dailyNoteURL: dailyNoteURL, date: date)
        var contents = try String(contentsOf: dailyNoteURL, encoding: .utf8)
        contents = ensureQuicksaveSection(in: contents)
        contents += entry
        try contents.write(to: dailyNoteURL, atomically: true, encoding: .utf8)

        return dailyNoteURL
    }

    public static func defaultDailyNotesURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        let raw = environment["QUICKSAVE_OBSIDIAN_DAILY_NOTES"] ?? defaultDailyNotesPath
        return URL(fileURLWithPath: NSString(string: raw).expandingTildeInPath, isDirectory: true)
    }

    public static func dailyNoteName(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM-dd-yyyy"
        return formatter.string(from: date)
    }

    private func markdownEntry(captureURL: URL, note: String?, dailyNoteURL: URL, date: Date) throws -> String {
        let renderedCapture = try renderCapture(captureURL, relativeTo: dailyNoteURL)
        let renderedNote = renderNote(note)
        return "\n- \(timeString(for: date))\n\(renderedCapture)\(renderedNote)\n"
    }

    private func renderCapture(_ captureURL: URL, relativeTo dailyNoteURL: URL) throws -> String {
        if captureURL.pathExtension.lowercased() == "txt" {
            let text = try String(contentsOf: captureURL, encoding: .utf8)
            return blockquote(text)
        }

        let assetURL = try copyAsset(captureURL, relativeTo: dailyNoteURL)
        let path = markdownPath(from: dailyNoteURL.deletingLastPathComponent(), to: assetURL)
        let label = assetURL.lastPathComponent

        if isImage(assetURL) {
            return "  ![\(label)](\(path))\n"
        }

        return "  [\(label)](\(path))\n"
    }

    private func blockquote(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard !lines.isEmpty else {
            return "  >\n"
        }
        return lines.map { "  > \($0)" }.joined(separator: "\n") + "\n"
    }

    private func renderNote(_ note: String?) -> String {
        guard let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else {
            return ""
        }

        let lines = note.split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.first else {
            return ""
        }

        let rest = lines.dropFirst().map { "    \($0)" }.joined(separator: "\n")
        if rest.isEmpty {
            return "  - \(first)\n"
        }
        return "  - \(first)\n\(rest)\n"
    }

    private func copyAsset(_ sourceURL: URL, relativeTo dailyNoteURL: URL) throws -> URL {
        let assetsDirectory = dailyNoteURL.deletingLastPathComponent().appendingPathComponent("quicksave-assets", isDirectory: true)
        try fileManager.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)

        let destination = FileNaming.uniqueURL(
            in: assetsDirectory,
            preferredName: sourceURL.lastPathComponent,
            fileManager: fileManager
        )
        try fileManager.copyItem(at: sourceURL, to: destination)
        return destination
    }

    private func ensureDailyNote(at url: URL, date: Date) throws {
        guard !fileManager.fileExists(atPath: url.path) else {
            return
        }

        let title = Self.dailyNoteName(for: date)
        try "# \(title)\n".write(to: url, atomically: true, encoding: .utf8)
    }

    private func ensureQuicksaveSection(in contents: String) -> String {
        let normalized = contents.hasSuffix("\n") ? contents : contents + "\n"
        if normalized.contains("\n## Quicksave\n") || normalized.hasPrefix("## Quicksave\n") {
            return normalized
        }
        return normalized + "\n## Quicksave\n"
    }

    private func isImage(_ url: URL) -> Bool {
        ["png", "jpg", "jpeg", "gif", "heic", "webp"].contains(url.pathExtension.lowercased())
    }

    private func markdownPath(from base: URL, to target: URL) -> String {
        let relative = target.path.replacingOccurrences(of: base.path + "/", with: "")
        return relative
            .split(separator: "/")
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
    }

    private func timeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
