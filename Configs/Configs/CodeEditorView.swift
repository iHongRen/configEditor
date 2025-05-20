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
    
    // 添加 textView 属性
    private var textView: NSTextView? {
        ref?.textView
    }

    // 自定义 NSTextView，拦截 Cmd+F
    class EditorTextView: NSTextView {
        var codeEditorParent: CodeEditorView?
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView
        var textView: NSTextView?
        var ignoreTextChange = false
        var lastExternalText: String = ""
        var highlightTimer: Timer?
        var lastHighlightedRange: NSRange?
        var isTyping = false
        var lastSearch: String = ""

        init(_ parent: CodeEditorView) { 
            self.parent = parent
            super.init()
        }
        
        deinit {
            highlightTimer?.invalidate()
            NotificationCenter.default.removeObserver(self)
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
        let textView = EditorTextView()
        textView.codeEditorParent = self
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
        applyHighlight()
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        var needHighlight = false
        
        // 内容变化
        if context.coordinator.lastExternalText != text {
            let selectedRange = textView.selectedRange()
            context.coordinator.ignoreTextChange = true
            textView.string = text
            context.coordinator.ignoreTextChange = false
            textView.setSelectedRange(selectedRange)
            context.coordinator.lastExternalText = text
            needHighlight = true
        }
        
        // search 变化
        if context.coordinator.lastSearch != search {
            context.coordinator.lastSearch = search
            needHighlight = true
        }
        
        // 焦点变化
        if !isFocused {
            needHighlight = true
        }
        
        if needHighlight {
            // Save current selection and visible area
            let selectedRange = textView.selectedRange()
            let visibleRect = textView.visibleRect
            
            // Apply highlighting immediately
            applyHighlight()
            
            // Restore selection and visible area
            textView.setSelectedRange(selectedRange)
            textView.scrollToVisible(visibleRect)
            
            // Force layout update
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        }
    }

    private func applyHighlight() {
        guard let textView = textView,
              let textStorage = textView.textStorage else { return }
        
        // 保存当前选择范围和可见区域
        let selectedRange = textView.selectedRange()
        let visibleRect = textView.visibleRect
        let totalLength = textStorage.length
        let largeFileThreshold = 100_000 // 100KB
        
        // 只高亮可见区域（大文件优化）
        if totalLength > largeFileThreshold {
            let layoutManager = textView.layoutManager!
            let container = textView.textContainer!
            let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
            let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            applyHighlightToRange(textView, range: characterRange)
            // 异步延迟全量高亮，避免阻塞UI
            DispatchQueue.global(qos: .userInitiated).async {
                self.applyHighlightFullAsync()
            }
        } else {
            // 小文件直接全量高亮
            // 重置所有属性
            textStorage.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: textStorage.length))
            
            // 根据文件扩展名应用不同的语法高亮
            switch fileExtension {
            case "json":
                if let jsonData = textStorage.string.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) {
                    highlightJSON(json: json, in: textStorage)
                }
            case "yml", "yaml":
                // YAML 语法高亮
                let pattern = try? NSRegularExpression(pattern: "^(\\s*)([^#:]+)(:)(.*)$", options: [.anchorsMatchLines])
                pattern?.enumerateMatches(in: textStorage.string, range: NSRange(location: 0, length: textStorage.length)) { match, _, _ in
                    if let match = match {
                        // 键
                        if let keyRange = Range(match.range(at: 2), in: textStorage.string) {
                            textStorage.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: match.range(at: 2))
                        }
                        // 冒号
                        if let colonRange = Range(match.range(at: 3), in: textStorage.string) {
                            textStorage.addAttribute(.foregroundColor, value: NSColor.systemGray, range: match.range(at: 3))
                        }
                    }
                }
            case "sh":
                // Shell 脚本语法高亮
                let patterns: [(String, NSColor)] = [
                    ("#.*$", .systemGreen),  // 注释
                    ("\\b(if|then|else|elif|fi|for|while|do|done|case|esac|in|function)\\b", .systemPurple),  // 关键字
                    ("\\b(echo|cd|ls|mkdir|rm|cp|mv|grep|find|cat|chmod|chown)\\b", .systemOrange),  // 常用命令
                    ("\\$\\{[^}]+\\}|\\$[a-zA-Z0-9_]+", .systemRed),  // 变量
                    ("'[^']*'", .systemBrown),  // 单引号字符串
                    ("\"[^\"]*\"", .systemBrown)  // 双引号字符串
                ]
                
                for (pattern, color) in patterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                        regex.enumerateMatches(in: textStorage.string, range: NSRange(location: 0, length: textStorage.length)) { match, _, _ in
                            if let match = match {
                                textStorage.addAttribute(.foregroundColor, value: color, range: match.range)
                            }
                        }
                    }
                }
            case "ini":
                // INI 配置文件语法高亮 (包括 .npmrc, .yarnrc, .pypirc, .gitconfig)
                let patterns: [(String, NSColor)] = [
                    ("^\\s*#.*$", .systemGreen),  // 注释
                    ("^\\s*;.*$", .systemGreen),  // 分号注释
                    ("^\\s*\\[[^\\]]+\\]\\s*$", .systemPurple),  // 节名
                    ("^\\s*([^=]+)\\s*=\\s*(.*)$", .systemBlue),  // 键值对
                    ("\\b(true|false|yes|no|on|off)\\b", .systemOrange),  // 布尔值
                    ("\\b\\d+\\b", .systemRed),  // 数字
                    ("'[^']*'", .systemBrown),  // 单引号字符串
                    ("\"[^\"]*\"", .systemBrown)  // 双引号字符串
                ]
                
                for (pattern, color) in patterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                        regex.enumerateMatches(in: textStorage.string, range: NSRange(location: 0, length: textStorage.length)) { match, _, _ in
                            if let match = match {
                                textStorage.addAttribute(.foregroundColor, value: color, range: match.range)
                            }
                        }
                    }
                }
                
                // 特殊处理 .gitconfig 文件
                if fileExtension == "git" {
                    let gitPatterns: [(String, NSColor)] = [
                        ("\\b(pull|push|commit|checkout|branch|merge|rebase|stash|tag|remote|fetch|clone|init|add|status|log|diff|show|reset|revert|cherry-pick|reflog|blame|bisect|submodule|worktree|config|help)\\b", .systemPurple),  // Git 命令
                        ("\\b(main|master|develop|feature|bugfix|hotfix|release|HEAD|origin|upstream)\\b", .systemOrange),  // Git 常用分支名
                        ("\\b(untracked|modified|staged|committed|ahead|behind|conflict|detached|fast-forward|merge|rebase|squash|amend|revert|cherry-pick|stash|tag|remote|fetch|clone|init|add|status|log|diff|show|reset|revert|cherry-pick|reflog|blame|bisect|submodule|worktree|config|help)\\b", .systemBlue)  // Git 状态和操作
                    ]
                    
                    for (pattern, color) in gitPatterns {
                        if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                            regex.enumerateMatches(in: textStorage.string, range: NSRange(location: 0, length: textStorage.length)) { match, _, _ in
                                if let match = match {
                                    textStorage.addAttribute(.foregroundColor, value: color, range: match.range)
                                }
                            }
                        }
                    }
                }
            case "py":
                // Python 语法高亮
                let patterns: [(String, NSColor)] = [
                    ("#.*$", .systemGreen),  // 注释
                    ("\\b(def|class|if|elif|else|while|for|in|try|except|finally|with|as|import|from|return|yield|break|continue|pass|raise|assert|global|nonlocal|lambda|and|or|not|is|None|True|False)\\b", .systemPurple),  // 关键字
                    ("\\b(int|float|str|list|dict|set|tuple|bool|None|True|False)\\b", .systemBlue),  // 内置类型
                    ("\\b(print|len|range|enumerate|zip|map|filter|sorted|reversed|open|with|as)\\b", .systemOrange),  // 内置函数
                    ("'[^']*'", .systemBrown),  // 单引号字符串
                    ("\"[^\"]*\"", .systemBrown)  // 双引号字符串
                ]
                
                for (pattern, color) in patterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                        regex.enumerateMatches(in: textStorage.string, range: NSRange(location: 0, length: textStorage.length)) { match, _, _ in
                            if let match = match {
                                textStorage.addAttribute(.foregroundColor, value: color, range: match.range)
                            }
                        }
                    }
                }
            case "js", "ts", "jsx", "tsx":
                // JavaScript/TypeScript 语法高亮
                let patterns: [(String, NSColor)] = [
                    ("//.*$", .systemGreen),  // 单行注释
                    ("/\\*[\\s\\S]*?\\*/", .systemGreen),  // 多行注释
                    ("\\b(const|let|var|function|class|extends|implements|interface|type|enum|namespace|module|export|import|from|as|default|return|yield|async|await|try|catch|finally|throw|if|else|switch|case|break|continue|for|while|do|in|of|new|this|super|static|public|private|protected|readonly|abstract|get|set|constructor)\\b", .systemPurple),  // 关键字
                    ("\\b(undefined|null|true|false|NaN|Infinity)\\b", .systemBlue),  // 字面量
                    ("'[^']*'", .systemBrown),  // 单引号字符串
                    ("\"[^\"]*\"", .systemBrown),  // 双引号字符串
                    ("`[^`]*`", .systemBrown)  // 模板字符串
                ]
                
                for (pattern, color) in patterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                        regex.enumerateMatches(in: textStorage.string, range: NSRange(location: 0, length: textStorage.length)) { match, _, _ in
                            if let match = match {
                                textStorage.addAttribute(.foregroundColor, value: color, range: match.range)
                            }
                        }
                    }
                }
            default:
                // 为所有文件类型添加 URL 高亮
                let urlPattern = "(https?://[\\w\\d\\-._~:/?#\\[\\]@!$&'()*+,;=]+)"
                highlightPattern(textStorage, urlPattern, color: .systemBlue, options: [])
                break
            }
            
            // 添加搜索高亮
            if !search.isEmpty {
                let pattern = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: search), options: [.caseInsensitive])
                pattern?.enumerateMatches(in: textStorage.string, range: NSRange(location: 0, length: textStorage.length)) { match, _, _ in
                    if let match = match {
                        textStorage.addAttribute(.backgroundColor, value: NSColor.yellow.withAlphaComponent(0.3), range: match.range)
                    }
                }
            }
        }
        // 恢复选择范围和可见区域
        textView.setSelectedRange(selectedRange)
        textView.scrollToVisible(visibleRect)
        // 强制更新布局
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
    }

    // 异步全量高亮（大文件优化）
    private func applyHighlightFullAsync() {
        // 在主线程获取必要的 UI 组件引用
        DispatchQueue.main.async {
            guard let textView = self.textView,
                  let textStorage = textView.textStorage else { return }
            
            let fullRange = NSRange(location: 0, length: textStorage.length)
            let content = textStorage.string
            let fileExt = self.fileExtension
            let searchText = self.search
            let currentFont = textView.font // 保存当前字体
            
            // VS Code Dark+ 主题颜色
            let colors = (
                keyword: NSColor(red: 0.569, green: 0.776, blue: 0.988, alpha: 1.0),      // 关键字
                string: NSColor(red: 0.804, green: 0.475, blue: 0.475, alpha: 1.0),       // 字符串
                comment: NSColor(red: 0.475, green: 0.804, blue: 0.475, alpha: 1.0),      // 注释
                number: NSColor(red: 0.804, green: 0.475, blue: 0.475, alpha: 1.0),       // 数字
                property: NSColor(red: 0.569, green: 0.776, blue: 0.988, alpha: 1.0),     // 属性名
                url: NSColor(red: 0.569, green: 0.776, blue: 0.988, alpha: 1.0),          // URL
                punctuation: NSColor(red: 0.804, green: 0.804, blue: 0.804, alpha: 1.0),  // 标点符号
                search: NSColor(red: 0.98, green: 0.98, blue: 0.0, alpha: 0.3)            // 搜索高亮
            )
            
            // 在后台线程处理高亮逻辑
            DispatchQueue.global(qos: .userInitiated).async {
                // 创建临时存储用于后台处理
                let tempStorage = NSTextStorage(string: content)
                
                // 在后台线程应用高亮规则
                let ext = fileExt.lowercased()
                switch ext {
                case "json":
                    self.highlightPattern(tempStorage, "\"[^\"]*\"\\s*:", color: colors.property)
                    self.highlightPattern(tempStorage, "\"[^\"]*\"", color: colors.string)
                    self.highlightPattern(tempStorage, "\\b(true|false|null)\\b", color: colors.keyword)
                    self.highlightPattern(tempStorage, "\\d+", color: colors.number)
                    self.highlightPattern(tempStorage, "[\\[\\]\\{\\},:]", color: colors.punctuation)
                case "yml", "yaml", "toml", "ini":
                    self.highlightPattern(tempStorage, "^[ \\t\\-]*[\\w\\-\\.]+:", color: colors.property, options: [.anchorsMatchLines])
                    self.highlightPattern(tempStorage, "#.*", color: colors.comment)
                    self.highlightPattern(tempStorage, "\"[^\"]*\"", color: colors.string)
                    self.highlightPattern(tempStorage, "\\b(true|false|yes|no|on|off)\\b", color: colors.keyword)
                    self.highlightPattern(tempStorage, "\\d+", color: colors.number)
                case "sh", "zsh", "bash":
                    self.highlightPattern(tempStorage, "#.*", color: colors.comment)
                    self.highlightPattern(tempStorage, "\\b(if|then|else|fi|for|in|do|done|case|esac|function|export|return|local|while|break|continue)\\b", color: colors.keyword)
                    self.highlightPattern(tempStorage, "\"[^\"]*\"", color: colors.string)
                    self.highlightPattern(tempStorage, "\\b\\d+\\b", color: colors.number)
                case "py":
                    self.highlightPattern(tempStorage, "#.*", color: colors.comment)
                    self.highlightPattern(tempStorage, "\\b(def|class|import|from|as|if|elif|else|for|while|try|except|finally|with|return|yield|break|continue|pass|in|is|not|and|or|print|True|False|None)\\b", color: colors.keyword)
                    self.highlightPattern(tempStorage, "\"[^\"]*\"|'[^']*'", color: colors.string)
                    self.highlightPattern(tempStorage, "\\b\\d+\\b", color: colors.number)
                case "js", "ts", "jsx", "tsx":
                    self.highlightPattern(tempStorage, "//.*", color: colors.comment)
                    self.highlightPattern(tempStorage, "/\\*.*?\\*/", color: colors.comment, options: [.dotMatchesLineSeparators])
                    self.highlightPattern(tempStorage, "\\b(function|var|let|const|if|else|for|while|return|import|from|export|class|extends|new|this|true|false|null|undefined)\\b", color: colors.keyword)
                    self.highlightPattern(tempStorage, "\"[^\"]*\"|'[^']*'", color: colors.string)
                    self.highlightPattern(tempStorage, "\\b\\d+\\b", color: colors.number)
                default:
                    // 为所有文件类型添加 URL 高亮
                    let urlPattern = "(https?://[\\w\\d\\-._~:/?#\\[\\]@!$&'()*+,;=]+)"
                    self.highlightPattern(tempStorage, urlPattern, color: colors.url, options: [])
                    break
                }
                
                // 搜索高亮
                if !searchText.isEmpty {
                    let pattern = NSRegularExpression.escapedPattern(for: searchText)
                    self.highlightPattern(tempStorage, pattern, color: .clear, background: colors.search)
                }
                
                // 在主线程应用高亮结果
                DispatchQueue.main.async {
                    // 保存当前选择范围和可见区域
                    let selectedRange = textView.selectedRange()
                    let visibleRect = textView.visibleRect
                    
                    // 应用高亮
                    textStorage.beginEditing()
                    textStorage.replaceCharacters(in: fullRange, with: tempStorage.string)
                    tempStorage.enumerateAttributes(in: NSRange(location: 0, length: tempStorage.length), options: []) { (attrs, range, _) in
                        textStorage.setAttributes(attrs, range: range)
                    }
                    textStorage.endEditing()
                    
                    // 恢复字体设置
                    textView.font = currentFont
                    
                    // 恢复选择范围和可见区域
                    textView.setSelectedRange(selectedRange)
                    textView.scrollToVisible(visibleRect)
                    
                    // 强制更新布局
                    textView.layoutManager?.ensureLayout(for: textView.textContainer!)
                }
            }
        }
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

    // JSON 语法高亮
    private func highlightJSON(json: Any, in textStorage: NSTextStorage) {
        let patterns: [(String, NSColor)] = [
            ("\"[^\"]*\"\\s*:", .systemBlue),  // 键
            ("\"[^\"]*\"", .systemBrown),      // 字符串
            ("\\b(true|false|null)\\b", .systemPurple),  // 布尔值和 null
            ("\\b\\d+\\b", .systemRed),        // 数字
            ("\\[|\\]", .systemGray),          // 数组括号
            ("\\{|\\}", .systemGray),          // 对象括号
            (":", .systemGray),                // 冒号
            (",", .systemGray)                 // 逗号
        ]
        
        for (pattern, color) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                regex.enumerateMatches(in: textStorage.string, range: NSRange(location: 0, length: textStorage.length)) { match, _, _ in
                    if let match = match {
                        textStorage.addAttribute(.foregroundColor, value: color, range: match.range)
                    }
                }
            }
        }
    }
}
