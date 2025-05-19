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
    var onSave: (() -> Void)? = nil
    var showSearchBar: (() -> Void)? = nil

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView
        var textView: NSTextView?
        var ignoreTextChange = false
        var lastExternalText: String = ""
        var highlightTimer: Timer?
        var lastHighlightedRange: NSRange?
        var isTyping = false

        init(_ parent: CodeEditorView) { 
            self.parent = parent
            super.init()
        }
        
        deinit {
            highlightTimer?.invalidate()
        }
        
        func textDidBeginEditing(_ notification: Notification) {
            isTyping = true
        }
        
        func textDidEndEditing(_ notification: Notification) {
            isTyping = false
            // Re-highlight the entire visible area when editing ends
            if let tv = textView {
                // Calculate visible range
                let visibleRect = tv.visibleRect
                let layoutManager = tv.layoutManager!
                let container = tv.textContainer!
                let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
                let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
                
                // 应用高亮到可见区域
                parent.applyHighlightToRange(tv, range: characterRange)
            }
        }

        func scheduleHighlight() {
            // Cancel previous timer
            highlightTimer?.invalidate()
            
            guard let tv = textView else { return }
            
            // Save current state
            let selectedRange = tv.selectedRange()
            let currentLine = getCurrentLine(for: selectedRange, in: tv)
            
            // Skip if current line is same as last highlighted line and user is typing
            if isTyping,
               let lastRange = lastHighlightedRange,
               currentLine.intersection(lastRange) != nil {
                return
            }
            
            // Update last highlighted range
            lastHighlightedRange = currentLine
            
         
            highlightTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
                guard let self = self, let tv = self.textView else { return }
                
                // Store scroll position
                let visibleRect = tv.visibleRect
                
                // Apply highlighting
                self.parent.applyHighlightToRangeWithoutReset(tv, range: currentLine)
                
                // Restore cursor position and scroll position
                tv.selectedRange = selectedRange
                tv.scrollToVisible(visibleRect)
            }
        }
        
        private func getCurrentLine(for range: NSRange, in textView: NSTextView) -> NSRange {
            let text = textView.string as NSString
            var lineStart = 0, lineEnd = 0, contentsEnd = 0
            text.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: range)
            return NSRange(location: lineStart, length: lineEnd - lineStart)
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            if !ignoreTextChange {
                parent.text = tv.string
                scheduleHighlight()
            }
        }
    }

    class Ref {
        weak var textView: NSTextView?
        weak var coordinator: Coordinator?
        init(textView: NSTextView, coordinator: Coordinator) {
            self.textView = textView
            self.coordinator = coordinator
        }
        func findNext(_ text: String) {
            guard let tv = textView, !text.isEmpty else { return }
            let ns = tv.string as NSString
            let sel = tv.selectedRange()
            let searchRange = NSRange(location: sel.upperBound, length: ns.length - sel.upperBound)
            let r = ns.range(of: text, options: .caseInsensitive, range: searchRange)
            if r.location != NSNotFound {
                tv.scrollRangeToVisible(r)
                tv.setSelectedRange(r)
            } else {
                let r2 = ns.range(of: text, options: .caseInsensitive)
                if r2.location != NSNotFound {
                    tv.scrollRangeToVisible(r2)
                    tv.setSelectedRange(r2)
                }
            }
        }
        func findPrevious(_ text: String) {
            guard let tv = textView, !text.isEmpty else { return }
            let ns = tv.string as NSString
            let sel = tv.selectedRange()
            let searchRange = NSRange(location: 0, length: sel.location)
            let r = ns.range(of: text, options: [.backwards, .caseInsensitive], range: searchRange)
            if r.location != NSNotFound {
                tv.scrollRangeToVisible(r)
                tv.setSelectedRange(r)
            } else {
                let r2 = ns.range(of: text, options: [.backwards, .caseInsensitive])
                if r2.location != NSNotFound {
                    tv.scrollRangeToVisible(r2)
                    tv.setSelectedRange(r2)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFindBar = false
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.delegate = context.coordinator
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.autoresizingMask = [.width, .height]
        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.lastExternalText = text
        DispatchQueue.main.async {
            ref = Ref(textView: textView, coordinator: context.coordinator)
        }
        textView.string = text
        // Apply highlighting immediately on initialization, no debounce needed
        applyHighlight(textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        // Only sync when external content changes, without affecting cursor
        if context.coordinator.lastExternalText != text {
            let selectedRange = textView.selectedRange()
            context.coordinator.ignoreTextChange = true
            textView.string = text
            context.coordinator.ignoreTextChange = false
            textView.setSelectedRange(selectedRange)
            context.coordinator.lastExternalText = text
            // Apply highlighting immediately when external content changes, no debounce needed
            applyHighlight(textView)
        }
    }

    func applyHighlight(_ textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }
        
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        // Return if text is empty
        guard fullRange.length > 0 else { return }
        
        // Save current selection range and visible area
        let selectedRange = textView.selectedRange()
        let visibleRect = textView.visibleRect
        
        applyHighlightToRange(textView, range: fullRange)
        
        // Restore selection range and visible area
        textView.selectedRange = selectedRange
        textView.scrollToVisible(visibleRect)
        
        // Automatically choose highlight style based on file extension
        let ext = fileExtension.lowercased()
        switch ext {
        case "json":
            highlightPattern(textStorage, "\"[^\"]*\"\\s*:", color: .systemBlue)
            highlightPattern(textStorage, "\"[^\"]*\"", color: .systemRed)
            highlightPattern(textStorage, "\\b(true|false|null)\\b", color: .systemPurple)
            highlightPattern(textStorage, "\\d+", color: .systemOrange)
        case "yml", "yaml", "toml", "ini":
            highlightPattern(textStorage, "^[ \\t\\-]*[\\w\\-\\.]+:", color: .systemBlue, options: [.anchorsMatchLines])
            highlightPattern(textStorage, "#.*", color: .systemGreen)
            highlightPattern(textStorage, "\"[^\"]*\"", color: .systemRed)
        case "sh", "zsh", "bash":
            highlightPattern(textStorage, "#.*", color: .systemGreen)
            highlightPattern(textStorage, "\\b(if|then|else|fi|for|in|do|done|case|esac|function|export|return|local|while|break|continue)\\b", color: .systemPurple)
            highlightPattern(textStorage, "\"[^\"]*\"", color: .systemRed)
        case "py":
            highlightPattern(textStorage, "#.*", color: .systemGreen)
            highlightPattern(textStorage, "\\b(def|class|import|from|as|if|elif|else|for|while|try|except|finally|with|return|yield|break|continue|pass|in|is|not|and|or|print|True|False|None)\\b", color: .systemPurple)
            highlightPattern(textStorage, "\"[^\"]*\"|'[^']*'", color: .systemRed)
        case "js", "ts", "jsx", "tsx":
            highlightPattern(textStorage, "//.*", color: .systemGreen)
            highlightPattern(textStorage, "/\\*.*?\\*/", color: .systemGreen, options: [.dotMatchesLineSeparators])
            highlightPattern(textStorage, "\\b(function|var|let|const|if|else|for|while|return|import|from|export|class|extends|new|this|true|false|null|undefined)\\b", color: .systemPurple)
            highlightPattern(textStorage, "\"[^\"]*\"|'[^']*'", color: .systemRed)
        default:
            break // plain text
        }
        
       
        if !search.isEmpty {
            let pattern = NSRegularExpression.escapedPattern(for: search)
            highlightPattern(textStorage, pattern, color: .yellow, background: .systemYellow)
        }
        
        textStorage.endEditing()
    }

    func applyHighlightToRange(_ textView: NSTextView, range: NSRange) {
        guard let textStorage = textView.textStorage else { return }
        
        textStorage.removeAttribute(.foregroundColor, range: range)
        textStorage.removeAttribute(.backgroundColor, range: range)
        textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)
        
        let ext = fileExtension.lowercased()
        switch ext {
        case "json","json5":
            highlightPatternInRange(textStorage, "\"[^\"]*\"\\s*:", color: .systemBlue, range: range)
            highlightPatternInRange(textStorage, "\"[^\"]*\"", color: .systemRed, range: range)
            highlightPatternInRange(textStorage, "\\b(true|false|null)\\b", color: .systemPurple, range: range)
            highlightPatternInRange(textStorage, "\\d+", color: .systemOrange, range: range)
        case "yml", "yaml", "toml", "ini":
            highlightPatternInRange(textStorage, "^[ \\t\\-]*[\\w\\-\\.]+:", color: .systemBlue, options: [.anchorsMatchLines], range: range)
            highlightPatternInRange(textStorage, "#.*", color: .systemGreen, range: range)
            highlightPatternInRange(textStorage, "\"[^\"]*\"", color: .systemRed, range: range)
        case "sh", "zsh", "bash":
            highlightPatternInRange(textStorage, "#.*", color: .systemGreen, range: range)
            highlightPatternInRange(textStorage, "\\b(if|then|else|fi|for|in|do|done|case|esac|function|export|return|local|while|break|continue)\\b", color: .systemPurple, range: range)
            highlightPatternInRange(textStorage, "\"[^\"]*\"", color: .systemRed, range: range)
        case "py":
            highlightPatternInRange(textStorage, "#.*", color: .systemGreen, range: range)
            highlightPatternInRange(textStorage, "\\b(def|class|import|from|as|if|elif|else|for|while|try|except|finally|with|return|yield|break|continue|pass|in|is|not|and|or|print|True|False|None)\\b", color: .systemPurple, range: range)
            highlightPatternInRange(textStorage, "\"[^\"]*\"|'[^']*'", color: .systemRed, range: range)
        case "js", "ts", "jsx", "tsx":
            highlightPatternInRange(textStorage, "//.*", color: .systemGreen, range: range)
            highlightPatternInRange(textStorage, "/\\*.*?\\*/", color: .systemGreen, options: [.dotMatchesLineSeparators], range: range)
            highlightPatternInRange(textStorage, "\\b(function|var|let|const|if|else|for|while|return|import|from|export|class|extends|new|this|true|false|null|undefined)\\b", color: .systemPurple, range: range)
            highlightPatternInRange(textStorage, "\"[^\"]*\"|'[^']*'", color: .systemRed, range: range)
        default:
            break
        }
        
        if !search.isEmpty {
            let pattern = NSRegularExpression.escapedPattern(for: search)
            highlightPatternInRange(textStorage, pattern, color: .yellow, background: .systemYellow, range: range)
        }
    }
    
    func applyHighlightToRangeWithoutReset(_ textView: NSTextView, range: NSRange) {
        guard let textStorage = textView.textStorage else { return }
        
        // Begin batch editing
        textStorage.beginEditing()
        
        // Apply highlighting without resetting existing attributes
        let ext = fileExtension.lowercased()
        switch ext {
        case "json":
            highlightPatternInRange(textStorage, "\"[^\"]*\"\\s*:", color: .systemBlue, range: range, reset: false)
            highlightPatternInRange(textStorage, "\"[^\"]*\"", color: .systemRed, range: range, reset: false)
            highlightPatternInRange(textStorage, "\\b(true|false|null)\\b", color: .systemPurple, range: range, reset: false)
            highlightPatternInRange(textStorage, "\\d+", color: .systemOrange, range: range, reset: false)
        case "yml", "yaml", "toml", "ini":
            highlightPatternInRange(textStorage, "^[ \\t\\-]*[\\w\\-\\.]+:", color: .systemBlue, options: [.anchorsMatchLines], range: range, reset: false)
            highlightPatternInRange(textStorage, "#.*", color: .systemGreen, range: range, reset: false)
            highlightPatternInRange(textStorage, "\"[^\"]*\"", color: .systemRed, range: range, reset: false)
        case "sh", "zsh", "bash":
            highlightPatternInRange(textStorage, "#.*", color: .systemGreen, range: range, reset: false)
            highlightPatternInRange(textStorage, "\\b(if|then|else|fi|for|in|do|done|case|esac|function|export|return|local|while|break|continue)\\b", color: .systemPurple, range: range, reset: false)
            highlightPatternInRange(textStorage, "\"[^\"]*\"", color: .systemRed, range: range, reset: false)
        case "py":
            highlightPatternInRange(textStorage, "#.*", color: .systemGreen, range: range, reset: false)
            highlightPatternInRange(textStorage, "\\b(def|class|import|from|as|if|elif|else|for|while|try|except|finally|with|return|yield|break|continue|pass|in|is|not|and|or|print|True|False|None)\\b", color: .systemPurple, range: range, reset: false)
            highlightPatternInRange(textStorage, "\"[^\"]*\"|'[^']*'", color: .systemRed, range: range, reset: false)
        case "js", "ts", "jsx", "tsx":
            highlightPatternInRange(textStorage, "//.*", color: .systemGreen, range: range, reset: false)
            highlightPatternInRange(textStorage, "/\\*.*?\\*/", color: .systemGreen, options: [.dotMatchesLineSeparators], range: range, reset: false)
            highlightPatternInRange(textStorage, "\\b(function|var|let|const|if|else|for|while|return|import|from|export|class|extends|new|this|true|false|null|undefined)\\b", color: .systemPurple, range: range, reset: false)
            highlightPatternInRange(textStorage, "\"[^\"]*\"|'[^']*'", color: .systemRed, range: range, reset: false)
        default:
            break
        }
        
        if !search.isEmpty {
            let pattern = NSRegularExpression.escapedPattern(for: search)
            highlightPatternInRange(textStorage, pattern, color: .yellow, background: .systemYellow, range: range, reset: false)
        }
        
        textStorage.endEditing()
    }
    
    func highlightPatternInRange(_ textStorage: NSTextStorage, _ pattern: String, color: NSColor, background: NSColor? = nil, options: NSRegularExpression.Options = [], range: NSRange, reset: Bool = true) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        
        // If reset is needed, clear existing attributes first
        if reset {
            textStorage.removeAttribute(.foregroundColor, range: range)
            textStorage.removeAttribute(.backgroundColor, range: range)
            textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)
        }
        
        regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
            guard let r = match?.range,
                  r.location + r.length <= textStorage.length,
                  r.intersection(range) != nil else { return }
            
            // Check if correct highlighting already exists
            var needsUpdate = true
            if !reset {
                let attrs = textStorage.attributes(at: r.location, effectiveRange: nil)
                if attrs[.foregroundColor] as? NSColor == color {
                    if let bg = background {
                        needsUpdate = attrs[.backgroundColor] as? NSColor != bg
                    } else {
                        needsUpdate = attrs[.backgroundColor] != nil
                    }
                }
            }
            
            // Only update attributes when needed
            if needsUpdate {
                textStorage.addAttribute(.foregroundColor, value: color, range: r)
                if let bg = background {
                    textStorage.addAttribute(.backgroundColor, value: bg, range: r)
                } else {
                    textStorage.removeAttribute(.backgroundColor, range: r)
                }
            }
        }
    }
    
    func highlightPattern(_ textStorage: NSTextStorage, _ pattern: String, color: NSColor, background: NSColor? = nil, options: NSRegularExpression.Options = []) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let str = textStorage.string as NSString
        let range = NSRange(location: 0, length: str.length)
        
        regex.enumerateMatches(in: str as String, options: [], range: range) { match, _, _ in
            guard let r = match?.range, r.location + r.length <= str.length else { return }
            textStorage.addAttribute(.foregroundColor, value: color, range: r)
            if let bg = background {
                textStorage.addAttribute(.backgroundColor, value: bg, range: r)
            }
        }
    }
}
