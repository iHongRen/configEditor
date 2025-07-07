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

    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
