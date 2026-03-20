//
//  ColorSchemeOption.swift
//  Configs
//
//  Created by cxy on 2025/7/7.
//

import SwiftUI

enum ColorSchemeOption: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"

    var displayName: String {
        switch self {
        case .light:
            return L10n.tr("light")
        case .dark:
            return L10n.tr("dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
