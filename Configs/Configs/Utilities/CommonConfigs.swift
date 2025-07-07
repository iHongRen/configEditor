//  CommonConfigs.swift
//  Configs
//
//  Created by cxy on 2025/7/7.
//

import Foundation

struct CommonConfigData {
    // Common development configuration files covering mainstream programming languages and development tools
    static let commonConfigs = [
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

    static func scanForDefaultConfigFiles() -> [ConfigFile] {
        let homePath = NSHomeDirectory()
        let fileManager = FileManager.default
        var results: [ConfigFile] = []
        for (name, relPath) in commonConfigs {
            let filePath = (relPath.hasPrefix("/")) ? relPath : homePath + "/" + relPath
            if fileManager.fileExists(atPath: filePath) {
                results.append(ConfigFile(name: name, path: filePath, isCustom: false))
            }
        }
        return results
    }
}
