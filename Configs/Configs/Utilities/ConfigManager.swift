//
//  ConfigManager.swift
//  Configs
//
//  Created by cxy on 2025/7/7.
//

import Foundation


class ConfigManager: ObservableObject {
    private enum StorageKeys {
        static let allConfigs = "allConfigs"
        static let configGroups = "configGroups"
        static let selectedGroupID = "selectedConfigGroupID"
    }

    @Published var configFiles: [ConfigFile] = []
    @Published var groups: [ConfigGroup] = []
    @Published var selectedGroupID: String? = nil {
        didSet {
            saveSelectedGroupID()
        }
    }

    init() {
        loadGroups()
        setupInitialConfigs()
        normalizeGroupState()
    }

    private func saveAllConfigs() {
        let configDicts = configFiles.map { $0.toDictionary() }
        UserDefaults.standard.set(configDicts, forKey: StorageKeys.allConfigs)
    }

    private func saveGroups() {
        let groupDicts = groups.map { $0.toDictionary() }
        UserDefaults.standard.set(groupDicts, forKey: StorageKeys.configGroups)
    }

    private func saveSelectedGroupID() {
        if let selectedGroupID {
            UserDefaults.standard.set(selectedGroupID, forKey: StorageKeys.selectedGroupID)
        } else {
            UserDefaults.standard.removeObject(forKey: StorageKeys.selectedGroupID)
        }
    }

    private func loadGroups() {
        if let groupDicts = UserDefaults.standard.array(forKey: StorageKeys.configGroups) as? [[String: Any]] {
            groups = groupDicts.compactMap { ConfigGroup.fromDictionary($0) }
        }
        selectedGroupID = UserDefaults.standard.string(forKey: StorageKeys.selectedGroupID)
    }

    private func setupInitialConfigs() {
        // Try loading from "allConfigs" first
        if let configDicts = UserDefaults.standard.array(forKey: StorageKeys.allConfigs) as? [[String: Any]], !configDicts.isEmpty {
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

    private func normalizeGroupState() {
        let validGroupIDs = Set(groups.map(\.id))
        var needsSave = false

        for index in configFiles.indices {
            if let groupID = configFiles[index].groupID, !validGroupIDs.contains(groupID) {
                configFiles[index].groupID = nil
                needsSave = true
            }
        }

        if let selectedGroupID, !validGroupIDs.contains(selectedGroupID) {
            self.selectedGroupID = nil
        }

        if needsSave {
            saveAllConfigs()
        }
    }

    func visibleFiles(searchText: String) -> [ConfigFile] {
        configFiles.filter { file in
            let matchesGroup = selectedGroupID == nil || file.groupID == selectedGroupID
            let matchesSearch = searchText.isEmpty
                || file.name.localizedCaseInsensitiveContains(searchText)
                || file.path.localizedCaseInsensitiveContains(searchText)
            return matchesGroup && matchesSearch
        }
    }

    func groupName(for groupID: String?) -> String {
        guard let groupID else {
            return "全部"
        }
        return groups.first(where: { $0.id == groupID })?.name ?? "未知分组"
    }

    func selectGroup(_ groupID: String?) {
        selectedGroupID = groupID
    }

    @discardableResult
    func addGroup(name: String) -> ConfigGroup? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return nil
        }

        let group = ConfigGroup(name: trimmedName)
        groups.append(group)
        saveGroups()
        return group
    }

    func updateGroup(id: String, name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let index = groups.firstIndex(where: { $0.id == id }) else {
            return
        }

        groups[index].name = trimmedName
        saveGroups()
    }

    func deleteGroup(id: String) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else {
            return
        }

        groups.remove(at: index)

        for fileIndex in configFiles.indices where configFiles[fileIndex].groupID == id {
            configFiles[fileIndex].groupID = nil
        }

        if selectedGroupID == id {
            selectedGroupID = nil
        }

        saveGroups()
        saveAllConfigs()
    }

    func moveGroup(from sourceID: String, to destinationID: String) {
        guard sourceID != destinationID,
              let sourceIndex = groups.firstIndex(where: { $0.id == sourceID }),
              let destinationIndex = groups.firstIndex(where: { $0.id == destinationID }) else {
            return
        }

        let movingGroup = groups.remove(at: sourceIndex)
        let targetIndex = sourceIndex < destinationIndex ? destinationIndex - 1 : destinationIndex
        groups.insert(movingGroup, at: targetIndex)
        saveGroups()
    }

    func moveGroupToEnd(_ sourceID: String) {
        guard let sourceIndex = groups.firstIndex(where: { $0.id == sourceID }) else {
            return
        }

        let movingGroup = groups.remove(at: sourceIndex)
        groups.append(movingGroup)
        saveGroups()
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

    func moveFile(_ file: ConfigFile, to groupID: String?) {
        if let index = configFiles.firstIndex(where: { $0.id == file.id }) {
            configFiles[index].groupID = groupID
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
