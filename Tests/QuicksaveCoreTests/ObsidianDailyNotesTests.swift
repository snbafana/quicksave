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
}

private struct ObsidianFixture {
    let root: URL
    let dailyNotes: URL
    let writer: ObsidianDailyNotes
    let date: Date

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("quicksave-obsidian-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        dailyNotes = root.appendingPathComponent("Zettelkatsen", isDirectory: true)
        writer = ObsidianDailyNotes(dailyNotesDirectory: dailyNotes)

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
    }
}
