//  CodeEditorView.swift
//  Configs
//  Editor component with syntax highlighting, search, copy/paste support
//
//  Created by cxy on 2025/5/19.


import SwiftUI
import AppKit

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

    private struct Theme {
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
        
        let textView = NSTextView()
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
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange)
            needsHighlight = true
            // Ensure the selected range is visible after external text update
            textView.scrollRangeToVisible(selectedRange)
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

        textStorage.beginEditing()
        
        textStorage.setAttributes([
            .foregroundColor: theme.normalText,
            .font: NSFont.monospacedSystemFont(ofSize: 14 * zoomLevel, weight: .regular)
        ], range: fullRange)
        
        textView.backgroundColor = theme.background
        
        let patterns = getHighlightPatterns(for: fileExtension, theme: theme)
        for (pattern, color) in patterns {
            highlightPattern(textStorage, pattern, color: color, range: fullRange)
        }
        
        if !search.isEmpty {
            let pattern = NSRegularExpression.escapedPattern(for: search)
            highlightPattern(textStorage, pattern, color: theme.searchHighlight, isBackground: true, range: fullRange)
        }
        
        textStorage.endEditing()
        
        textView.setSelectedRange(selectedRange)
    }

    private func getHighlightPatterns(for fileExtension: String, theme: Theme) -> [(String, NSColor)] {
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

    private func highlightPattern(_ textStorage: NSTextStorage, _ pattern: String, color: NSColor, isBackground: Bool = false, range: NSRange) {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
                guard let match = match else { return }
                
                let highlightRange = (match.numberOfRanges > 1) ? match.range(at: 1) : match.range
                
                let attribute: [NSAttributedString.Key: Any] = isBackground ? [.backgroundColor: color] : [.foregroundColor: color]
                textStorage.addAttributes(attribute, range: highlightRange)
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
    }
}
