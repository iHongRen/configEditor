//
//  HistoryView.swift
//  Configs
//
//  Created by cxy on 2025/8/1.
//

import SwiftUI

struct HistoryView: View {
    let configPath: String
    @State private var commits: [Commit] = []
    var onRestore: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text("Version History for \(URL(fileURLWithPath: configPath).lastPathComponent)")
                .font(.headline)
                .padding()

            List(commits) { commit in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(commit.message).bold()
                        Text("Commit: \(commit.hash.prefix(7))")
                            .font(.system(.body, design: .monospaced))
                        Text("Date: \(commit.date)")
                    }
                    Spacer()
                    Button("Restore") {
                        if let content = VersionManager.shared.getContentForCommit(commit, for: configPath) {
                            onRestore(content)
                            dismiss()
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .onAppear {
            self.commits = VersionManager.shared.getCommitHistory(for: configPath)
        }
        .frame(minWidth: 450, minHeight: 300)
    }
}
