import AppKit
import Foundation

public final class ClipboardCapture {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func captureClipboard(to inboxDirectory: URL, pasteboard: NSPasteboard = .general) throws -> CaptureResult {
        try fileManager.createDirectory(at: inboxDirectory, withIntermediateDirectories: true)

        let items = pasteboard.pasteboardItems ?? []
        var saved: [URL] = []

        for (offset, item) in items.enumerated() {
            if let url = try saveItem(item, itemIndex: offset + 1, itemCount: items.count, to: inboxDirectory) {
                saved.append(url)
            }
        }

        if saved.isEmpty {
            throw ClipboardCaptureError.noSupportedClipboardContent
        }

        return CaptureResult(savedURLs: saved)
    }

    private func saveItem(_ item: NSPasteboardItem, itemIndex: Int, itemCount: Int, to inboxDirectory: URL) throws -> URL? {
        let stem = fileStem(itemIndex: itemIndex, itemCount: itemCount)

        if let fileURL = fileURL(from: item) {
            let destination = uniqueURL(in: inboxDirectory, preferredName: "\(stem)-\(fileURL.lastPathComponent)")
            try copyReplacingNothing(from: fileURL, to: destination)
            return destination
        }

        if let pdf = item.data(forType: NSPasteboard.PasteboardType("com.adobe.pdf")), !pdf.isEmpty {
            let destination = uniqueURL(in: inboxDirectory, preferredName: "\(stem).pdf")
            try pdf.write(to: destination, options: [.atomic])
            return destination
        }

        if let image = image(from: item), let png = pngData(from: image) {
            let destination = uniqueURL(in: inboxDirectory, preferredName: "\(stem).png")
            try png.write(to: destination, options: [.atomic])
            return destination
        }

        if let text = text(from: item), !text.isEmpty {
            let destination = uniqueURL(in: inboxDirectory, preferredName: "\(stem).txt")
            try Data(text.utf8).write(to: destination, options: [.atomic])
            return destination
        }

        return nil
    }

    private func text(from item: NSPasteboardItem) -> String? {
        if let text = item.string(forType: .string), !text.isEmpty {
            return text
        }
        if let url = item.string(forType: .URL), !url.isEmpty {
            return url
        }
        return nil
    }

    private func fileURL(from item: NSPasteboardItem) -> URL? {
        if let string = item.string(forType: .fileURL), let url = URL(string: string), url.isFileURL {
            return url
        }

        if let string = item.string(forType: NSPasteboard.PasteboardType("public.file-url")),
           let url = URL(string: string),
           url.isFileURL {
            return url
        }

        return nil
    }

    private func image(from item: NSPasteboardItem) -> NSImage? {
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.heic")
        ]

        for type in imageTypes {
            if let data = item.data(forType: type), let image = NSImage(data: data) {
                return image
            }
        }

        return nil
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    private func copyReplacingNothing(from source: URL, to destination: URL) throws {
        try fileManager.copyItem(at: source, to: destination)
    }

    private func uniqueURL(in directory: URL, preferredName: String) -> URL {
        let cleanName = sanitizeFileName(preferredName)
        var candidate = directory.appendingPathComponent(cleanName)
        let ext = candidate.pathExtension
        let stem = candidate.deletingPathExtension().lastPathComponent
        var counter = 2

        while fileManager.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(stem)-\(counter)" : "\(stem)-\(counter).\(ext)"
            candidate = directory.appendingPathComponent(name)
            counter += 1
        }

        return candidate
    }

    private func fileStem(itemIndex: Int, itemCount: Int) -> String {
        let timestamp = Self.timestampFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        if itemCount <= 1 {
            return timestamp
        }
        return "\(timestamp)-\(String(format: "%02d", itemIndex))"
    }

    private func sanitizeFileName(_ raw: String) -> String {
        let illegal = CharacterSet(charactersIn: "/:")
        let scalars = raw.unicodeScalars.map { illegal.contains($0) ? Character("-") : Character($0) }
        let value = String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "capture" : value
    }

    private static func timestampFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}

public enum ClipboardCaptureError: LocalizedError {
    case noSupportedClipboardContent

    public var errorDescription: String? {
        switch self {
        case .noSupportedClipboardContent:
            "No supported clipboard content found."
        }
    }
}
