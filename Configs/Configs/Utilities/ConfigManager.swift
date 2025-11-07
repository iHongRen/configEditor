//
//  ConfigManager.swift
//  Configs
//
//  Created by cxy on 2025/7/7.
//

import Foundation


class ConfigManager: ObservableObject {
    @Published var configFiles: [ConfigFile] = []

    init() {
        setupInitialConfigs()
    }

    private func saveAllConfigs() {
        let configDicts = configFiles.map { $0.toDictionary() }
        UserDefaults.standard.set(configDicts, forKey: "allConfigs")
    }

    private func setupInitialConfigs() {
        // Try loading from "allConfigs" first
        if let configDicts = UserDefaults.standard.array(forKey: "allConfigs") as? [[String: Any]], !configDicts.isEmpty {
            let configs = configDicts.compactMap { ConfigFile.fromDictionary($0) }
            // Filter out files that no longer exist
            let validConfigs = configs.filter { FileManager.default.fileExists(atPath: $0.path) }
            configFiles = validConfigs
            
            // If some files were removed, update UserDefaults
            if validConfigs.count != configs.count {
                saveAllConfigs()
            }
        } else {
            // First launch or cleared data: scan the filesystem
            configFiles = CommonConfigData.scanForDefaultConfigFiles()
            // Persist the scanned files for next launch
            saveAllConfigs()
        }
    }

    func togglePin(for file: ConfigFile) {
        if let index = configFiles.firstIndex(where: { $0.id == file.id }) {
            configFiles[index].isPinned.toggle()
            sortConfigFiles()
            saveAllConfigs()
        }
    }

    /// Set or remove a tag for a given config file and persist changes.
    func setTag(_ tag: FileTag?, for file: ConfigFile) {
        if let index = configFiles.firstIndex(where: { $0.id == file.id }) {
            configFiles[index].tag = tag
            sortConfigFiles()
            saveAllConfigs()
        }
    }

    func sortConfigFiles() {
        configFiles.sort {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.name < $1.name
        }
    }
    
    func addConfigFile(_ newConfig: ConfigFile) {
        if !configFiles.contains(where: { $0.path == newConfig.path }) {
            configFiles.append(newConfig)
            sortConfigFiles()
            saveAllConfigs()
        }
    }
    
    func deleteConfigFile(_ file: ConfigFile) {
        if let index = configFiles.firstIndex(where: { $0.id == file.id }) {
            configFiles.remove(at: index)
            saveAllConfigs()
        }
    }
}
