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
                Button("About Configs") {
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
            
            for item in mainMenu.items {
                if ["File", "Edit", "View", "Window", "Help"].contains(item.title) {
                    item.isHidden = true
                }
                
                if item.title == "Configs" {
                    if let submenu = item.submenu {
                        for subItem in submenu.items {
                            if ["About Configs", "Quit Configs"].contains(subItem.title) {
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
