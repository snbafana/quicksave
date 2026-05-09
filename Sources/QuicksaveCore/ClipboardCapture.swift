import AppKit
import Foundation

public final class ClipboardCapture {
    private enum PasteboardType {
        static let pdf = NSPasteboard.PasteboardType("com.adobe.pdf")
        static let fileURL = NSPasteboard.PasteboardType("public.file-url")
        static let imageTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.heic")
        ]
    }

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
            let destination = FileNaming.uniqueURL(
                in: inboxDirectory,
                preferredName: "\(stem)-\(fileURL.lastPathComponent)",
                fileManager: fileManager
            )
            try fileManager.copyItem(at: fileURL, to: destination)
            return destination
        }

        if let pdf = item.data(forType: PasteboardType.pdf), !pdf.isEmpty {
            let destination = FileNaming.uniqueURL(
                in: inboxDirectory,
                preferredName: "\(stem).pdf",
                fileManager: fileManager
            )
            try pdf.write(to: destination, options: [.atomic])
            return destination
        }

        if let image = image(from: item), let png = pngData(from: image) {
            let destination = FileNaming.uniqueURL(
                in: inboxDirectory,
                preferredName: "\(stem).png",
                fileManager: fileManager
            )
            try png.write(to: destination, options: [.atomic])
            return destination
        }

        if let text = text(from: item), !text.isEmpty {
            let destination = FileNaming.uniqueURL(
                in: inboxDirectory,
                preferredName: "\(stem).txt",
                fileManager: fileManager
            )
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

        if let string = item.string(forType: PasteboardType.fileURL),
           let url = URL(string: string),
           url.isFileURL {
            return url
        }

        return nil
    }

    private func image(from item: NSPasteboardItem) -> NSImage? {
        for type in PasteboardType.imageTypes {
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

    private func fileStem(itemIndex: Int, itemCount: Int) -> String {
        let timestamp = FileNaming.timestamp()
        if itemCount <= 1 {
            return timestamp
        }
        return "\(timestamp)-\(String(format: "%02d", itemIndex))"
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
