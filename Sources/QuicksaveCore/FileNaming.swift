import Foundation

enum FileNaming {
    static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
    }

    static func uniqueURL(in directory: URL, preferredName: String, fileManager: FileManager = .default) -> URL {
        let cleanName = sanitizeFileName(preferredName)
        var candidate = directory.appendingPathComponent(cleanName)
        let pathExtension = candidate.pathExtension
        let stem = candidate.deletingPathExtension().lastPathComponent
        var counter = 2

        while fileManager.fileExists(atPath: candidate.path) {
            let name = pathExtension.isEmpty ? "\(stem)-\(counter)" : "\(stem)-\(counter).\(pathExtension)"
            candidate = directory.appendingPathComponent(name)
            counter += 1
        }

        return candidate
    }

    private static func sanitizeFileName(_ raw: String) -> String {
        let illegal = CharacterSet(charactersIn: "/:")
        let scalars = raw.unicodeScalars.map { illegal.contains($0) ? Character("-") : Character($0) }
        let value = String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "capture" : value
    }
}
