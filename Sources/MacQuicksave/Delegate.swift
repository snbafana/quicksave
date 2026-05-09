import AppKit
import Carbon
import Foundation
import QuicksaveCore
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class Delegate: NSObject, NSApplicationDelegate {
    private enum HotKey: UInt32 {
        case save = 1
        case note = 2
    }

    private var statusItem: NSStatusItem?
    private var saveHotKeyRef: EventHotKeyRef?
    private var noteHotKeyRef: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private let capture = ClipboardCapture()
    private let noteWriter = ContextNoteWriter()
    private var lastStatus = "Ready"
    private var lastCaptureURLs: [URL] = []
    private var notePanel: NotePanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMenuBarItem()
        installHotKeys()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let saveHotKeyRef {
            UnregisterEventHotKey(saveHotKeyRef)
        }
        if let noteHotKeyRef {
            UnregisterEventHotKey(noteHotKeyRef)
        }
        if let hotKeyHandler {
            RemoveEventHandler(hotKeyHandler)
        }
    }

    private func installMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "tray.and.arrow.down", accessibilityDescription: "Mac Quicksave")
        item.button?.imagePosition = .imageOnly
        statusItem = item
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let status = NSMenuItem(title: lastStatus, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        menu.addItem(optionMenuItem(title: "Save", action: #selector(saveClipboardNow), keyEquivalent: "c"))
        menu.addItem(optionMenuItem(title: "Note", action: #selector(addContextNote), keyEquivalent: "w"))
        menu.addItem(optionMenuItem(title: "Obsidian", action: #selector(appendLatestToObsidian), keyEquivalent: "d"))
        menu.addItem(optionMenuItem(title: "Open Inbox", action: #selector(openInbox), keyEquivalent: "o"))
        menu.addItem(optionMenuItem(title: "Choose Inbox...", action: #selector(chooseInbox), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Choose Vault...", action: #selector(chooseObsidianVault), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Choose Daily Notes...", action: #selector(chooseObsidianDailyNotes), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Choose Daily Template...", action: #selector(chooseObsidianDailyTemplate), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reset Obsidian Config", action: #selector(resetObsidianConfig), keyEquivalent: ""))
        menu.addItem(loginItem())
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: ""))

        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
    }

    private func optionMenuItem(title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.keyEquivalentModifierMask = [.option]
        return item
    }

    private func loginItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        item.state = SMAppService.mainApp.status == .enabled ? .on : .off
        return item
    }

    @objc private func saveClipboardNow() {
        do {
            let result = try capture.captureClipboard(to: QuicksaveSettings.inboxURL())
            lastCaptureURLs = result.savedURLs
            let captureStatus = statusText(for: result)
            do {
                try appendCapturesToObsidian(result.savedURLs)
                lastStatus = "\(captureStatus) + Obsidian"
            } catch {
                lastStatus = "\(captureStatus); Obsidian Error"
            }
        } catch {
            lastStatus = "Error"
        }
        rebuildMenu()
    }

    @objc private func addContextNote() {
        if notePanel?.isVisible == true {
            notePanel?.focus()
            return
        }

        let panel = NotePanel { [weak self] text in
            self?.saveContextNote(text)
        } onCancel: { [weak self] in
            self?.notePanel = nil
        }

        notePanel = panel
        panel.show()
    }

    private func saveContextNote(_ text: String) {
        do {
            let noteTargets = latestCaptureTargets()
            _ = try noteWriter.save(
                note: text,
                for: noteTargets,
                in: QuicksaveSettings.inboxURL()
            )
            if noteTargets.isEmpty {
                lastStatus = "Noted"
            } else {
                lastCaptureURLs = noteTargets
                do {
                    try appendNotesToObsidian(for: noteTargets, note: text)
                    lastStatus = "Noted + Obsidian"
                } catch {
                    lastStatus = "Noted; Obsidian Error"
                }
            }
        } catch {
            lastStatus = "Note Error"
        }
        notePanel = nil
        rebuildMenu()
    }

    @objc private func appendLatestToObsidian() {
        do {
            try appendCapturesToObsidian(latestCaptureTargets())
            lastStatus = "Obsidian"
        } catch {
            lastStatus = "Obsidian Error"
        }
        rebuildMenu()
    }

    private func appendCapturesToObsidian(_ captureURLs: [URL]) throws {
        guard !captureURLs.isEmpty else {
            throw ObsidianAppendError.noCapture
        }

        let writer = obsidianDailyNotes()
        _ = try writer.append(captureURLs: captureURLs)
    }

    private func appendNotesToObsidian(for captureURLs: [URL], note: String) throws {
        guard !captureURLs.isEmpty else {
            throw ObsidianAppendError.noCapture
        }

        let writer = obsidianDailyNotes()
        _ = try writer.appendNotes(for: captureURLs, note: note)
    }

    private func obsidianDailyNotes() -> ObsidianDailyNotes {
        ObsidianDailyNotes(
            dailyNotesDirectory: QuicksaveSettings.obsidianDailyNotesURL(),
            vaultDirectory: QuicksaveSettings.obsidianVaultURL(),
            resolveDailyNote: ObsidianDailyNotes.obsidianTemplateDailyNoteResolver(
                vaultURL: QuicksaveSettings.obsidianVaultURL(),
                templateURL: QuicksaveSettings.obsidianDailyTemplateURL()
            )
        )
    }

    private func latestCaptureURL() throws -> URL {
        if let captureURL = lastCaptureURLs.first {
            return captureURL
        }

        let captures = try FileManager.default.contentsOfDirectory(
            at: QuicksaveSettings.inboxURL(),
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { !$0.lastPathComponent.hasSuffix(".note.txt") }
        .sorted { modificationDate($0) > modificationDate($1) }

        guard let latest = captures.first else {
            throw ObsidianAppendError.noCapture
        }
        return latest
    }

    private func latestCaptureTargets() -> [URL] {
        if !lastCaptureURLs.isEmpty {
            return lastCaptureURLs
        }
        guard let latest = try? latestCaptureURL() else {
            return []
        }
        return [latest]
    }

    private func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    @objc private func openInbox() {
        let inbox = QuicksaveSettings.inboxURL()
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        NSWorkspace.shared.open(inbox)
    }

    @objc private func chooseInbox() {
        let panel = NSOpenPanel()
        panel.title = "Choose Quicksave Inbox"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = QuicksaveSettings.inboxURL()

        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            QuicksaveSettings.setInboxURL(url)
            lastStatus = "Inbox Set"
            rebuildMenu()
        }
    }

    @objc private func chooseObsidianVault() {
        chooseDirectory(
            title: "Choose Obsidian Vault",
            currentURL: QuicksaveSettings.obsidianVaultURL(),
            status: "Vault Set",
            setter: { QuicksaveSettings.setObsidianVaultURL($0) }
        )
    }

    @objc private func chooseObsidianDailyNotes() {
        chooseDirectory(
            title: "Choose Obsidian Daily Notes Folder",
            currentURL: QuicksaveSettings.obsidianDailyNotesURL(),
            status: "Daily Notes Set",
            setter: { QuicksaveSettings.setObsidianDailyNotesURL($0) }
        )
    }

    @objc private func chooseObsidianDailyTemplate() {
        let panel = NSOpenPanel()
        panel.title = "Choose Obsidian Daily Template"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.text, .plainText, .utf8PlainText]
        panel.directoryURL = QuicksaveSettings.obsidianDailyTemplateURL().deletingLastPathComponent()

        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            QuicksaveSettings.setObsidianDailyTemplateURL(url)
            lastStatus = "Template Set"
            rebuildMenu()
        }
    }

    @objc private func resetObsidianConfig() {
        QuicksaveSettings.resetObsidian()
        lastStatus = "Obsidian Reset"
        rebuildMenu()
    }

    private func chooseDirectory(
        title: String,
        currentURL: URL,
        status: String,
        setter: (URL) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = currentURL

        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            setter(url)
            lastStatus = status
            rebuildMenu()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                lastStatus = "Login Off"
            } else {
                try SMAppService.mainApp.register()
                lastStatus = "Login On"
            }
        } catch {
            lastStatus = "Login Error"
        }
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func statusText(for result: CaptureResult) -> String {
        if result.savedURLs.count == 1, let savedURL = result.firstSavedURL {
            return "Saved \(savedURL.pathExtension.uppercased())"
        }
        return "Saved \(result.savedURLs.count) items"
    }

    private func installHotKeys() {
        let saveStatus = registerHotKey(.save, keyCode: UInt32(kVK_ANSI_C), ref: &saveHotKeyRef)
        let noteStatus = registerHotKey(.note, keyCode: UInt32(kVK_ANSI_W), ref: &noteHotKeyRef)
        guard saveStatus == noErr, noteStatus == noErr else {
            lastStatus = "Hotkey unavailable"
            rebuildMenu()
            return
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard let hotKey = HotKey(rawValue: hotKeyID.id) else {
                    return noErr
                }

                let delegateAddress = UInt(bitPattern: userData)
                DispatchQueue.main.async {
                    guard let pointer = UnsafeRawPointer(bitPattern: delegateAddress) else {
                        return
                    }
                    let delegate = Unmanaged<Delegate>.fromOpaque(pointer).takeUnretainedValue()
                    if hotKey == .save {
                        delegate.saveClipboardNow()
                    } else {
                        delegate.addContextNote()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &hotKeyHandler
        )
    }

    private func registerHotKey(_ hotKey: HotKey, keyCode: UInt32, ref: inout EventHotKeyRef?) -> OSStatus {
        let hotKeyID = EventHotKeyID(signature: OSType("MQSV".fourCharCode), id: hotKey.rawValue)
        return RegisterEventHotKey(keyCode, UInt32(optionKey), hotKeyID, GetApplicationEventTarget(), 0, &ref)
    }
}

private enum ObsidianAppendError: Error {
    case noCapture
}

private extension String {
    var fourCharCode: FourCharCode {
        utf8.reduce(0) { ($0 << 8) + FourCharCode($1) }
    }
}
