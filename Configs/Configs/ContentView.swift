//
//  ContentView.swift
//  Configs
//
//  Created by cxy on 2025/5/18.
//

import SwiftUI


import Foundation

enum ColorSchemeOption: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

struct ConfigFile: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let isCustom: Bool
    var isPinned: Bool = false
    
    // 用于 UserDefaults 存储
    static func fromDictionary(_ dict: [String: Any]) -> ConfigFile? {
        guard let name = dict["name"] as? String,
              let path = dict["path"] as? String,
              let isCustom = dict["isCustom"] as? Bool else {
            return nil
        }
        let isPinned = dict["isPinned"] as? Bool ?? false
        return ConfigFile(name: name, path: path, isCustom: isCustom, isPinned: isPinned)
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "path": path,
            "isCustom": isCustom,
            "isPinned": isPinned
        ]
    }
}

struct ContentView: View {
    // Date formatter
    private func formatModificationDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            // Show only time for today's modifications
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else {
            // Show full date and time for other dates
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy HH:mm"
            return formatter.string(from: date)
        }
    }
    
    @State private var configFiles: [ConfigFile] = []
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
    @State private var keyMonitor: Any?
    @State private var fileSize: Int64 = 0
    @State private var fileModificationDate: Date? = nil
    @FocusState private var searchFieldFocused: Bool
    
    @State private var editorMatchCount: Int = 0
    @State private var editorCurrentMatchIndex: Int = 0
    
    @State private var contextMenuFile: ConfigFile?
    @State private var showDeleteAlert = false
    
    // Automatically scan user's home directory for all hidden config files and common config directories

    

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
            configFiles = scanForDefaultConfigFiles()
            // Persist the scanned files for next launch
            saveAllConfigs()
        }
    }

    

    private func togglePin(for file: ConfigFile) {
        if let index = configFiles.firstIndex(where: { $0.id == file.id }) {
            configFiles[index].isPinned.toggle()
            sortConfigFiles()
            saveAllConfigs()
        }
    }

    private func sortConfigFiles() {
        configFiles.sort {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.name < $1.name
        }
    }

    var body: some View {
        NavigationSplitView {
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
                    let filteredFiles = configFiles.filter { file in
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
                                loadFileContent(file: file)
                            }
                            .contextMenu {
                                Button(action: {
                                    togglePin(for: file)
                                }) {
                                    HStack {
                                        Image(systemName: file.isPinned ? "pin.slash" : "pin")
                                        Text(file.isPinned ? "Unpin" : "Pin")
                                    }
                                }
                                
                                Button(action: {
                                    copyPathToClipboard(file.path)
                                }) {
                                    HStack {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy Path")
                                    }
                                }
                                
                                Button(action: {
                                    openInFinder(file.path)
                                }) {
                                    HStack {
                                        Image(systemName: "folder")
                                        Text("Open in Finder")
                                    }
                                }
                                
                                Button(action: {
                                    openInCode(file.path)
                                }) {
                                    HStack {
                                        Image(systemName: "highlighter")
                                        Text("Open in VSCode")
                                    }
                                }
                                
                                Button(action: {
                                    openInCursor(file.path)
                                }) {
                                    HStack {
                                        Image(systemName: "rectangle.and.pencil.and.ellipsis")
                                        Text("Open in Cursor")
                                    }
                                }
                                
                                Button(action: {
                                    openInTerminal(file.path)
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
                .onAppear {
                    setupInitialConfigs()
                    sortConfigFiles()
                    if let first = configFiles.first {
                        selectedFile = first
                        loadFileContent(file: first)
                    }
                   
                    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                        if event.modifierFlags.contains(.command) {
                            if event.charactersIgnoringModifiers == "f" {
                                showEditorSearchBar = true
                                DispatchQueue.main.async {
                                    searchFieldFocused = true
                                }
                                return nil
                            }
                            if event.charactersIgnoringModifiers == "s" {
                                saveFileContent()
                                return nil
                            }
                            if event.charactersIgnoringModifiers == "=" || event.charactersIgnoringModifiers == "+" {
                                globalZoomLevel = min(2.0, globalZoomLevel + 0.1) // Max zoom 2.0
                                return nil
                            }
                            if event.charactersIgnoringModifiers == "-" {
                                globalZoomLevel = max(0.5, globalZoomLevel - 0.1) // Min zoom 0.5
                                return nil
                            }
                            if event.charactersIgnoringModifiers == "0" {
                                globalZoomLevel = 1.0 // Reset zoom
                                return nil
                            }
                        }
                        if event.keyCode == 53 { // 53 = esc
                            if showEditorSearchBar {
                                showEditorSearchBar = false
                                editorSearchText = ""
                                return nil
                            }
                        }
                        if event.keyCode == 36 || event.keyCode == 76 { // Enter or Return
                            if showEditorSearchBar {
                                editorViewRef?.findNext(editorSearchText)
                                return nil
                            }
                        }
                        return event
                    }
                }
                .onDisappear {
                    if let monitor = keyMonitor {
                        NSEvent.removeMonitor(monitor)
                        keyMonitor = nil
                    }
                }
                .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            let name = url.lastPathComponent
                            let path = url.path
                         
                            if !configFiles.contains(where: { $0.path == path }) {
                                let newConfig = ConfigFile(name: name, path: path, isCustom: true)
                                configFiles.append(newConfig)
                                sortConfigFiles()
                                selectedFile = newConfig
                                loadFileContent(file: newConfig)
                                saveAllConfigs()
                            }
                        }
                    default:
                        break
                    }
                }
            }
            .frame(minWidth: 200 * globalZoomLevel)
        } detail: {
            VStack(spacing: 0) {
                if showEditorSearchBar {
                    HStack {
                        TextField("Search content...", text: $editorSearchText)
                            .frame(width: 200 * globalZoomLevel)
                            .disableAutocorrection(true)
                            .help("Search in current file (Press Enter for next)")
                            .focused($searchFieldFocused)
                            .font(.system(size: 13 * globalZoomLevel))
                            .onSubmit {
                                editorViewRef?.findNext(editorSearchText)
                            }
                            .onChange(of: editorSearchText) {
                                editorViewRef?.findNext(editorSearchText)
                            }
                        Button(action: {
                            editorViewRef?.findNext(editorSearchText)
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13 * globalZoomLevel))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Find next")
                        Button(action: {
                            editorViewRef?.findPrevious(editorSearchText)
                        }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 13 * globalZoomLevel))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Find previous")
                       
                        Text("\(editorCurrentMatchIndex) of \(editorMatchCount)")
                            .font(.system(size: 11 * globalZoomLevel))
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            showEditorSearchBar = false
                            editorSearchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13 * globalZoomLevel))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Close search")
                    }
                    .padding(.all, 5 * globalZoomLevel)
                }
               
                CodeEditorView(text: $fileContent, 
                           fileExtension: LanguageDetector.detectLanguage(selectedFile?.name), 
                           search: $editorSearchText, 
                           ref: $editorViewRef,
                           isFocused: !searchFieldFocused,
                           showSearchBar: { 
                               showEditorSearchBar = true
                               DispatchQueue.main.async {
                                   searchFieldFocused = true
                               }
                           },
                           zoomLevel: globalZoomLevel,
                           matchCount: $editorMatchCount,
                           currentMatchIndex: $editorCurrentMatchIndex)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
               
                Divider()
                HStack(spacing: 8 * globalZoomLevel) {
                    if let selectedFile = selectedFile {
                        Text(selectedFile.name)
                            .foregroundColor(.secondary)
                        Spacer()
                        if fileSize > 0 {
                            Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                                .foregroundColor(.secondary)
                        }
                        if let modDate = fileModificationDate {
                            Text("Modified \(formatModificationDate(modDate))")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .font(.system(size: 11 * globalZoomLevel))
                .padding(.horizontal, 8 * globalZoomLevel)
                .padding(.vertical, 4 * globalZoomLevel)
                .frame(height: 24 * globalZoomLevel)
            }
            .frame(minWidth: 400 * globalZoomLevel)
            .toolbar {
                Menu {
                    Picker("Appearance", selection: $colorSchemeOption) {
                        ForEach(ColorSchemeOption.allCases, id: \.self) {
                            option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(InlinePickerStyle())
                } label: {
                    Image(systemName: colorSchemeOption == .dark ? "moon.fill" : "sun.max.fill")
                        .foregroundColor(.accentColor)
                        .help("Change appearance")
                }
            }
        }
        .frame(minWidth: 600 * globalZoomLevel, minHeight: 400 * globalZoomLevel)
        .alert("Delete Config File", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let file = contextMenuFile {
                    deleteConfigFile(file)
                }
            }
        } message: {
            Text("Are you sure you want to remove this config file from the list?")
        }
        .preferredColorScheme(colorSchemeOption.colorScheme)
    }

    func saveFileContent() {
        guard let file = selectedFile else { return }
        do {
            try fileContent.write(toFile: file.path, atomically: true, encoding: .utf8)
            // Update modification date after saving
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            fileModificationDate = attributes[.modificationDate] as? Date
            
            // 检查是否为 Zsh 或 Bash 配置文件
            if file.path.hasSuffix(".zshrc") || file.path.hasSuffix(".bashrc") || file.path.hasSuffix(".bash_profile") {
                let shell = file.path.hasSuffix(".zshrc") ? "zsh" : "bash"
                let sourceCommand = "source \(file.path)"
                executeShellCommand(command: sourceCommand, shell: shell)
            }
        } catch {
            // TODO: Show save failure alert
        }
    }
    
    // 执行 shell 命令
   private func executeShellCommand(command: String, shell: String) {
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
               print(output)
           }
       } catch {
           print("Failed to execute command: \(error)")
       }
   }

    // Detect syntax highlighting language based on filename (returns extension string)
    


    func loadConfigFiles() {
        sortConfigFiles()
    }

    func loadFileContent(file: ConfigFile) {
        fileContent = "Loading content..."
        Task {
            let content: String
            let url = URL(fileURLWithPath: file.path)
            do {
                // Get file attributes
                let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                fileSize = attributes[.size] as? Int64 ?? 0
                fileModificationDate = attributes[.modificationDate] as? Date
                
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
            await MainActor.run {
                fileContent = content
            }
        }
    }

    // 复制路径到剪贴板
    private func copyPathToClipboard(_ path: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
    }
    
    // 在 Finder 中打开
    private func openInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
    
    // 在 VS Code 中打开
    private func openInCode(_ path: String) {
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
    
    // 在 Cursor 中打开
    private func openInCursor(_ path: String) {
        let fileURL = URL(fileURLWithPath: path)
        let appURL = URL(fileURLWithPath: "/Applications/Cursor.app")
        
        NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: .init()) { (app, error) in
            if app == nil {
                // 如果通过 NSWorkspace 打开失败，尝试使用命令行方式
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
    
    // 在终端中打开
    private func openInTerminal(_ path: String) {
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
    
    // 删除配置文件
    private func deleteConfigFile(_ file: ConfigFile) {
        do {
            // 如果是自定义配置，删除文件
            if file.isCustom {
                try FileManager.default.removeItem(atPath: file.path)
            }
            
            // 从列表中移除
            if let index = configFiles.firstIndex(where: { $0.id == file.id }) {
                configFiles.remove(at: index)
                if selectedFile?.id == file.id {
                    selectedFile = configFiles.first
                    if let first = configFiles.first {
                        loadFileContent(file: first)
                    } else {
                        fileContent = ""
                    }
                }
                saveAllConfigs()
            }
        } catch {
            print("Error deleting file: \(error)")
        }
    }
}
