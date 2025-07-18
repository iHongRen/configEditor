//
//  ContentView.swift
//  Configs
//
//  Created by cxy on 2025/5/18.
//

import SwiftUI
import Foundation


struct ContentView: View {

    @StateObject private var configManager = ConfigManager()
    @State private var selectedFile: ConfigFile?
    @State private var fileContent: String = ""
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
    

    var body: some View {
        NavigationSplitView {
            SidebarView(
                configManager: configManager,
                selectedFile: $selectedFile,
                searchText: $searchText,
                showFileImporter: $showFileImporter,
                globalZoomLevel: $globalZoomLevel,
                contextMenuFile: $contextMenuFile,
                showDeleteAlert: $showDeleteAlert,
                fileContent: $fileContent,
                fileSize: $fileSize,
                fileModificationDate: $fileModificationDate
            )
            .frame(minWidth: 200 * globalZoomLevel)
            
        } detail: {
            DetailContentView(
                fileContent: $fileContent,
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
                colorSchemeOption: $colorSchemeOption
            )
        }
        .frame(minWidth: 600 * globalZoomLevel, minHeight: 400 * globalZoomLevel)
        .onAppear {
            configManager.sortConfigFiles()
            if let first = configManager.configFiles.first {
                selectedFile = first
                FileOperations.loadAndSetFileContent(file: first, fileContent: $fileContent, fileSize: $fileSize, fileModificationDate: $fileModificationDate)
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    let name = url.lastPathComponent
                    let path = url.path
                 
                    if !configManager.configFiles.contains(where: { $0.path == path }) {
                        let newConfig = ConfigFile(name: name, path: path, isCustom: true)
                        configManager.addConfigFile(newConfig)
                        selectedFile = newConfig
                        FileOperations.loadAndSetFileContent(file: newConfig, fileContent: $fileContent, fileSize: $fileSize, fileModificationDate: $fileModificationDate)
                    }
                }
            default:
                break
            }
        }
        .keyboardShortcutHandler(
            showEditorSearchBar: $showEditorSearchBar,
            editorSearchText: $editorSearchText,
            editorViewRef: $editorViewRef,
            searchFieldFocused: _searchFieldFocused,
            globalZoomLevel: $globalZoomLevel,
            fileContent: $fileContent,
            selectedFile: $selectedFile,
            fileModificationDate: $fileModificationDate
        )
        .alert("Delete Config File", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let file = contextMenuFile {
                    configManager.deleteConfigFile(file)
                    if selectedFile?.id == file.id {
                        selectedFile = configManager.configFiles.first
                        if let newSelectedFile = selectedFile {
                            FileOperations.loadAndSetFileContent(file: newSelectedFile, fileContent: $fileContent, fileSize: $fileSize, fileModificationDate: $fileModificationDate)
                        } else {
                            fileContent = ""
                            fileSize = 0
                            fileModificationDate = nil
                        }
                    }
                }
            }
        } message: {
            Text("Are you sure you want to remove this config file from the list?")
        }
        .preferredColorScheme(colorSchemeOption.colorScheme)
    }
}
