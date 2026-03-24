//
//  ContentView.swift
//  Configs
//
//  Created by cxy on 2025/5/18.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers


struct ContentView: View {

    @StateObject private var configManager = ConfigManager()
    @ObservedObject private var localization = LocalizationSettings.shared
    @State private var selectedFile: ConfigFile?
    @State private var fileContent: String = ""
    @State private var originalFileContent: String = "" // Track original content for change detection
    @State private var searchText: String = ""
    @State private var showFileImporter: Bool = false
    @AppStorage("globalZoomLevel") private var globalZoomLevel: Double = 1.0 // Default 1.0
    @AppStorage("colorScheme") private var colorSchemeOption: ColorSchemeOption = .dark

    // Editor-related states
    @State private var editorSearchText: String = ""
    @State private var editorViewRef: CodeEditorView.Ref? = nil
    @State private var showEditorSearchBar: Bool = false
    
    @State private var fileSize: Int64 = 0
    @State private var fileModificationDate: Date? = nil
    @FocusState private var searchFieldFocused: Bool
    
    @State private var editorMatchCount: Int = 0
    @State private var editorCurrentMatchIndex: Int = 0
    
    @State private var contextMenuFile: ConfigFile?
    @State private var showDeleteAlert = false
    @State private var showHistorySidebar = false
    @State private var isDropTargeted = false

    private let fileDropTypes: [UTType] = [.fileURL]

    private func loadSelectedFile(_ file: ConfigFile?) {
        selectedFile = file

        guard let file else {
            fileContent = ""
            originalFileContent = ""
            fileSize = 0
            fileModificationDate = nil
            return
        }

        FileOperations.loadAndSetFileContent(
            file: file,
            fileContent: $fileContent,
            originalFileContent: $originalFileContent,
            fileSize: $fileSize,
            fileModificationDate: $fileModificationDate
        )
    }

    private func addCustomConfigFiles(from urls: [URL]) {
        let fileManager = FileManager.default
        let normalizedURLs = urls.map { $0.standardizedFileURL }

        if normalizedURLs.count == 1,
           let existingFile = configManager.configFiles.first(where: { $0.path == normalizedURLs[0].path }) {
            configManager.selectGroup(existingFile.groupID)
            if showHistorySidebar {
                showHistorySidebar = false
            }
            loadSelectedFile(existingFile)
            return
        }

        var lastAddedFile: ConfigFile?

        for url in normalizedURLs {
            let path = url.path
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
                  !isDirectory.boolValue,
                  !configManager.configFiles.contains(where: { $0.path == path }) else {
                continue
            }

            let newConfig = ConfigFile(
                name: url.lastPathComponent,
                path: path,
                isCustom: true,
                groupID: configManager.selectedGroupID
            )
            configManager.addConfigFile(newConfig)
            lastAddedFile = newConfig
        }

        guard let lastAddedFile else {
            return
        }

        if showHistorySidebar {
            showHistorySidebar = false
        }
        loadSelectedFile(lastAddedFile)
    }

    private func handleDroppedFileProviders(_ providers: [NSItemProvider]) -> Bool {
        let fileURLType = UTType.fileURL.identifier
        let supportedProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(fileURLType) }
        guard !supportedProviders.isEmpty else {
            return false
        }

        let group = DispatchGroup()
        var droppedURLs: [URL] = []
        let lock = NSLock()

        for provider in supportedProviders {
            group.enter()
            provider.loadItem(forTypeIdentifier: fileURLType, options: nil) { item, _ in
                defer { group.leave() }

                let resolvedURL: URL?
                if let data = item as? Data {
                    resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
                } else if let url = item as? URL {
                    resolvedURL = url
                } else if let nsData = item as? NSData {
                    resolvedURL = URL(dataRepresentation: nsData as Data, relativeTo: nil)
                } else {
                    resolvedURL = nil
                }

                guard let resolvedURL else {
                    return
                }

                lock.lock()
                droppedURLs.append(resolvedURL)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            let uniqueURLs = Array(Set(droppedURLs.map { $0.standardizedFileURL.path }))
                .map { URL(fileURLWithPath: $0) }
                .sorted { $0.path < $1.path }
            addCustomConfigFiles(from: uniqueURLs)
        }

        return true
    }

    var body: some View {
        NavigationSplitView {
            // Left sidebar - File list
            SidebarView(
                configManager: configManager,
                selectedFile: $selectedFile,
                searchText: $searchText,
                showFileImporter: $showFileImporter,
                globalZoomLevel: $globalZoomLevel,
                contextMenuFile: $contextMenuFile,
                showDeleteAlert: $showDeleteAlert,
                fileContent: $fileContent,
                originalFileContent: $originalFileContent,
                fileSize: $fileSize,
                fileModificationDate: $fileModificationDate
            )
            .navigationSplitViewColumnWidth(min: 200 * globalZoomLevel, ideal: 250 * globalZoomLevel, max: 300 * globalZoomLevel)
            .onDrop(of: fileDropTypes, isTargeted: $isDropTargeted) { providers in
                handleDroppedFileProviders(providers)
            }
        } detail: {
            // Main content area with optional right sidebar
            HStack(spacing: 0) {
                DetailContentView(
                    fileContent: $fileContent,
                    originalFileContent: $originalFileContent,
                    selectedFile: $selectedFile,
                    editorSearchText: $editorSearchText,
                    editorViewRef: $editorViewRef,
                    showEditorSearchBar: $showEditorSearchBar,
                    searchFieldFocused: _searchFieldFocused,
                    globalZoomLevel: $globalZoomLevel,
                    editorMatchCount: $editorMatchCount,
                    editorCurrentMatchIndex: $editorCurrentMatchIndex,
                    fileSize: $fileSize,
                    fileModificationDate: $fileModificationDate,
                    colorSchemeOption: $colorSchemeOption,
                    showHistorySidebar: $showHistorySidebar,
                    onFileDrop: { urls in
                        addCustomConfigFiles(from: urls)
                    },
                    onFileDragStateChanged: { isDragging in
                        isDropTargeted = isDragging
                    }
                )
                .frame(maxWidth: .infinity)
                .onDrop(of: fileDropTypes, isTargeted: $isDropTargeted) { providers in
                    handleDroppedFileProviders(providers)
                }
                
                // Right sidebar - History (conditionally shown)
                if showHistorySidebar {
                    Divider()
                    
                    if let file = selectedFile {
                        HistorySidebarView(
                            configPath: file.path,
                            showHistorySidebar: $showHistorySidebar,
                            globalZoomLevel: globalZoomLevel,
                            onRestore: { restoredContent, commitHash in
                                // 立即更新 UI，让弹窗快速消失
                                self.fileContent = restoredContent
                                self.originalFileContent = restoredContent // Update original content when restoring
                                
                                // 在后台线程执行保存操作，避免阻塞 UI
                                DispatchQueue.global(qos: .userInitiated).async {
                                    FileOperations.saveFileContentWithVersioning(
                                        file: file,
                                        content: restoredContent,
                                        originalContent: restoredContent, // Use the restored content as original
                                        cursorLine: "\(L10n.tr("restore")) \(commitHash.prefix(7))",
                                        onSaveSuccess: { newDate, newContent in
                                            DispatchQueue.main.async {
                                                self.fileModificationDate = newDate
                                                self.originalFileContent = newContent
                                            }
                                        }
                                    )
                                }
                            }
                        )
                        .frame(minWidth: 300 * globalZoomLevel, maxWidth: 400 * globalZoomLevel)
                        .onDrop(of: fileDropTypes, isTargeted: $isDropTargeted) { providers in
                            handleDroppedFileProviders(providers)
                        }
                    }
                }
            }
            .onDrop(of: fileDropTypes, isTargeted: $isDropTargeted) { providers in
                handleDroppedFileProviders(providers)
            }
        }
        .frame(minWidth: 600 * globalZoomLevel, minHeight: 400 * globalZoomLevel)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                    .padding(.horizontal, 5)
                    .padding(.top, -5)
                    .padding(.bottom, 5)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            configManager.sortConfigFiles()
            loadSelectedFile(configManager.visibleFiles(searchText: searchText).first)
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                addCustomConfigFiles(from: urls)
            default:
                break
            }
        }
        .onDrop(of: fileDropTypes, isTargeted: $isDropTargeted) { providers in
            handleDroppedFileProviders(providers)
        }
        .keyboardShortcutHandler(
            showEditorSearchBar: $showEditorSearchBar,
            editorSearchText: $editorSearchText,
            editorViewRef: $editorViewRef,
            searchFieldFocused: _searchFieldFocused,
            globalZoomLevel: $globalZoomLevel,
            fileContent: $fileContent,
            originalFileContent: $originalFileContent,
            selectedFile: $selectedFile,
            fileModificationDate: $fileModificationDate
        )
        .alert(L10n.tr("delete.config.file"), isPresented: $showDeleteAlert) {
            Button(L10n.tr("cancel"), role: .cancel) { }
            Button(L10n.tr("delete"), role: .destructive) {
                if let file = contextMenuFile {
                    configManager.deleteConfigFile(file)
                    if selectedFile?.id == file.id {
                        // Close history sidebar when deleting the currently selected file
                        if showHistorySidebar {
                            showHistorySidebar = false
                        }

                        loadSelectedFile(configManager.visibleFiles(searchText: searchText).first)
                    }
                }
            }
        } message: {
            Text(L10n.tr("are.you.sure.remove.config.file"))
        }
        .preferredColorScheme(colorSchemeOption.colorScheme)
        .compatibleOnChange(of: selectedFile) { oldFile, newFile in
            // Close history sidebar when switching to a different file
            if showHistorySidebar {
                showHistorySidebar = false
            }
        }
    }
}
