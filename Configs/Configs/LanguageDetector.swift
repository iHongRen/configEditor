//
//  LanguageDetector.swift
//  Configs
//
//  Created by cxy on 2025/7/7.
//

import Foundation

struct LanguageDetector {
    static func detectLanguage(_ name: String?) -> String {
        guard let n = name?.lowercased() else { return "" }
        
        // Shell related config files
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
        
        // Git related config files
        if n.hasSuffix(".gitconfig") || n.hasSuffix(".gitignore") || 
           n.hasSuffix(".gitattributes") || n.hasSuffix(".gitmodules") {
            return "git"
        }
        
        // Node.js related config files
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
        
        // Python related config files
        if n.hasSuffix(".pypirc") || n.hasSuffix(".pythonrc") ||
           n.hasSuffix(".condarc") || n.hasSuffix("jupyter_notebook_config.py") ||
           n.hasSuffix("ipython_config.py") {
            return "py"
        }
        
        // Ruby related config files
        if n.hasSuffix(".irbrc") || n.hasSuffix(".pryrc") ||
           n.hasSuffix(".gemrc") || n.hasSuffix(".railsrc") ||
           n.hasSuffix(".rspec") || n.hasSuffix(".rubocop.yml") ||
           n.hasSuffix(".ruby-version") || n.hasSuffix(".ruby-gemset") {
            return "ruby"
        }
        
        // Java related config files
        if n.hasSuffix("settings.xml") || n.hasSuffix("pom.xml") ||
           n.hasSuffix("gradle.properties") || n.hasSuffix("gradle-wrapper.properties") {
            return "xml"
        }
        
        // Go related config files
        if n.hasSuffix(".goenv") || n.hasSuffix(".gorc") {
            return "go"
        }
        
        // Rust
        if n.hasSuffix("Cargo.toml") || n.hasSuffix("rustfmt.toml") ||
           n.hasSuffix("clippy.toml") {
            return "toml"
        }
        
        // PHP
        if n.hasSuffix(".phpenv") || n.hasSuffix(".php.ini") {
            return "php"
        }
        
        // C/C++
        if n.hasSuffix(".clang-format") || n.hasSuffix(".clang-tidy") ||
           n.hasSuffix(".gdbinit") || n.hasSuffix(".lldbinit") {
            return "cpp"
        }
        
        // R
        if n.hasSuffix(".Rprofile") || n.hasSuffix(".Renviron") ||
           n.hasSuffix(".Rhistory") {
            return "r"
        }
        
        // Docker
        if n.hasSuffix("Dockerfile") || n.hasSuffix(".dockerignore") ||
           n.hasSuffix("docker-compose.yml") || n.hasSuffix("docker-compose.yaml") {
            return "docker"
        }
        
        // sql
        if n.hasSuffix(".my.cnf") || n.hasSuffix(".psqlrc") ||
           n.hasSuffix(".pgpass") || n.hasSuffix(".sqliterc") {
            return "sql"
        }
        
        // other
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
}
