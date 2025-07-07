//
//  ConfigFile.swift
//  Configs
//
//  Created by cxy on 2025/7/7.
//

import Foundation

struct ConfigFile: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let isCustom: Bool
    var isPinned: Bool = false
    
    static func fromDictionary(_ dict: [String: Any]) -> ConfigFile? {
        guard let name = dict["name"] as? String,
              let path = dict["path"] as? String,
              let isCustom = dict["isCustom"] as? Bool else {
            return nil
        }
        let isPinned = dict["isPinned"] as? Bool ?? false
        return ConfigFile(name: name, path: path, isCustom: isCustom, isPinned: isPinned)
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "path": path,
            "isCustom": isCustom,
            "isPinned": isPinned
        ]
    }
}
