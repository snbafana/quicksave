import Foundation

public struct QuicksaveSettings {
    private static let inboxPathKey = "inboxPath"
    private static let obsidianVaultPathKey = "obsidianVaultPath"
    private static let obsidianDailyNotesPathKey = "obsidianDailyNotesPath"
    private static let obsidianDailyTemplatePathKey = "obsidianDailyTemplatePath"

    public static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "com.snbafana.quicksave") ?? .standard
    }

    public static func defaultInboxURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Quicksave Inbox", isDirectory: true)
    }

    public static func inboxURL(defaults: UserDefaults = QuicksaveSettings.sharedDefaults()) -> URL {
        storedURL(forKey: inboxPathKey, defaultURL: defaultInboxURL(), isDirectory: true, defaults: defaults)
    }

    public static func setInboxURL(_ url: URL, defaults: UserDefaults = QuicksaveSettings.sharedDefaults()) {
        defaults.set(url.path, forKey: inboxPathKey)
    }

    public static func obsidianVaultURL(defaults: UserDefaults = QuicksaveSettings.sharedDefaults()) -> URL {
        storedURL(
            forKey: obsidianVaultPathKey,
            defaultURL: ObsidianDailyNotes.defaultVaultURL(),
            isDirectory: true,
            defaults: defaults
        )
    }

    public static func setObsidianVaultURL(_ url: URL, defaults: UserDefaults = QuicksaveSettings.sharedDefaults()) {
        defaults.set(url.path, forKey: obsidianVaultPathKey)
    }

    public static func obsidianDailyNotesURL(defaults: UserDefaults = QuicksaveSettings.sharedDefaults()) -> URL {
        storedURL(
            forKey: obsidianDailyNotesPathKey,
            defaultURL: ObsidianDailyNotes.defaultDailyNotesURL(),
            isDirectory: true,
            defaults: defaults
        )
    }

    public static func setObsidianDailyNotesURL(_ url: URL, defaults: UserDefaults = QuicksaveSettings.sharedDefaults()) {
        defaults.set(url.path, forKey: obsidianDailyNotesPathKey)
    }

    public static func obsidianDailyTemplateURL(defaults: UserDefaults = QuicksaveSettings.sharedDefaults()) -> URL {
        storedURL(
            forKey: obsidianDailyTemplatePathKey,
            defaultURL: ObsidianDailyNotes.defaultDailyTemplateURL(),
            isDirectory: false,
            defaults: defaults
        )
    }

    public static func setObsidianDailyTemplateURL(_ url: URL, defaults: UserDefaults = QuicksaveSettings.sharedDefaults()) {
        defaults.set(url.path, forKey: obsidianDailyTemplatePathKey)
    }

    public static func resetObsidian(defaults: UserDefaults = QuicksaveSettings.sharedDefaults()) {
        defaults.removeObject(forKey: obsidianVaultPathKey)
        defaults.removeObject(forKey: obsidianDailyNotesPathKey)
        defaults.removeObject(forKey: obsidianDailyTemplatePathKey)
    }

    private static func storedURL(
        forKey key: String,
        defaultURL: URL,
        isDirectory: Bool,
        defaults: UserDefaults
    ) -> URL {
        guard let path = defaults.string(forKey: key), !path.isEmpty else {
            return defaultURL
        }
        return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath, isDirectory: isDirectory)
    }
}
