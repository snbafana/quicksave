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
        installHotKey()
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
            let inbox = QuicksaveSettings.inboxURL()
            let result = try capture.captureClipboard(to: inbox)
            lastSavedURLs = result.savedURLs
            if result.savedURLs.count == 1, let savedURL = result.firstSavedURL {
                lastStatus = "Saved \(savedURL.pathExtension.uppercased())"
            } else {
                lastStatus = "Saved \(result.savedURLs.count) items"
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

        let panel = NotePanelController { [weak self] text in
            guard let self else { return }
            do {
                let noteURL = try self.noteWriter.save(
                    note: text,
                    for: self.lastSavedURLs,
                    in: QuicksaveSettings.inboxURL()
                )
                self.lastStatus = "Noted"
                self.lastSavedURLs = [noteURL]
            } catch {
                self.lastStatus = "Note Error"
            }
            self.notePanel = nil
            self.rebuildMenu()
        } onCancel: { [weak self] in
            self?.notePanel = nil
        }

        notePanel = panel
        panel.show()
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

    private func installHotKey() {
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

                if hotKeyID.id == 1 || hotKeyID.id == 2 {
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

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

@MainActor
private final class NotePanelController: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    private let onSave: (String) -> Void
    private let onCancel: () -> Void
    private let textField: MinimalNoteTextField
    private let window: NSPanel

    var isVisible: Bool {
        window.isVisible
    }

    init(onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.onSave = onSave
        self.onCancel = onCancel

        textField = MinimalNoteTextField(frame: NSRect(x: 22, y: 19, width: 456, height: 28))
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 17, weight: .regular)
        textField.textColor = .labelColor
        textField.placeholderString = "Add context..."
        textField.lineBreakMode = .byTruncatingTail

        window = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 66),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init()

        textField.delegate = self
        textField.onSubmit = { [weak self] in
            self?.save()
        }
        textField.onCancel = { [weak self] in
            self?.cancel()
        }
        window.delegate = self
        window.contentView = MinimalNoteView(textField: textField)
        window.isFloatingPanel = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.hidesOnDeactivate = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }

    func show() {
        positionCentered()
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.makeFirstResponder(textField)
        textField.selectText(nil)
    }

    func focus() {
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        positionCentered()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.makeFirstResponder(textField)
        textField.selectText(nil)
    }

    @objc func cancelOperation(_ sender: Any?) {
        cancel()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            save()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancel()
            return true
        }
        return false
    }

    private func save() {
        let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            cancel()
            return
        }
        window.orderOut(nil)
        onSave(text)
    }

    private func cancel() {
        window.orderOut(nil)
        onCancel()
    }

    private func positionCentered() {
        guard let screen = NSScreen.main else {
            window.center()
            return
        }
        let frame = screen.visibleFrame
        let size = window.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        )
        window.setFrameOrigin(origin)
    }
}

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}

private final class MinimalNoteTextField: NSTextField {
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 {
            onSubmit?()
            return
        }
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }
}

private final class MinimalNoteView: NSView {
    private let effectView: NSVisualEffectView

    init(textField: NSTextField) {
        effectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 500, height: 66))
        super.init(frame: NSRect(x: 0, y: 0, width: 500, height: 66))

        wantsLayer = true
        layer?.cornerRadius = 22
        layer?.masksToBounds = true
        layer?.borderColor = NSColor.white.withAlphaComponent(0.26).cgColor
        layer?.borderWidth = 1

        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 22
        effectView.layer?.masksToBounds = true
        addSubview(effectView)
        effectView.addSubview(textField)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
