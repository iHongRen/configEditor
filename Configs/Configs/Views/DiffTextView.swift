//
//  DiffTextView.swift
//  Configs
//
//  Created by cxy on 2025/8/3.
//

import SwiftUI

struct DiffTextView: View {
    let diffString: String
    var fontSize: CGFloat = 12

    private struct DiffLine: Identifiable {
        let id = UUID()
        let text: String
        let color: Color
    }

    private var diffLines: [DiffLine] {
        diffString.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            let lineString = String(line)
            if lineString.starts(with: "+") {
                return DiffLine(text: lineString, color: .green)
            } else if lineString.starts(with: "-") {
                return DiffLine(text: lineString, color: .red)
            } else if lineString.starts(with: "@@") {
                return DiffLine(text: lineString, color: .cyan)
            } else {
                return DiffLine(text: lineString, color: .primary)
            }
        }
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 1) {
            ForEach(diffLines) { line in
                Text(line.text)
                    .foregroundColor(line.color)
                    .font(.system(size: fontSize, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 4)
        .background(Color(NSColor.textBackgroundColor))
    }
}