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
        print("🔄 VersionManager.commit called for: \(configPath)")
        let repoURL = getRepositoryURL(for: configPath)
        print("📁 Repository URL: \(repoURL.path)")
        
        initializeRepository(for: configPath)

        let fileURL = repoURL.appendingPathComponent("config")
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Content written to: \(fileURL.path)")
        } catch {
            print("❌ Failed to write content to temp file for commit: \(error)")
            return
        }

        let addResult = runGitCommand(args: ["add", "config"], in: repoURL)
        if addResult.status != 0 {
            print("❌ Git add failed: \(addResult.error ?? "Unknown error")")
            return
        } else {
            print("✅ Git add successful")
        }
        
        let commitMessage = "Update at \(Date().formatted(date: .numeric, time: .shortened))"
        // Allow empty commits to ensure every save creates a version
        let commitResult = runGitCommand(args: ["commit", "--allow-empty", "-m", commitMessage], in: repoURL)
        if commitResult.status != 0 {
            print("❌ Git commit failed: \(commitResult.error ?? "Unknown error")")
        } else {
            print("✅ Successfully committed changes for \(configPath)")
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
        let showResult = runGitCommand(args: ["show", "\(commit.hash):config"], in: repoURL)
        
        if showResult.status != 0 {
            print("Git show failed: \(showResult.error ?? "Unknown error")")
            return nil
        }
        return showResult.output
    }

    func getDiffForCommit(_ commit: Commit, for configPath: String) -> String? {
        let repoURL = getRepositoryURL(for: configPath)
        // Diff against the parent commit (HEAD^)
        let diffResult = runGitCommand(args: ["diff", "\(commit.hash)^", commit.hash, "--", "config"], in: repoURL)

        if diffResult.status != 0 {
            // If it's the first commit, there's no parent to diff with.
            // In this case, we show the full content of the initial commit.
            if let error = diffResult.error, error.contains("unknown revision") {
                return getContentForCommit(commit, for: configPath)
            }
            print("Git diff failed: \(diffResult.error ?? "Unknown error")")
            return "Could not load diff."
        }
        return diffResult.output
    }
}
