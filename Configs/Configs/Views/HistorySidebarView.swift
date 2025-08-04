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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
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
            
            Divider()
            
            // Commit list
            List(commits, selection: $selectedCommit) { commit in
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
            .listStyle(SidebarListStyle())
            
            if let commit = selectedCommit {
                Divider()
                
                // Changes view
                ScrollView {
                    if let diff = selectedCommitDiff {
                        DiffTextView(diffString: diff, fontSize: 11 * globalZoomLevel)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
                
                Divider()
                
                // Action buttons
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
            } else {
                Spacer()
                
                Text("Select a commit to see details")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13 * globalZoomLevel))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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