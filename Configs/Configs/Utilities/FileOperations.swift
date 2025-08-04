//
//  FileOperations.swift
//  Configs
//
//  Created by cxy on 2025/7/7.
//

import Foundation
import AppKit
import SwiftUI

struct FileOperations {
    static func saveFileContent(file: ConfigFile, content: String, onSaveSuccess: @escaping (Date) -> Void) {
        do {
            try content.write(toFile: file.path, atomically: true, encoding: .utf8)
            // Update modification date after saving
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            if let modDate = attributes[.modificationDate] as? Date {
                onSaveSuccess(modDate)
            }
            
            // Check if it's a Zsh or Bash config file and auto-source it
            if file.path.hasSuffix(".zshrc") || file.path.hasSuffix(".bashrc") || file.path.hasSuffix(".bash_profile") {
                let shell = file.path.hasSuffix(".zshrc") ? "zsh" : "bash"
                let sourceCommand = "source \(file.path)"
                executeShellCommand(command: sourceCommand, shell: shell)
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
    
    static func saveFileContentWithVersioning(file: ConfigFile, content: String, originalContent: String, cursorLine: String? = nil, onSaveSuccess: @escaping (Date, String) -> Void) {
        do {
            try content.write(toFile: file.path, atomically: true, encoding: .utf8)
            // Update modification date after saving
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            if let modDate = attributes[.modificationDate] as? Date {
                onSaveSuccess(modDate, content) // Pass the new content as the new original
            }
            
            // Version control for all config files - commit only if content has changed
            VersionManager.shared.commitIfChanged(content: content, originalContent: originalContent, for: file.path, cursorLine: cursorLine)
            
            // Check if it's a Zsh or Bash config file and auto-source it
            if file.path.hasSuffix(".zshrc") || file.path.hasSuffix(".bashrc") || file.path.hasSuffix(".bash_profile") {
                let shell = file.path.hasSuffix(".zshrc") ? "zsh" : "bash"
                let sourceCommand = "source \(file.path)"
                executeShellCommand(command: sourceCommand, shell: shell)
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
    
    
    
    static func loadAndSetFileContent(file: ConfigFile, fileContent: Binding<String>, fileSize: Binding<Int64>, fileModificationDate: Binding<Date?>) {
        fileContent.wrappedValue = "Loading content..."
        Task {
            var content: String = ""
            var currentFileSize: Int64 = 0
            var currentFileModificationDate: Date? = nil
            let url = URL(fileURLWithPath: file.path)
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                currentFileSize = attributes[.size] as? Int64 ?? 0
                currentFileModificationDate = attributes[.modificationDate] as? Date
                
                let data = try Data(contentsOf: url)
                if let str = String(data: data, encoding: .utf8) {
                    content = str
                } else if let str = String(data: data, encoding: .isoLatin1) {
                    content = str
                } else if let str = String(data: data, encoding: .ascii) {
                    content = str
                } else {
                    content = "Unable to read content with common encodings. File may be binary or in a special format."
                }
            } catch {
                content = "Failed to read file content: \(error.localizedDescription)"
            }
            await MainActor.run { [content, currentFileSize, currentFileModificationDate] in
                fileContent.wrappedValue = content
                fileSize.wrappedValue = currentFileSize
                fileModificationDate.wrappedValue = currentFileModificationDate
            }
        }
    }
    
    static func loadAndSetFileContent(file: ConfigFile, fileContent: Binding<String>, originalFileContent: Binding<String>, fileSize: Binding<Int64>, fileModificationDate: Binding<Date?>) {
        fileContent.wrappedValue = "Loading content..."
        Task {
            var content: String = ""
            var currentFileSize: Int64 = 0
            var currentFileModificationDate: Date? = nil
            let url = URL(fileURLWithPath: file.path)
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                currentFileSize = attributes[.size] as? Int64 ?? 0
                currentFileModificationDate = attributes[.modificationDate] as? Date
                
                let data = try Data(contentsOf: url)
                if let str = String(data: data, encoding: .utf8) {
                    content = str
                } else if let str = String(data: data, encoding: .isoLatin1) {
                    content = str
                } else if let str = String(data: data, encoding: .ascii) {
                    content = str
                } else {
                    content = "Unable to read content with common encodings. File may be binary or in a special format."
                }
            } catch {
                content = "Failed to read file content: \(error.localizedDescription)"
            }
            await MainActor.run { [content, currentFileSize, currentFileModificationDate] in
                fileContent.wrappedValue = content
                originalFileContent.wrappedValue = content // Set original content for change detection
                fileSize.wrappedValue = currentFileSize
                fileModificationDate.wrappedValue = currentFileModificationDate
            }
        }
    }
    
    static func executeShellCommand(command: String, shell: String) {
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", "\(shell) -c '\(command)'"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print("Shell command output: \(output)")
            }
        } catch {
            print("Failed to execute shell command: \(error)")
        }
    }
    
  



    static func copyPathToClipboard(_ path: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
    }
    
    static func openInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
    

    static func openInCode(_ path: String) {
        let fileURL = URL(fileURLWithPath: path)
        let appURL = URL(fileURLWithPath: "/Applications/Visual Studio Code.app")
        
        NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: .init()) { (app, error) in
            if app == nil {
                // 如果通过 NSWorkspace 打开失败，尝试使用命令行方式
                let process = Process()
                process.launchPath = "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
                process.arguments = [path]
                do {
                    try process.run()
                } catch {
                    print("Failed to open in VS Code: \(error)")
                }
            }
        }
    }
    

    static func openInCursor(_ path: String) {
        let fileURL = URL(fileURLWithPath: path)
        let appURL = URL(fileURLWithPath: "/Applications/Cursor.app")
        
        NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: .init()) { (app, error) in
            if app == nil {
                let process = Process()
                process.launchPath = "/Applications/Cursor.app/Contents/MacOS/Cursor"
                process.arguments = [path]
                do {
                    try process.run()
                } catch {
                    print("Failed to open in Cursor: \(error)")
                }
            }
        }
    }
    
    static func openInTerminal(_ path: String) {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: path, isDirectory: &isDirectory)

        let directoryPath: String
        if exists && isDirectory.boolValue {
            directoryPath = path
        } else {
            directoryPath = URL(fileURLWithPath: path).deletingLastPathComponent().path
        }

        let terminalApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") != nil ? "iTerm" : "Terminal"

        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["-a", terminalApp, directoryPath]
        
        do {
            try process.run()
        } catch {
            print("Failed to open in terminal: \(error)")
        }
    }
}
