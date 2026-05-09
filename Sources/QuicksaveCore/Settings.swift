import Foundation

public struct QuicksaveSettings {
    public static let inboxBookmarkKey = "inboxBookmark"
    public static let inboxPathKey = "inboxPath"

    public static func defaultInboxURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Quicksave Inbox", isDirectory: true)
    }

    public static func inboxURL(defaults: UserDefaults = .standard) -> URL {
        if let path = defaults.string(forKey: inboxPathKey), !path.isEmpty {
            return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath, isDirectory: true)
        }
        return defaultInboxURL()
    }

    public static func setInboxURL(_ url: URL, defaults: UserDefaults = .standard) {
        defaults.set(url.path, forKey: inboxPathKey)
    }
}
