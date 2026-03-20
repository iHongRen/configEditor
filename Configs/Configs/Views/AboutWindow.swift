//
//  AboutWindow.swift
//  Configs
//
//  Created by cxy on 2025/8/5.
//

import SwiftUI
import AppKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localization = LocalizationSettings.shared
    
    private let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Configs"
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    private let githubURL = "https://github.com/iHongRen/configEditor"
    
    private var shortcuts: [ShortcutItem] {
        [
            ShortcutItem(keys: ["⌘", "F"], description: L10n.tr("show.search.bar"), category: L10n.tr("search"), icon: "magnifyingglass"),
            ShortcutItem(keys: ["⌘", "S"], description: L10n.language == .chinese ? "保存文件并提交 git" : "Save File & git commit", category: L10n.tr("file"), icon: "doc.badge.plus"),
            ShortcutItem(keys: ["⌘", "/"], description: L10n.language == .chinese ? "切换注释/取消注释" : "Toggle Comment/Uncomment Lines", category: L10n.tr("edit"), icon: "text.bubble"),
            ShortcutItem(keys: ["⌘", "=", "/", "⌘", "+"], description: L10n.language == .chinese ? "放大" : "Zoom In", category: L10n.tr("view"), icon: "plus.magnifyingglass"),
            ShortcutItem(keys: ["⌘", "-"], description: L10n.language == .chinese ? "缩小" : "Zoom Out", category: L10n.tr("view"), icon: "minus.magnifyingglass"),
            ShortcutItem(keys: ["⌘", "0"], description: L10n.language == .chinese ? "重置缩放" : "Reset Zoom", category: L10n.tr("view"), icon: "1.magnifyingglass"),
            ShortcutItem(keys: ["esc"], description: L10n.language == .chinese ? "关闭搜索栏" : "Close Search Bar", category: L10n.tr("search"), icon: "xmark.circle"),
        ]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with app icon and info
            VStack(spacing: 16) {
                // App Icon
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "doc.text")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.white)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                
                // App Name and Version
                VStack(spacing: 4) {
                    Text(appName)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(L10n.tr("version.label", version, buildNumber))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
            }
            .padding(.top, 28)
            .padding(.bottom, 20)
            
            Divider()

            VStack(alignment: .leading, spacing: 10) {
              
                Picker(L10n.tr("language"), selection: Binding(
                    get: { localization.language },
                    set: { L10n.setLanguage($0) }
                )) {
                    Text(L10n.tr("language.english")).tag(AppLanguage.english)
                    Text(L10n.tr("language.chinese")).tag(AppLanguage.chinese)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()
            
            // Keyboard Shortcuts section
            VStack(spacing: 16) {
                Text(L10n.tr("keyboard.shortcuts"))
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedShortcuts.keys.sorted(), id: \.self) { category in
                            if let categoryShortcuts = groupedShortcuts[category] {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Category header
                                    HStack {
                                        Image(systemName: categoryIcon(for: category))
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.accentColor)
                                            .frame(width: 20)
                                        
                                        Text(category)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.top, category == shortcuts.first?.category ? 4 : 12)
                                    
                                    // Shortcuts in this category
                                    ForEach(categoryShortcuts, id: \.id) { shortcut in
                                        shortcutRow(shortcut)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxHeight: .infinity)
            
            Divider()
            
            // Footer with links
            HStack(spacing: 12) {
                Spacer()
                
                // GitHub link
                Button(action: {
                    if let url = URL(string: githubURL) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                        Text(L10n.tr("view.on.github"))
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .help(L10n.tr("open.github.repository"))
                
                // User homepage button
                Button(action: {
                    if let url = URL(string: "https://ihongren.github.io/") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 12))
                        Text("仙银")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .help(L10n.tr("developer.homepage"))
                
                // Donate button
                Button(action: {
                    if let url = URL(string: "https://ihongren.github.io/donate.html") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                        Text(L10n.tr("donate"))
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color.pink, Color.pink.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .help(L10n.tr("support.developer"))
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 480, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var groupedShortcuts: [String: [ShortcutItem]] {
        Dictionary(grouping: shortcuts, by: \.category)
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case L10n.tr("search"): return "magnifyingglass"
        case L10n.tr("file"): return "doc"
        case L10n.tr("edit"): return "pencil"
        case L10n.tr("view"): return "eye"
        default: return "questionmark"
        }
    }
    
    private func shortcutRow(_ shortcut: ShortcutItem) -> some View {
        HStack(spacing: 16) {
            // Shortcut keys
            HStack(spacing: 4) {
                ForEach(shortcut.keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(NSColor.controlBackgroundColor),
                                            Color(NSColor.controlBackgroundColor).opacity(0.8)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                        )
                }
            }
            .frame(minWidth: 120, alignment: .leading)
            
            // Icon and Description
            HStack(spacing: 8) {
                Image(systemName: shortcut.icon)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 14)
                
                Text(shortcut.description)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 3)
    }
}



class AboutWindow {
    private static var window: NSWindow?
    
    static func show() {
        // Close existing window if any
        window?.close()
        
        let contentView = AboutView()
        let hostingController = NSHostingController(rootView: contentView)
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = L10n.tr("about.configs")
        newWindow.contentViewController = hostingController
        newWindow.center()
        newWindow.setFrameAutosaveName("AboutWindow")
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .floating
        
        // Make window appear above all other windows
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        window = newWindow
    }
    
    static func close() {
        window?.close()
    }
}

struct ShortcutItem {
    let id = UUID()
    let keys: [String]
    let description: String
    let category: String
    let icon: String
}
