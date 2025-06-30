//
//  ConfigsApp.swift
//  Configs
//
//  Created by cxy on 2025/5/18.
//

import SwiftUI
import AppKit // Import AppKit for NSApplication

@main
struct ConfigsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Configs") {
                    let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Configs"
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

                    let creditsString = "https://github.com/iHongRen/configEditor"
                    
                    let attributedCredits = NSMutableAttributedString(string: creditsString, attributes: [
                        .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
                    ])

                    if let githubRange = creditsString.range(of: creditsString) {
                        attributedCredits.addAttribute(.link, value: creditsString, range: NSRange(githubRange, in: creditsString))
                    }

                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: appName,
                        .applicationVersion: version,
                        .credits: attributedCredits,
                        .applicationIcon: NSImage(named: "AppIcon")!
                    ])
                }
            }
        }
    }
    
    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
}
