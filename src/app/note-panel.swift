import AppKit

@MainActor
final class NotePanel: NSObject, NSWindowDelegate, NSTextViewDelegate {
    private enum Layout {
        static let width: CGFloat = 420
        static let minHeight: CGFloat = 74
        static let maxHeight: CGFloat = 260
        static let horizontalPadding: CGFloat = 18
        static let verticalPadding: CGFloat = 14
        static let growthBuffer: CGFloat = 18
        static let cornerRadius: CGFloat = 18

        static var panelSize: NSSize {
            NSSize(width: width, height: minHeight)
        }

        static func editorFrame(for panelHeight: CGFloat) -> NSRect {
            NSRect(
                x: horizontalPadding,
                y: verticalPadding,
                width: width - horizontalPadding * 2,
                height: panelHeight - verticalPadding * 2
            )
        }
    }

    private let onSave: (String) -> Void
    private let onCancel: () -> Void
    private let textView: MinimalNoteTextView
    private let window: NSPanel

    var isVisible: Bool {
        window.isVisible
    }

    init(onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.onSave = onSave
        self.onCancel = onCancel
        let editorFrame = Layout.editorFrame(for: Layout.minHeight)
        textView = MinimalNoteTextView(frame: editorFrame)
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
        textView.needsDisplay = true
        resizeForContent()
    }

    private func configureEditor() {
        textView.delegate = self
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.textContainerInset = NSSize(width: 0, height: 9)
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.minSize = textView.frame.size
        textView.maxSize = NSSize(width: textView.frame.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(width: textView.frame.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.onSubmit = { [weak self] in self?.save() }
        textView.onCancel = { [weak self] in self?.cancel() }
    }

    private func configureWindow() {
        window.delegate = self
        window.contentView = MinimalNoteView(
            textView: textView,
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

    private func resizeForContent() {
        guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else {
            return
        }

        layoutManager.ensureLayout(for: textContainer)
        let textHeight = ceil(layoutManager.usedRect(for: textContainer).height + textView.textContainerInset.height * 2)
        let targetHeight = min(
            max(textHeight + Layout.verticalPadding * 2 + Layout.growthBuffer, Layout.minHeight),
            Layout.maxHeight
        )
        guard abs(window.frame.height - targetHeight) > 0.5 else {
            return
        }

        let previousFrame = window.frame
        let nextFrame = NSRect(
            x: previousFrame.minX,
            y: previousFrame.maxY - targetHeight,
            width: Layout.width,
            height: targetHeight
        )

        window.setFrame(nextFrame, display: true, animate: false)
        updateEditorLayout(panelHeight: targetHeight)
    }

    private func updateEditorLayout(panelHeight: CGFloat) {
        let editorFrame = Layout.editorFrame(for: panelHeight)
        textView.frame = editorFrame
        textView.minSize = editorFrame.size
        textView.maxSize = NSSize(width: editorFrame.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(width: editorFrame.width, height: CGFloat.greatestFiniteMagnitude)
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
    private let placeholder = "Add context..."

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

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty else {
            return
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? .systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: NSColor.placeholderTextColor
        ]
        let lineHeight = ceil((font ?? .systemFont(ofSize: 16, weight: .regular)).boundingRectForFont.height)
        let y = isFlipped
            ? textContainerInset.height
            : bounds.height - textContainerInset.height - lineHeight
        placeholder.draw(
            at: NSPoint(x: textContainerInset.width, y: y),
            withAttributes: attributes
        )
    }
}

private final class MinimalNoteView: NSView {
    private let effectView: NSVisualEffectView

    init(textView: NSTextView, size: NSSize, cornerRadius: CGFloat) {
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
        effectView.autoresizingMask = [.width, .height]
        effectView.layer?.cornerRadius = cornerRadius
        effectView.layer?.masksToBounds = true
        addSubview(effectView)
        effectView.addSubview(textView)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
