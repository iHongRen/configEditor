//
//  SidebarView.swift
//  Configs
//
//  Created by cxy on 2025/7/7.
//

import SwiftUI


struct SidebarView: View {
    @ObservedObject var configManager: ConfigManager
    @Binding var selectedFile: ConfigFile?
    @Binding var searchText: String
    @Binding var showFileImporter: Bool
    @Binding var globalZoomLevel: Double
    @Binding var contextMenuFile: ConfigFile?
    @Binding var showDeleteAlert: Bool
    @Binding var fileContent: String
    @Binding var originalFileContent: String
    @Binding var fileSize: Int64
    @Binding var fileModificationDate: Date?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                ZStack {
                    TextField("Search config file...", text: $searchText, prompt: Text("Search config files..."))
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.leading, 12)
                        .disableAutocorrection(true)
                        .frame(height: 28 * globalZoomLevel)
                        .font(.system(size: 13 * globalZoomLevel))
                    
                    if !searchText.isEmpty {
                        HStack {
                            Spacer()
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 24 * globalZoomLevel, height: 28 * globalZoomLevel)
                            .padding(.trailing, 2)
                        }
                    }
                }
                .frame(height: 40 * globalZoomLevel)
                
                Button(action: { showFileImporter = true }) {
                    Image(systemName: "plus.circle")
                        .resizable()
                        .frame(width: 20 * globalZoomLevel, height: 20 * globalZoomLevel)
                        .foregroundColor(.accentColor)
                        .help("Add custom config file")
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 12)
            }
            
            List(selection: $selectedFile) {
                let filteredFiles = configManager.configFiles.filter { file in
                    searchText.isEmpty || file.name.localizedCaseInsensitiveContains(searchText) || file.path.localizedCaseInsensitiveContains(searchText)
                }
                if filteredFiles.isEmpty {
                    Text("No config files found")
                        .font(.system(size: 13 * globalZoomLevel))
                } else {
                    ForEach(filteredFiles) { file in
                        HStack {
                            Text(file.name)
                                .font(.system(size: 13 * globalZoomLevel))
                            Spacer()
                            if file.isPinned {
                                Image(systemName: "pin.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 13 * globalZoomLevel))
                            }
                        }
                        .help(file.path)
                        .padding(.vertical, 4 * globalZoomLevel)
                        .padding(.horizontal, 8 * globalZoomLevel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            (selectedFile == file) ? Color.accentColor.opacity(0.3) : (file.isPinned ? Color.accentColor.opacity(0.1) : Color.clear)
                        )
                        .cornerRadius(6)
                        .tag(file as ConfigFile?)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFile = file
                            FileOperations.loadAndSetFileContent(file: file, fileContent: $fileContent, originalFileContent: $originalFileContent, fileSize: $fileSize, fileModificationDate: $fileModificationDate)
                        }
                        .contextMenu {
                            Button(action: {
                                configManager.togglePin(for: file)
                            }) {
                                HStack {
                                    Image(systemName: file.isPinned ? "pin.slash" : "pin")
                                    Text(file.isPinned ? "Unpin" : "Pin")
                                }
                            }
                            
                            Button(action: {
                                FileOperations.copyPathToClipboard(file.path)
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy Path")
                                }
                            }
                            
                            Button(action: {
                                FileOperations.openInFinder(file.path)
                            }) {
                                HStack {
                                    Image(systemName: "folder")
                                    Text("Open in Finder")
                                }
                            }
                            
                            Button(action: {
                                FileOperations.openInCode(file.path)
                            }) {
                                HStack {
                                    Image(systemName: "highlighter")
                                    Text("Open in VSCode")
                                }
                            }
                            
                            Button(action: {
                                FileOperations.openInCursor(file.path)
                            }) {
                                HStack {
                                    Image(systemName: "rectangle.and.pencil.and.ellipsis")
                                    Text("Open in Cursor")
                                }
                            }
                            
                            Button(action: {
                                FileOperations.openInTerminal(file.path)
                            }) {
                                HStack {
                                    Image(systemName: "terminal")
                                    Text("Open in Terminal")
                                }
                            }
                            
                            Button(role: .destructive, action: {
                                contextMenuFile = file
                                showDeleteAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete")
                                }
                            }
                        }
                    }
                }
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
                        FileOperations.loadAndSetFileContent(file: newConfig, fileContent: $fileContent, originalFileContent: $originalFileContent, fileSize: $fileSize, fileModificationDate: $fileModificationDate)
                    }
                }
            default:
                break
            }
        }
    }
}
