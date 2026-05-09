import AppKit

@MainActor
final class NotePanelController: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    private enum Layout {
        static let panelSize = NSSize(width: 500, height: 66)
        static let cornerRadius: CGFloat = 22
        static let textFieldFrame = NSRect(x: 22, y: 19, width: 456, height: 28)
    }

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
        textField = MinimalNoteTextField(frame: Layout.textFieldFrame)
        window = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: Layout.panelSize),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init()

        configureTextField()
        configureWindow()
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
        show()
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

    private func configureTextField() {
        textField.delegate = self
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 17, weight: .regular)
        textField.textColor = .labelColor
        textField.placeholderString = "Add context..."
        textField.lineBreakMode = .byTruncatingTail
        textField.onSubmit = { [weak self] in self?.save() }
        textField.onCancel = { [weak self] in self?.cancel() }
    }

    private func configureWindow() {
        window.delegate = self
        window.contentView = MinimalNoteView(textField: textField, size: Layout.panelSize, cornerRadius: Layout.cornerRadius)
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
        let origin = NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2)
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

    init(textField: NSTextField, size: NSSize, cornerRadius: CGFloat) {
        effectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        super.init(frame: NSRect(origin: .zero, size: size))

        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = true
        layer?.borderColor = NSColor.white.withAlphaComponent(0.26).cgColor
        layer?.borderWidth = 1

        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = cornerRadius
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
