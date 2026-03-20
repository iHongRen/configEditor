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
        static let deletedAutoDiscoveredPaths = "deletedAutoDiscoveredPaths"
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

    private func loadDeletedAutoDiscoveredPaths() -> Set<String> {
        let paths = UserDefaults.standard.stringArray(forKey: StorageKeys.deletedAutoDiscoveredPaths) ?? []
        return Set(paths)
    }

    private func saveDeletedAutoDiscoveredPaths(_ paths: Set<String>) {
        UserDefaults.standard.set(Array(paths).sorted(), forKey: StorageKeys.deletedAutoDiscoveredPaths)
    }

    private func loadGroups() {
        if let groupDicts = UserDefaults.standard.array(forKey: StorageKeys.configGroups) as? [[String: Any]] {
            groups = groupDicts.compactMap { ConfigGroup.fromDictionary($0) }
        }
        selectedGroupID = UserDefaults.standard.string(forKey: StorageKeys.selectedGroupID)
    }

    private func setupInitialConfigs() {
        let scannedConfigs = scanHomeDirectoryConfigFiles()
        let scannedPaths = Set(scannedConfigs.map(\.path))
        let deletedPaths = loadDeletedAutoDiscoveredPaths()

        let savedConfigs: [ConfigFile]
        if let configDicts = UserDefaults.standard.array(forKey: StorageKeys.allConfigs) as? [[String: Any]] {
            savedConfigs = configDicts.compactMap { ConfigFile.fromDictionary($0) }
        } else {
            savedConfigs = []
        }

        let existingSavedConfigs = savedConfigs.filter { FileManager.default.fileExists(atPath: $0.path) }
        let migratedConfigs = existingSavedConfigs.filter { file in
            if file.isCustom {
                return true
            }
            return scannedPaths.contains(file.path) && !deletedPaths.contains(file.path)
        }

        var mergedConfigs = migratedConfigs
        let existingPaths = Set(mergedConfigs.map(\.path))

        for scannedConfig in scannedConfigs {
            guard !existingPaths.contains(scannedConfig.path),
                  !deletedPaths.contains(scannedConfig.path) else {
                continue
            }
            mergedConfigs.append(scannedConfig)
        }

        configFiles = mergedConfigs
        sortConfigFiles()
        saveAllConfigs()
    }

    private func scanHomeDirectoryConfigFiles() -> [ConfigFile] {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let fileManager = FileManager.default
        guard let itemURLs = try? fileManager.contentsOfDirectory(
            at: homeURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        var discoveredPaths = Set<String>()

        for itemURL in itemURLs {
            let itemName = itemURL.lastPathComponent
            let values = try? itemURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])

            if values?.isRegularFile == true, matchesAutoDiscoveredFileName(itemName) {
                discoveredPaths.insert(itemURL.path)
            }

            if values?.isDirectory == true, itemName.hasPrefix(".") {
                discoveredPaths.formUnion(scanOneLevel(in: itemURL))
            }
        }

        return discoveredPaths
            .map { path in
                ConfigFile(name: URL(fileURLWithPath: path).lastPathComponent, path: path, isCustom: false)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func scanOneLevel(in directoryURL: URL) -> Set<String> {
        let fileManager = FileManager.default
        guard let itemURLs = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        return Set(
            itemURLs.compactMap { itemURL in
                let values = try? itemURL.resourceValues(forKeys: [.isRegularFileKey])
                guard values?.isRegularFile == true,
                      matchesAutoDiscoveredFileName(itemURL.lastPathComponent) else {
                    return nil
                }
                return itemURL.path
            }
        )
    }

    private func matchesAutoDiscoveredFileName(_ name: String) -> Bool {
        let lowercasedName = name.lowercased()
        guard name != ".DS_Store" else {
            return false
        }
        return name.hasPrefix(".") || lowercasedName.contains("config")
    }

    private func isAutoDiscoveredConfigPath(_ path: String) -> Bool {
        let homePath = NSHomeDirectory()
        let homeURL = URL(fileURLWithPath: homePath, isDirectory: true)
        let fileURL = URL(fileURLWithPath: path)
        let standardizedFileURL = fileURL.standardizedFileURL
        let parentURL = standardizedFileURL.deletingLastPathComponent()
        let fileName = standardizedFileURL.lastPathComponent

        if parentURL == homeURL.standardizedFileURL {
            return matchesAutoDiscoveredFileName(fileName)
        }

        let grandparentURL = parentURL.deletingLastPathComponent()
        return grandparentURL == homeURL.standardizedFileURL
            && parentURL.lastPathComponent.hasPrefix(".")
            && matchesAutoDiscoveredFileName(fileName)
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
            return L10n.tr("all.groups")
        }
        return groups.first(where: { $0.id == groupID })?.name ?? L10n.tr("unknown.group")
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
            if isAutoDiscoveredConfigPath(newConfig.path) {
                var deletedPaths = loadDeletedAutoDiscoveredPaths()
                deletedPaths.remove(newConfig.path)
                saveDeletedAutoDiscoveredPaths(deletedPaths)
            }
            configFiles.append(newConfig)
            sortConfigFiles()
            saveAllConfigs()
        }
    }
    
    func deleteConfigFile(_ file: ConfigFile) {
        if let index = configFiles.firstIndex(where: { $0.id == file.id }) {
            if isAutoDiscoveredConfigPath(file.path) {
                var deletedPaths = loadDeletedAutoDiscoveredPaths()
                deletedPaths.insert(file.path)
                saveDeletedAutoDiscoveredPaths(deletedPaths)
            }
            configFiles.remove(at: index)
            saveAllConfigs()
        }
    }
}
