//
//  ConfigsApp.swift
//  Configs
//
//  Created by cxy on 2025/5/18.
//

import SwiftUI
import AppKit


@main
struct ConfigsApp: App {
    let githubURLString = "https://github.com/iHongRen/configEditor"

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L10n.tr("about.configs")) {
                    AboutWindow.show()
                }
            }
            

        }
    }
    
    init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Self.hideDefaultMenuItems()
        }
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    
    private static func hideDefaultMenuItems() {
            guard let mainMenu = NSApplication.shared.mainMenu else { return }

            let hiddenMenuTitles = ["File", "Edit", "View", "Window", "Help", "文件", "编辑", "显示", "窗口", "帮助"]
            let appMenuTitles = ["Configs"]
            let visibleSubmenuTitles = [L10n.tr("about.configs"), L10n.tr("quit.configs"), "About Configs", "Quit Configs", "关于 Configs", "退出 Configs"]
            
            for item in mainMenu.items {
                if hiddenMenuTitles.contains(item.title) {
                    item.isHidden = true
                }
                
                if appMenuTitles.contains(item.title) {
                    if let submenu = item.submenu {
                        for subItem in submenu.items {
                            if visibleSubmenuTitles.contains(subItem.title) {
                                subItem.isHidden = false
                            } else {
                                subItem.isHidden = true
                            }
                        }
                    }
                }
            }
        }
}
