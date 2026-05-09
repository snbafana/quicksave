import Foundation

public struct ObsidianDailyNotes {
    public static let defaultVaultPath = "~/Documents/Obsidian-Vault"
    public static let defaultDailyNotesPath = "~/Documents/Obsidian-Vault/Zettelkatsen"
    public static let defaultDailyTemplatePath = "~/Documents/Obsidian-Vault/Templates/Daily Note.md"
    public typealias DailyNoteResolver = (URL, Date) throws -> URL

    private let dailyNotesDirectory: URL
    private let fileManager: FileManager
    private let resolveDailyNote: DailyNoteResolver

    public init(
        dailyNotesDirectory: URL,
        fileManager: FileManager = .default,
        resolveDailyNote: DailyNoteResolver? = nil
    ) {
        self.dailyNotesDirectory = dailyNotesDirectory
        self.fileManager = fileManager
        self.resolveDailyNote = resolveDailyNote ?? Self.obsidianTemplateDailyNoteResolver(fileManager: fileManager)
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

    public static func defaultVaultURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        let raw = environment["QUICKSAVE_OBSIDIAN_VAULT"] ?? defaultVaultPath
        return URL(fileURLWithPath: NSString(string: raw).expandingTildeInPath, isDirectory: true)
    }

    public static func defaultDailyTemplateURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        let raw = environment["QUICKSAVE_OBSIDIAN_DAILY_TEMPLATE"] ?? defaultDailyTemplatePath
        return URL(fileURLWithPath: NSString(string: raw).expandingTildeInPath, isDirectory: false)
    }

    public static func dailyNoteName(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM-dd-yyyy"
        return formatter.string(from: date)
    }

    public static func obsidianTemplateDailyNoteResolver(
        vaultURL: URL = defaultVaultURL(),
        templateURL: URL = defaultDailyTemplateURL(),
        fileManager: FileManager = .default
    ) -> DailyNoteResolver {
        { expectedURL, date in
            if fileManager.fileExists(atPath: expectedURL.path) {
                return expectedURL
            }

            let content = try renderDailyTemplate(at: templateURL, date: date, title: expectedURL.deletingPathExtension().lastPathComponent)
            let relativePath = vaultRelativePath(for: expectedURL, vaultURL: vaultURL)

            do {
                try ObsidianCLI.create(path: relativePath, content: content)
            } catch {
                try createDailyNoteFile(at: expectedURL, content: content, fileManager: fileManager)
            }

            guard fileManager.fileExists(atPath: expectedURL.path) else {
                throw ObsidianDailyNoteError.notCreated(expectedURL.path, nil)
            }
            return expectedURL
        }
    }

    public static func fileSystemDailyNoteResolver(
        fileManager: FileManager = .default,
        templateURL: URL? = nil
    ) -> DailyNoteResolver {
        { expectedURL, date in
            if !fileManager.fileExists(atPath: expectedURL.path) {
                let content = try renderDailyTemplate(
                    at: templateURL,
                    date: date,
                    title: expectedURL.deletingPathExtension().lastPathComponent
                )
                try createDailyNoteFile(at: expectedURL, content: content, fileManager: fileManager)
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

    private static func createDailyNoteFile(at url: URL, content: String, fileManager: FileManager) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func renderDailyTemplate(at templateURL: URL?, date: Date, title: String) throws -> String {
        let template: String
        if let templateURL, FileManager.default.fileExists(atPath: templateURL.path) {
            template = try String(contentsOf: templateURL, encoding: .utf8)
        } else {
            template = "# {{title}}\n"
        }

        return renderTemplate(template, date: date, title: title)
    }

    private static func renderTemplate(_ template: String, date: Date, title: String) -> String {
        var output = template
        output = replaceTemplateTokens(named: "date", in: output, date: date, defaultFormat: "YYYY-MM-DD")
        output = replaceTemplateTokens(named: "time", in: output, date: date, defaultFormat: "HH:mm")
        output = output.replacingOccurrences(of: "{{title}}", with: title)
        return output.hasSuffix("\n") ? output : output + "\n"
    }

    private static func replaceTemplateTokens(named token: String, in text: String, date: Date, defaultFormat: String) -> String {
        let escapedToken = NSRegularExpression.escapedPattern(for: token)
        let pattern = "\\{\\{\(escapedToken)(?::([^}]+))?\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).reversed()
        var output = text

        for match in matches {
            let formatRange = match.range(at: 1)
            let momentFormat = formatRange.location == NSNotFound ? defaultFormat : nsText.substring(with: formatRange)
            let value = formatDate(date, momentFormat: momentFormat)
            if let range = Range(match.range, in: output) {
                output.replaceSubrange(range, with: value)
            }
        }

        return output
    }

    private static func formatDate(_ date: Date, momentFormat: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = swiftDateFormat(from: momentFormat)
        return formatter.string(from: date)
    }

    private static func swiftDateFormat(from momentFormat: String) -> String {
        momentFormat
            .replacingOccurrences(of: "YYYY", with: "yyyy")
            .replacingOccurrences(of: "YY", with: "yy")
            .replacingOccurrences(of: "DD", with: "dd")
    }

    private static func vaultRelativePath(for url: URL, vaultURL: URL) -> String {
        let vaultPath = vaultURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        let prefix = vaultPath.hasSuffix("/") ? vaultPath : vaultPath + "/"

        if path.hasPrefix(prefix) {
            return String(path.dropFirst(prefix.count))
        }
        return url.lastPathComponent
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
    public static func create(path: String, content: String) throws {
        _ = try run([
            "create",
            "path=\(path)",
            "content=\(escapedContent(content))",
            "open"
        ])
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

    private static func escapedContent(_ content: String) -> String {
        content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}
