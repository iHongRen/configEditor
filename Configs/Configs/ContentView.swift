//
//  ContentView.swift
//  Configs
//
//  Created by cxy on 2025/5/18.
//

import SwiftUI


import Foundation

struct ConfigFile: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let isCustom: Bool
    
    // 用于 UserDefaults 存储
    static func fromDictionary(_ dict: [String: Any]) -> ConfigFile? {
        guard let name = dict["name"] as? String,
              let path = dict["path"] as? String,
              let isCustom = dict["isCustom"] as? Bool else {
            return nil
        }
        return ConfigFile(name: name, path: path, isCustom: isCustom)
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "path": path,
            "isCustom": isCustom
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

    // Editor-related states
    @State private var editorSearchText: String = ""
    @State private var editorViewRef: CodeEditorView.Ref? = nil
    @State private var showEditorSearchBar: Bool = false
    @State private var keyMonitor: Any?
    @State private var fileSize: Int64 = 0
    @State private var fileModificationDate: Date? = nil
    @FocusState private var searchFieldFocused: Bool
    
    // 添加右键菜单状态
    @State private var contextMenuFile: ConfigFile?
    @State private var showDeleteAlert = false
    
    // Automatically scan user's home directory for all hidden config files and common config directories

    // Common development configuration files covering mainstream programming languages and development tools
    let commonConfigs = [
        // Shell 
        (".zshrc", ".zshrc"), (".bashrc", ".bashrc"), (".bash_profile", ".bash_profile"), (".profile", ".profile"), (".zprofile", ".zprofile"), (".zshenv", ".zshenv"), (".zlogin", ".zlogin"), (".zlogout", ".zlogout"), (".inputrc", ".inputrc"), (".dir_colors", ".dir_colors"), (".tmux.conf", ".tmux.conf"), (".screenrc", ".screenrc"), (".nanorc", ".nanorc"), (".fzf.zsh", ".fzf.zsh"), (".fzf.bash", ".fzf.bash"),
        // Git 
        (".gitconfig", ".gitconfig"), (".gitignore", ".gitignore"), (".gitattributes", ".gitattributes"), (".hgignore", ".hgignore"), (".gitmodules", ".gitmodules"),
        // SSH & GPG
        (".ssh/config", ".ssh/config"), (".gnupg/gpg.conf", ".gnupg/gpg.conf"), (".gnupg/gpg-agent.conf", ".gnupg/gpg-agent.conf"),
        // eidt
        (".vimrc", ".vimrc"), (".viminfo", ".viminfo"), (".emacs", ".emacs"), (".spacemacs", ".spacemacs"), (".config/Code/User/settings.json", ".config/Code/User/settings.json"), (".config/Code/User/keybindings.json", ".config/Code/User/keybindings.json"), (".editorconfig", ".editorconfig"),
        // Node.js & fe
        (".npmrc", ".npmrc"), (".yarnrc", ".yarnrc"), (".nvmrc", ".nvmrc"), (".npmignore", ".npmignore"), (".prettierrc", ".prettierrc"), (".prettierignore", ".prettierignore"), (".eslintrc", ".eslintrc"), (".eslintrc.json", ".eslintrc.json"), (".eslintignore", ".eslintignore"), (".stylelintrc", ".stylelintrc"), (".stylelintignore", ".stylelintignore"), (".babelrc", ".babelrc"), (".babelrc.js", ".babelrc.js"), (".parcelrc", ".parcelrc"), (".mocharc.json", ".mocharc.json"), (".mocharc.js", ".mocharc.js"),
        // Python
        (".pythonrc", ".pythonrc"), (".pypirc", ".pypirc"), (".condarc", ".condarc"), (".jupyter/jupyter_notebook_config.py", ".jupyter/jupyter_notebook_config.py"), (".ipython/profile_default/ipython_config.py", ".ipython/profile_default/ipython_config.py"),
        // Ruby
        (".irbrc", ".irbrc"), (".pryrc", ".pryrc"), (".gemrc", ".gemrc"), (".railsrc", ".railsrc"), (".rspec", ".rspec"), (".rubocop.yml", ".rubocop.yml"), (".ruby-version", ".ruby-version"), (".ruby-gemset", ".ruby-gemset"), (".bundle/config", ".bundle/config"),
        // Java
        (".m2/settings.xml", ".m2/settings.xml"), (".gradle/gradle.properties", ".gradle/gradle.properties"), (".gradle/gradle-wrapper.properties", ".gradle/gradle-wrapper.properties"),
        // Go
        (".goenv", ".goenv"), (".gorc", ".gorc"),
        // Rust
        (".cargo/config", ".cargo/config"), (".cargo/credentials", ".cargo/credentials"),
        // PHP
        (".phpenv", ".phpenv"), (".php.ini", ".php.ini"),
        // C/C++
        (".clang-format", ".clang-format"), (".clang-tidy", ".clang-tidy"), (".gdbinit", ".gdbinit"), (".lldbinit", ".lldbinit"),
        // R
        (".Rprofile", ".Rprofile"), (".Renviron", ".Renviron"), (".Rhistory", ".Rhistory"),
        // Docker
        (".docker/config.json", ".docker/config.json"), (".dockerignore", ".dockerignore"), (".compose.yaml", ".compose.yaml"), ("docker-compose.yml", "docker-compose.yml"),
        // db
        (".my.cnf", ".my.cnf"), (".psqlrc", ".psqlrc"), (".pgpass", ".pgpass"), (".sqliterc", ".sqliterc"),
        // other
        (".env", ".env"), (".env.local", ".env.local"), (".env.production", ".env.production"), (".env.development", ".env.development"), (".env.test", ".env.test"), (".agignore", ".agignore"), (".ackrc", ".ackrc"), (".rsyncrc", ".rsyncrc"), (".wgetrc", ".wgetrc"), (".curlrc", ".curlrc"), (".lscolors", ".lscolors"), (".lesshst", ".lesshst"), (".node_repl_history", ".node_repl_history"), (".bash_history", ".bash_history"), (".zsh_history", ".zsh_history"), (".mysql_history", ".mysql_history"), (".psql_history", ".psql_history"), (".sqlite_history", ".sqlite_history"),
        // tool
        (".config/starship.toml", ".config/starship.toml"), (".config/alacritty/alacritty.yml", ".config/alacritty/alacritty.yml"), (".config/kitty/kitty.conf", ".config/kitty/kitty.conf"), (".config/fish/config.fish", ".config/fish/config.fish")
    ]

    // 保存自定义配置到 UserDefaults
    private func saveCustomConfigs() {
        let customConfigs = configFiles.filter { $0.isCustom }
        let configDicts = customConfigs.map { $0.toDictionary() }
        UserDefaults.standard.set(configDicts, forKey: "customConfigs")
    }
    
    // 从 UserDefaults 加载自定义配置
    private func loadCustomConfigs() {
        if let configDicts = UserDefaults.standard.array(forKey: "customConfigs") as? [[String: Any]] {
            let customConfigs = configDicts.compactMap { ConfigFile.fromDictionary($0) }
            // 移除已不存在的自定义配置
            let validCustomConfigs = customConfigs.filter { FileManager.default.fileExists(atPath: $0.path) }
            // 更新配置列表
            configFiles = configFiles.filter { !$0.isCustom }
            configFiles.append(contentsOf: validCustomConfigs)
        }
    }

    // 保存默认配置到 UserDefaults
    private func saveDefaultConfigs() {
        let defaultConfigs = configFiles.filter { !$0.isCustom }
        let configDicts = defaultConfigs.map { $0.toDictionary() }
        UserDefaults.standard.set(configDicts, forKey: "defaultConfigs")
    }
    
    // 从 UserDefaults 加载默认配置
    private func loadDefaultConfigs() -> [ConfigFile] {
        if let configDicts = UserDefaults.standard.array(forKey: "defaultConfigs") as? [[String: Any]] {
            let defaultConfigs = configDicts.compactMap { ConfigFile.fromDictionary($0) }
            // 只返回仍然存在的配置文件
            return defaultConfigs.filter { FileManager.default.fileExists(atPath: $0.path) }
        }
        return []
    }

    func scanConfigFiles() -> [ConfigFile] {
        // 首先尝试从 UserDefaults 加载默认配置
        let savedDefaultConfigs = loadDefaultConfigs()
        if !savedDefaultConfigs.isEmpty {
            return savedDefaultConfigs
        }
        
        // 如果没有保存的配置，则扫描文件系统
        let homePath = NSHomeDirectory()
        let fileManager = FileManager.default
        var results: [ConfigFile] = []
        for (name, relPath) in commonConfigs {
            let filePath = (relPath.hasPrefix("/")) ? relPath : homePath + "/" + relPath
            if fileManager.fileExists(atPath: filePath) {
                results.append(ConfigFile(name: name, path: filePath, isCustom: false))
            }
        }
        
        // 保存扫描到的默认配置
        if !results.isEmpty {
            let configDicts = results.map { $0.toDictionary() }
            UserDefaults.standard.set(configDicts, forKey: "defaultConfigs")
        }
        
        return results
    }

    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
              
                    HStack(alignment: .center) {
                        ZStack {
                            TextField("Search config files...", text: $searchText, prompt: Text("Search config files..."))
                                .textFieldStyle(.roundedBorder)
                                .padding(.leading, 12)
                                .disableAutocorrection(true)
                                .frame(height: 28)

                            if !searchText.isEmpty {
                                HStack {
                                    Spacer()
                                    Button(action: { searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .frame(width: 24, height: 28)
                                    .padding(.trailing, 2)
                                }
                            }
                        }
                        .frame(height: 40)
               
                        Button(action: { showFileImporter = true }) {
                            Image(systemName: "plus.circle")
                                .resizable()
                                .frame(width: 20, height: 20)
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
                        } else {
                            ForEach(filteredFiles) { file in
                                Text(file.name)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        (selectedFile == file) ? Color.accentColor.opacity(0.2) : Color.clear
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
                                            copyPathToClipboard(file.path)
                                        }) {
                                            Label("Copy Path", systemImage: "doc.on.doc")
                                        }
                                        
                                        Button(action: {
                                            openInFinder(file.path)
                                        }) {
                                            Label("Open in Finder", systemImage: "folder")
                                        }
                                        
                                        Button(action: {
                                            openInCode(file.path)
                                        }) {
                                            Label("Open in Code", systemImage: "chevron.left.forwardslash.chevron.right")
                                        }
                                        
                                        Button(action: {
                                            openInCursor(file.path)
                                        }) {
                                            Label("Open in Cursor", systemImage: "cursorarrow")
                                        }
                                        
                                        Button(role: .destructive, action: {
                                            contextMenuFile = file
                                            showDeleteAlert = true
                                        }) {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    .frame(minWidth: 200)
                    .onAppear {
                        loadConfigFiles()
                        loadCustomConfigs() // 加载自定义配置
                        if let first = configFiles.first {
                            selectedFile = first
                            loadFileContent(file: first)
                        }
                       
                        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "f" {
                                showEditorSearchBar = true
                                DispatchQueue.main.async {
                                    searchFieldFocused = true
                                }
                                return nil
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
                                    selectedFile = newConfig
                                    loadFileContent(file: newConfig)
                                    // 保存新的自定义配置
                                    saveCustomConfigs()
                                }
                            }
                        default:
                            break
                        }
                    }
                }
            }


            VStack(spacing: 0) {
                if showEditorSearchBar {
                    HStack {
                        TextField("Search content...", text: $editorSearchText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                            .disableAutocorrection(true)
                            .help("Search in current file (Press Enter for next)")
                            .focused($searchFieldFocused)
                            .onSubmit {
                                editorViewRef?.findNext(editorSearchText)
                            }
                        Button(action: {
                            editorViewRef?.findNext(editorSearchText)
                        }) {
                            Image(systemName: "chevron.down")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Find next")
                        Button(action: {
                            editorViewRef?.findPrevious(editorSearchText)
                        }) {
                            Image(systemName: "chevron.up")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Find previous")
                        Button(action: {
                            showEditorSearchBar = false
                            editorSearchText = "" 
                        }) {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Close search")
                    }
                    .padding(.all, 5)
                }
               
                CodeEditorView(text: $fileContent, 
                           fileExtension: detectLanguage(selectedFile?.name), 
                           search: $editorSearchText, 
                           ref: $editorViewRef,
                           isFocused: !searchFieldFocused,
                           showSearchBar: { 
                               showEditorSearchBar = true
                               DispatchQueue.main.async {
                                   searchFieldFocused = true
                               }
                           })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
               
                Divider()
                HStack(spacing: 8) {
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
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(height: 24)
            }
            .frame(minWidth: 400)
        }
        .frame(minWidth: 600, minHeight: 400)
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
    }

    // Save edited content to file
    func saveFileContent() {
        guard let file = selectedFile else { return }
        do {
            try fileContent.write(toFile: file.path, atomically: true, encoding: .utf8)
        } catch {
            // TODO: Show save failure alert
        }
    }

    // Detect syntax highlighting language based on filename (returns extension string)
    func detectLanguage(_ name: String?) -> String {
        guard let n = name?.lowercased() else { return "" }
        
        // Shell 相关配置文件
        if n.hasSuffix(".sh") || n.hasSuffix(".zsh") || n.hasSuffix(".bash") || 
           n.hasPrefix(".zsh") || n.hasPrefix(".bash") || 
           n.hasSuffix(".profile") || n.hasSuffix(".zprofile") || 
           n.hasSuffix(".rc") || n.hasSuffix(".bashrc") || 
           n.hasSuffix(".zshrc") || n.hasSuffix(".zshenv") || 
           n.hasSuffix(".zlogin") || n.hasSuffix(".zlogout") || 
           n.hasSuffix(".inputrc") || n.hasSuffix(".dir_colors") || 
           n.hasSuffix(".tmux.conf") || n.hasSuffix(".screenrc") || 
           n.hasSuffix(".nanorc") || n.hasSuffix(".fzf.zsh") || 
           n.hasSuffix(".fzf.bash") {
            return "sh"
        }
        
        // Git 相关配置文件
        if n.hasSuffix(".gitconfig") || n.hasSuffix(".gitignore") || 
           n.hasSuffix(".gitattributes") || n.hasSuffix(".gitmodules") {
            return "git"
        }
        
        // Node.js 相关配置文件
        if n.hasSuffix(".npmrc") || n.hasSuffix(".yarnrc") || 
           n.hasSuffix(".nvmrc") || n.hasSuffix(".npmignore") ||
           n.hasSuffix(".prettierrc") || n.hasSuffix(".prettierignore") ||
           n.hasSuffix(".eslintrc") || n.hasSuffix(".eslintrc.json") ||
           n.hasSuffix(".eslintignore") || n.hasSuffix(".stylelintrc") ||
           n.hasSuffix(".stylelintignore") || n.hasSuffix(".babelrc") ||
           n.hasSuffix(".babelrc.js") || n.hasSuffix(".parcelrc") ||
           n.hasSuffix(".mocharc.json") || n.hasSuffix(".mocharc.js") {
            return "json"
        }
        
        // Python 相关配置文件
        if n.hasSuffix(".pypirc") || n.hasSuffix(".pythonrc") ||
           n.hasSuffix(".condarc") || n.hasSuffix("jupyter_notebook_config.py") ||
           n.hasSuffix("ipython_config.py") {
            return "py"
        }
        
        // Ruby 相关配置文件
        if n.hasSuffix(".irbrc") || n.hasSuffix(".pryrc") ||
           n.hasSuffix(".gemrc") || n.hasSuffix(".railsrc") ||
           n.hasSuffix(".rspec") || n.hasSuffix(".rubocop.yml") ||
           n.hasSuffix(".ruby-version") || n.hasSuffix(".ruby-gemset") {
            return "ruby"
        }
        
        // Java 相关配置文件
        if n.hasSuffix("settings.xml") || n.hasSuffix("pom.xml") ||
           n.hasSuffix("gradle.properties") || n.hasSuffix("gradle-wrapper.properties") {
            return "xml"
        }
        
        // Go 相关配置文件
        if n.hasSuffix(".goenv") || n.hasSuffix(".gorc") {
            return "go"
        }
        
        // Rust 相关配置文件
        if n.hasSuffix("Cargo.toml") || n.hasSuffix("rustfmt.toml") ||
           n.hasSuffix("clippy.toml") {
            return "toml"
        }
        
        // PHP 相关配置文件
        if n.hasSuffix(".phpenv") || n.hasSuffix(".php.ini") {
            return "php"
        }
        
        // C/C++ 相关配置文件
        if n.hasSuffix(".clang-format") || n.hasSuffix(".clang-tidy") ||
           n.hasSuffix(".gdbinit") || n.hasSuffix(".lldbinit") {
            return "cpp"
        }
        
        // R 相关配置文件
        if n.hasSuffix(".Rprofile") || n.hasSuffix(".Renviron") ||
           n.hasSuffix(".Rhistory") {
            return "r"
        }
        
        // Docker 相关配置文件
        if n.hasSuffix("Dockerfile") || n.hasSuffix(".dockerignore") ||
           n.hasSuffix("docker-compose.yml") || n.hasSuffix("docker-compose.yaml") {
            return "docker"
        }
        
        // 数据库相关配置文件
        if n.hasSuffix(".my.cnf") || n.hasSuffix(".psqlrc") ||
           n.hasSuffix(".pgpass") || n.hasSuffix(".sqliterc") {
            return "sql"
        }
        
        // 其他常见配置文件
        if n.hasSuffix(".json") { return "json" }
        if n.hasSuffix(".yml") || n.hasSuffix(".yaml") { return "yml" }
        if n.hasSuffix(".py") || n.hasPrefix(".python") { return "py" }
        if n.hasSuffix(".js") { return "js" }
        if n.hasSuffix(".ts") { return "ts" }
        if n.hasSuffix(".toml") { return "toml" }
        if n.hasSuffix(".ini") || n.hasSuffix(".conf") { return "ini" }
        if n.hasSuffix(".xml") { return "xml" }
        if n.hasSuffix(".md") { return "markdown" }
        if n.hasSuffix(".html") || n.hasSuffix(".htm") { return "html" }
        if n.hasSuffix(".css") { return "css" }
        if n.hasSuffix(".scss") || n.hasSuffix(".sass") { return "scss" }
        if n.hasSuffix(".less") { return "less" }
        if n.hasSuffix(".vue") { return "vue" }
        if n.hasSuffix(".svelte") { return "svelte" }
        if n.hasSuffix(".rs") { return "rust" }
        if n.hasSuffix(".go") { return "go" }
        if n.hasSuffix(".rb") { return "ruby" }
        if n.hasSuffix(".php") { return "php" }
        if n.hasSuffix(".java") { return "java" }
        if n.hasSuffix(".kt") { return "kotlin" }
        if n.hasSuffix(".swift") { return "swift" }
        if n.hasSuffix(".c") { return "c" }
        if n.hasSuffix(".cpp") || n.hasSuffix(".cc") || n.hasSuffix(".cxx") { return "cpp" }
        if n.hasSuffix(".h") || n.hasSuffix(".hpp") { return "cpp" }
        if n.hasSuffix(".sql") { return "sql" }
        if n.hasSuffix(".lua") { return "lua" }
        if n.hasSuffix(".pl") || n.hasSuffix(".pm") { return "perl" }
        if n.hasSuffix(".r") { return "r" }
        if n.hasSuffix(".scala") { return "scala" }
        if n.hasSuffix(".groovy") { return "groovy" }
        if n.hasSuffix(".gradle") { return "groovy" }
        if n.hasSuffix(".tf") { return "terraform" }
        if n.hasSuffix(".tfvars") { return "terraform" }
        if n.hasSuffix(".hcl") { return "hcl" }
        if n.hasSuffix(".proto") { return "protobuf" }
        if n.hasSuffix(".graphql") { return "graphql" }
        if n.hasSuffix(".gql") { return "graphql" }
        if n.hasSuffix(".env") { return "env" }
        if n.hasSuffix(".properties") { return "properties" }
        if n.hasSuffix(".toml") { return "toml" }
        if n.hasSuffix(".ini") { return "ini" }
        if n.hasSuffix(".conf") { return "conf" }
        if n.hasSuffix(".config") { return "conf" }
        if n.hasSuffix(".log") { return "log" }
        if n.hasSuffix(".txt") { return "text" }
        
        return ""
    }


    func loadConfigFiles() {
        configFiles = scanConfigFiles()
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
        // 首先尝试使用 NSWorkspace 打开
        let success = NSWorkspace.shared.openFile(path, withApplication: "Visual Studio Code")
        
        // 如果失败，尝试使用命令行方式
        if !success {
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
    
    // 在 Cursor 中打开
    private func openInCursor(_ path: String) {
        // 首先尝试使用 NSWorkspace 打开
        let success = NSWorkspace.shared.openFile(path, withApplication: "Cursor")
        
        // 如果失败，尝试使用命令行方式
        if !success {
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
                // 如果是自定义配置，更新 UserDefaults
                if file.isCustom {
                    saveCustomConfigs()
                }
            }
        } catch {
            print("Error deleting file: \(error)")
        }
    }
}
