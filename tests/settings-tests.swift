import Foundation
import Testing
@testable import QuicksaveCore

@Suite("Quicksave settings")
struct QuicksaveSettingsTests {
    @Test func storesConfigurablePaths() throws {
        let defaultsName = "quicksave-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let inbox = URL(fileURLWithPath: "/tmp/quicksave-inbox", isDirectory: true)
        let vault = URL(fileURLWithPath: "/tmp/Obsidian-Vault", isDirectory: true)
        let dailyNotes = vault.appendingPathComponent("Daily", isDirectory: true)
        let template = vault.appendingPathComponent("Templates/Daily.md")

        QuicksaveSettings.setInboxURL(inbox, defaults: defaults)
        QuicksaveSettings.setObsidianVaultURL(vault, defaults: defaults)
        QuicksaveSettings.setObsidianDailyNotesURL(dailyNotes, defaults: defaults)
        QuicksaveSettings.setObsidianDailyTemplateURL(template, defaults: defaults)

        #expect(QuicksaveSettings.inboxURL(defaults: defaults) == inbox)
        #expect(QuicksaveSettings.obsidianVaultURL(defaults: defaults) == vault)
        #expect(QuicksaveSettings.obsidianDailyNotesURL(defaults: defaults) == dailyNotes)
        #expect(QuicksaveSettings.obsidianDailyTemplateURL(defaults: defaults) == template)

        QuicksaveSettings.resetObsidian(defaults: defaults)

        #expect(QuicksaveSettings.obsidianVaultURL(defaults: defaults) == ObsidianDailyNotes.defaultVaultURL())
        #expect(QuicksaveSettings.obsidianDailyNotesURL(defaults: defaults) == ObsidianDailyNotes.defaultDailyNotesURL())
        #expect(QuicksaveSettings.obsidianDailyTemplateURL(defaults: defaults) == ObsidianDailyNotes.defaultDailyTemplateURL())
    }
}
