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
        #expect(!contents.contains("## Quicksave"))
        #expect(contents.contains("> first line\n  > second line"))
        #expect(contents.contains("  - my note"))
    }

    @Test func copiesImagesToAssetsAndEmbedsMarkdownImage() throws {
        let fixture = try ObsidianFixture()
        let image = fixture.root.appendingPathComponent("clip image.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: image)

        _ = try fixture.writer.append(captureURL: image, date: fixture.date)
        let dailyNote = try fixture.writer.appendNotes(for: [image], note: "image context", date: fixture.date)
        let contents = try String(contentsOf: dailyNote, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: fixture.media.appendingPathComponent("clip image.png").path))
        #expect(contents.contains("![[clip image.png]]"))
        #expect(contents.contains("![[clip image.png]]\n  - image context"))
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
        let embeddedImage = fixture.media.appendingPathComponent(capture.lastPathComponent)

        #expect(capture.pathExtension == "png")
        #expect(FileManager.default.fileExists(atPath: embeddedImage.path))
        #expect(contents.contains("![[\(capture.lastPathComponent)]]"))
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

    @Test func attachesNotesToExistingCaptureEntries() throws {
        let fixture = try ObsidianFixture()
        let first = fixture.root.appendingPathComponent("first.txt")
        let second = fixture.root.appendingPathComponent("second.txt")
        try "first capture body".write(to: first, atomically: true, encoding: .utf8)
        try "second capture body".write(to: second, atomically: true, encoding: .utf8)

        _ = try fixture.writer.append(captureURLs: [first, second], date: fixture.date)
        let dailyNote = try fixture.writer.appendNotes(for: [first, second], note: "why this mattered", date: fixture.date)
        let contents = try String(contentsOf: dailyNote, encoding: .utf8)

        #expect(!contents.contains("Note for `first.txt`"))
        #expect(!contents.contains("Note for `second.txt`"))
        #expect(contents.contains("> first capture body\n  - why this mattered"))
        #expect(contents.contains("> second capture body\n  - why this mattered"))
        #expect(contents.components(separatedBy: "first capture body").count == 2)
        #expect(contents.components(separatedBy: "second capture body").count == 2)
        #expect(contents.components(separatedBy: "why this mattered").count == 3)
    }

    @Test func appendsMultipleNotesToSameCaptureEntry() throws {
        let fixture = try ObsidianFixture()
        let capture = fixture.root.appendingPathComponent("capture.txt")
        try "saved once".write(to: capture, atomically: true, encoding: .utf8)

        _ = try fixture.writer.append(captureURL: capture, date: fixture.date)
        let dailyNote = try fixture.writer.appendNotes(for: [capture], note: "first thought", date: fixture.date)
        _ = try fixture.writer.appendNotes(for: [capture], note: "second thought", date: fixture.date)
        let contents = try String(contentsOf: dailyNote, encoding: .utf8)

        #expect(contents.contains("> saved once\n  - first thought\n  - second thought"))
        #expect(contents.components(separatedBy: "saved once").count == 2)
        #expect(!contents.contains("Note for `capture.txt`"))
    }

    @Test func noteFallbackIncludesCaptureWhenEntryDoesNotExist() throws {
        let fixture = try ObsidianFixture()
        let capture = fixture.root.appendingPathComponent("capture.txt")
        try "capture body".write(to: capture, atomically: true, encoding: .utf8)

        let dailyNote = try fixture.writer.appendNotes(for: [capture], note: "why this mattered", date: fixture.date)
        let contents = try String(contentsOf: dailyNote, encoding: .utf8)

        #expect(!contents.contains("Note for `capture.txt`"))
        #expect(contents.contains("> capture body"))
        #expect(contents.contains("  - why this mattered"))
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

    @Test func fileSystemResolverCreatesDailyNoteFromTemplate() throws {
        let fixture = try ObsidianFixture()
        let template = fixture.root.appendingPathComponent("Templates/Daily Note.md")
        try FileManager.default.createDirectory(at: template.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        ---
        date: {{date:YYYY-MM-DD}}
        week: {{date:ww}}
        ---
        ## Notes created {{date:MM/DD/YY}}
        # {{title}}
        """.write(to: template, atomically: true, encoding: .utf8)

        let writer = ObsidianDailyNotes(
            dailyNotesDirectory: fixture.dailyNotes,
            vaultDirectory: fixture.root,
            resolveDailyNote: ObsidianDailyNotes.fileSystemDailyNoteResolver(templateURL: template)
        )
        let capture = fixture.root.appendingPathComponent("capture.txt")
        try "templated daily note".write(to: capture, atomically: true, encoding: .utf8)

        let dailyNote = try writer.append(captureURL: capture, date: fixture.date)
        let contents = try String(contentsOf: dailyNote, encoding: .utf8)

        #expect(dailyNote.path == fixture.dailyNotes.appendingPathComponent("05-09-2026.md").path)
        #expect(contents.contains("date: 2026-05-09"))
        #expect(contents.contains("## Notes created 05/09/26"))
        #expect(contents.contains("# 05-09-2026"))
        #expect(contents.contains("> templated daily note"))
    }
}

private final class ObsidianFixture {
    let root: URL
    let dailyNotes: URL
    let media: URL
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
        media = root.appendingPathComponent(ObsidianDailyNotes.defaultMediaRelativePath, isDirectory: true)

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
        writer = ObsidianDailyNotes(dailyNotesDirectory: dailyNotes, vaultDirectory: root) { url, date in
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

private func makeObsidianTestImage() -> NSImage {
    let image = NSImage(size: NSSize(width: 12, height: 12))
    image.lockFocus()
    NSColor.systemGreen.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 12, height: 12)).fill()
    image.unlockFocus()
    return image
}
