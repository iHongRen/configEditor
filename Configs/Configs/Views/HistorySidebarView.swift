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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider()
            resizableContentView
        }
        .background(Color(NSColor.controlBackgroundColor))
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
    }
    
    private var headerView: some View {
        HStack {
            Text("Version History")
                .font(.headline)
                .font(.system(size: 16 * globalZoomLevel))
            
            Spacer()
            
            Button(action: {
                showHistorySidebar = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Close history")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var resizableContentView: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                commitListView(geometry: geometry)
                draggableDivider(geometry: geometry)
                bottomContentView(geometry: geometry)
            }
        }
    }
    
    private func commitListView(geometry: GeometryProxy) -> some View {
        List(commits, selection: $selectedCommit) { commit in
            commitRowView(commit: commit)
        }
        .listStyle(.sidebar)
        .frame(height: max(100, geometry.size.height * splitPosition))
    }
    
    private func commitRowView(commit: Commit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(commit.message)
                .font(.system(size: 13 * globalZoomLevel, weight: .medium))
                .lineLimit(2)
            
            Text(commit.hash.prefix(7))
                .font(.system(size: 11 * globalZoomLevel, design: .monospaced))
                .foregroundColor(.secondary)
            
            Text(commit.date)
                .font(.system(size: 11 * globalZoomLevel))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
        .tag(commit)
    }
    
    private func draggableDivider(geometry: GeometryProxy) -> some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.3))
            .frame(height: 6)
            .overlay(
                Rectangle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(height: 1)
            )
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
                        
                        splitPosition = max(0.2, min(0.8, newSplitPosition))
                    }
            )
    }
    
    private func bottomContentView(geometry: GeometryProxy) -> some View {
        Group {
            if selectedCommit != nil {
                diffContentView(geometry: geometry)
            } else {
                emptyStateView(geometry: geometry)
            }
        }
    }
    
    private func diffContentView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                if let diff = selectedCommitDiff {
                    DiffTextView(diffString: diff, fontSize: 11 * globalZoomLevel)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: max(50, geometry.size.height * (1 - splitPosition) - 50))
            
            Divider()
            actionButtonsView
        }
    }
    
    private var actionButtonsView: some View {
        HStack {
            Button("Copy Diff") {
                if let diff = selectedCommitDiff {
                    copyDiffToClipboard(diff)
                }
            }
            .buttonStyle(.bordered)
            .font(.system(size: 12 * globalZoomLevel))
            .disabled(selectedCommitDiff == nil)
            
            Spacer()
            
            Button("Restore this Version") {
                if let content = selectedCommitContent {
                    onRestore(content)
                }
            }
            .buttonStyle(.borderedProminent)
            .font(.system(size: 12 * globalZoomLevel))
            .disabled(selectedCommitContent == nil)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: 44)
    }
    
    private func emptyStateView(geometry: GeometryProxy) -> some View {
        VStack {
            Spacer()
            Text("Select a commit to see details")
                .foregroundColor(.secondary)
                .font(.system(size: 13 * globalZoomLevel))
            Spacer()
        }
        .frame(height: max(50, geometry.size.height * (1 - splitPosition)))
    }
    
    private func loadCommits() {
        commits = VersionManager.shared.getCommitHistory(for: configPath)
        if let firstCommit = commits.first {
            selectedCommit = firstCommit
        }
    }
    
    private func loadCommitDetails(_ commit: Commit) {
        selectedCommitContent = VersionManager.shared.getContentForCommit(commit, for: configPath)
        selectedCommitDiff = VersionManager.shared.getDiffForCommit(commit, for: configPath)
    }
    
    private func copyDiffToClipboard(_ diff: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diff, forType: .string)
    }
}

struct HistorySidebarView_Previews: PreviewProvider {
    static var previews: some View {
        HistorySidebarView(
            configPath: "/path/to/config",
            showHistorySidebar: .constant(true),
            globalZoomLevel: 1.0,
            onRestore: { _ in }
        )
        .frame(width: 300, height: 600)
    }
}