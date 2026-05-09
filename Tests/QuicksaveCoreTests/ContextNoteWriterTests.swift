import Foundation
import Testing
@testable import QuicksaveCore

@Suite("Context notes")
struct ContextNoteWriterTests {
    @Test func savesNoteNextToSingleFile() throws {
        let fixture = try NoteFixture()
        let savedURL = fixture.inboxURL.appendingPathComponent("capture.txt")
        try "saved".write(to: savedURL, atomically: true, encoding: .utf8)

        let noteURL = try ContextNoteWriter().save(note: "my thought", for: [savedURL], in: fixture.inboxURL)

        #expect(noteURL.lastPathComponent == "capture.note.txt")
        #expect(try String(contentsOf: noteURL, encoding: .utf8) == "my thought")
    }

    @Test func savesStandaloneNoteWhenNoCaptureExists() throws {
        let fixture = try NoteFixture()

        let noteURL = try ContextNoteWriter().save(note: "standalone thought", for: [], in: fixture.inboxURL)

        #expect(noteURL.lastPathComponent.hasSuffix("-note.txt"))
        #expect(try String(contentsOf: noteURL, encoding: .utf8) == "standalone thought")
    }
}

private struct NoteFixture {
    let inboxURL: URL

    init() throws {
        inboxURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mac-quicksave-note-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
    }
}
