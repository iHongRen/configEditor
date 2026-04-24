//
//  HistorySidebarView.swift
//  Configs
//
//  Created by cxy on 2025/8/3.
//

import SwiftUI
import AppKit

struct HistorySidebarView: View {
    private static let largeInitialCommitThreshold = 512 * 1024
    private static let initialCommitPreviewLineCount = 50

    @ObservedObject private var localization = LocalizationSettings.shared
    let configPath: String
    @Binding var showHistorySidebar: Bool
    let globalZoomLevel: Double
    var onRestore: (String, String) -> Void // (content, commitHash)
    
    @State private var commits: [Commit] = []
    @State private var selectedCommit: Commit?
    @State private var selectedCommitContent: String?
    @State private var selectedCommitDiff: String?
    @State private var splitPosition: CGFloat = 0.4 // 40% for commit list, 60% for diff view
    @State private var hoveredCommit: Commit?
    @State private var isLoadingDiff = false
    @State private var showRestoreConfirmation = false
    @State private var isRestoring = false

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
        .compatibleOnChange(of: configPath) { _, _ in
            loadCommits()
        }
        .compatibleOnChange(of: selectedCommit) { _, newCommit in
            guard let commit = newCommit else {
                selectedCommitContent = nil
                selectedCommitDiff = nil
                return
            }
            loadCommitDetails(commit)
        }
        .onReceive(NotificationCenter.default.publisher(for: .configVersionHistoryDidChange)) { notification in
            guard let updatedConfigPath = notification.userInfo?["configPath"] as? String,
                  updatedConfigPath == configPath else {
                return
            }

            let commitHash = notification.userInfo?["commitHash"] as? String
            loadCommits(selecting: commitHash)
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyNavigateCommit)) { notification in
            guard let updatedConfigPath = notification.userInfo?["configPath"] as? String,
                  updatedConfigPath == configPath else {
                return
            }

            let offset = notification.userInfo?["offset"] as? Int ?? 0
            guard offset != 0 else {
                return
            }
            selectCommit(offset: offset)
        }
        .alert(L10n.tr("restore.version"), isPresented: $showRestoreConfirmation) {
            Button(L10n.tr("cancel"), role: .cancel) { }
            Button(L10n.tr("restore"), role: .destructive) {
                if let content = selectedCommitContent, let commit = selectedCommit, !isRestoring {
                    isRestoring = true
           
                    onRestore(content, commit.hash)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isRestoring = false
                        self.showRestoreSuccess()
                    }
                }
            }
        } message: {
            if let commit = selectedCommit {
                Text(L10n.tr("restore.version.message", String(commit.hash.prefix(7))))
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
                    .frame(width: 28 * globalZoomLevel, height: 28 * globalZoomLevel)
                
                Image(systemName: "clock")
                    .font(.system(size: 14 * globalZoomLevel, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("version.history"))
                    .font(.system(size: 14 * globalZoomLevel, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(L10n.tr("version.count", commits.count))
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
            .help(L10n.tr("close.history"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
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
                        
                        Image(systemName: "clock")
                            .font(.system(size: 24 * globalZoomLevel, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 6) {
                        Text(L10n.tr("no.version.history"))
                            .font(.system(size: 15 * globalZoomLevel, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(L10n.tr("changes.will.appear.here"))
                            .font(.system(size: 12 * globalZoomLevel))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(commits) { commit in
                                commitRowView(commit: commit)
                                    .id(commit.hash)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .compatibleOnChange(of: selectedCommit?.hash) { _, newHash in
                        guard let newHash else {
                            return
                        }
                        withAnimation(.easeInOut(duration: 0.18)) {
                            proxy.scrollTo(newHash, anchor: .center)
                        }
                    }
                }
                .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            }
        }
        .frame(height: max(120, geometry.size.height * splitPosition))
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
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
                
                // Header
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
                                    .frame(width: 20 * globalZoomLevel, height: 20 * globalZoomLevel)
                                
                                Image(systemName: "doc.text")
                                    .font(.system(size: 12 * globalZoomLevel, weight: .medium))
                                    .foregroundColor(Color.accentColor)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(L10n.tr("copy.content.to.clipboard"))
                        .onHover { isHovering in
                            DispatchQueue.main.async {
                                if isHovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                        
                        Text(L10n.tr("changes"))
                            .font(.system(size: 13 * globalZoomLevel, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            openGitProjectInFinder()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "folder")
                                    .font(.system(size: 10 * globalZoomLevel, weight: .semibold))
                                Text(L10n.language == .chinese ? "Git 项目" : "Git Project")
                                    .font(.system(size: 11 * globalZoomLevel, weight: .semibold))
                            }
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(L10n.tr("open.git.project.in.finder"))

                        // Restore button
                        Button(action: {
                            if !isRestoring {
                                showRestoreConfirmation = true
                            }
                        }) {
                            HStack(spacing: 5) {
                                if isRestoring {
                                    ProgressView()
                                        .scaleEffect(0.4)
                                        .frame(width: 8 * globalZoomLevel, height: 8 * globalZoomLevel)
                                } else {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 10 * globalZoomLevel, weight: .semibold))
                                }
                                Text(isRestoring ? L10n.tr("restoring") : L10n.tr("restore"))
                                    .font(.system(size: 11 * globalZoomLevel, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: isRestoring ? 
                                                [Color.secondary, Color.secondary.opacity(0.8)] :
                                                [Color.accentColor, Color.accentColor.opacity(0.8)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .shadow(color: (isRestoring ? Color.secondary : Color.accentColor).opacity(0.2), radius: 3, x: 0, y: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isRestoring)
                        .help(isRestoring ? L10n.tr("restoring.version") : L10n.tr("restore.this.version"))
                        .onHover { isHovering in
                            DispatchQueue.main.async {
                                if isHovering && !isRestoring {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 36 * globalZoomLevel)
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
                        
                        Text(L10n.tr("loading.changes"))
                            .font(.system(size: 13 * globalZoomLevel, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Text(L10n.tr("no.changes.display"))
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
                Text(L10n.tr("select.a.commit"))
                    .font(.system(size: 16 * globalZoomLevel, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(L10n.tr("select.commit.description"))
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
    
    private func loadCommits(selecting commitHash: String? = nil) {
        commits = VersionManager.shared.getCommitHistory(for: configPath)
        print("Loaded \(commits.count) commits for \(configPath)")

        if let commitHash,
           let matchedCommit = commits.first(where: { $0.hash == commitHash }) {
            print("Selecting updated commit: \(matchedCommit.hash)")
            selectedCommit = matchedCommit
            return
        }

        if let currentSelectedHash = selectedCommit?.hash,
           let matchedCommit = commits.first(where: { $0.hash == currentSelectedHash }) {
            selectedCommit = matchedCommit
            return
        }

        if let firstCommit = commits.first {
            print("Selecting first commit: \(firstCommit.hash)")
            selectedCommit = firstCommit
        } else {
            print("No commits found")
            selectedCommit = nil
        }
    }

    private func selectCommit(offset: Int) {
        guard !commits.isEmpty else {
            return
        }

        let currentIndex: Int
        if let selectedCommit,
           let idx = commits.firstIndex(where: { $0.hash == selectedCommit.hash }) {
            currentIndex = idx
        } else {
            currentIndex = 0
        }

        let nextIndex = max(0, min(commits.count - 1, currentIndex + offset))
        guard nextIndex != currentIndex else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            selectedCommit = commits[nextIndex]
        }
    }
    
    private func loadCommitDetails(_ commit: Commit) {
        isLoadingDiff = true
        selectedCommitContent = nil
        selectedCommitDiff = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            let content = VersionManager.shared.getContentForCommit(commit, for: self.configPath)
            let isInitialCommit = commit.hash == self.commits.last?.hash
            let diff: String?

            if isInitialCommit,
               let content,
               content.utf8.count > Self.largeInitialCommitThreshold {
                diff = self.makeInitialCommitPreviewDiff(from: content)
            } else {
                diff = VersionManager.shared.getDiffForCommit(commit, for: self.configPath)
            }
            
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

    private func makeInitialCommitPreviewDiff(from content: String) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        let previewLines = lines.prefix(Self.initialCommitPreviewLineCount).map { "+\($0)" }
        let omittedLineCount = max(0, lines.count - Self.initialCommitPreviewLineCount)

        guard omittedLineCount > 0 else {
            return previewLines.joined(separator: "\n")
        }

        let tailLine = L10n.language == .chinese
            ? "+... 已省略 \(omittedLineCount) 行（首次大文件提交仅预览前 \(Self.initialCommitPreviewLineCount) 行）"
            : "+... \(omittedLineCount) lines omitted (large initial commit preview shows first \(Self.initialCommitPreviewLineCount) lines)"

        return (previewLines + [tailLine]).joined(separator: "\n")
    }
    
    private func copyDiffToClipboard(_ diff: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diff, forType: .string)
        
        showCopySuccess(L10n.tr("copy.diff.to.clipboard"))
    }
    
    private func copyContentToClipboard(_ content: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        
        showCopySuccess(L10n.tr("copy.content.copied"))
    }
    
    private func showCopySuccess(_ message: String) {
        print(message)
    }
    
    private func showRestoreSuccess() {
        print(L10n.tr("version.restored.successfully"))
    }

    private func openGitProjectInFinder() {
        guard let projectRootURL = VersionManager.shared.getGitProjectRoot(for: configPath) else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([projectRootURL])
    }
}
