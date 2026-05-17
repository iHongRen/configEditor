//  CodeEditorView.swift
//  Configs
//  Editor component with syntax highlighting, search, copy/paste support
//
//  Created by cxy on 2025/5/19.


import SwiftUI
import AppKit

private extension NSColor {
    static func fromHex(_ hex: String) -> NSColor {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 {
            let chars = Array(s)
            s = "\(chars[0])\(chars[0])\(chars[1])\(chars[1])\(chars[2])\(chars[2])"
        }
        guard s.count == 6, let v = UInt32(s, radix: 16) else {
            return .textColor
        }
        let r = CGFloat((v >> 16) & 0xFF) / 255.0
        let g = CGFloat((v >> 8) & 0xFF) / 255.0
        let b = CGFloat(v & 0xFF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// MARK: - Custom NSTextView for handling keyboard shortcuts
class CustomTextView: NSTextView {
    weak var coordinator: CodeEditorView.Coordinator?
    var onFileDrop: (([URL]) -> Void)?
    var onFileDragStateChanged: ((Bool) -> Void)?
    var onInteraction: (() -> Void)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()

        var insertIndex = 0

        if let coordinator, let filePath = coordinator.currentFilePath() {
            let openInFinder = NSMenuItem(
                title: L10n.tr("open.in.finder"),
                action: #selector(openInFinderAction(_:)),
                keyEquivalent: ""
            )
            openInFinder.target = self
            openInFinder.representedObject = filePath
            menu.insertItem(openInFinder, at: insertIndex)
            insertIndex += 1

            let openInTerminal = NSMenuItem(
                title: L10n.tr("open.in.terminal"),
                action: #selector(openInTerminalAction(_:)),
                keyEquivalent: ""
            )
            openInTerminal.target = self
            openInTerminal.representedObject = filePath
            menu.insertItem(openInTerminal, at: insertIndex)
            insertIndex += 1

            let copyPath = NSMenuItem(
                title: L10n.tr("copy.path"),
                action: #selector(copyPathAction(_:)),
                keyEquivalent: ""
            )
            copyPath.target = self
            copyPath.representedObject = filePath
            menu.insertItem(copyPath, at: insertIndex)
            insertIndex += 1

            if coordinator.isVSCodeInstalled() {
                let openInVSCode = NSMenuItem(
                    title: L10n.tr("open.in.vscode"),
                    action: #selector(openInVSCodeAction(_:)),
                    keyEquivalent: ""
                )
                openInVSCode.target = self
                openInVSCode.representedObject = filePath
                menu.insertItem(openInVSCode, at: insertIndex)
                insertIndex += 1
            }

            menu.insertItem(.separator(), at: insertIndex)
            insertIndex += 1
        }

        // Only show format for files we can format.
        if coordinator?.canFormatCurrentDocument() == true {
            let formatItem = NSMenuItem(
                title: L10n.tr("format.document"),
                action: #selector(formatDocumentAction(_:)),
                keyEquivalent: ""
            )
            formatItem.target = self
            menu.insertItem(formatItem, at: insertIndex)
            insertIndex += 1
            menu.insertItem(.separator(), at: insertIndex)
        }

        return menu
    }

    @objc private func formatDocumentAction(_ sender: Any?) {
        coordinator?.formatDocumentForSaveIfNeeded()
    }

    @objc private func openInFinderAction(_ sender: Any?) {
        guard let path = (sender as? NSMenuItem)?.representedObject as? String else { return }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func openInTerminalAction(_ sender: Any?) {
        guard let path = (sender as? NSMenuItem)?.representedObject as? String else { return }
        let fileURL = URL(fileURLWithPath: path)
        let dirURL = fileURL.deletingLastPathComponent()
        guard let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([dirURL], withApplicationAt: terminalURL, configuration: config)
    }

    @objc private func openInVSCodeAction(_ sender: Any?) {
        guard let path = (sender as? NSMenuItem)?.representedObject as? String else { return }
        coordinator?.openInVSCode(path: path)
    }

    @objc private func copyPathAction(_ sender: Any?) {
        guard let path = (sender as? NSMenuItem)?.representedObject as? String else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
    }
    
    override func keyDown(with event: NSEvent) {
        // Handle Cmd+/ for toggle comment
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "/" {
            coordinator?.toggleComment()
            return
        }
        
        // Handle Cmd+S for save - let it pass through to the global handler
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "s" {
            coordinator?.save()
            return
        }

        // VSCode-like editor behaviors for JSON/JSON5/JSONL
        if !event.modifierFlags.contains(.command) &&
            !event.modifierFlags.contains(.option) &&
            !event.modifierFlags.contains(.control) {
            if event.keyCode == 48 { // Tab
                if coordinator?.handleTab(in: self, isShift: event.modifierFlags.contains(.shift)) == true {
                    return
                }
            }
            if event.keyCode == 36 || event.keyCode == 76 { // Enter or Return
                if coordinator?.handleReturn(in: self) == true {
                    return
                }
            }
        }

        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        onInteraction?()
        super.mouseDown(with: event)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
        onFileDragStateChanged?( !urls.isEmpty )
        return urls.isEmpty ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onFileDragStateChanged?(false)
        super.draggingExited(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
        guard !urls.isEmpty else {
            onFileDragStateChanged?(false)
            return false
        }
        onFileDrop?(urls)
        onFileDragStateChanged?(false)
        return true
    }
}

private final class DropAwareScrollView: NSScrollView {
    var onFileDrop: (([URL]) -> Void)?
    var onFileDragStateChanged: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
        onFileDragStateChanged?( !urls.isEmpty )
        return urls.isEmpty ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onFileDragStateChanged?(false)
        super.draggingExited(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
        guard !urls.isEmpty else {
            onFileDragStateChanged?(false)
            return false
        }
        onFileDrop?(urls)
        onFileDragStateChanged?(false)
        return true
    }
}

// MARK: - Stable Left Gutter (replaces NSRuler placement quirks)
private final class LineNumberGutterView: NSView {
    weak var textView: NSTextView?
    weak var scrollView: NSScrollView?
    var zoomLevel: Double = 1.0 {
        didSet { needsDisplay = true }
    }

    private var observers: [NSObjectProtocol] = []

    init(textView: NSTextView, scrollView: NSScrollView, zoomLevel: Double) {
        self.textView = textView
        self.scrollView = scrollView
        self.zoomLevel = zoomLevel
        super.init(frame: .zero)
        installObservers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var isFlipped: Bool { true }

    deinit {
        for o in observers {
            NotificationCenter.default.removeObserver(o)
        }
        observers.removeAll()
    }

    func preferredWidth() -> CGFloat {
        guard let tv = textView else { return 36 }
        let totalLines = max(1, tv.string.split(separator: "\n", omittingEmptySubsequences: false).count)
        let digits = String(totalLines).count
        let font = NSFont.monospacedSystemFont(ofSize: max(10, 11 * zoomLevel), weight: .regular)
        let charWidth = ("8" as NSString).size(withAttributes: [.font: font]).width
        // Reserve extra room for active line bold weight and larger zoom levels.
        let computed = max(32, CGFloat(digits) * charWidth + max(20, 22 * zoomLevel)) + 10
        // Keep an upper bound to avoid squeezing editor content on very large files.
        return min(180, computed)
    }

    private func installObservers() {
        guard let tv = textView else { return }
        observers.append(
            NotificationCenter.default.addObserver(forName: NSText.didChangeNotification, object: tv, queue: .main) { [weak self] _ in
                self?.needsDisplay = true
                self?.superview?.needsLayout = true
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(forName: NSTextView.didChangeSelectionNotification, object: tv, queue: .main) { [weak self] _ in
                self?.needsDisplay = true
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView?.contentView, queue: .main) { [weak self] _ in
                self?.needsDisplay = true
            }
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let tv = textView,
              let layoutManager = tv.layoutManager,
              let textContainer = tv.textContainer else {
            return
        }

        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        let font = NSFont.monospacedSystemFont(ofSize: max(10, 11 * zoomLevel), weight: .regular)
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let currentAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: max(10, 11 * zoomLevel), weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]

        let text = tv.string as NSString
        let visibleRectInView = tv.visibleRect
        let visibleRectInContainer = visibleRectInView.offsetBy(dx: -tv.textContainerOrigin.x, dy: -tv.textContainerOrigin.y)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRectInContainer, in: textContainer)

        let selectedCharIndex = min(max(0, tv.selectedRange().location), text.length)
        let currentLine = text.lineNumber(at: selectedCharIndex) + 1

        var glyphIndex = glyphRange.location
        var lastDrawnLineStart = -1
        var visibleLineNumber: Int?
        while glyphIndex < NSMaxRange(glyphRange) {
            var lineGlyphRange = NSRange(location: 0, length: 0)
            let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange, withoutAdditionalLayout: true)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let lineCharRange = text.lineRange(for: NSRange(location: charIndex, length: 0))

            if lineCharRange.location != lastDrawnLineStart {
                lastDrawnLineStart = lineCharRange.location
                if visibleLineNumber == nil {
                    visibleLineNumber = text.lineNumber(at: lineCharRange.location) + 1
                } else {
                    visibleLineNumber? += 1
                }
                let lineNo = visibleLineNumber ?? 1
                let attrs = (lineNo == currentLine) ? currentAttrs : baseAttrs
                let s = "\(lineNo)" as NSString
                let size = s.size(withAttributes: attrs)
                let padding = max(6, 8 * zoomLevel)
                let x = bounds.maxX - size.width - padding
                let y = (lineFragmentRect.minY - visibleRectInContainer.origin.y) + (lineFragmentRect.height - size.height) / 2.0
                if y + size.height >= dirtyRect.minY && y <= dirtyRect.maxY {
                    s.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
                }
            }
            glyphIndex = NSMaxRange(lineGlyphRange)
        }
    }
}

private final class EditorContainerView: NSView {
    let scrollView: DropAwareScrollView
    let gutterView: LineNumberGutterView
    private var gutterWidthConstraint: NSLayoutConstraint?

    init(scrollView: DropAwareScrollView, textView: NSTextView, zoomLevel: Double) {
        self.scrollView = scrollView
        self.gutterView = LineNumberGutterView(textView: textView, scrollView: scrollView, zoomLevel: zoomLevel)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        gutterView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gutterView)
        addSubview(scrollView)

        let width = gutterView.preferredWidth()
        let widthConstraint = gutterView.widthAnchor.constraint(equalToConstant: width)
        gutterWidthConstraint = widthConstraint

        NSLayoutConstraint.activate([
            gutterView.leadingAnchor.constraint(equalTo: leadingAnchor),
            gutterView.topAnchor.constraint(equalTo: topAnchor),
            gutterView.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthConstraint,

            scrollView.leadingAnchor.constraint(equalTo: gutterView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refreshGutterWidth() {
        gutterWidthConstraint?.constant = gutterView.preferredWidth()
    }

    func updateZoom(_ zoomLevel: Double) {
        gutterView.zoomLevel = zoomLevel
        refreshGutterWidth()
        needsLayout = true
    }
}

struct CodeEditorView: NSViewRepresentable {
    private static let largeFileSizeThreshold: Int64 = 512 * 1024
    private static let largeTextLengthThreshold = 120_000

    @Binding var text: String
    var filePath: String? = nil
    var fileExtension: String
    @Binding var search: String
    @Binding var ref: Ref?
    var isFocused: Bool
    var showSearchBar: (() -> Void)? = nil
    var onSave: (() -> Void)? = nil
    var onSaveWithCursorLine: ((String?) -> Void)? = nil
    var onFileDrop: (([URL]) -> Void)? = nil
    var onFileDragStateChanged: ((Bool) -> Void)? = nil
    var onInteraction: (() -> Void)? = nil
    var estimatedFileSize: Int64 = 0
    var zoomLevel: Double
    @Binding var matchCount: Int
    @Binding var currentMatchIndex: Int
    
    @Environment(\.colorScheme) private var colorScheme

    internal struct Theme {
        let keyword: NSColor
        let string: NSColor
        let comment: NSColor
        let number: NSColor
        let property: NSColor
        let command: NSColor
        let variable: NSColor
        let punctuation: NSColor
        let link: NSColor
        let searchHighlight: NSColor
        let normalText: NSColor
        let background: NSColor
        let jsonKey: NSColor
        let jsonString: NSColor
        let jsonNumber: NSColor
        let jsonLiteral: NSColor
        let jsonPunctuation: NSColor

        static let light = Theme(
            keyword: NSColor(red: 0.67, green: 0.13, blue: 0.55, alpha: 1.0),
            string: NSColor(red: 0.82, green: 0.1, blue: 0.1, alpha: 1.0),
            comment: NSColor(red: 0.0, green: 0.45, blue: 0.0, alpha: 1.0),
            number: NSColor(red: 0.17, green: 0.0, blue: 0.83, alpha: 1.0),
            property: NSColor(red: 0.42, green: 0.16, blue: 0.58, alpha: 1.0),
            command: NSColor(red: 0.17, green: 0.0, blue: 0.83, alpha: 1.0),
            variable: NSColor(red: 0.79, green: 0.41, blue: 0.0, alpha: 1.0),
            punctuation: .gray,
            link: .blue,
            searchHighlight: NSColor.yellow.withAlphaComponent(0.3),
            normalText: .textColor,
            background: .textBackgroundColor,
            jsonKey: NSColor.fromHex("#001080"),
            jsonString: NSColor.fromHex("#A31515"),
            jsonNumber: NSColor.fromHex("#098658"),
            jsonLiteral: NSColor.fromHex("#0000FF"),
            jsonPunctuation: NSColor.fromHex("#666666")
        )

        static let dark = Theme(
            keyword: NSColor(red: 0.84, green: 0.21, blue: 0.5, alpha: 1.0),      // Magenta
            string: NSColor(red: 0.15, green: 0.68, blue: 0.64, alpha: 1.0),       // Cyan
            comment: NSColor(red: 0.35, green: 0.43, blue: 0.46, alpha: 1.0),      // Muted Blue-Gray
            number: NSColor(red: 0.52, green: 0.8, blue: 0.0, alpha: 1.0),        // Green
            property: NSColor(red: 0.15, green: 0.55, blue: 0.82, alpha: 1.0),     // Blue
            command: NSColor(red: 0.8, green: 0.34, blue: 0.0, alpha: 1.0),        // Orange
            variable: NSColor(red: 0.7, green: 0.45, blue: 0.0, alpha: 1.0),       // Yellow
            punctuation: NSColor(red: 0.5, green: 0.58, blue: 0.6, alpha: 1.0),   // Gray
            link: NSColor(red: 0.25, green: 0.68, blue: 0.88, alpha: 1.0),      // Bright Blue
            searchHighlight: NSColor.yellow.withAlphaComponent(0.4),
            normalText: NSColor(red: 0.8, green: 0.82, blue: 0.84, alpha: 1.0),   // Light Gray
            background: NSColor(red: 0.01, green: 0.16, blue: 0.21, alpha: 1.0),  // Dark Slate
            jsonKey: NSColor.fromHex("#9CDCFE"),
            jsonString: NSColor.fromHex("#CE9178"),
            jsonNumber: NSColor.fromHex("#B5CEA8"),
            jsonLiteral: NSColor.fromHex("#569CD6"),
            jsonPunctuation: NSColor.fromHex("#D4D4D4")
        )
    }
    
    private var currentTheme: Theme {
        colorScheme == .dark ? Theme.dark : Theme.light
    }

    private var usesLightweightHighlighting: Bool {
        estimatedFileSize >= Self.largeFileSizeThreshold || text.count >= Self.largeTextLengthThreshold
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSView {
        let scrollView = DropAwareScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.verticalScrollElasticity = .none
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollView.onFileDrop = onFileDrop
        scrollView.onFileDragStateChanged = onFileDragStateChanged
        
        let textView = CustomTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.autoresizingMask = [.width, .height]
        textView.registerForDraggedTypes([.fileURL])
        textView.onFileDragStateChanged = onFileDragStateChanged
        
        // Ensure undo manager is properly configured
        // NSTextView automatically creates an undo manager, so we don't need to set it manually
        
        // Disable smart quotes and other automatic substitutions for a better code editing experience
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        scrollView.documentView = textView
        scrollView.hasVerticalRuler = false
        scrollView.rulersVisible = false
        
        context.coordinator.textView = textView
        textView.coordinator = context.coordinator
        textView.onFileDrop = onFileDrop
        textView.onInteraction = onInteraction
        textView.delegate = context.coordinator
        
        textView.string = text
        textView.font = .monospacedSystemFont(ofSize: 14 * zoomLevel, weight: .regular)
        textView.drawsBackground = true
        applyHighlighting(context: context)
        
        DispatchQueue.main.async {
            ref = Ref(textView: textView, coordinator: context.coordinator, matchCount: $matchCount, currentMatchIndex: $currentMatchIndex)
        }
        
        return EditorContainerView(scrollView: scrollView, textView: textView, zoomLevel: zoomLevel)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Keep coordinator in sync with the latest SwiftUI props (CodeEditorView is a value type).
        // Without this, coordinator.parent may keep an old fileExtension (e.g. "sh") after switching files.
        context.coordinator.parent = self

        guard let container = nsView as? EditorContainerView,
              let textView = container.scrollView.documentView as? NSTextView else { return }

        // Keep scroll view background opaque to avoid unintended transparency.
        container.scrollView.drawsBackground = true
        container.scrollView.backgroundColor = currentTheme.background
        container.updateZoom(zoomLevel)
        container.refreshGutterWidth()
        if let customTextView = textView as? CustomTextView {
            customTextView.drawsBackground = true
        }
        
        var needsHighlight = false
        
        if context.coordinator.lastColorScheme != colorScheme {
            context.coordinator.lastColorScheme = colorScheme
            needsHighlight = true
        }
        
        // If the text change comes from the parent view, update the text view
        if textView.string != text && !context.coordinator.textChanged {
            textView.string = text
            // Clear selection when switching configurations (external text update)
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            needsHighlight = true
            // Scroll to top when switching configurations
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        }
        
        if context.coordinator.lastSearch != search {
            context.coordinator.lastSearch = search
            needsHighlight = true
            if search.isEmpty {
                ref?.resetCounts()
            }
        }
        
        if let currentFont = textView.font, abs(currentFont.pointSize - (14 * zoomLevel)) > 0.1 {
            textView.font = .monospacedSystemFont(ofSize: 14 * zoomLevel, weight: .regular)
            needsHighlight = true
        }

        if needsHighlight || context.coordinator.textChanged {
            container.gutterView.needsDisplay = true
            container.needsLayout = true
        }

        if let customTextView = textView as? CustomTextView {
            customTextView.onInteraction = onInteraction
        }
        
        // Only apply highlighting if textChanged is true and it's not from a save operation
        if context.coordinator.textChanged && !context.coordinator.isFromSave {
            needsHighlight = true
            context.coordinator.textChanged = false
        } else if context.coordinator.isFromSave {
            // Reset the save flag without triggering highlighting
            context.coordinator.isFromSave = false
            context.coordinator.textChanged = false
        }

        if needsHighlight {
            applyHighlighting(context: context)
        }
    }
    
    private func applyHighlighting(context: Context) {
        guard let textView = context.coordinator.textView,
              let textStorage = textView.textStorage else { return }

        let theme = currentTheme
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let selectedRange = textView.selectedRange()
        let visibleRect = textView.visibleRect
        let currentHeight = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 0

        // Disable undo registration during highlighting to preserve undo stack
        textView.undoManager?.disableUndoRegistration()
        
        textStorage.beginEditing()

        textStorage.setAttributes([
            .foregroundColor: theme.normalText,
            .font: NSFont.monospacedSystemFont(ofSize: 14 * zoomLevel, weight: .regular)
        ], range: fullRange)

        textView.backgroundColor = theme.background

        let patterns = usesLightweightHighlighting ? lightweightHighlightPatterns(theme: theme) : getHighlightPatterns(for: fileExtension, theme: theme)
        let commentRanges = usesLightweightHighlighting ? [] : getCommentRanges(for: fileExtension, in: textStorage.string, fullRange: fullRange)
        for (pattern, color) in patterns {
            let addsLinkAttribute = pattern.contains("https?://")
            if usesLightweightHighlighting || isCommentPattern(pattern) {
                highlightPattern(textStorage, pattern, color: color, range: fullRange, addsLinkAttribute: addsLinkAttribute)
            } else {
                // Apply other patterns excluding comment ranges
                highlightPattern(textStorage, pattern, color: color, range: fullRange, excludeRanges: commentRanges, addsLinkAttribute: addsLinkAttribute)
            }
        }

        if !search.isEmpty {
            let pattern = NSRegularExpression.escapedPattern(for: search)
            highlightPattern(textStorage, pattern, color: theme.searchHighlight, isBackground: true, range: fullRange)
        }

        textStorage.endEditing()
        
        // Re-enable undo registration after highlighting
        textView.undoManager?.enableUndoRegistration()

        let newHeight = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 0
        
        if currentHeight == newHeight {
            textView.setSelectedRange(selectedRange)
            textView.scrollRangeToVisible(selectedRange)
        } else {
            textView.scrollToVisible(visibleRect)
        }
    }

    private func lightweightHighlightPatterns(theme: Theme) -> [(String, NSColor)] {
        [
            ("(^\\s*(#|//|;|--).*)", theme.comment),
            ("(<!--([\\s\\S]*?)-->|/\\*[\\s\\S]*?\\*/)", theme.comment),
            ("(\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*')", theme.string),
            ("(https?://(?:[A-Za-z0-9\\-._~:/?#\\[\\]@!$&*+,;=%]|\\([^\\s()]*\\))*(?:[A-Za-z0-9\\-._~:/?#\\[\\]@!$&*+=%]|\\([^\\s()]*\\)))", theme.link)
        ]
    }

    internal func getHighlightPatterns(for fileExtension: String, theme: Theme) -> [(String, NSColor)] {
        let ext = fileExtension.lowercased()
        var patterns: [(String, NSColor)] = []
        
        switch ext {
        case "json":
            patterns = [
                ("(\"(?:\\\\.|[^\"\\\\])*\")\\s*:", theme.jsonKey),
                ("(\"(?:\\\\.|[^\"\\\\])*\")", theme.jsonString),
                ("\\b(true|false|null)\\b", theme.jsonLiteral),
                ("\\b-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\b", theme.jsonNumber),
                ("[{}\\[\\]:,]", theme.jsonPunctuation)
            ]
        case "jsonl":
            patterns = [
                ("(\"(?:\\\\.|[^\"\\\\])*\")\\s*:", theme.jsonKey),
                ("(\"(?:\\\\.|[^\"\\\\])*\")", theme.jsonString),
                ("\\b(true|false|null)\\b", theme.jsonLiteral),
                ("\\b-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\b", theme.jsonNumber),
                ("[{}\\[\\]:,]", theme.jsonPunctuation)
            ]
        case "json5":
            patterns = [
                ("(\"(?:\\\\.|[^\"\\\\])*\")\\s*:", theme.jsonKey),
                ("\\b([A-Za-z_\\$][A-Za-z0-9_\\$]*)\\s*:", theme.jsonKey),
                ("(\"(?:\\\\.|[^\"\\\\])*\")", theme.jsonString),
                ("('(?:\\\\.|[^'\\\\])*')", theme.jsonString),
                ("\\b(true|false|null|Infinity|NaN)\\b", theme.jsonLiteral),
                ("\\b-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\b", theme.jsonNumber),
                ("[{}\\[\\]:,]", theme.jsonPunctuation)
            ]
        case "yml", "yaml":
            patterns = [
                ("(^[ \\t]*[-a-zA-Z0-9_]+:)", theme.property),
                ("(#.*)", theme.comment),
                ("(\"([^\"]*)\"|'[^']*')", theme.string)
            ]
        case "sh", "zsh", "bash", ".zshrc", ".bashrc", ".profile":
            patterns = [
                ("(#.*)", theme.comment),
                ("\\b(if|then|else|elif|fi|for|while|do|done|case|esac|in|function|export|return|local)\\b", theme.keyword),
                ("\\b(echo|printf|cd|ls|rm|mv|cp|mkdir|touch|grep|sed|awk|cat|head|tail|chmod|chown)\\b", theme.command),
                ("(\"([^\"]*)\"|'[^']*')", theme.string),
                ("\\$[a-zA-Z_][a-zA-Z0-9_]*|\\$\\{[^}]*\\}", theme.variable)
            ]
        case "py":
            patterns = [
                ("(#.*)", theme.comment),
                ("\\b(def|class|import|from|as|return|if|elif|else|for|while|try|except|finally|with|lambda|yield|async|await|pass|break|continue|True|False|None)\\b", theme.keyword),
                ("(\"\"\"[\\s\\S]*?\"\"\"|'''[\\s\\S]*?'''|\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*')", theme.string),
                ("\\b\\d+(\\.\\d+)?\\b", theme.number)
            ]
        case "js", "ts":
            patterns = [
                ("(//.*)", theme.comment),
                ("/\\*[\\s\\S]*?\\*/", theme.comment),
                ("\\b(const|let|var|function|return|if|else|for|while|switch|case|break|continue|import|from|export|default|class|extends|async|await|try|catch|finally|new|typeof|instanceof)\\b", theme.keyword),
                ("(\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*'|`([^`\\\\]|\\\\.)*`)", theme.string),
                ("\\b\\d+(\\.\\d+)?\\b", theme.number)
            ]
        case "swift":
            patterns = [
                ("(//.*)", theme.comment),
                ("/\\*[\\s\\S]*?\\*/", theme.comment),
                ("\\b(let|var|func|struct|class|enum|protocol|extension|if|else|guard|for|while|switch|case|return|import|try|catch|throw|async|await|actor|init|deinit)\\b", theme.keyword),
                ("(\"([^\"\\\\]|\\\\.)*\")", theme.string),
                ("\\b\\d+(\\.\\d+)?\\b", theme.number)
            ]
        case "toml":
            patterns = [
                ("(^\\s*#.*)", theme.comment),
                ("(\\[[^\\]]+\\])", theme.keyword),
                ("(^\\s*[A-Za-z0-9_.-]+\\s*=)", theme.property),
                ("(\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*')", theme.string),
                ("\\b(true|false)\\b", theme.keyword),
                ("\\b\\d+(\\.\\d+)?\\b", theme.number)
            ]
        case "xml", "html":
            patterns = [
                ("(<!--([\\s\\S]*?)-->)", theme.comment),
                ("(<\\/?[A-Za-z0-9:_-]+)", theme.keyword),
                ("([A-Za-z_:][-A-Za-z0-9_:.]*(?=\\=))", theme.property),
                ("(\"([^\"]*)\"|'([^']*)')", theme.string)
            ]
        case "markdown":
            patterns = [
                ("(^#{1,6}\\s.*$)", theme.keyword),
                ("(```[\\s\\S]*?```|`[^`]+`)", theme.string),
                ("(\\*\\*[^*]+\\*\\*|__[^_]+__)", theme.property),
                ("(\\[[^\\]]+\\]\\([^\\)]+\\))", theme.link)
            ]
        case "properties", "env":
            patterns = [
                ("(^\\s*[#!].*$)", theme.comment),
                ("(^\\s*[A-Za-z0-9_.-]+\\s*[=:])", theme.property),
                ("(\"([^\"]*)\"|'([^']*)')", theme.string)
            ]
        case "docker":
            patterns = [
                ("(^\\s*#.*)", theme.comment),
                ("\\b(FROM|RUN|CMD|LABEL|EXPOSE|ENV|ADD|COPY|ENTRYPOINT|VOLUME|USER|WORKDIR|ARG|ONBUILD|STOPSIGNAL|HEALTHCHECK|SHELL)\\b", theme.keyword),
                ("(\"([^\"]*)\"|'([^']*)')", theme.string)
            ]
        case "ini", "git", "conf":
             patterns = [
                ("(^\\s*[#;].*)", theme.comment),
                ("(^\\s*\\[[^\\]]+\\])", theme.keyword),
                ("(^\\s*[^=:#;\\s][^=:#;]*\\s*[=:])", theme.property),
                ("(\"([^\"]*)\"|'([^']*)')", theme.string)
            ]
        case "makefile":
            patterns = [
                ("(^\\s*#.*)", theme.comment),
                ("(^[A-Za-z0-9_.-]+\\s*:)", theme.property),
                ("\\b(ifdef|ifndef|ifeq|ifneq|else|endif|include|define|endef|export|unexport|override|private|vpath)\\b", theme.keyword),
                ("\\$\\([^)]+\\)|\\$\\{[^}]+\\}", theme.variable),
                ("(\"([^\"]*)\"|'([^']*)')", theme.string)
            ]
        case "css", "scss", "less":
            patterns = [
                ("/\\*[\\s\\S]*?\\*/", theme.comment),
                ("@[A-Za-z-]+", theme.keyword),
                ("([A-Za-z-]+)(?=\\s*:)", theme.property),
                ("(#[0-9A-Fa-f]{3,8}\\b|\\b\\d+(?:\\.\\d+)?(?:px|em|rem|%|vh|vw|s|ms)?\\b)", theme.number),
                ("(\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*')", theme.string),
                ("(\\$[A-Za-z_-][A-Za-z0-9_-]*|@[A-Za-z_-][A-Za-z0-9_-]*(?=\\s*:))", theme.variable)
            ]
        case "ruby":
            patterns = [
                ("(#.*)", theme.comment),
                ("\\b(def|class|module|do|end|if|elsif|else|unless|case|when|while|until|for|in|begin|rescue|ensure|return|yield|self|nil|true|false|require|include|extend)\\b", theme.keyword),
                ("(\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*'|`([^`\\\\]|\\\\.)*`)", theme.string),
                ("(:[A-Za-z_][A-Za-z0-9_]*|@[A-Za-z_][A-Za-z0-9_]*|\\$[A-Za-z_][A-Za-z0-9_]*)", theme.variable),
                ("\\b\\d+(?:\\.\\d+)?\\b", theme.number)
            ]
        case "php":
            patterns = [
                ("(//.*|#.*)", theme.comment),
                ("/\\*[\\s\\S]*?\\*/", theme.comment),
                ("(<\\?php|\\?>)", theme.keyword),
                ("\\b(abstract|array|as|break|case|catch|class|const|continue|declare|default|echo|else|elseif|extends|final|for|foreach|function|global|if|implements|include|namespace|new|null|private|protected|public|require|return|static|switch|throw|trait|try|use|var|while|true|false)\\b", theme.keyword),
                ("\\$[A-Za-z_][A-Za-z0-9_]*", theme.variable),
                ("(\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*')", theme.string),
                ("\\b\\d+(?:\\.\\d+)?\\b", theme.number)
            ]
        case "go", "rust", "java", "kotlin", "scala", "groovy", "c", "cpp":
            patterns = [
                ("(//.*)", theme.comment),
                ("/\\*[\\s\\S]*?\\*/", theme.comment),
                ("\\b(abstract|as|async|await|auto|break|case|catch|class|const|continue|data|defer|do|else|enum|extern|false|final|for|func|fun|go|guard|if|impl|import|in|inline|interface|let|match|mut|namespace|new|null|nullptr|object|operator|override|package|private|protected|protocol|public|return|self|static|struct|super|switch|template|this|throw|trait|true|try|type|typedef|typename|use|using|val|var|virtual|void|when|where|while)\\b", theme.keyword),
                ("(\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*')", theme.string),
                ("\\b\\d+(?:\\.\\d+)?\\b", theme.number)
            ]
        case "sql":
            patterns = [
                ("(--.*)", theme.comment),
                ("/\\*[\\s\\S]*?\\*/", theme.comment),
                ("\\b(SELECT|FROM|WHERE|JOIN|LEFT|RIGHT|INNER|OUTER|ON|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|ALTER|DROP|TABLE|VIEW|INDEX|PRIMARY|KEY|FOREIGN|REFERENCES|AND|OR|NOT|NULL|IS|IN|LIKE|ORDER|GROUP|BY|HAVING|LIMIT|OFFSET|UNION|ALL|DISTINCT|AS|CASE|WHEN|THEN|ELSE|END)\\b", theme.keyword),
                ("(\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*')", theme.string),
                ("\\b\\d+(?:\\.\\d+)?\\b", theme.number)
            ]
        case "terraform", "hcl":
            patterns = [
                ("(^\\s*(#|//).*)", theme.comment),
                ("/\\*[\\s\\S]*?\\*/", theme.comment),
                ("\\b(resource|data|module|variable|locals|output|provider|terraform|backend|required_providers)\\b", theme.keyword),
                ("(^\\s*[A-Za-z0-9_.-]+\\s*=)", theme.property),
                ("(\"([^\"\\\\]|\\\\.)*\")", theme.string),
                ("\\b(true|false|null)\\b", theme.keyword),
                ("\\b\\d+(?:\\.\\d+)?\\b", theme.number)
            ]
        case "protobuf":
            patterns = [
                ("(//.*)", theme.comment),
                ("/\\*[\\s\\S]*?\\*/", theme.comment),
                ("\\b(syntax|package|import|option|message|enum|service|rpc|returns|repeated|optional|required|reserved|oneof|map|true|false)\\b", theme.keyword),
                ("\\b(double|float|int32|int64|uint32|uint64|sint32|sint64|fixed32|fixed64|sfixed32|sfixed64|bool|string|bytes)\\b", theme.property),
                ("(\"([^\"\\\\]|\\\\.)*\")", theme.string),
                ("\\b\\d+\\b", theme.number)
            ]
        case "graphql":
            patterns = [
                ("(#.*)", theme.comment),
                ("\\b(query|mutation|subscription|fragment|on|schema|type|interface|union|enum|input|extend|directive|scalar|implements)\\b", theme.keyword),
                ("(\"\"\"[\\s\\S]*?\"\"\"|\"([^\"\\\\]|\\\\.)*\")", theme.string),
                ("([A-Za-z_][A-Za-z0-9_]*)(?=\\s*[:(])", theme.property),
                ("\\b(true|false|null)\\b", theme.keyword),
                ("\\b\\d+(?:\\.\\d+)?\\b", theme.number)
            ]
        case "lua":
            patterns = [
                ("(--.*)", theme.comment),
                ("\\b(function|local|return|if|then|else|elseif|end|for|while|repeat|until|do|break|nil|true|false|and|or|not|require)\\b", theme.keyword),
                ("(\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*')", theme.string),
                ("\\b\\d+(?:\\.\\d+)?\\b", theme.number)
            ]
        case "perl":
            patterns = [
                ("(#.*)", theme.comment),
                ("\\b(my|our|use|sub|return|if|elsif|else|unless|while|for|foreach|last|next|redo|package|require|true|false|undef)\\b", theme.keyword),
                ("[$@%][A-Za-z_][A-Za-z0-9_]*", theme.variable),
                ("(\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*'|`([^`\\\\]|\\\\.)*`)", theme.string),
                ("\\b\\d+(?:\\.\\d+)?\\b", theme.number)
            ]
        case "r":
            patterns = [
                ("(#.*)", theme.comment),
                ("\\b(function|if|else|for|while|repeat|break|next|return|TRUE|FALSE|NULL|NA|library|require)\\b", theme.keyword),
                ("(\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*')", theme.string),
                ("\\b\\d+(?:\\.\\d+)?\\b", theme.number)
            ]
        case "log":
            patterns = [
                ("\\b(ERROR|WARN|WARNING|INFO|DEBUG|TRACE|FATAL|CRITICAL)\\b", theme.keyword),
                ("\\b\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?(?:Z|[+-]\\d{2}:?\\d{2})?\\b", theme.number),
                ("(\"([^\"\\\\]|\\\\.)*\")", theme.string)
            ]
        default:
            break
        }
        
        patterns.append(("(https?://(?:[A-Za-z0-9\\-._~:/?#\\[\\]@!$&*+,;=%]|\\([^\\s()]*\\))*(?:[A-Za-z0-9\\-._~:/?#\\[\\]@!$&*+=%]|\\([^\\s()]*\\)))", theme.link))
        
        return patterns
    }

    internal func getCommentRanges(for fileExtension: String, in text: String, fullRange: NSRange) -> [NSRange] {
        let ext = fileExtension.lowercased()
        var commentPatterns: [String] = []
        
        switch ext {
        case "sh", "zsh", "bash", ".zshrc", ".bashrc", ".profile", "yml", "yaml", "py", "toml", "docker", "properties", "env", "makefile", "ruby", "graphql", "perl", "r":
            commentPatterns = ["#.*"]
        case "ini", "git", "conf":
            commentPatterns = ["^\\s*#.*", "^\\s*;.*"]
        case "js", "ts", "swift", "json5", "css", "scss", "less", "php", "go", "rust", "java", "kotlin", "scala", "groovy", "c", "cpp", "terraform", "hcl", "protobuf":
            commentPatterns = ["//.*", "/\\*[\\s\\S]*?\\*/"]
        case "sql", "lua":
            commentPatterns = ["--.*", "/\\*[\\s\\S]*?\\*/"]
        case "xml", "html":
            commentPatterns = ["<!--([\\s\\S]*?)-->"]
        default:
            return []
        }
        
        var commentRanges: [NSRange] = []
        
        for pattern in commentPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
                regex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                    guard let match = match else { return }
                    commentRanges.append(match.range)
                }
            } catch {
                print("Regex error for comment pattern \\'(pattern)\\': \\(error.localizedDescription)")
            }
        }
        
        return commentRanges
    }
    
    private func isCommentPattern(_ pattern: String) -> Bool {
        pattern.contains("#.*") ||
        pattern.contains("//.*") ||
        pattern.contains("--.*") ||
        pattern.contains(";.*") ||
        pattern.contains("/\\*") ||
        pattern.contains("<!--")
    }

    internal func highlightPattern(_ textStorage: NSTextStorage, _ pattern: String, color: NSColor, isBackground: Bool = false, range: NSRange, excludeRanges: [NSRange] = [], addsLinkAttribute: Bool = false) {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
                guard let match = match else { return }
                
                let highlightRange = (match.numberOfRanges > 1) ? match.range(at: 1) : match.range
                
                // Check if this range overlaps with any comment range
                let shouldExclude = excludeRanges.contains { commentRange in
                    NSIntersectionRange(highlightRange, commentRange).length > 0
                }
                
                if !shouldExclude {
                    if isBackground {
                        textStorage.addAttributes([.backgroundColor: color], range: highlightRange)
                    } else {
                        var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: color]
                        if addsLinkAttribute {
                            let linkValue = (textStorage.string as NSString).substring(with: highlightRange)
                            attributes[.link] = linkValue
                            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                            attributes[.cursor] = NSCursor.pointingHand
                        }
                        textStorage.addAttributes(attributes, range: highlightRange)
                    }
                }
            }
        } catch {
            print("Regex error for pattern \\'(pattern)\\': \\(error.localizedDescription)")
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView
        weak var textView: NSTextView?
        
        var lastColorScheme: ColorScheme?
        var lastSearch: String = ""
        var textChanged: Bool = false
        var isFromSave: Bool = false
        private var isTogglingComment = false

        init(_ parent: CodeEditorView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            if isTogglingComment { return }
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
            self.textChanged = true
            self.isFromSave = false // Reset save flag on user input
            // Ensure the cursor is visible after text changes
            textView.scrollRangeToVisible(textView.selectedRange())
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            let linkString: String?
            if let url = link as? URL {
                linkString = url.absoluteString
            } else {
                linkString = link as? String
            }

            guard let linkString,
                  let url = URL(string: linkString) else {
                return false
            }

            NSWorkspace.shared.open(url)
            return true
        }
        
        func save() {
            let cursorLine = getCurrentLineContent()
            if let onSaveWithCursorLine = parent.onSaveWithCursorLine {
                onSaveWithCursorLine(cursorLine)
            } else {
                parent.onSave?()
            }
        }

        // Format JSON/JSONL on save (best-effort; JSON5 intentionally skipped for safety).
        func formatDocumentForSaveIfNeeded() {
            guard let textView else { return }
            let ext = parent.fileExtension.lowercased()
            guard ext == "json" || ext == "jsonl" else { return }

            let original = textView.string
            let formatted: String?
            if ext == "json" {
                formatted = Self.formatJSON(original)
            } else {
                formatted = Self.formatJSONLines(original)
            }
            guard let formatted, formatted != original else { return }

            let oldSel = textView.selectedRange()
            let fullRange = NSRange(location: 0, length: (original as NSString).length)

            textView.undoManager?.beginUndoGrouping()
            defer { textView.undoManager?.endUndoGrouping() }

            if textView.shouldChangeText(in: fullRange, replacementString: formatted) {
                textView.textStorage?.replaceCharacters(in: fullRange, with: formatted)
                textView.didChangeText()
            }

            // Best-effort cursor preservation.
            let newLen = (formatted as NSString).length
            let newLoc = min(oldSel.location, newLen)
            textView.setSelectedRange(NSRange(location: newLoc, length: 0))

            parent.text = formatted
        }

        func canFormatCurrentDocument() -> Bool {
            let ext = parent.fileExtension.lowercased()
            return ext == "json" || ext == "jsonl"
        }

        func currentFilePath() -> String? {
            parent.filePath
        }

        func isVSCodeInstalled() -> Bool {
            vsCodeApplicationURL() != nil
        }

        func openInVSCode(path: String) {
            guard let appURL = vsCodeApplicationURL() else { return }
            let fileURL = URL(fileURLWithPath: path)
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: config)
        }

        private func vsCodeApplicationURL() -> URL? {
            // Stable bundle identifiers for VSCode variants.
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") {
                return url
            }
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCodeInsiders") {
                return url
            }
            return nil
        }

        private static func formatJSON(_ text: String) -> String? {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return text }
            guard let data = trimmed.data(using: .utf8) else { return nil }
            guard let obj = try? JSONSerialization.jsonObject(with: data, options: []) else { return nil }

            var options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
            if #available(macOS 13.0, *) {
                options.insert(.withoutEscapingSlashes)
            }
            guard let out = try? JSONSerialization.data(withJSONObject: obj, options: options),
                  let s = String(data: out, encoding: .utf8) else { return nil }
            return s + "\n"
        }

        private static func formatJSONLines(_ text: String) -> String? {
            let hadTrailingNewline = text.hasSuffix("\n")
            let rawLines = text.split(separator: "\n", omittingEmptySubsequences: false)
            var out: [String] = []
            out.reserveCapacity(rawLines.count)

            for raw in rawLines {
                let line = String(raw)
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    out.append(line)
                    continue
                }
                guard let data = trimmed.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data, options: []) else {
                    out.append(line)
                    continue
                }
                let compact = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
                if let compact, let s = String(data: compact, encoding: .utf8) {
                    out.append(s)
                } else {
                    out.append(line)
                }
            }

            var joined = out.joined(separator: "\n")
            if hadTrailingNewline && !joined.hasSuffix("\n") {
                joined += "\n"
            }
            return joined
        }

        // MARK: - VSCode-like Indent / Tab (JSON family)
        func handleTab(in textView: NSTextView, isShift: Bool) -> Bool {
            let ext = parent.fileExtension.lowercased()
            guard ext == "json" || ext == "jsonl" || ext == "json5" else { return false }

            if isShift {
                return outdentCurrentLine(in: textView, spaces: 2)
            } else {
                return replaceSelection(in: textView, with: "  ")
            }
        }

        func handleReturn(in textView: NSTextView) -> Bool {
            let ext = parent.fileExtension.lowercased()
            guard ext == "json" || ext == "jsonl" || ext == "json5" else { return false }

            let ns = textView.string as NSString
            let sel = textView.selectedRange()
            let cursor = sel.location

            // Special case: between {} or [] -> create an indented blank line like VSCode.
            let prevNonWS = findPrevNonWhitespace(in: ns, before: cursor)
            let nextNonWS = findNextNonWhitespace(in: ns, after: cursor)
            if let p = prevNonWS, let n = nextNonWS {
                let prevCh = ns.substring(with: NSRange(location: p, length: 1))
                let nextCh = ns.substring(with: NSRange(location: n, length: 1))
                let isBracePair = (prevCh == "{" && nextCh == "}") || (prevCh == "[" && nextCh == "]")
                if isBracePair {
                    let baseIndent = currentLineIndent(in: ns, at: cursor)
                    let innerIndent = baseIndent + "  "
                    let insert = "\n\(innerIndent)\n\(baseIndent)"
                    if replaceSelection(in: textView, with: insert) {
                        let newCursor = cursor + 1 + (innerIndent as NSString).length
                        textView.setSelectedRange(NSRange(location: newCursor, length: 0))
                        return true
                    }
                }
            }

            let lineRange = ns.lineRange(for: NSRange(location: cursor, length: 0))
            let lineStart = lineRange.location
            let linePrefixLen = max(0, min(cursor - lineStart, ns.length - lineStart))
            let beforeCursor = ns.substring(with: NSRange(location: lineStart, length: linePrefixLen))

            let baseIndent = currentLineIndent(in: ns, at: cursor)
            let trimmed = beforeCursor.trimmingCharacters(in: .whitespacesAndNewlines)
            let shouldIndentMore = trimmed.hasSuffix("{") || trimmed.hasSuffix("[")
            let newIndent = shouldIndentMore ? (baseIndent + "  ") : baseIndent
            return replaceSelection(in: textView, with: "\n\(newIndent)")
        }

        private func replaceSelection(in textView: NSTextView, with s: String) -> Bool {
            let sel = textView.selectedRange()
            if textView.shouldChangeText(in: sel, replacementString: s) {
                textView.textStorage?.replaceCharacters(in: sel, with: s)
                textView.didChangeText()
                let newLoc = sel.location + (s as NSString).length
                textView.setSelectedRange(NSRange(location: newLoc, length: 0))
                return true
            }
            return false
        }

        private func outdentCurrentLine(in textView: NSTextView, spaces: Int) -> Bool {
            let ns = textView.string as NSString
            let sel = textView.selectedRange()
            let cursor = sel.location
            let lineRange = ns.lineRange(for: NSRange(location: cursor, length: 0))
            let line = ns.substring(with: lineRange)
            let prefix = String(line.prefix(while: { $0 == " " }))
            let removeCount = min(spaces, prefix.count)
            guard removeCount > 0 else { return true }

            let removalRange = NSRange(location: lineRange.location, length: removeCount)
            if textView.shouldChangeText(in: removalRange, replacementString: "") {
                textView.textStorage?.replaceCharacters(in: removalRange, with: "")
                textView.didChangeText()
                let newCursor = max(lineRange.location, cursor - removeCount)
                textView.setSelectedRange(NSRange(location: newCursor, length: 0))
                return true
            }
            return false
        }

        private func currentLineIndent(in ns: NSString, at location: Int) -> String {
            let lineRange = ns.lineRange(for: NSRange(location: location, length: 0))
            let line = ns.substring(with: lineRange)
            let indent = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
            return indent.replacingOccurrences(of: "\t", with: "  ")
        }

        private func isWhitespace(_ ch: unichar) -> Bool {
            guard let scalar = UnicodeScalar(ch) else { return false }
            return Character(scalar).isWhitespace
        }

        private func findPrevNonWhitespace(in ns: NSString, before location: Int) -> Int? {
            var i = min(location - 1, ns.length - 1)
            while i >= 0 {
                if !isWhitespace(ns.character(at: i)) {
                    return i
                }
                i -= 1
            }
            return nil
        }

        private func findNextNonWhitespace(in ns: NSString, after location: Int) -> Int? {
            var i = max(0, location)
            while i < ns.length {
                if !isWhitespace(ns.character(at: i)) {
                    return i
                }
                i += 1
            }
            return nil
        }
        
        func getCurrentLineContent() -> String? {
            guard let textView = textView else { 
                print("DEBUG: textView is nil")
                return nil 
            }
            let selectedRange = textView.selectedRange()
            let text = textView.string as NSString
            
            // Use NSString's lineRange method to get the full line range
            let lineRange = text.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            let lineContent = text.substring(with: lineRange)
            let trimmedContent = lineContent.trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("DEBUG: Cursor at range \(selectedRange), line range \(lineRange), line content: '\(trimmedContent)'")
            return trimmedContent.isEmpty ? nil : trimmedContent
        }
        
        func toggleComment() {
            guard let textView = textView, textView.isEditable, let undoManager = textView.undoManager else { return }

            isTogglingComment = true
            defer { isTogglingComment = false }

            let selectedRange = textView.selectedRange()
            let fullText = textView.string as NSString

            // Determine the line ranges to be commented or uncommented
            var lineRanges: [NSRange] = []
            if selectedRange.length > 0 {
                let lines = fullText.substring(with: selectedRange)
                var currentPos = selectedRange.location
                for _ in lines.components(separatedBy: .newlines) {
                    let lineRange = fullText.lineRange(for: NSRange(location: currentPos, length: 0))
                    lineRanges.append(lineRange)
                    currentPos = lineRange.upperBound
                    if currentPos >= selectedRange.upperBound { break }
                }
            } else {
                lineRanges.append(fullText.lineRange(for: selectedRange))
            }

            let commentPrefix = getCommentPrefix(for: parent.fileExtension)
            guard !commentPrefix.isEmpty else { return }
            let isXMLStyle = commentPrefix == "<!-- "

            // Determine if we are commenting or uncommenting
            let isUncommenting = lineRanges.allSatisfy { range in
                let line = fullText.substring(with: range)
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if isXMLStyle {
                    return trimmed.hasPrefix("<!--") && trimmed.hasSuffix("-->")
                }
                return trimmed.hasPrefix(commentPrefix.trimmingCharacters(in: .whitespaces))
            }

            undoManager.beginUndoGrouping()
            for range in lineRanges.reversed() { // Process from bottom to top to keep ranges valid
                let line = fullText.substring(with: range)
                let lineWithoutNewline = line.trimmingCharacters(in: .newlines)
                let leadingWhitespace = String(lineWithoutNewline.prefix(while: { $0 == " " || $0 == "\t" }))
                let insertionLocation = range.location + (leadingWhitespace as NSString).length

                if isXMLStyle {
                    if isUncommenting {
                        if let openingRange = line.range(of: "<!--"), let closingRange = line.range(of: "-->", options: .backwards) {
                            let openEnd = openingRange.upperBound
                            let removeOpeningSpace = openEnd < line.endIndex && line[openEnd] == " "
                            let openingRemoval = NSRange(location: range.location + openingRange.lowerBound.utf16Offset(in: line), length: removeOpeningSpace ? 5 : 4)
                            let beforeClose = closingRange.lowerBound > line.startIndex ? line.index(before: closingRange.lowerBound) : closingRange.lowerBound
                            let removeClosingSpace = beforeClose < closingRange.lowerBound && line[beforeClose] == " "
                            let closingRemoval = NSRange(location: range.location + (removeClosingSpace ? beforeClose : closingRange.lowerBound).utf16Offset(in: line), length: removeClosingSpace ? 4 : 3)
                            if textView.shouldChangeText(in: closingRemoval, replacementString: "") {
                                textView.replaceCharacters(in: closingRemoval, with: "")
                            }
                            if textView.shouldChangeText(in: openingRemoval, replacementString: "") {
                                textView.replaceCharacters(in: openingRemoval, with: "")
                            }
                        }
                    } else {
                        let lineContentLength = (lineWithoutNewline as NSString).length
                        let closingLocation = range.location + lineContentLength
                        if textView.shouldChangeText(in: NSRange(location: closingLocation, length: 0), replacementString: " -->") {
                            textView.replaceCharacters(in: NSRange(location: closingLocation, length: 0), with: " -->")
                        }
                        if textView.shouldChangeText(in: NSRange(location: insertionLocation, length: 0), replacementString: "<!-- ") {
                            textView.replaceCharacters(in: NSRange(location: insertionLocation, length: 0), with: "<!-- ")
                        }
                    }
                    continue
                }

                if isUncommenting {
                    let trimmedPrefix = commentPrefix.trimmingCharacters(in: .whitespaces)
                    let contentStart = line.index(line.startIndex, offsetBy: leadingWhitespace.count)
                    if line[contentStart...].hasPrefix(commentPrefix) {
                        let removalRange = NSRange(location: insertionLocation, length: (commentPrefix as NSString).length)
                        if textView.shouldChangeText(in: removalRange, replacementString: "") {
                            textView.replaceCharacters(in: removalRange, with: "")
                        }
                    } else if line[contentStart...].hasPrefix(trimmedPrefix) {
                        let removalRange = NSRange(location: insertionLocation, length: (trimmedPrefix as NSString).length)
                        if textView.shouldChangeText(in: removalRange, replacementString: "") {
                            textView.replaceCharacters(in: removalRange, with: "")
                        }
                    }
                } else {
                    if textView.shouldChangeText(in: NSRange(location: insertionLocation, length: 0), replacementString: commentPrefix) {
                        textView.replaceCharacters(in: NSRange(location: insertionLocation, length: 0), with: commentPrefix)
                    }
                }
            }
            undoManager.endUndoGrouping()

            // Manually trigger update
            self.parent.text = textView.string
            self.textChanged = true
        }
        
        private func updateHighlightingForRange(_ range: NSRange) {
            guard let textView = textView,
                  let textStorage = textView.textStorage else { return }
            
            // Validate and clamp the range to text storage bounds
            let textLength = textStorage.length
            guard textLength > 0 else { return }
            
            let safeRange = NSRange(
                location: max(0, min(range.location, textLength - 1)),
                length: min(range.length, textLength - max(0, min(range.location, textLength - 1)))
            )
            
            // Skip if the safe range is invalid
            guard safeRange.length > 0 && safeRange.location < textLength else { return }
            
            let theme = parent.colorScheme == .dark ? CodeEditorView.Theme.dark : CodeEditorView.Theme.light
            let selectedRange = textView.selectedRange()

            // Disable undo registration during highlighting to preserve undo stack
            textView.undoManager?.disableUndoRegistration()

            textStorage.beginEditing()

            // Reset attributes for the specific range only
            textStorage.setAttributes([
                .foregroundColor: theme.normalText,
                .font: NSFont.monospacedSystemFont(ofSize: 14 * parent.zoomLevel, weight: .regular)
            ], range: safeRange)

            // Get comment ranges within the specific range
            let commentRanges = parent.getCommentRanges(for: parent.fileExtension, in: textStorage.string, fullRange: safeRange)
            
            // Apply highlighting patterns only to the specific range
            let patterns = parent.getHighlightPatterns(for: parent.fileExtension, theme: theme)
            
            for (pattern, color) in patterns {
                let addsLinkAttribute = pattern.contains("https?://")
                if parent.isCommentPattern(pattern) {
                    parent.highlightPattern(textStorage, pattern, color: color, range: safeRange, addsLinkAttribute: addsLinkAttribute)
                } else {
                    // Apply other patterns excluding comment ranges
                    parent.highlightPattern(textStorage, pattern, color: color, range: safeRange, excludeRanges: commentRanges, addsLinkAttribute: addsLinkAttribute)
                }
            }

            // Apply search highlighting if needed
            if !parent.search.isEmpty {
                let pattern = NSRegularExpression.escapedPattern(for: parent.search)
                parent.highlightPattern(textStorage, pattern, color: theme.searchHighlight, isBackground: true, range: safeRange)
            }

            textStorage.endEditing()
            
            // Re-enable undo registration after highlighting
            textView.undoManager?.enableUndoRegistration()
            
            // Restore selection
            textView.setSelectedRange(selectedRange)
        }


        
        private func getCommentPrefix(for fileExtension: String) -> String {
            let ext = fileExtension.lowercased()
            switch ext {
            case "json", "jsonl", "text", "log":
                return ""
            case "xml", "html":
                return "<!-- "
            case "js", "ts", "json5", "c", "cpp", "java", "swift", "css", "scss", "less", "php", "go", "rust", "kotlin", "scala", "groovy", "terraform", "hcl", "protobuf":
                return "// "
            case "sql", "lua":
                return "-- "
            default:
                return "# "
            }
        }
        


        
        private func commentLine(_ line: String, commentPrefix: String) -> String {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return line
            }
            
            // Find leading whitespace
            let leadingWhitespace = String(line.prefix(while: { $0.isWhitespace && $0 != "\n" && $0 != "\r" }))
            let content = String(line.dropFirst(leadingWhitespace.count))
            
            return leadingWhitespace + commentPrefix + content.trimmingCharacters(in: .newlines)
        }
        
        private func uncommentLine(_ line: String, commentPrefix: String) -> String {
            let trimmedPrefix = commentPrefix.trimmingCharacters(in: .whitespaces)
            
            // Find the comment prefix in the line
            if let range = line.range(of: trimmedPrefix) {
                let beforeComment = String(line[..<range.lowerBound])
                var afterComment = String(line[range.upperBound...])
                
                // Remove one space after comment prefix if it exists
                if afterComment.hasPrefix(" ") {
                    afterComment = String(afterComment.dropFirst())
                }
                
                return beforeComment + afterComment
            }
            
            return line
        }
    }

    class Ref { // Added comment to force recompile
        weak var textView: NSTextView?
        weak var coordinator: Coordinator?
        var matchCount: Binding<Int>
        var currentMatchIndex: Binding<Int>
        
        init(textView: NSTextView, coordinator: Coordinator, matchCount: Binding<Int>, currentMatchIndex: Binding<Int>) {
            self.textView = textView
            self.coordinator = coordinator
            self.matchCount = matchCount
            self.currentMatchIndex = currentMatchIndex
        }
        
        func findNext(_ text: String) {
            guard let tv = textView, !text.isEmpty else { return }
            let ns = tv.string as NSString
            let fullRange = NSRange(location: 0, length: ns.length)
            
            let pattern = NSRegularExpression.escapedPattern(for: text)
            let matches = (try? NSRegularExpression(pattern: pattern, options: .caseInsensitive))?.matches(in: ns as String, options: [], range: fullRange) ?? []
            self.matchCount.wrappedValue = matches.count
            
            if matches.isEmpty { 
                self.currentMatchIndex.wrappedValue = 0
                return 
            }
            
            let sel = tv.selectedRange()
            var nextMatchIndex = -1
            
            for (index, match) in matches.enumerated() {
                if match.range.location >= sel.upperBound {
                    nextMatchIndex = index
                    break
                }
            }
            
            if nextMatchIndex == -1 { // Wrap around to the beginning
                nextMatchIndex = 0
            }
            
            let r = matches[nextMatchIndex].range
            tv.scrollRangeToVisible(r)
            tv.setSelectedRange(r)
            self.currentMatchIndex.wrappedValue = nextMatchIndex + 1
        }
        
        func findPrevious(_ text: String) {
            guard let tv = textView, !text.isEmpty else { return }
            let ns = tv.string as NSString
            let fullRange = NSRange(location: 0, length: ns.length)
            
            let pattern = NSRegularExpression.escapedPattern(for: text)
            let matches = (try? NSRegularExpression(pattern: pattern, options: .caseInsensitive))?.matches(in: ns as String, options: [], range: fullRange) ?? []
            self.matchCount.wrappedValue = matches.count
            
            if matches.isEmpty { 
                self.currentMatchIndex.wrappedValue = 0
                return 
            }
            
            let sel = tv.selectedRange()
            var prevMatchIndex = -1
            
            for (index, match) in matches.enumerated().reversed() {
                if match.range.location < sel.location {
                    prevMatchIndex = index
                    break
                }
            }
            
            if prevMatchIndex == -1 { // Wrap around to the end
                prevMatchIndex = matches.count - 1
            }
            
            let r = matches[prevMatchIndex].range
            tv.scrollRangeToVisible(r)
            tv.setSelectedRange(r)
            self.currentMatchIndex.wrappedValue = prevMatchIndex + 1
        }
        
        func resetCounts() {
            matchCount.wrappedValue = 0
            currentMatchIndex.wrappedValue = 0
        }
        
        func clearSelection() {
            guard let tv = textView else { return }
            tv.setSelectedRange(NSRange(location: 0, length: 0))
            tv.scrollRangeToVisible(NSRange(location: 0, length: 0))
        }

        func resignFirstResponder() {
            guard let tv = textView else { return }
            guard let window = tv.window else { return }
            if window.firstResponder === tv {
                window.makeFirstResponder(nil)
            }
        }
    }
}

// MARK: - NSString Extensions for Line Handling
extension NSString {
    func lineNumber(at location: Int) -> Int {
        // Treat a caret at the *start* of a line as being on that line.
        // Using (location + 1) prevents the "two 1s" issue when the first line is empty.
        let safeLocation = min(max(0, location) + 1, self.length)
        var lineNumber = 0
        
        self.enumerateSubstrings(in: NSRange(location: 0, length: safeLocation), 
                                options: [.byLines, .substringNotRequired]) { _, range, _, _ in
            if range.location + range.length <= safeLocation {
                lineNumber += 1
            }
        }
        
        return max(0, lineNumber - 1)
    }
    
    func lineRange(for lineNumber: Int) -> NSRange {
        var currentLine = 0
        var result = NSRange(location: 0, length: 0)
        
        self.enumerateSubstrings(in: NSRange(location: 0, length: self.length), 
                                options: [.byLines]) { _, range, _, stop in
            if currentLine == lineNumber {
                result = range
                stop.pointee = true
            }
            currentLine += 1
        }
        
        return result
    }
}
