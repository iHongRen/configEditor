//
//  VersionManager.swift
//  Configs
//
//  Created by cxy on 2025/8/1.
//

import Foundation

struct Commit: Identifiable, Hashable {
    let id = UUID()
    let hash: String
    let message: String
    let date: String
}

class VersionManager {
    static let shared = VersionManager()
    private let fileManager = FileManager.default
    private var versionsDirectory: URL

    private init() {
        guard let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to find application support directory.")
        }
        self.versionsDirectory = applicationSupport.appendingPathComponent("Configs/versions")
        try? fileManager.createDirectory(at: self.versionsDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    private func getRepositoryURL(for configPath: String) -> URL {
        let safeFileName = URL(fileURLWithPath: configPath).lastPathComponent.replacingOccurrences(of: ".", with: "_")
        return versionsDirectory.appendingPathComponent(safeFileName)
    }
    
    private func getOriginalFileName(for configPath: String) -> String {
        return URL(fileURLWithPath: configPath).lastPathComponent
    }

    private func runGitCommand(args: [String], in directory: URL) -> (output: String?, error: String?, status: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = directory

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            process.waitUntilExit()
            
            let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let error = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return (output, error, process.terminationStatus)
        } catch {
            return (nil, "Failed to run git process: \(error.localizedDescription)", -1)
        }
    }

    func initializeRepository(for configPath: String) {
        let repoURL = getRepositoryURL(for: configPath)
        if !fileManager.fileExists(atPath: repoURL.appendingPathComponent(".git").path) {
            do {
                try fileManager.createDirectory(at: repoURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create repository directory: \(error)")
                return
            }
            
            let initResult = runGitCommand(args: ["init"], in: repoURL)
            if initResult.status != 0 {
                print("Git init failed: \(initResult.error ?? "Unknown error")")
                return
            }
            
            // Configure user info locally for this repo to ensure commits can be made
            let nameResult = runGitCommand(args: ["config", "user.name", "Configs App"], in: repoURL)
            if nameResult.status != 0 {
                print("Git config user.name failed: \(nameResult.error ?? "Unknown error")")
            }
            
            let emailResult = runGitCommand(args: ["config", "user.email", "configs@app.local"], in: repoURL)
            if emailResult.status != 0 {
                print("Git config user.email failed: \(emailResult.error ?? "Unknown error")")
            }
            
            print("Initialized git repository for \(configPath) at \(repoURL.path)")
        }
    }

    func commit(content: String, for configPath: String) {
        let repoURL = getRepositoryURL(for: configPath)
        let fileName = getOriginalFileName(for: configPath)
        initializeRepository(for: configPath)

        let fileURL = repoURL.appendingPathComponent(fileName)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write content to temp file for commit: \(error)")
            return
        }

        let addResult = runGitCommand(args: ["add", fileName], in: repoURL)
        if addResult.status != 0 {
            print("Git add failed: \(addResult.error ?? "Unknown error")")
            return
        }
        
        let commitMessage = "Update at \(Date().formatted(date: .numeric, time: .shortened))"
        // Allow empty commits to ensure every save creates a version
        let commitResult = runGitCommand(args: ["commit", "--allow-empty", "-m", commitMessage], in: repoURL)
        if commitResult.status != 0 {
            print("Git commit failed: \(commitResult.error ?? "Unknown error")")
        }
    }
    
    func commitIfChanged(content: String, originalContent: String, for configPath: String) {
        // Only commit if content has actually changed
        guard content != originalContent else {
            print("No changes detected, skipping commit for \(configPath)")
            return
        }
        
        let repoURL = getRepositoryURL(for: configPath)
        let fileName = getOriginalFileName(for: configPath)
        initializeRepository(for: configPath)

        let fileURL = repoURL.appendingPathComponent(fileName)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write content to temp file for commit: \(error)")
            return
        }

        let addResult = runGitCommand(args: ["add", fileName], in: repoURL)
        if addResult.status != 0 {
            print("Git add failed: \(addResult.error ?? "Unknown error")")
            return
        }
        
        let commitMessage = "Update at \(Date().formatted(date: .numeric, time: .shortened))"
        let commitResult = runGitCommand(args: ["commit", "-m", commitMessage], in: repoURL)
        if commitResult.status != 0 {
            print("Git commit failed: \(commitResult.error ?? "Unknown error")")
        } else {
            print("Successfully committed changes for \(configPath)")
        }
    }

    func getCommitHistory(for configPath: String) -> [Commit] {
        let repoURL = getRepositoryURL(for: configPath)
        guard fileManager.fileExists(atPath: repoURL.appendingPathComponent(".git").path) else {
            return []
        }

        let logResult = runGitCommand(args: ["log", "--pretty=format:%H,%ad,%s", "--date=short"], in: repoURL)
        
        if logResult.status != 0 {
            print("Git log failed: \(logResult.error ?? "Unknown error")")
            return []
        }
        
        guard let logOutput = logResult.output, !logOutput.isEmpty else {
            return []
        }
        
        return logOutput.split(separator: "\n").compactMap { line -> Commit? in
            let parts = line.split(separator: ",", maxSplits: 2)
            guard parts.count == 3 else { return nil }
            return Commit(hash: String(parts[0]), message: String(parts[2]), date: String(parts[1]))
        }
    }

    func getContentForCommit(_ commit: Commit, for configPath: String) -> String? {
        let repoURL = getRepositoryURL(for: configPath)
        let fileName = getOriginalFileName(for: configPath)
        let showResult = runGitCommand(args: ["show", "\(commit.hash):\(fileName)"], in: repoURL)
        
        if showResult.status != 0 {
            print("Git show failed: \(showResult.error ?? "Unknown error")")
            return nil
        }
        return showResult.output
    }

    func getDiffForCommit(_ commit: Commit, for configPath: String) -> String? {
        let repoURL = getRepositoryURL(for: configPath)
        
        // First, check if this is the first commit by trying to get parent commits
        let parentResult = runGitCommand(args: ["rev-list", "--parents", "-n", "1", commit.hash], in: repoURL)
        
        if parentResult.status == 0, let output = parentResult.output {
            let parts = output.split(separator: " ")
            if parts.count == 1 {
                // This is the first commit (no parents), show the full content as diff
                if let content = getContentForCommit(commit, for: configPath) {
                    // Format as a diff showing all lines as additions
                    let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
                    let diffLines = lines.map { "+\($0)" }
                    return diffLines.joined(separator: "\n")
                }
                return "Initial commit - no changes to show"
            }
        }
        
        // Not the first commit, do normal diff
        let fileName = getOriginalFileName(for: configPath)
        let diffResult = runGitCommand(args: ["diff", "\(commit.hash)^", commit.hash, "--", fileName], in: repoURL)

        if diffResult.status != 0 {
            print("Git diff failed: \(diffResult.error ?? "Unknown error")")
            return "Could not load diff."
        }
        return diffResult.output
    }
}
