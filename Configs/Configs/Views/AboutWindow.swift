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
    
    private let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Configs"
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    private let githubURL = "https://github.com/iHongRen/configEditor"
    
    private let shortcuts = [
        ShortcutItem(keys: ["⌘", "F"], description: "Show Search Bar", category: "Search", icon: "magnifyingglass"),
        ShortcutItem(keys: ["⌘", "S"], description: "Save File & git commit", category: "File", icon: "doc.badge.plus"),
        ShortcutItem(keys: ["⌘", "/"], description: "Toggle Comment/Uncomment Lines", category: "Edit", icon: "text.bubble"),
        ShortcutItem(keys: ["⌘", "=", "/", "⌘", "+"], description: "Zoom In", category: "View", icon: "plus.magnifyingglass"),
        ShortcutItem(keys: ["⌘", "-"], description: "Zoom Out", category: "View", icon: "minus.magnifyingglass"),
        ShortcutItem(keys: ["⌘", "0"], description: "Reset Zoom", category: "View", icon: "1.magnifyingglass"),
        ShortcutItem(keys: ["esc"], description: "Close Search Bar", category: "Search", icon: "xmark.circle"),
    ]
    
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
                    
                    Text("Version \(version) (\(buildNumber))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
            }
            .padding(.top, 28)
            .padding(.bottom, 20)
            
            Divider()
            
            // Keyboard Shortcuts section
            VStack(spacing: 16) {
                Text("Keyboard Shortcuts")
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
                        Text("View on GitHub")
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
                .help("Open GitHub repository")
                
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
                .help("Visit developer's homepage")
                
                // Donate button
                Button(action: {
                    if let url = URL(string: "https://ihongren.github.io/donate.html") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                        Text("Donate")
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
                .help("Support the developer")
                
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
        case "Search": return "magnifyingglass"
        case "File": return "doc"
        case "Edit": return "pencil"
        case "View": return "eye"
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
        
        newWindow.title = "About Configs"
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
