import Foundation
import QuicksaveCore

@main
struct QuicksaveCLI {
    static func main() {
        do {
            try run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            fputs("quicksave: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func run(arguments: [String]) throws {
        guard let command = arguments.first else {
            printUsage()
            return
        }

        switch command {
        case "obsidian":
            try runObsidian(arguments: Array(arguments.dropFirst()))
        case "help", "--help", "-h":
            printUsage()
        default:
            throw CLIError.unknownCommand(command)
        }
    }

    private static func runObsidian(arguments: [String]) throws {
        guard let command = arguments.first else {
            printObsidianUsage()
            return
        }

        let options = Options(Array(arguments.dropFirst()))
        let dailyNotes = ObsidianDailyNotes(dailyNotesDirectory: options.dailyNotesDirectory)

        switch command {
        case "append":
            let captureURL = try options.requiredURL("--capture")
            try append(captureURL, options: options, dailyNotes: dailyNotes)
        case "append-latest":
            let captureURL = try latestCapture(in: options.inboxDirectory)
            try append(captureURL, options: options, dailyNotes: dailyNotes)
        case "today":
            let dailyNoteURL = options.dailyNotesDirectory
                .appendingPathComponent("\(ObsidianDailyNotes.dailyNoteName(for: Date())).md")
            print(dailyNoteURL.path)
        case "help", "--help", "-h":
            printObsidianUsage()
        default:
            throw CLIError.unknownCommand("obsidian \(command)")
        }
    }

    private static func append(_ captureURL: URL, options: Options, dailyNotes: ObsidianDailyNotes) throws {
        let note = try options.noteOrSidecar(for: captureURL)
        let dailyNote = try dailyNotes.append(captureURL: captureURL, note: note)
        print(dailyNote.path)
    }

    private static func latestCapture(in inboxDirectory: URL) throws -> URL {
        let files = try FileManager.default.contentsOfDirectory(
            at: inboxDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { !$0.lastPathComponent.hasSuffix(".note.txt") }
        .sorted { lhs, rhs in
            modificationDate(lhs) > modificationDate(rhs)
        }

        guard let latest = files.first else {
            throw CLIError.noCaptures(inboxDirectory.path)
        }
        return latest
    }

    private static func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private static func printUsage() {
        print("""
        Usage:
          quicksave obsidian append --capture <path> [--note <text>] [--daily-notes-dir <path>]
          quicksave obsidian append-latest [--inbox <path>] [--note <text>] [--daily-notes-dir <path>]
          quicksave obsidian today [--daily-notes-dir <path>]

        Install:
          ./scripts/install-cli.sh
        """)
    }

    private static func printObsidianUsage() {
        printUsage()
    }
}

private struct Options {
    private var values: [String: String] = [:]

    init(_ arguments: [String]) {
        var index = 0
        while index < arguments.count {
            let key = arguments[index]
            if key.hasPrefix("--"), index + 1 < arguments.count {
                values[key] = arguments[index + 1]
                index += 2
            } else {
                index += 1
            }
        }
    }

    var dailyNotesDirectory: URL {
        if let path = values["--daily-notes-dir"] {
            return expandedURL(path, isDirectory: true)
        }
        return ObsidianDailyNotes.defaultDailyNotesURL()
    }

    var inboxDirectory: URL {
        if let path = values["--inbox"] {
            return expandedURL(path, isDirectory: true)
        }
        return QuicksaveSettings.inboxURL()
    }

    func requiredURL(_ key: String) throws -> URL {
        guard let path = values[key] else {
            throw CLIError.missingOption(key)
        }
        return expandedURL(path, isDirectory: false)
    }

    func noteOrSidecar(for captureURL: URL) throws -> String? {
        if let note = values["--note"] {
            return note
        }

        let sidecar = captureURL
            .deletingPathExtension()
            .appendingPathExtension("note")
            .appendingPathExtension("txt")

        guard FileManager.default.fileExists(atPath: sidecar.path) else {
            return nil
        }
        return try String(contentsOf: sidecar, encoding: .utf8)
    }

    private func expandedURL(_ path: String, isDirectory: Bool) -> URL {
        URL(fileURLWithPath: NSString(string: path).expandingTildeInPath, isDirectory: isDirectory)
    }
}

private enum CLIError: LocalizedError {
    case missingOption(String)
    case noCaptures(String)
    case unknownCommand(String)

    var errorDescription: String? {
        switch self {
        case .missingOption(let option):
            "Missing required option \(option)."
        case .noCaptures(let path):
            "No captures found in \(path)."
        case .unknownCommand(let command):
            "Unknown command \(command)."
        }
    }
}
