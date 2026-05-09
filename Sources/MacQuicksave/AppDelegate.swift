import AppKit
import Carbon
import Foundation
import QuicksaveCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var saveHotKeyRef: EventHotKeyRef?
    private var noteHotKeyRef: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private let capture = ClipboardCapture()
    private let noteWriter = ContextNoteWriter()
    private var lastStatus = "Ready"
    private var lastSavedURLs: [URL] = []
    private var notePanel: NotePanelController?

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
        menu.addItem(optionMenuItem(title: "Open Inbox", action: #selector(openInbox), keyEquivalent: "o"))
        menu.addItem(optionMenuItem(title: "Choose...", action: #selector(chooseInbox), keyEquivalent: ","))
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
            lastSavedURLs = result.savedURLs
            lastStatus = statusText(for: result)
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

        let panel = NotePanelController { [weak self] text in
            self?.saveContextNote(text)
        } onCancel: { [weak self] in
            self?.notePanel = nil
        }

        notePanel = panel
        panel.show()
    }

    private func saveContextNote(_ text: String) {
        do {
            let noteURL = try noteWriter.save(
                note: text,
                for: lastSavedURLs,
                in: QuicksaveSettings.inboxURL()
            )
            lastStatus = "Noted"
            lastSavedURLs = [noteURL]
        } catch {
            lastStatus = "Note Error"
        }
        notePanel = nil
        rebuildMenu()
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
        let saveStatus = registerHotKey(id: 1, keyCode: UInt32(kVK_ANSI_C), ref: &saveHotKeyRef)
        let noteStatus = registerHotKey(id: 2, keyCode: UInt32(kVK_ANSI_W), ref: &noteHotKeyRef)
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

                guard hotKeyID.id == 1 || hotKeyID.id == 2 else {
                    return noErr
                }

                let delegateAddress = UInt(bitPattern: userData)
                DispatchQueue.main.async {
                    guard let pointer = UnsafeRawPointer(bitPattern: delegateAddress) else {
                        return
                    }
                    let delegate = Unmanaged<AppDelegate>.fromOpaque(pointer).takeUnretainedValue()
                    if hotKeyID.id == 1 {
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

    private func registerHotKey(id: UInt32, keyCode: UInt32, ref: inout EventHotKeyRef?) -> OSStatus {
        let hotKeyID = EventHotKeyID(signature: OSType("MQSV".fourCharCode), id: id)
        return RegisterEventHotKey(keyCode, UInt32(optionKey), hotKeyID, GetApplicationEventTarget(), 0, &ref)
    }
}

private extension String {
    var fourCharCode: FourCharCode {
        utf8.reduce(0) { ($0 << 8) + FourCharCode($1) }
    }
}
