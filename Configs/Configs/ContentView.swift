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
    @State private var configFiles: [ConfigFile] = []
    @State private var selectedFile: ConfigFile?
    @State private var fileContent: String = ""
    @State private var searchText: String = ""
    @State private var showFileImporter: Bool = false

    // 自动扫描用户主目录下的所有隐藏配置文件和常见配置目录

    // 日常开发常用配置文件，涵盖主流编程语言和开发工具
    let commonConfigs = [
        // Shell & 终端
        (".zshrc", ".zshrc"), (".bashrc", ".bashrc"), (".bash_profile", ".bash_profile"), (".profile", ".profile"), (".zprofile", ".zprofile"), (".zshenv", ".zshenv"), (".zlogin", ".zlogin"), (".zlogout", ".zlogout"), (".inputrc", ".inputrc"), (".dir_colors", ".dir_colors"), (".tmux.conf", ".tmux.conf"), (".screenrc", ".screenrc"), (".nanorc", ".nanorc"), (".fzf.zsh", ".fzf.zsh"), (".fzf.bash", ".fzf.bash"),
        // Git & 版本控制
        (".gitconfig", ".gitconfig"), (".gitignore", ".gitignore"), (".gitattributes", ".gitattributes"), (".hgignore", ".hgignore"), (".gitmodules", ".gitmodules"),
        // SSH & GPG
        (".ssh/config", ".ssh/config"), (".gnupg/gpg.conf", ".gnupg/gpg.conf"), (".gnupg/gpg-agent.conf", ".gnupg/gpg-agent.conf"),
        // 编辑器
        (".vimrc", ".vimrc"), (".viminfo", ".viminfo"), (".emacs", ".emacs"), (".spacemacs", ".spacemacs"), (".config/Code/User/settings.json", ".config/Code/User/settings.json"), (".config/Code/User/keybindings.json", ".config/Code/User/keybindings.json"), (".editorconfig", ".editorconfig"),
        // Node.js & 前端
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
        // Docker & 容器
        (".docker/config.json", ".docker/config.json"), (".dockerignore", ".dockerignore"), (".compose.yaml", ".compose.yaml"), ("docker-compose.yml", "docker-compose.yml"),
        // 数据库
        (".my.cnf", ".my.cnf"), (".psqlrc", ".psqlrc"), (".pgpass", ".pgpass"), (".sqliterc", ".sqliterc"),
        // 其他常用
        (".env", ".env"), (".env.local", ".env.local"), (".env.production", ".env.production"), (".env.development", ".env.development"), (".env.test", ".env.test"), (".agignore", ".agignore"), (".ackrc", ".ackrc"), (".rsyncrc", ".rsyncrc"), (".wgetrc", ".wgetrc"), (".curlrc", ".curlrc"), (".lscolors", ".lscolors"), (".lesshst", ".lesshst"), (".node_repl_history", ".node_repl_history"), (".bash_history", ".bash_history"), (".zsh_history", ".zsh_history"), (".mysql_history", ".mysql_history"), (".psql_history", ".psql_history"), (".sqlite_history", ".sqlite_history"),
        // 终端美化/工具
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
                    // 搜索框和加号按钮
                    HStack(alignment: .center) {
                        ZStack {
                            TextField("搜索配置文件...", text: $searchText, prompt: Text("搜索配置文件..."))
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
                        // 加号按钮（无背景色，间距12）
                        Button(action: { showFileImporter = true }) {
                            Image(systemName: "plus.circle")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.accentColor)
                                .help("添加自定义配置文件")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.trailing, 12)
                    }

                    // 列表始终在搜索框下方
                    List(selection: $selectedFile) {
                        let filteredFiles = configFiles.filter { file in
                            searchText.isEmpty || file.name.localizedCaseInsensitiveContains(searchText) || file.path.localizedCaseInsensitiveContains(searchText)
                        }
                        if filteredFiles.isEmpty {
                            Text("未找到任何配置文件")
                        } else {
                            ForEach(filteredFiles) { file in
                                // 让每一项可点击选中并切换内容，并有选中高亮效果
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
                    .onAppear(perform: loadConfigFiles)
                    // 文件选择器
                    .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
                        switch result {
                        case .success(let urls):
                            if let url = urls.first {
                                let name = url.lastPathComponent
                                let path = url.path
                                // 避免重复添加
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

            ScrollView {
                Text(fileContent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(minWidth: 400)
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    func loadConfigFiles() {
        configFiles = scanConfigFiles()
        if let first = configFiles.first {
            selectedFile = first
            loadFileContent(file: first)
        }
    }

    func loadFileContent(file: ConfigFile) {
        fileContent = "正在加载内容..."
        Task {
            let content: String
            if #available(macOS 15.0, *) {
                do {
                    let url = URL(fileURLWithPath: file.path)
                    content = try String(contentsOf: url, encoding: .utf8)
                } catch {
                    content = "无法读取文件内容。"
                }
            } else {
                if let loaded = try? String(contentsOfFile: file.path) {
                    content = loaded
                } else {
                    content = "无法读取文件内容。"
                }
            }
            await MainActor.run {
                fileContent = content
            }
        }
    }
}

#Preview {
    ContentView()
}
