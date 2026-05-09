import Foundation

public final class ContextNoteWriter {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func save(note: String, for savedURLs: [URL], in inboxDirectory: URL) throws -> URL {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ContextNoteError.emptyNote
        }

        try fileManager.createDirectory(at: inboxDirectory, withIntermediateDirectories: true)
        let destination = FileNaming.uniqueURL(
            in: inboxDirectory,
            preferredName: noteFileName(for: savedURLs),
            fileManager: fileManager
        )
        try Data(trimmed.utf8).write(to: destination, options: [.atomic])
        return destination
    }

    private func noteFileName(for savedURLs: [URL]) -> String {
        guard savedURLs.count == 1, let target = savedURLs.first else {
            return "\(FileNaming.timestamp())-note.txt"
        }

        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: target.path, isDirectory: &isDirectory)
        if exists && isDirectory.boolValue {
            return "\(target.lastPathComponent).note.txt"
        }

        let stem = target.deletingPathExtension().lastPathComponent
        return "\(stem).note.txt"
    }
}

public enum ContextNoteError: LocalizedError {
    case emptyNote

    public var errorDescription: String? {
        switch self {
        case .emptyNote:
            "No note entered."
        }
    }
}
