import AppKit

@MainActor
final class NotePanel: NSObject, NSWindowDelegate, NSTextViewDelegate {
    private enum Layout {
        static let panelSize = NSSize(width: 540, height: 154)
        static let cornerRadius: CGFloat = 20
        static let editorFrame = NSRect(x: 18, y: 16, width: 504, height: 122)
    }

    private let onSave: (String) -> Void
    private let onCancel: () -> Void
    private let textView: MinimalNoteTextView
    private let placeholder: NSTextField
    private let scrollView: NSScrollView
    private let window: NSPanel

    var isVisible: Bool {
        window.isVisible
    }

    init(onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.onSave = onSave
        self.onCancel = onCancel
        textView = MinimalNoteTextView(frame: NSRect(origin: .zero, size: Layout.editorFrame.size))
        placeholder = NSTextField(labelWithString: "Add context...")
        scrollView = NSScrollView(frame: Layout.editorFrame)
        window = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: Layout.panelSize),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init()

        configureEditor()
        configureWindow()
    }

    func show() {
        positionCentered()
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.makeFirstResponder(textView)
    }

    func focus() {
        show()
    }

    @objc func cancelOperation(_ sender: Any?) {
        cancel()
    }

    func textDidChange(_ notification: Notification) {
        placeholder.isHidden = !textView.string.isEmpty
    }

    private func configureEditor() {
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView

        textView.delegate = self
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: Layout.editorFrame.width, height: Layout.editorFrame.height)
        textView.maxSize = NSSize(width: Layout.editorFrame.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(width: Layout.editorFrame.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.onSubmit = { [weak self] in self?.save() }
        textView.onCancel = { [weak self] in self?.cancel() }

        placeholder.frame = NSRect(x: Layout.editorFrame.minX, y: Layout.editorFrame.maxY - 32, width: Layout.editorFrame.width, height: 22)
        placeholder.font = .systemFont(ofSize: 16, weight: .regular)
        placeholder.textColor = .placeholderTextColor
    }

    private func configureWindow() {
        window.delegate = self
        window.contentView = MinimalNoteView(
            scrollView: scrollView,
            placeholder: placeholder,
            size: Layout.panelSize,
            cornerRadius: Layout.cornerRadius
        )
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
        let text = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
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

private final class MinimalNoteTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if (event.keyCode == 36 || event.keyCode == 76), event.modifierFlags.contains(.command) {
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

    init(scrollView: NSScrollView, placeholder: NSTextField, size: NSSize, cornerRadius: CGFloat) {
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
        effectView.addSubview(scrollView)
        effectView.addSubview(placeholder)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
