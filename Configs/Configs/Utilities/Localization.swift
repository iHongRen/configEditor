//
//  Localization.swift
//  Configs
//

import Foundation
import SwiftUI

enum AppLanguage: String {
    case english = "en"
    case chinese = "zh-Hans"

    static var systemDefault: AppLanguage {
        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferredLanguage.hasPrefix("zh") ? .chinese : .english
    }
}

final class LocalizationSettings: ObservableObject {
    static let shared = LocalizationSettings()

    private static let languageKey = "selectedAppLanguage"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
        }
    }

    private init() {
        if let rawValue = UserDefaults.standard.string(forKey: Self.languageKey),
           let savedLanguage = AppLanguage(rawValue: rawValue) {
            language = savedLanguage
        } else {
            language = AppLanguage.systemDefault
        }
    }
}

enum L10n {
    static var language: AppLanguage {
        LocalizationSettings.shared.language
    }

    static func setLanguage(_ language: AppLanguage) {
        LocalizationSettings.shared.language = language
    }

    static func tr(_ key: String) -> String {
        localizedStrings[key]?[language] ?? localizedStrings[key]?[.english] ?? key
    }

    static func tr(_ key: String, _ args: CVarArg...) -> String {
        String(format: tr(key), locale: Locale.current, arguments: args)
    }

    private static let localizedStrings: [String: [AppLanguage: String]] = [
        "about.configs": [.english: "About Configs", .chinese: "关于 Configs"],
        "add.custom.config.file": [.english: "Add custom config file", .chinese: "添加自定义配置文件"],
        "add.tag": [.english: "Add Tag", .chinese: "添加标签"],
        "all.groups": [.english: "All", .chinese: "全部"],
        "appearance": [.english: "Appearance", .chinese: "外观"],
        "are.you.sure.remove.config.file": [.english: "Are you sure you want to remove this config file from the list?", .chinese: "确定要将这个配置文件从列表中移除吗？"],
        "cancel": [.english: "Cancel", .chinese: "取消"],
        "change.appearance": [.english: "Change appearance", .chinese: "切换外观"],
        "changes": [.english: "Changes", .chinese: "变更"],
        "changes.will.appear.here": [.english: "Changes will appear here once you start editing", .chinese: "开始编辑后，变更历史会显示在这里"],
        "close.history": [.english: "Close history", .chinese: "关闭历史记录"],
        "close.search": [.english: "Close search", .chinese: "关闭搜索"],
        "copy.content.to.clipboard": [.english: "Copy content to clipboard", .chinese: "复制内容到剪贴板"],
        "copy.diff": [.english: "Copy Diff", .chinese: "复制差异"],
        "copy.diff.to.clipboard": [.english: "Diff copied to clipboard", .chinese: "已复制差异到剪贴板"],
        "copy.content.copied": [.english: "Content copied to clipboard", .chinese: "已复制内容到剪贴板"],
        "copy.path": [.english: "Copy Path", .chinese: "复制路径"],
        "delete": [.english: "Delete", .chinese: "删除"],
        "delete.group": [.english: "Delete Group", .chinese: "删除分组"],
        "delete.config.file": [.english: "Delete Config File", .chinese: "删除配置文件"],
        "developer.homepage": [.english: "Visit developer's homepage", .chinese: "访问开发者主页"],
        "directory.item.message": [.english: "This item is a directory. Use Finder, Terminal, VSCode, or Cursor to inspect its contents.", .chinese: "这是一个目录。请使用 Finder、Terminal、VSCode 或 Cursor 查看其内容。"],
        "donate": [.english: "Donate", .chinese: "赞助"],
        "edit": [.english: "Edit", .chinese: "编辑"],
        "empty.group.description": [.english: "Add config files from the sidebar, or move existing config files into this group.", .chinese: "从左侧添加配置文件，或把已有配置文件移动到这个分组。"],
        "empty.group.title": [.english: "No config files in this group yet", .chinese: "当前分组还没有配置文件"],
        "error": [.english: "Error", .chinese: "错误"],
        "file": [.english: "File", .chinese: "文件"],
        "find.next": [.english: "Find next", .chinese: "查找下一个"],
        "find.previous": [.english: "Find previous", .chinese: "查找上一个"],
        "hide.version.history": [.english: "Hide version history", .chinese: "隐藏版本历史"],
        "keyboard.shortcuts": [.english: "Keyboard Shortcuts", .chinese: "快捷键"],
        "language": [.english: "Language", .chinese: "语言"],
        "language.english": [.english: "English", .chinese: "English"],
        "language.chinese": [.english: "Chinese", .chinese: "中文"],
        "list.empty.description": [.english: "add a config file to get started.", .chinese: "添加配置文件后，这里就会显示内容。"],
        "list.empty.title": [.english: "No config files yet", .chinese: "还没有配置文件"],
        "light": [.english: "Light", .chinese: "浅色"],
        "dark": [.english: "Dark", .chinese: "深色"],
        "loading.changes": [.english: "Loading changes...", .chinese: "正在加载变更..."],
        "loading.content": [.english: "Loading content...", .chinese: "正在加载内容..."],
        "modified.at": [.english: "Modified %@", .chinese: "修改于 %@"],
        "move.to.group": [.english: "Move to Group", .chinese: "移动到分组"],
        "new.group.create": [.english: "Create", .chinese: "创建"],
        "group.name.placeholder": [.english: "Enter group name", .chinese: "输入分组名称"],
        "new.group.title": [.english: "New Group", .chinese: "新建分组"],
        "no.changes.display": [.english: "No changes to display", .chinese: "没有可显示的变更"],
        "no.config.files.found": [.english: "No config files found", .chinese: "未找到配置文件"],
        "no.version.history": [.english: "No Version History", .chinese: "暂无版本历史"],
        "open.github.repository": [.english: "Open GitHub repository", .chinese: "打开 GitHub 仓库"],
        "open.git.project.in.finder": [.english: "Open Git project in Finder", .chinese: "在 Finder 中打开 Git 项目"],
        "open.in.cursor": [.english: "Open in Cursor", .chinese: "在 Cursor 中打开"],
        "open.in.finder": [.english: "Open in Finder", .chinese: "在 Finder 中打开"],
        "open.in.terminal": [.english: "Open in Terminal", .chinese: "在终端中打开"],
        "open.in.vscode": [.english: "Open in VSCode", .chinese: "在 VSCode 中打开"],
        "quit.configs": [.english: "Quit Configs", .chinese: "退出 Configs"],
        "restore": [.english: "Restore", .chinese: "恢复"],
        "restore.this.version": [.english: "Restore this version to the editor", .chinese: "将此版本恢复到编辑器"],
        "restore.version": [.english: "Restore Version", .chinese: "恢复版本"],
        "restore.version.message": [.english: "Are you sure you want to restore to version %@? This will replace the current content in the editor.", .chinese: "确定要恢复到版本 %@ 吗？这会替换编辑器中的当前内容。"],
        "restoring": [.english: "Restoring...", .chinese: "恢复中..."],
        "restoring.version": [.english: "Restoring version...", .chinese: "正在恢复版本..."],
        "save": [.english: "Save", .chinese: "保存"],
        "search": [.english: "Search", .chinese: "搜索"],
        "search.config.file.placeholder": [.english: "Search config file...", .chinese: "搜索配置文件..."],
        "search.config.files.prompt": [.english: "Search config files...", .chinese: "搜索配置文件..."],
        "search.content.placeholder": [.english: "Search content...", .chinese: "搜索内容..."],
        "search.current.file.help": [.english: "Search in current file (Press Enter for next)", .chinese: "在当前文件中搜索（按 Enter 查找下一个）"],
        "select.a.commit": [.english: "Select a Commit", .chinese: "选择一个提交"],
        "select.commit.description": [.english: "Choose a commit from the timeline above to view its changes and restore previous versions", .chinese: "从上方时间线选择一个提交，以查看其变更并恢复旧版本"],
        "show.search.bar": [.english: "Show Search Bar", .chinese: "显示搜索栏"],
        "show.version.history": [.english: "Show version history", .chinese: "显示版本历史"],
        "support.developer": [.english: "Support the developer", .chinese: "支持开发者"],
        "tag": [.english: "Tag", .chinese: "标签"],
        "unknown.group": [.english: "Unknown Group", .chinese: "未知分组"],
        "unpin": [.english: "Unpin", .chinese: "取消置顶"],
        "pin": [.english: "Pin", .chinese: "置顶"],
        "version.count": [.english: "%d commits available", .chinese: "共 %d 条提交记录"],
        "version.history": [.english: "Version History", .chinese: "版本历史"],
        "version.restored.successfully": [.english: "Version restored successfully", .chinese: "版本恢复成功"],
        "version.label": [.english: "Version %@ (%@)", .chinese: "版本 %@（%@）"],
        "view": [.english: "View", .chinese: "视图"],
        "view.on.github": [.english: "View on GitHub", .chinese: "在 GitHub 上查看"],
        "unable.read.common.encodings": [.english: "Unable to read content with common encodings. File may be binary or in a special format.", .chinese: "无法使用常见编码读取内容。该文件可能是二进制文件或特殊格式。"],
        "failed.read.file.content": [.english: "Failed to read file content: %@", .chinese: "读取文件内容失败：%@"],
        "show.copy.success": [.english: "%@", .chinese: "%@"]
    ]
}
