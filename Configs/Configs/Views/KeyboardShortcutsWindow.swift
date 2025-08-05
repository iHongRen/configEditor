//
//  KeyboardShortcutsWindow.swift
//  Configs
//
//  Created by cxy on 2025/8/5.
//

import SwiftUI
import AppKit

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hoveredShortcut: UUID?
    
    private let shortcuts = [
        ShortcutItem(keys: ["⌘", "F"], description: "Show/Hide Search Bar", category: "Search", icon: "magnifyingglass"),
        ShortcutItem(keys: ["⌘", "S"], description: "Save File", category: "File", icon: "square.and.arrow.down"),
        ShortcutItem(keys: ["⌘", "/"], description: "Toggle Comment/Uncomment Lines", category: "Edit", icon: "text.bubble"),
        ShortcutItem(keys: ["⌘", "=", "/", "⌘", "+"], description: "Zoom In", category: "View", icon: "plus.magnifyingglass"),
        ShortcutItem(keys: ["⌘", "-"], description: "Zoom Out", category: "View", icon: "minus.magnifyingglass"),
        ShortcutItem(keys: ["⌘", "0"], description: "Reset Zoom", category: "View", icon: "1.magnifyingglass"),
        ShortcutItem(keys: ["⎋"], description: "Close Search Bar", category: "Search", icon: "xmark.circle"),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard Shortcuts")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Quick reference for all available shortcuts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    KeyboardShortcutsWindow.close()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Close")
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
            
            // Content
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
                                        .font(.headline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, category == shortcuts.first?.category ? 16 : 24)
                                
                                // Shortcuts in this category
                                ForEach(categoryShortcuts, id: \.id) { shortcut in
                                    shortcutRow(shortcut)
                                        .onHover { isHovering in
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                hoveredShortcut = isHovering ? shortcut.id : nil
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .frame(width: 520, height: 450)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
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
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
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
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                        )
                }
            }
            .frame(minWidth: 140, alignment: .leading)
            
            // Icon and Description
            HStack(spacing: 8) {
                Image(systemName: shortcut.icon)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                
                Text(shortcut.description)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                .opacity(hoveredShortcut == shortcut.id ? 1 : 0)
        )
    }
}

struct ShortcutItem {
    let id = UUID()
    let keys: [String]
    let description: String
    let category: String
    let icon: String
}

class KeyboardShortcutsWindow {
    private static var window: NSWindow?
    
    static func show() {
        // Close existing window if any
        window?.close()
        
        let contentView = KeyboardShortcutsView()
        let hostingController = NSHostingController(rootView: contentView)
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 450),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "Keyboard Shortcuts"
        newWindow.contentViewController = hostingController
        newWindow.center()
        newWindow.setFrameAutosaveName("KeyboardShortcutsWindow")
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
