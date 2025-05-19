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

    func scanConfigFiles() -> [ConfigFile] {
        let homePath = NSHomeDirectory()
        let fileManager = FileManager.default
        var results: [ConfigFile] = []
        for (name, relPath) in commonConfigs {
            let filePath = (relPath.hasPrefix("/")) ? relPath : homePath + "/" + relPath
            if fileManager.fileExists(atPath: filePath) {
                results.append(ConfigFile(name: name, path: filePath))
            }
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
                            }
                        }
                    }
                    .frame(minWidth: 200)
                    .onAppear {
                        loadConfigFiles()
                       
                        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "f" {
                                showEditorSearchBar = true
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
                                    let newConfig = ConfigFile(name: name, path: path)
                                    configFiles.append(newConfig)
                                    selectedFile = newConfig
                                    loadFileContent(file: newConfig)
                                }
                            }
                        default:
                            break
                        }
                    }
                }
            }


            VStack(spacing: 0) {
             
                HStack {
                    if showEditorSearchBar {
                        TextField("Search content...", text: $editorSearchText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                            .disableAutocorrection(true)
                            .help("Search in current file (Press Enter for next)")
                            .onSubmit {
                                editorViewRef?.findNext(editorSearchText)
                            }
                            .onChange(of: editorSearchText) { _ in
                               
                                if showEditorSearchBar {
                                    
                                }
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
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                Divider()
               
                CodeEditorView(text: $fileContent, 
                           fileExtension: detectLanguage(selectedFile?.name), 
                           search: $editorSearchText, 
                           ref: $editorViewRef,
                           showSearchBar: { showEditorSearchBar = true })
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
        if n.hasSuffix(".json") { return "json" }
        if n.hasSuffix(".yml") || n.hasSuffix(".yaml") { return "yml" }
        if n.hasSuffix(".sh") || n.hasSuffix(".zsh") || n.hasSuffix(".bash") || n.hasPrefix(".zsh") || n.hasPrefix(".bash") { return "sh" }
        if n.hasSuffix(".py") || n.hasPrefix(".python") { return "py" }
        if n.hasSuffix(".js") { return "js" }
        if n.hasSuffix(".ts") { return "ts" }
        if n.hasSuffix(".toml") { return "toml" }
        if n.hasSuffix(".ini") || n.hasSuffix(".conf") { return "ini" }
        if n.hasSuffix(".rc") { return "sh" }
        // TODO: Add more extensions as needed
        return ""
    }


    func loadConfigFiles() {
        configFiles = scanConfigFiles()
        if let first = configFiles.first {
            selectedFile = first
            loadFileContent(file: first)
        }
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
}
