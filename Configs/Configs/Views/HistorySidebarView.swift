//
//  HistorySidebarView.swift
//  Configs
//
//  Created by cxy on 2025/8/3.
//

import SwiftUI
import AppKit

struct HistorySidebarView: View {
    let configPath: String
    @Binding var showHistorySidebar: Bool
    let globalZoomLevel: Double
    var onRestore: (String) -> Void
    
    @State private var commits: [Commit] = []
    @State private var selectedCommit: Commit?
    @State private var selectedCommitContent: String?
    @State private var selectedCommitDiff: String?
    @State private var splitPosition: CGFloat = 0.4 // 40% for commit list, 60% for diff view
    @State private var hoveredCommit: Commit?
    @State private var isLoadingDiff = false
    @State private var showRestoreConfirmation = false


    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            resizableContentView
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .onAppear {
            loadCommits()
        }
        .onChange(of: configPath) { _, _ in
            loadCommits()
        }
        .onChange(of: selectedCommit) { _, newCommit in
            guard let commit = newCommit else {
                selectedCommitContent = nil
                selectedCommitDiff = nil
                return
            }
            loadCommitDetails(commit)
        }
        .alert("Restore Version", isPresented: $showRestoreConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Restore", role: .destructive) {
                if let content = selectedCommitContent {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onRestore(content)
                        showRestoreSuccess()
                    }
                }
            }
        } message: {
            if let commit = selectedCommit {
                Text("Are you sure you want to restore to version \(commit.hash.prefix(7))? This will replace the current content in the editor.")
            }
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 12) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.8), Color.accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32 * globalZoomLevel, height: 32 * globalZoomLevel)
                
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14 * globalZoomLevel, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Version History")
                    .font(.system(size: 16 * globalZoomLevel, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("\(commits.count) commits available")
                    .font(.system(size: 11 * globalZoomLevel, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHistorySidebar = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12 * globalZoomLevel, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 28 * globalZoomLevel, height: 28 * globalZoomLevel)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .help("Close history")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.9))
                .overlay(
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }
    
    private var resizableContentView: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                commitListView(geometry: geometry)
                bottomContentView(geometry: geometry)
            }
        }
    }
    
    private func commitListView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Commits list
            if commits.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 60 * globalZoomLevel, height: 60 * globalZoomLevel)
                        
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 24 * globalZoomLevel, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 6) {
                        Text("No Version History")
                            .font(.system(size: 15 * globalZoomLevel, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Changes will appear here once you start editing")
                            .font(.system(size: 12 * globalZoomLevel))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(commits) { commit in
                            commitRowView(commit: commit)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            }
        }
        .frame(height: max(120, geometry.size.height * splitPosition))
    }
    
    private func commitRowView(commit: Commit) -> some View {
        let isSelected = selectedCommit?.id == commit.id
        let isHovered = hoveredCommit?.id == commit.id
        
        return HStack(spacing: 12) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
                    .frame(width: 8 * globalZoomLevel, height: 8 * globalZoomLevel)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 12 * globalZoomLevel, height: 12 * globalZoomLevel)
                    )
                
                if commit.id != commits.last?.id {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 1, height: 40 * globalZoomLevel)
                }
            }
            
            // Commit content
            VStack(alignment: .leading, spacing: 8) {
                // Commit message
                Text(commit.message)
                    .font(.system(size: 13 * globalZoomLevel, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Metadata row
                HStack(spacing: 12) {
                    // Hash badge
                    Text(commit.hash.prefix(7))
                        .font(.system(size: 10 * globalZoomLevel, weight: .medium, design: .monospaced))
                        .foregroundColor(isSelected ? Color.accentColor : Color.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.2))
                        )
                    
                    Spacer()
                    
                    // Date
                    Text(commit.date)
                        .font(.system(size: 11 * globalZoomLevel, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isSelected ? 
                        Color.accentColor.opacity(0.08) : 
                        (isHovered ? Color.secondary.opacity(0.1) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                            lineWidth: 1.5
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCommit = commit
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredCommit = hovering ? commit : nil
            }
        }
//        .scaleEffect(isSelected ? 1.02 : (isHovered ? 1.01 : 1.0))
//        .animation(.easeInOut(duration: 0.15), value: isSelected)
//        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
    

    
    private func bottomContentView(geometry: GeometryProxy) -> some View {
        Group {
            if selectedCommit != nil {
                diffContentView(geometry: geometry)
            } else {
                emptyStateView(geometry: geometry)
            }
        }
        .frame(height: max(160, geometry.size.height * (1 - splitPosition)))
    }
    
    private func diffContentView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Diff header with drag functionality
            ZStack {
                // 可拖动的背景层 - 覆盖整个 header
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onHover { isHovering in
                        DispatchQueue.main.async {
                            if isHovering {
                                NSCursor.resizeUpDown.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let totalHeight = geometry.size.height
                                guard totalHeight > 100 else { return }
                                
                                let currentSplitHeight = totalHeight * splitPosition
                                let newSplitHeight = currentSplitHeight + value.translation.height
                                let newSplitPosition = newSplitHeight / totalHeight
                                
                                splitPosition = max(0.25, min(0.75, newSplitPosition))
                            }
                    )
                
                // Header 内容层 - 按钮可以正常交互
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Button(action: {
                            if let diff = selectedCommitDiff {
                                copyDiffToClipboard(diff)
                            } else if let content = selectedCommitContent {
                                copyContentToClipboard(content)
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.15))
                                    .frame(width: 24 * globalZoomLevel, height: 24 * globalZoomLevel)
                                
                                Image(systemName: "doc.text")
                                    .font(.system(size: 11 * globalZoomLevel, weight: .medium))
                                    .foregroundColor(Color.accentColor)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Copy content to clipboard")
                        .onHover { isHovering in
                            DispatchQueue.main.async {
                                if isHovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                        
                        Text("Changes")
                            .font(.system(size: 14 * globalZoomLevel, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        if let commit = selectedCommit {
                            HStack(spacing: 6) {   
                                Text(commit.hash.prefix(7))
                                    .font(.system(size: 11 * globalZoomLevel, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color.accentColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.accentColor.opacity(0.1))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                        }
                        
                        // Restore button
                        Button(action: {
                            showRestoreConfirmation = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 10 * globalZoomLevel, weight: .semibold))
                                Text("Restore")
                                    .font(.system(size: 11 * globalZoomLevel, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .shadow(color: Color.accentColor.opacity(0.2), radius: 3, x: 0, y: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Restore this version to the editor")
                        .onHover { isHovering in
                            DispatchQueue.main.async {
                                if isHovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .frame(height: 48 * globalZoomLevel)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
            .overlay(
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // Diff content
            ScrollView {
                if let diff = selectedCommitDiff {
                    DiffTextView(diffString: diff, fontSize: 13 * globalZoomLevel)
                } else if isLoadingDiff {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        ProgressView()
                            .scaleEffect(0.8)
                        
                        Text("Loading changes...")
                            .font(.system(size: 13 * globalZoomLevel, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Text("No changes to display")
                            .font(.system(size: 13 * globalZoomLevel, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color(NSColor.textBackgroundColor).opacity(0.7))
        }
    }
    

    
    private func emptyStateView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 80 * globalZoomLevel, height: 80 * globalZoomLevel)
                
                Circle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 60 * globalZoomLevel, height: 60 * globalZoomLevel)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 28 * globalZoomLevel, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 10) {
                Text("Select a Commit")
                    .font(.system(size: 16 * globalZoomLevel, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Choose a commit from the timeline above to view its changes and restore previous versions")
                    .font(.system(size: 12 * globalZoomLevel))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 24)
            }
            
            Spacer()
        }
        .background(Color(NSColor.textBackgroundColor).opacity(0.5))
    }
    
    private func loadCommits() {
        commits = VersionManager.shared.getCommitHistory(for: configPath)
        print("Loaded \(commits.count) commits for \(configPath)")
        
        if let firstCommit = commits.first {
            print("Selecting first commit: \(firstCommit.hash)")
            selectedCommit = firstCommit
        } else {
            print("No commits found")
            selectedCommit = nil
        }
    }
    
    private func loadCommitDetails(_ commit: Commit) {
        isLoadingDiff = true
        selectedCommitContent = nil
        selectedCommitDiff = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            let content = VersionManager.shared.getContentForCommit(commit, for: self.configPath)
            let diff = VersionManager.shared.getDiffForCommit(commit, for: self.configPath)
            
            print("Loading commit details for \(commit.hash)")
            print("Content loaded: \(content != nil ? "Yes (\(content?.count ?? 0) chars)" : "No")")
            print("Diff loaded: \(diff != nil ? "Yes (\(diff?.count ?? 0) chars)" : "No")")
            
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.selectedCommitContent = content
                    self.selectedCommitDiff = diff
                    self.isLoadingDiff = false
                }
            }
        }
    }
    
    private func copyDiffToClipboard(_ diff: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diff, forType: .string)
        
        // 显示复制成功的提示
        showCopySuccess("Diff copied to clipboard")
    }
    
    private func copyContentToClipboard(_ content: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        
        // 显示复制成功的提示
        showCopySuccess("Content copied to clipboard")
    }
    
    private func showCopySuccess(_ message: String) {
        // 这里可以添加一个临时的成功提示
        // 由于这是一个简单的实现，我们暂时使用 print
        print(message)
    }
    
    private func showRestoreSuccess() {
        // 这里可以添加一个临时的成功提示
        print("Version restored successfully")
    }
}

