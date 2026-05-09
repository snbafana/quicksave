import AppKit
import Foundation
import Testing
@testable import QuicksaveCore

@Suite("Obsidian daily notes")
struct ObsidianDailyNotesTests {
    @Test func createsDailyNoteAndAppendsTextAsBlockquote() throws {
        let fixture = try ObsidianFixture()
        let capture = fixture.root.appendingPathComponent("capture.txt")
        try "first line\nsecond line".write(to: capture, atomically: true, encoding: .utf8)

        let dailyNote = try fixture.writer.append(captureURL: capture, note: "my note", date: fixture.date)
        let contents = try String(contentsOf: dailyNote, encoding: .utf8)

        #expect(dailyNote.lastPathComponent == "05-09-2026.md")
        #expect(contents.contains("# 05-09-2026"))
        #expect(contents.contains("## Quicksave"))
        #expect(contents.contains("> first line\n  > second line"))
        #expect(contents.contains("  - my note"))
    }

    @Test func copiesImagesToAssetsAndEmbedsMarkdownImage() throws {
        let fixture = try ObsidianFixture()
        let image = fixture.root.appendingPathComponent("clip image.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: image)

        let dailyNote = try fixture.writer.append(captureURL: image, date: fixture.date)
        let contents = try String(contentsOf: dailyNote, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: fixture.dailyNotes.appendingPathComponent("quicksave-assets/clip image.png").path))
        #expect(contents.contains("![clip image.png](quicksave-assets/clip%20image.png)"))
    }

    @Test func appendsMarkdownTextCaptureAsBlockquote() throws {
        let fixture = try ObsidianFixture()
        let capture = fixture.root.appendingPathComponent("linked-text.md")
        try "Read [example](https://example.com) now".write(to: capture, atomically: true, encoding: .utf8)

        let dailyNote = try fixture.writer.append(captureURL: capture, date: fixture.date)
        let contents = try String(contentsOf: dailyNote, encoding: .utf8)

        #expect(contents.contains("> Read [example](https://example.com) now"))
    }

    @Test func capturedImageCanBeSavedAndEmbeddedInDailyNote() throws {
        let fixture = try ObsidianFixture()
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        pasteboard.writeObjects([makeObsidianTestImage()])

        let capture = try #require(
            try ClipboardCapture().captureClipboard(to: fixture.root.appendingPathComponent("inbox", isDirectory: true), pasteboard: pasteboard).firstSavedURL
        )
        let dailyNote = try fixture.writer.append(captureURL: capture, date: fixture.date)
        let contents = try String(contentsOf: dailyNote, encoding: .utf8)
        let embeddedImage = fixture.dailyNotes.appendingPathComponent("quicksave-assets/\(capture.lastPathComponent)")

        #expect(capture.pathExtension == "png")
        #expect(FileManager.default.fileExists(atPath: embeddedImage.path))
        #expect(contents.contains("![\(capture.lastPathComponent)](quicksave-assets/\(capture.lastPathComponent))"))
    }

    @Test func copiesFilesToAssetsAndAddsMarkdownLink() throws {
        let fixture = try ObsidianFixture()
        let file = fixture.root.appendingPathComponent("source.pdf")
        try Data("%PDF-1.4".utf8).write(to: file)

        let dailyNote = try fixture.writer.append(captureURL: file, note: "pdf context", date: fixture.date)
        let contents = try String(contentsOf: dailyNote, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: fixture.dailyNotes.appendingPathComponent("quicksave-assets/source.pdf").path))
        #expect(contents.contains("[source.pdf](quicksave-assets/source.pdf)"))
        #expect(contents.contains("  - pdf context"))
    }

    @Test func appendsMultipleCapturesInOneDailyNote() throws {
        let fixture = try ObsidianFixture()
        let first = fixture.root.appendingPathComponent("first.txt")
        let second = fixture.root.appendingPathComponent("second.txt")
        try "first".write(to: first, atomically: true, encoding: .utf8)
        try "second".write(to: second, atomically: true, encoding: .utf8)

        let dailyNote = try fixture.writer.append(captureURLs: [first, second], date: fixture.date)
        let contents = try String(contentsOf: dailyNote, encoding: .utf8)

        #expect(contents.contains("> first"))
        #expect(contents.contains("> second"))
    }

    @Test func appendsNotesForEachCaptureWithoutDuplicatingCaptureBody() throws {
        let fixture = try ObsidianFixture()
        let first = fixture.root.appendingPathComponent("first.txt")
        let second = fixture.root.appendingPathComponent("second.txt")
        try "first capture body".write(to: first, atomically: true, encoding: .utf8)
        try "second capture body".write(to: second, atomically: true, encoding: .utf8)

        let dailyNote = try fixture.writer.appendNotes(for: [first, second], note: "why this mattered", date: fixture.date)
        let contents = try String(contentsOf: dailyNote, encoding: .utf8)

        #expect(contents.contains("Note for `first.txt`"))
        #expect(contents.contains("Note for `second.txt`"))
        #expect(contents.contains("  - why this mattered"))
        #expect(!contents.contains("first capture body"))
        #expect(!contents.contains("second capture body"))
    }

    @Test func usesDailyNoteResolverWhenDailyNoteIsMissing() throws {
        let fixture = try ObsidianFixture()
        let capture = fixture.root.appendingPathComponent("capture.txt")
        try "created through injected cli".write(to: capture, atomically: true, encoding: .utf8)

        _ = try fixture.writer.append(captureURL: capture, date: fixture.date)

        #expect(fixture.resolvedDailyNoteCount == 1)
    }

    @Test func usesDailyNoteResolverWhenDailyNoteExists() throws {
        let fixture = try ObsidianFixture()
        let capture = fixture.root.appendingPathComponent("capture.txt")
        let dailyNote = fixture.dailyNotes.appendingPathComponent("05-09-2026.md")
        try "# Existing\n".write(to: dailyNote, atomically: true, encoding: .utf8)
        try "existing daily note".write(to: capture, atomically: true, encoding: .utf8)

        _ = try fixture.writer.append(captureURL: capture, date: fixture.date)

        #expect(fixture.resolvedDailyNoteCount == 1)
    }

    @Test func obsidianCLIResolverUsesDailyPathVaultThenDaily() throws {
        let fixture = try ObsidianFixture()
        let expectedDailyNote = fixture.dailyNotes.appendingPathComponent("05-09-2026.md")
        let cliDailyNote = fixture.root.appendingPathComponent("Obsidian-Vault/2026-05-09.md")
        let log = fixture.root.appendingPathComponent("obsidian-cli.log")
        let fakeCLI = fixture.root.appendingPathComponent("fake-obsidian")
        let script = """
        #!/bin/sh
        echo "$1" >> \(shellQuote(log.path))
        if [ "$1" = "daily:path" ]; then
          echo "2026-05-09.md"
          exit 0
        fi
        if [ "$1" = "vault" ]; then
          echo \(shellQuote(fixture.root.appendingPathComponent("Obsidian-Vault", isDirectory: true).path))
          exit 0
        fi
        if [ "$1" = "daily" ]; then
          mkdir -p \(shellQuote(cliDailyNote.deletingLastPathComponent().path))
          printf '# 2026-05-09\\n' > \(shellQuote(cliDailyNote.path))
          exit 0
        fi
        exit 1
        """
        try script.write(to: fakeCLI, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeCLI.path)

        let resolved = try ObsidianCLI.resolveOrCreateDailyNote(
            expectedURL: expectedDailyNote,
            date: fixture.date,
            executable: fakeCLI.path
        )

        let calls = try String(contentsOf: log, encoding: .utf8)
        #expect(calls == "daily:path\nvault\ndaily\n")
        #expect(resolved == cliDailyNote)
        #expect(FileManager.default.fileExists(atPath: cliDailyNote.path))
    }
}

private final class ObsidianFixture {
    let root: URL
    let dailyNotes: URL
    let writer: ObsidianDailyNotes
    let date: Date
    private let resolvedDailyNotes = CountBox()

    var resolvedDailyNoteCount: Int {
        resolvedDailyNotes.value
    }

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("quicksave-obsidian-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        dailyNotes = root.appendingPathComponent("Zettelkatsen", isDirectory: true)

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = 9
        components.hour = 12
        components.minute = 30
        date = try #require(components.date)

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dailyNotes, withIntermediateDirectories: true)

        let resolvedDailyNotes = resolvedDailyNotes
        writer = ObsidianDailyNotes(dailyNotesDirectory: dailyNotes) { url, date in
            resolvedDailyNotes.value += 1
            if !FileManager.default.fileExists(atPath: url.path) {
                let title = ObsidianDailyNotes.dailyNoteName(for: date)
                try "# \(title)\n".write(to: url, atomically: true, encoding: .utf8)
            }
            return url
        }
    }
}

private final class CountBox {
    var value = 0
}

private func shellQuote(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
}

private func makeObsidianTestImage() -> NSImage {
    let image = NSImage(size: NSSize(width: 12, height: 12))
    image.lockFocus()
    NSColor.systemGreen.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 12, height: 12)).fill()
    image.unlockFocus()
    return image
}
