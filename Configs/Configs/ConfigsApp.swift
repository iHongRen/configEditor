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
                    let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Configs"
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

                    let creditsString = githubURLString
                    
                    let attributedCredits = NSMutableAttributedString(string: creditsString, attributes: [
                        .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
                    ])

                    if let githubRange = creditsString.range(of: githubURLString) {
                        attributedCredits.addAttribute(.link, value: URL(string: githubURLString)!, range: NSRange(githubRange, in: creditsString))
                    }

                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: appName,
                        .applicationVersion: version,
                        .credits: attributedCredits,
                        .applicationIcon: NSImage(named: "AppIcon")!
                    ])
                }
            }
            
            // Add a new CommandGroup for Help menu items
            CommandGroup(replacing: .help) { // Replace the default Help menu
                Button("Keyboard Shortcuts") {
                    KeyboardShortcutsWindow.show()
                }
                
                Button("View on GitHub") {
                    if let url = URL(string: githubURLString) {
                        NSWorkspace.shared.open(url)
                    }
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
                if ["File", "Edit", "View", "Window"].contains(item.title) {
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
