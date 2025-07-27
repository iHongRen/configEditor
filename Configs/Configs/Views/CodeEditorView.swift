//  CodeEditorView.swift
//  Configs
//  Editor component with syntax highlighting, search, copy/paste support
//
//  Created by cxy on 2025/5/19.


import SwiftUI
import AppKit

// MARK: - Custom NSTextView for handling keyboard shortcuts
class CustomTextView: NSTextView {
    weak var coordinator: CodeEditorView.Coordinator?
    
    override func keyDown(with event: NSEvent) {
        // Handle Cmd+/ for toggle comment
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "/" {
            coordinator?.toggleComment()
            return
        }
        
        super.keyDown(with: event)
    }
}

struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    var fileExtension: String
    @Binding var search: String
    @Binding var ref: Ref?
    var isFocused: Bool
    var showSearchBar: (() -> Void)? = nil
    var onSave: (() -> Void)? = nil
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
            background: .textBackgroundColor
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
            background: NSColor(red: 0.01, green: 0.16, blue: 0.21, alpha: 1.0)  // Dark Slate
        )
    }
    
    private var currentTheme: Theme {
        colorScheme == .dark ? Theme.dark : Theme.light
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        
        let textView = CustomTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.autoresizingMask = [.width, .height]
        
        // Disable smart quotes and other automatic substitutions for a better code editing experience
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        scrollView.documentView = textView
        
        context.coordinator.textView = textView
        textView.coordinator = context.coordinator
        textView.delegate = context.coordinator
        
        textView.string = text
        textView.font = .monospacedSystemFont(ofSize: 14 * zoomLevel, weight: .regular)
        applyHighlighting(context: context)
        
        DispatchQueue.main.async {
            ref = Ref(textView: textView, coordinator: context.coordinator, matchCount: $matchCount, currentMatchIndex: $currentMatchIndex)
        }
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
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
        
        if context.coordinator.textChanged {
            needsHighlight = true
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

        textStorage.beginEditing()

        textStorage.setAttributes([
            .foregroundColor: theme.normalText,
            .font: NSFont.monospacedSystemFont(ofSize: 14 * zoomLevel, weight: .regular)
        ], range: fullRange)

        textView.backgroundColor = theme.background

        // Get comment ranges first to exclude them from other highlighting
        let commentRanges = getCommentRanges(for: fileExtension, in: textStorage.string, fullRange: fullRange)
        
        let patterns = getHighlightPatterns(for: fileExtension, theme: theme)
        for (pattern, color) in patterns {
            if pattern.contains("#.*") || pattern.contains(";.*") {
                // Apply comment highlighting without exclusion
                highlightPattern(textStorage, pattern, color: color, range: fullRange)
            } else {
                // Apply other patterns excluding comment ranges
                highlightPattern(textStorage, pattern, color: color, range: fullRange, excludeRanges: commentRanges)
            }
        }

        if !search.isEmpty {
            let pattern = NSRegularExpression.escapedPattern(for: search)
            highlightPattern(textStorage, pattern, color: theme.searchHighlight, isBackground: true, range: fullRange)
        }

        textStorage.endEditing()

        let newHeight = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 0
        
        if currentHeight == newHeight {
            textView.setSelectedRange(selectedRange)
            textView.scrollRangeToVisible(selectedRange)
        } else {
            textView.scrollToVisible(visibleRect)
        }
    }

    internal func getHighlightPatterns(for fileExtension: String, theme: Theme) -> [(String, NSColor)] {
        let ext = fileExtension.lowercased()
        var patterns: [(String, NSColor)] = []
        
        switch ext {
        case "json":
            patterns = [
                ("(\"([^\"]*)\")\\s*:", theme.property),
                ("(\"([^\"]*)\")", theme.string),
                ("\\b(true|false|null)\\b", theme.keyword),
                ("\\b-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b", theme.number)
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
        case "ini", "git", "conf":
             patterns = [
                ("(^#.*)", theme.comment),
                ("(^;.*)", theme.comment),
                ("(\\[[^\\]]+\\])", theme.keyword),
                ("(([^=]+)=(.+))", theme.property)
            ]
        default:
            break
        }
        
        patterns.append(("(https?://[^\\s]+)", theme.link))
        
        return patterns
    }

    internal func getCommentRanges(for fileExtension: String, in text: String, fullRange: NSRange) -> [NSRange] {
        let ext = fileExtension.lowercased()
        var commentPatterns: [String] = []
        
        switch ext {
        case "sh", "zsh", "bash", ".zshrc", ".bashrc", ".profile":
            commentPatterns = ["#.*"]
        case "ini", "git", "conf":
            commentPatterns = ["^#.*", "^;.*"]
        case "yml", "yaml":
            commentPatterns = ["#.*"]
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
    
    internal func highlightPattern(_ textStorage: NSTextStorage, _ pattern: String, color: NSColor, isBackground: Bool = false, range: NSRange, excludeRanges: [NSRange] = []) {
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
                    let attribute: [NSAttributedString.Key: Any] = isBackground ? [.backgroundColor: color] : [.foregroundColor: color]
                    textStorage.addAttributes(attribute, range: highlightRange)
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

        init(_ parent: CodeEditorView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
            self.textChanged = true
            // Ensure the cursor is visible after text changes
            textView.scrollRangeToVisible(textView.selectedRange())
        }
        
        func toggleComment() {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange()
            let fullText = textView.string
            let nsText = fullText as NSString
            
            // Get comment prefix for current file type
            let commentPrefix = getCommentPrefix(for: parent.fileExtension)
            
            // Find all lines that intersect with the selection
            var linesToProcess: [(lineStart: Int, lineEnd: Int)] = []

            let getLineContentRange = { (range: NSRange) -> (lineStart: Int, lineEnd: Int)? in
                let lineRange = nsText.lineRange(for: range)
                guard lineRange.length > 0 else { return nil }
                let lineStart = lineRange.location
                let lineText = nsText.substring(with: lineRange)
                var contentLength = lineRange.length
                if lineText.hasSuffix("\r\n") {
                    contentLength -= 2
                } else if lineText.hasSuffix("\n") {
                    contentLength -= 1
                }
                let lineEnd = lineStart + contentLength
                return (lineStart: lineStart, lineEnd: lineEnd)
            }

            if selectedRange.length == 0 {
                if let info = getLineContentRange(selectedRange) {
                    linesToProcess.append(info)
                }
            } else {
                var currentPos = selectedRange.location
                let endPos = selectedRange.upperBound
                while currentPos < endPos {
                    let lineRange = nsText.lineRange(for: NSRange(location: currentPos, length: 0))
                    if let info = getLineContentRange(NSRange(location: currentPos, length: 0)) {
                        if !linesToProcess.contains(where: { $0.lineStart == info.lineStart }) {
                            linesToProcess.append(info)
                        }
                    }
                    currentPos = lineRange.upperBound
                    if lineRange.length == 0 { break }
                }
            }
            
            // Process each line individually by inserting/removing comment at line start
            var offsetAdjustment = 0
            
            for lineInfo in linesToProcess {
                let adjustedStart = lineInfo.lineStart + offsetAdjustment
                let adjustedEnd = lineInfo.lineEnd + offsetAdjustment
                
                // Get the line content (excluding newline)
                let lineRange = NSRange(location: adjustedStart, length: adjustedEnd - adjustedStart)
                let lineText = nsText.substring(with: lineRange)
                
                // Skip empty lines
                if lineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                
                // Find the position after leading whitespace
                let leadingWhitespace = String(lineText.prefix(while: { $0.isWhitespace && $0 != "\n" && $0 != "\r" }))
                let insertPosition = adjustedStart + leadingWhitespace.count
                
                // Check if line is already commented
                let contentAfterWhitespace = String(lineText.dropFirst(leadingWhitespace.count))
                let isCommented = contentAfterWhitespace.hasPrefix(commentPrefix.trimmingCharacters(in: .whitespaces))
                
                if isCommented {
                    // Remove comment - find and remove the comment prefix
                    let prefixToRemove = commentPrefix.trimmingCharacters(in: .whitespaces)
                    if contentAfterWhitespace.range(of: prefixToRemove) != nil {
                        let removeStart = insertPosition
                        var removeLength = prefixToRemove.count
                        
                        // Also remove the space after # if it exists
                        let afterPrefix = String(contentAfterWhitespace.dropFirst(prefixToRemove.count))
                        if afterPrefix.hasPrefix(" ") {
                            removeLength += 1
                        }
                        
                        let removeRange = NSRange(location: removeStart, length: removeLength)
                        textView.replaceCharacters(in: removeRange, with: "")
                        offsetAdjustment -= removeLength
                    }
                } else {
                    // Add comment - insert comment prefix at the position after whitespace
                    textView.replaceCharacters(in: NSRange(location: insertPosition, length: 0), with: commentPrefix)
                    offsetAdjustment += commentPrefix.count
                }
            }
            
            // Update parent text immediately
            parent.text = textView.string
            
            // Set the textChanged flag to trigger SwiftUI update
            self.textChanged = true
            
            // Update highlighting for all processed lines
            if let firstLine = linesToProcess.first, let lastLine = linesToProcess.last {
                let highlightStart = firstLine.lineStart + (offsetAdjustment < 0 ? offsetAdjustment : 0)
                let highlightEnd = lastLine.lineEnd + offsetAdjustment
                let highlightRange = NSRange(location: highlightStart, length: max(0, highlightEnd - highlightStart))
                updateHighlightingForRange(highlightRange)
            }
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
                if pattern.contains("#.*") || pattern.contains(";.*") {
                    // Apply comment highlighting without exclusion
                    parent.highlightPattern(textStorage, pattern, color: color, range: safeRange)
                } else {
                    // Apply other patterns excluding comment ranges
                    parent.highlightPattern(textStorage, pattern, color: color, range: safeRange, excludeRanges: commentRanges)
                }
            }

            // Apply search highlighting if needed
            if !parent.search.isEmpty {
                let pattern = NSRegularExpression.escapedPattern(for: parent.search)
                parent.highlightPattern(textStorage, pattern, color: theme.searchHighlight, isBackground: true, range: safeRange)
            }

            textStorage.endEditing()
            
            // Restore selection
            textView.setSelectedRange(selectedRange)
        }


        
        private func getCommentPrefix(for fileExtension: String) -> String {
            let ext = fileExtension.lowercased()
            switch ext {
            case "sh", "zsh", "bash", ".zshrc", ".bashrc", ".profile", "yml", "yaml", "py":
                return "# "
            case "ini", "git", "conf":
                return "# "
            case "js", "ts", "c", "cpp", "java":
                return "// "
            case "swift":
                return "// "
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
            
            let matches = (try? NSRegularExpression(pattern: text, options: .caseInsensitive))?.matches(in: ns as String, options: [], range: fullRange) ?? []
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
            
            let matches = (try? NSRegularExpression(pattern: text, options: .caseInsensitive))?.matches(in: ns as String, options: [], range: fullRange) ?? []
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
    }
}

// MARK: - NSString Extensions for Line Handling
extension NSString {
    func lineNumber(at location: Int) -> Int {
        let safeLocation = min(location, self.length)
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
