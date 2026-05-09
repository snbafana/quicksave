import AppKit
import Foundation
import Testing
@testable import QuicksaveCore

@Suite("Clipboard capture")
struct ClipboardCaptureTests {
    @Test func capturesPlainTextAsFlatTextFile() throws {
        let fixture = try ClipboardFixture()
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        pasteboard.setString("hello quicksave", forType: .string)

        let result = try ClipboardCapture().captureClipboard(to: fixture.inboxURL, pasteboard: pasteboard)
        let savedURL = try #require(result.firstSavedURL)

        #expect(result.savedURLs.count == 1)
        #expect(savedURL.pathExtension == "txt")
        #expect(savedURL.deletingLastPathComponent() == fixture.inboxURL)
        #expect(try String(contentsOf: savedURL, encoding: .utf8) == "hello quicksave")
        #expect(try fixture.fileNames().contains("metadata.json") == false)
    }

    @Test func repeatedCapturesCreateDistinctFiles() throws {
        let fixture = try ClipboardFixture()
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        pasteboard.setString("same text", forType: .string)

        let capture = ClipboardCapture()
        let first = try #require(try capture.captureClipboard(to: fixture.inboxURL, pasteboard: pasteboard).firstSavedURL)
        let second = try #require(try capture.captureClipboard(to: fixture.inboxURL, pasteboard: pasteboard).firstSavedURL)

        #expect(first != second)
        #expect(FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))
    }

    @Test func capturesURLAsTextFile() throws {
        let fixture = try ClipboardFixture()
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        let item = NSPasteboardItem()
        item.setString("https://example.com", forType: .URL)
        pasteboard.clearContents()
        pasteboard.writeObjects([item])

        let result = try ClipboardCapture().captureClipboard(to: fixture.inboxURL, pasteboard: pasteboard)
        let savedURL = try #require(result.firstSavedURL)

        #expect(savedURL.pathExtension == "txt")
        #expect(try String(contentsOf: savedURL, encoding: .utf8) == "https://example.com")
    }

    @Test func capturesHTMLLinksAsMarkdownFile() throws {
        let fixture = try ClipboardFixture()
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        let item = NSPasteboardItem()
        let html = #"Read <a href="https://example.com/path">example</a> now"#
        item.setData(Data(html.utf8), forType: NSPasteboard.PasteboardType("public.html"))
        item.setString("Read example now", forType: .string)
        pasteboard.clearContents()
        pasteboard.writeObjects([item])

        let result = try ClipboardCapture().captureClipboard(to: fixture.inboxURL, pasteboard: pasteboard)
        let savedURL = try #require(result.firstSavedURL)

        #expect(savedURL.pathExtension == "md")
        #expect(try String(contentsOf: savedURL, encoding: .utf8) == "Read [example](https://example.com/path) now")
    }

    @Test func capturesImageAsPNG() throws {
        let fixture = try ClipboardFixture()
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        pasteboard.writeObjects([makeTestImage()])

        let result = try ClipboardCapture().captureClipboard(to: fixture.inboxURL, pasteboard: pasteboard)
        let imageURL = try #require(result.firstSavedURL)
        let data = try Data(contentsOf: imageURL)

        #expect(imageURL.pathExtension == "png")
        #expect(data.count > 0)
        #expect(NSImage(data: data) != nil)
    }

    @Test func capturesCopiedFileIntoInbox() throws {
        let fixture = try ClipboardFixture()
        let sourceURL = fixture.rootURL.appendingPathComponent("source.txt")
        try "file payload".write(to: sourceURL, atomically: true, encoding: .utf8)

        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        pasteboard.writeObjects([sourceURL as NSURL])

        let result = try ClipboardCapture().captureClipboard(to: fixture.inboxURL, pasteboard: pasteboard)
        let copiedURL = try #require(result.firstSavedURL)

        #expect(copiedURL.deletingLastPathComponent() == fixture.inboxURL)
        #expect(copiedURL.lastPathComponent.hasSuffix("-source.txt"))
        #expect(try String(contentsOf: copiedURL, encoding: .utf8) == "file payload")
    }

    @Test func capturesCopiedFolderIntoInbox() throws {
        let fixture = try ClipboardFixture()
        let folderURL = fixture.rootURL.appendingPathComponent("source-folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try "nested payload".write(
            to: folderURL.appendingPathComponent("nested.txt"),
            atomically: true,
            encoding: .utf8
        )

        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        pasteboard.writeObjects([folderURL as NSURL])

        let result = try ClipboardCapture().captureClipboard(to: fixture.inboxURL, pasteboard: pasteboard)
        let copiedURL = try #require(result.firstSavedURL)
        var isDirectory: ObjCBool = false

        #expect(FileManager.default.fileExists(atPath: copiedURL.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
        #expect(copiedURL.lastPathComponent.hasSuffix("-source-folder"))
        #expect(try String(contentsOf: copiedURL.appendingPathComponent("nested.txt"), encoding: .utf8) == "nested payload")
    }

    @Test func capturesDirectPDFDataAsFlatPDF() throws {
        let fixture = try ClipboardFixture()
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        let item = NSPasteboardItem()
        let pdfData = Data("%PDF-1.4\n% quicksave test\n%%EOF\n".utf8)
        item.setData(pdfData, forType: NSPasteboard.PasteboardType("com.adobe.pdf"))
        pasteboard.clearContents()
        pasteboard.writeObjects([item])

        let result = try ClipboardCapture().captureClipboard(to: fixture.inboxURL, pasteboard: pasteboard)
        let savedURL = try #require(result.firstSavedURL)

        #expect(savedURL.pathExtension == "pdf")
        #expect(try Data(contentsOf: savedURL) == pdfData)
    }
}

private struct ClipboardFixture {
    let rootURL: URL
    let inboxURL: URL

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mac-quicksave-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        inboxURL = rootURL.appendingPathComponent("inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
    }

    func fileNames() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: inboxURL.path)
    }
}

private func makeTestImage() -> NSImage {
    let image = NSImage(size: NSSize(width: 12, height: 12))
    image.lockFocus()
    NSColor.systemBlue.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 12, height: 12)).fill()
    image.unlockFocus()
    return image
}
