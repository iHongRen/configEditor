//
//  DiffTextView.swift
//  Configs
//
//  Created by cxy on 2025/8/3.
//

import SwiftUI
import AppKit

struct DiffTextView: View {
    let diffString: String
    var fontSize: CGFloat = 12

    private var attributedString: AttributedString {
        var result = AttributedString()
        let lines = diffString.split(separator: "\n", omittingEmptySubsequences: false)
        
        for (index, line) in lines.enumerated() {
            let lineString = String(line)
            var attributedLine = AttributedString(lineString)
            
            // Set color based on line type
            if lineString.starts(with: "+") {
                attributedLine.foregroundColor = .green
            } else if lineString.starts(with: "-") {
                attributedLine.foregroundColor = .red
            } else if lineString.starts(with: "@@") {
                attributedLine.foregroundColor = .cyan
            } else {
                attributedLine.foregroundColor = .primary
            }
            
            result.append(attributedLine)
            
            // Add newline except for the last line
            if index < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }
        
        return result
    }

    var body: some View {
        ScrollView {
            Text(attributedString)
                .font(.system(size: fontSize, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .background(Color(NSColor.textBackgroundColor))
        .contextMenu {
            Button("Copy Diff") {
                copyDiffToClipboard()
            }
        }
    }
    
    private func copyDiffToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diffString, forType: .string)
    }
}
