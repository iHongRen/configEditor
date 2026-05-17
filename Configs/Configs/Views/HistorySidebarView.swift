//
//  HistorySidebarView.swift
//  Configs
//
//  Created by cxy on 2025/8/3.
//

import SwiftUI
import AppKit

struct HistorySidebarView: View {
    static let defaultSidebarWidth: CGFloat = 300
    static let minSidebarWidth: CGFloat = 240
    static let maxSidebarWidth: CGFloat = 520
    private static let largeInitialCommitThreshold = 512 * 1024
    private static let initialCommitPreviewLineCount = 50

    private enum VersionAction {
        case undo(target: Commit)
        case restore(target: Commit)

        var targetCommit: Commit {
            switch self {
            case .undo(let target), .restore(let target):
                return target
            }
        }

        var isUndo: Bool {
            if case .undo = self {
                return true
            }
            return false
        }

        var confirmationTitle: String {
            isUndo ? L10n.tr("undo.version") : L10n.tr("restore.version")
        }

        var confirmationButtonTitle: String {
            isUndo ? L10n.tr("undo") : L10n.tr("restore")
        }

        var inProgressTitle: String {
            isUndo ? L10n.tr("undoing") : L10n.tr("restoring")
        }

        var helpTitle: String {
            isUndo ? L10n.tr("undo.this.change") : L10n.tr("restore.this.version")
        }

        var inProgressHelpTitle: String {
            isUndo ? L10n.tr("undoing.version") : L10n.tr("restoring.version")
        }

        var confirmationMessage: String {
            let shortHash = String(targetCommit.hash.prefix(7))
            return isUndo ? L10n.tr("undo.version.message", shortHash) : L10n.tr("restore.version.message", shortHash)
        }

        var successMessage: String {
            isUndo ? L10n.tr("version.undone.successfully") : L10n.tr("version.restored.successfully")
        }
    }

    @ObservedObject private var localization = LocalizationSettings.shared
    let configPath: String
    @Binding var showHistorySidebar: Bool
    let globalZoomLevel: Double
    var onApplyVersion: (String, String, Bool) -> Void
    
    @State private var commits: [Commit] = []
    @State private var selectedCommit: Commit?
    @State private var selectedCommitContent: String?
    @State private var selectedCommitDiff: String?
    @State private var splitPosition: CGFloat = 0.4 // 40% for commit list, 60% for diff view
    @State private var hoveredCommit: Commit?
    @State private var isLoadingDiff = false
    @State private var showVersionActionConfirmation = false
    @State private var isApplyingVersionAction = false

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                headerView()
                resizableContentView(geometry: geometry)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .alert(currentVersionAction()?.confirmationTitle ?? L10n.tr("restore.version"), isPresented: $showVersionActionConfirmation) {
            Button(L10n.tr("cancel"), role: .cancel) { }
            if let action = currentVersionAction() {
                Button(action.confirmationButtonTitle, role: action.isUndo ? .destructive : nil) {
                    performVersionAction(action)
                }
            }
        } message: {
            if let action = currentVersionAction() {
                Text(action.confirmationMessage)
            }
        }
    }
    
    private func headerView() -> some View {
        let iconSize = 28 * globalZoomLevel
        let horizontalPadding = 12 * globalZoomLevel

        return HStack(spacing: 12 * globalZoomLevel) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.8), Color.accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: iconSize, height: iconSize)

                Image(systemName: "clock")
                    .font(.system(size: 14 * globalZoomLevel, weight: .semibold))
                    .foregroundColor(.white)
            }
            .layoutPriority(1)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("version.history"))
                    .font(.system(size: 14 * globalZoomLevel, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(L10n.tr("version.count", commits.count))
                    .font(.system(size: 11 * globalZoomLevel, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHistorySidebar = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12 * globalZoomLevel, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: iconSize, height: iconSize)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: iconSize, height: iconSize)
            .fixedSize()
            .help(L10n.tr("close.history"))
            .layoutPriority(20)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 12 * globalZoomLevel)
        .frame(maxWidth: .infinity)
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

    private func resizableContentView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            commitListView(geometry: geometry)
            bottomContentView(geometry: geometry)
        }
    }

    private func commitListView(geometry: GeometryProxy) -> some View {
        let horizontalPadding = 16 * globalZoomLevel
        let verticalPadding = 12 * globalZoomLevel
        let minHeight = 120 * globalZoomLevel

        return VStack(spacing: 0) {
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
                                    .padding(.horizontal, horizontalPadding)
                            }
                        }
                        .padding(.vertical, verticalPadding)
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
        .frame(height: max(minHeight, geometry.size.height * splitPosition))
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private func commitRowView(commit: Commit) -> some View {
        let isSelected = selectedCommit?.hash == commit.hash
        let isHovered = hoveredCommit?.hash == commit.hash
        let rowSpacing = 12 * globalZoomLevel
        let rowPadding = 16 * globalZoomLevel
        let metadataSpacing = 12 * globalZoomLevel

        return HStack(alignment: .top, spacing: rowSpacing) {
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
                
                if commit.hash != commits.last?.hash {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 1, height: 40 * globalZoomLevel)
                }
            }

            // Commit content
            VStack(alignment: .leading, spacing: 8 * globalZoomLevel) {
                // Commit message
                Text(commit.message)
                    .font(.system(size: 13 * globalZoomLevel, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)

                // Metadata row
                HStack(spacing: metadataSpacing) {
                    commitHashBadge(commit: commit, isSelected: isSelected)
                    Spacer(minLength: 8)
                    commitDateText(commit: commit)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12 * globalZoomLevel)
        .padding(.horizontal, rowPadding)
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
                selectCommit(commit)
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

    private func commitHashBadge(commit: Commit, isSelected: Bool) -> some View {
        Text(commit.hash.prefix(7))
            .font(.system(size: 10 * globalZoomLevel, weight: .medium, design: .monospaced))
            .foregroundColor(isSelected ? Color.accentColor : Color.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.2))
            )
    }

    private func commitDateText(commit: Commit) -> some View {
        Text(commit.date)
            .font(.system(size: 11 * globalZoomLevel, weight: .medium))
            .foregroundColor(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }

    

    
    private func bottomContentView(geometry: GeometryProxy) -> some View {
        let minHeight = 160 * globalZoomLevel

        return Group {
            if selectedCommit != nil {
                diffContentView(geometry: geometry)
            } else {
                emptyStateView()
            }
        }
        .frame(height: max(minHeight, geometry.size.height * (1 - splitPosition)))
    }

    private func diffContentView(geometry: GeometryProxy) -> some View {
        let action = currentVersionAction()
        let headerHeight = 42 * globalZoomLevel

        return VStack(spacing: 0) {
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
                
                headerControls(action: action)
                    .padding(.horizontal, 12 * globalZoomLevel)
            }
            .frame(height: headerHeight)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
            .overlay(
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            Group {
                if let diff = selectedCommitDiff {
                    DiffTextView(diffString: diff, fontSize: 13 * globalZoomLevel)
                } else if isLoadingDiff {
                    centeredDiffStateView(
                        spacing: 16,
                        icon: AnyView(ProgressView().scaleEffect(0.8)),
                        text: L10n.tr("loading.changes")
                    )
                } else {
                    centeredDiffStateView(
                        spacing: 16,
                        icon: nil,
                        text: L10n.tr("no.changes.display")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor).opacity(0.7))
        }
    }

    private func headerControls(action: VersionAction?) -> some View {
        let spacing = 12 * globalZoomLevel
        let title = Text(L10n.tr("changes"))
            .font(.system(size: 13 * globalZoomLevel, weight: .semibold))
            .foregroundColor(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)

        let copyButton = historyIconButton(
            systemImage: "doc.text",
            foregroundColor: .accentColor,
            background: Color.accentColor.opacity(0.15),
            help: L10n.tr("copy.content.to.clipboard")
        ) {
            if let diff = selectedCommitDiff {
                copyDiffToClipboard(diff)
            } else if let content = selectedCommitContent {
                copyContentToClipboard(content)
            }
        }

        let gitButton = historyHeaderButton(
            systemImage: "folder",
            text: L10n.tr("git.project"),
            foregroundColor: .accentColor,
            background: Color.accentColor.opacity(0.12),
            help: L10n.tr("open.git.project.in.finder"),
            action: openGitProjectInFinder
        )

        let versionButton = historyHeaderButton(
            systemImage: action?.isUndo == true ? "arrow.counterclockwise" : "clock.arrow.circlepath",
            text: isApplyingVersionAction ? action?.inProgressTitle : action?.confirmationButtonTitle,
            foregroundColor: .white,
            background: isApplyingVersionAction ? Color.secondary : Color.accentColor,
            help: isApplyingVersionAction ? (action?.inProgressHelpTitle ?? L10n.tr("restoring.version")) : (action?.helpTitle ?? L10n.tr("restore.this.version")),
            disabled: isApplyingVersionAction || action == nil,
            showsProgress: isApplyingVersionAction
        ) {
            if !isApplyingVersionAction {
                showVersionActionConfirmation = true
            }
        }

        return HStack(spacing: spacing) {
            copyButton
                .layoutPriority(3)
            title
                .layoutPriority(1)
            Spacer(minLength: 8 * globalZoomLevel)
            gitButton
                .layoutPriority(5)
            versionButton
                .layoutPriority(6)
        }
    }


    private func historyHeaderButton(
        systemImage: String,
        text: String?,
        foregroundColor: Color,
        background: Color,
        help: String,
        disabled: Bool = false,
        showsProgress: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5 * globalZoomLevel) {
                if showsProgress {
                    ProgressView()
                        .scaleEffect(0.4)
                        .frame(width: 8 * globalZoomLevel, height: 8 * globalZoomLevel)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 10 * globalZoomLevel, weight: .semibold))
                }

                if let text {
                    Text(text)
                        .font(.system(size: 11 * globalZoomLevel, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
            }
            .foregroundColor(foregroundColor)
            .frame(minWidth: text == nil ? 26 * globalZoomLevel : 44 * globalZoomLevel)
            .padding(.horizontal, (text == nil ? 6 : 8) * globalZoomLevel)
            .padding(.vertical, 4 * globalZoomLevel)
            .background(
                RoundedRectangle(cornerRadius: 6 * globalZoomLevel)
                    .fill(background)
                    .shadow(color: background.opacity(0.2), radius: 3, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(disabled)
        .fixedSize(horizontal: true, vertical: true)
        .help(help)
        .onHover { isHovering in
            DispatchQueue.main.async {
                if isHovering && !disabled {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }

    private func historyIconButton(
        systemImage: String,
        foregroundColor: Color,
        background: Color,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(background)
                    .frame(width: 22 * globalZoomLevel, height: 22 * globalZoomLevel)

                Image(systemName: systemImage)
                    .font(.system(size: 12 * globalZoomLevel, weight: .medium))
                    .foregroundColor(foregroundColor)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .help(help)
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

    private func centeredDiffStateView(spacing: CGFloat, icon: AnyView?, text: String) -> some View {
        VStack(spacing: spacing * globalZoomLevel) {
            Spacer()

            if let icon {
                icon
            }

            Text(text)
                .font(.system(size: 13 * globalZoomLevel, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 16 * globalZoomLevel)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyStateView() -> some View {
        let outerSize = 80 * globalZoomLevel
        let innerSize = 60 * globalZoomLevel
        let iconSize = 28 * globalZoomLevel
        let horizontalPadding = 24 * globalZoomLevel

        return VStack(spacing: 20 * globalZoomLevel) {
            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: outerSize, height: outerSize)

                Circle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: innerSize, height: innerSize)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 10 * globalZoomLevel) {
                Text(L10n.tr("select.a.commit"))
                    .font(.system(size: 16 * globalZoomLevel, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(L10n.tr("select.commit.description"))
                    .font(.system(size: 12 * globalZoomLevel))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, horizontalPadding)
            }

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor).opacity(0.5))
    }
    
    private func loadCommits(selecting commitHash: String? = nil) {
        commits = VersionManager.shared.getCommitHistory(for: configPath)
        print("Loaded \(commits.count) commits for \(configPath)")

        if let commitHash,
           let matchedCommit = commits.first(where: { $0.hash == commitHash }) {
            print("Selecting updated commit: \(matchedCommit.hash)")
            selectCommit(matchedCommit)
            return
        }

        if let currentSelectedHash = selectedCommit?.hash,
           let matchedCommit = commits.first(where: { $0.hash == currentSelectedHash }) {
            selectCommit(matchedCommit)
            return
        }

        if let firstCommit = commits.first {
            print("Selecting first commit: \(firstCommit.hash)")
            selectCommit(firstCommit)
        } else {
            print("No commits found")
            selectCommit(nil)
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
            selectCommit(commits[nextIndex])
        }
    }

    private func currentVersionAction() -> VersionAction? {
        guard let selectedCommit,
              let selectedIndex = commits.firstIndex(where: { $0.hash == selectedCommit.hash }) else {
            return nil
        }

        if selectedIndex == 0 {
            let previousIndex = selectedIndex + 1
            guard commits.indices.contains(previousIndex) else {
                return nil
            }
            return .undo(target: commits[previousIndex])
        }

        return .restore(target: selectedCommit)
    }

    private func performVersionAction(_ action: VersionAction) {
        guard !isApplyingVersionAction else {
            return
        }

        isApplyingVersionAction = true
        let targetCommit = action.targetCommit
        DispatchQueue.global(qos: .userInitiated).async {
            let content = VersionManager.shared.getContentForCommit(targetCommit, for: configPath)

            DispatchQueue.main.async {
                if let content {
                    onApplyVersion(content, targetCommit.hash, action.isUndo)
                    showVersionActionSuccess(action)
                }
                self.isApplyingVersionAction = false
            }
        }
    }

    private func selectCommit(_ commit: Commit?) {
        let previousHash = selectedCommit?.hash
        selectedCommit = commit

        guard let commit else {
            selectedCommitContent = nil
            selectedCommitDiff = nil
            isLoadingDiff = false
            return
        }

        guard previousHash != commit.hash || selectedCommitContent == nil else {
            return
        }

        loadCommitDetails(commit)
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
    
    private func showVersionActionSuccess(_ action: VersionAction) {
        print(action.successMessage)
    }

    private func openGitProjectInFinder() {
        guard let projectRootURL = VersionManager.shared.getGitProjectRoot(for: configPath) else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([projectRootURL])
    }
}
