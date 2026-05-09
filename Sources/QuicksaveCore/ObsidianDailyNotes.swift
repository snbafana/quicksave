import Foundation

public struct ObsidianDailyNotes {
    public static let defaultDailyNotesPath = "~/Documents/Obsidian-Vault/Zettelkatsen"
    public typealias DailyNoteResolver = (URL, Date) throws -> URL

    private let dailyNotesDirectory: URL
    private let fileManager: FileManager
    private let resolveDailyNote: DailyNoteResolver

    public init(
        dailyNotesDirectory: URL,
        fileManager: FileManager = .default,
        resolveDailyNote: @escaping DailyNoteResolver = ObsidianCLI.resolveOrCreateDailyNote
    ) {
        self.dailyNotesDirectory = dailyNotesDirectory
        self.fileManager = fileManager
        self.resolveDailyNote = resolveDailyNote
    }

    public func append(captureURL: URL, note: String? = nil, date: Date = Date()) throws -> URL {
        try append(captureURLs: [captureURL], note: note, date: date)
    }

    public func append(captureURLs: [URL], note: String? = nil, date: Date = Date()) throws -> URL {
        try fileManager.createDirectory(at: dailyNotesDirectory, withIntermediateDirectories: true)

        let dailyNoteURL = try dailyNoteURL(for: date)

        let entries = try captureURLs
            .map { try markdownEntry(captureURL: $0, note: note, dailyNoteURL: dailyNoteURL, date: date) }
            .joined()
        var contents = try String(contentsOf: dailyNoteURL, encoding: .utf8)
        contents = ensureQuicksaveSection(in: contents)
        contents += entries
        try contents.write(to: dailyNoteURL, atomically: true, encoding: .utf8)

        return dailyNoteURL
    }

    public func appendNotes(for captureURLs: [URL], note: String, date: Date = Date()) throws -> URL {
        try fileManager.createDirectory(at: dailyNotesDirectory, withIntermediateDirectories: true)

        let dailyNoteURL = try dailyNoteURL(for: date)

        let entries = captureURLs
            .map { markdownNoteEntry(captureURL: $0, note: note, date: date) }
            .joined()
        var contents = try String(contentsOf: dailyNoteURL, encoding: .utf8)
        contents = ensureQuicksaveSection(in: contents)
        contents += entries
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

    public static func fileSystemDailyNoteResolver(fileManager: FileManager = .default) -> DailyNoteResolver {
        { expectedURL, date in
            if !fileManager.fileExists(atPath: expectedURL.path) {
                try fileManager.createDirectory(at: expectedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let title = Self.dailyNoteName(for: date)
                try "# \(title)\n".write(to: expectedURL, atomically: true, encoding: .utf8)
            }
            return expectedURL
        }
    }

    public func dailyNoteURL(for date: Date = Date()) throws -> URL {
        let expectedURL = dailyNotesDirectory.appendingPathComponent("\(Self.dailyNoteName(for: date)).md")
        return try resolveDailyNote(expectedURL, date)
    }

    private func markdownEntry(captureURL: URL, note: String?, dailyNoteURL: URL, date: Date) throws -> String {
        let renderedCapture = try renderCapture(captureURL, relativeTo: dailyNoteURL)
        let renderedNote = renderNote(note)
        return "\n- \(timeString(for: date))\n\(renderedCapture)\(renderedNote)\n"
    }

    private func markdownNoteEntry(captureURL: URL, note: String, date: Date) -> String {
        "\n- \(timeString(for: date))\n  Note for `\(captureURL.lastPathComponent)`\n\(renderNote(note))\n"
    }

    private func renderCapture(_ captureURL: URL, relativeTo dailyNoteURL: URL) throws -> String {
        if isTextCapture(captureURL) {
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

    private func isTextCapture(_ url: URL) -> Bool {
        ["txt", "md"].contains(url.pathExtension.lowercased())
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

public enum ObsidianDailyNoteError: LocalizedError {
    case commandFailed(String, String)
    case notCreated(String, String?)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let command, let message):
            return "Obsidian CLI command `\(command)` failed: \(message)"
        case .notCreated(let path, let cliPath):
            if let cliPath, !cliPath.isEmpty {
                return "Obsidian CLI finished, but the daily note was not created at \(path). The CLI reported daily path `\(cliPath)`."
            }
            return "Obsidian CLI finished, but the daily note was not created at \(path)."
        }
    }
}

public enum ObsidianCLI {
    public static func resolveOrCreateDailyNote(expectedURL: URL, date: Date) throws -> URL {
        try resolveOrCreateDailyNote(expectedURL: expectedURL, date: date, executable: configuredExecutable())
    }

    static func resolveOrCreateDailyNote(expectedURL: URL, date: Date, executable: String) throws -> URL {
        _ = date

        let dailyNoteURL = try currentDailyNoteURL(executable: executable)
        if FileManager.default.fileExists(atPath: dailyNoteURL.path) {
            return dailyNoteURL
        }

        _ = try run(["daily"], executable: executable)

        guard FileManager.default.fileExists(atPath: dailyNoteURL.path) else {
            throw ObsidianDailyNoteError.notCreated(dailyNoteURL.path, relativeDailyPath(dailyNoteURL, fallback: expectedURL))
        }

        return dailyNoteURL
    }

    static func currentDailyNoteURL(executable: String = configuredExecutable()) throws -> URL {
        let cliDailyPath = try run(["daily:path"], executable: executable)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cliDailyPath.isEmpty else {
            throw ObsidianDailyNoteError.commandFailed("\(executable) daily:path", "empty daily note path")
        }

        if cliDailyPath.hasPrefix("/") {
            return URL(fileURLWithPath: cliDailyPath)
        }

        let vaultPath = try run(["vault", "info=path"], executable: executable)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !vaultPath.isEmpty else {
            throw ObsidianDailyNoteError.commandFailed("\(executable) vault info=path", "empty vault path")
        }

        return URL(fileURLWithPath: vaultPath, isDirectory: true).appendingPathComponent(cliDailyPath)
    }

    static func run(_ arguments: [String], executable: String = configuredExecutable()) throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ObsidianDailyNoteError.commandFailed(
                ([executable] + arguments).joined(separator: " "),
                message ?? "exit \(process.terminationStatus)"
            )
        }

        return String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    private static func configuredExecutable() -> String {
        ProcessInfo.processInfo.environment["QUICKSAVE_OBSIDIAN_CLI"] ?? "obsidian"
    }

    private static func relativeDailyPath(_ url: URL, fallback: URL) -> String {
        let path = url.path
        let fallbackDirectory = fallback.deletingLastPathComponent().path + "/"
        if path.hasPrefix(fallbackDirectory) {
            return String(path.dropFirst(fallbackDirectory.count))
        }
        return path
    }
}
