//
//  ConfigFile.swift
//  Configs
//
//  Created by cxy on 2025/7/7.
//

import Foundation
import SwiftUI

struct ConfigGroup: Identifiable, Hashable {
    let id: String
    var name: String

    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }

    static func fromDictionary(_ dict: [String: Any]) -> ConfigGroup? {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String else {
            return nil
        }
        return ConfigGroup(id: id, name: name)
    }

    func toDictionary() -> [String: Any] {
        [
            "id": id,
            "name": name
        ]
    }
}

/// Lightweight tag structure for a config file.
/// Stores display text and RGBA components (0.0 - 1.0) so it can be persisted easily.
struct FileTag: Hashable {
    let text: String
    let r: Double
    let g: Double
    let b: Double
    let a: Double
}

struct ConfigFile: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let isCustom: Bool
    var isPinned: Bool = false
    var tag: FileTag? = nil
    var groupID: String? = nil
    
    static func fromDictionary(_ dict: [String: Any]) -> ConfigFile? {
        guard let name = dict["name"] as? String,
              let path = dict["path"] as? String,
              let isCustom = dict["isCustom"] as? Bool else {
            return nil
        }
        let isPinned = dict["isPinned"] as? Bool ?? false
        let groupID = dict["groupID"] as? String

        var file = ConfigFile(name: name, path: path, isCustom: isCustom, isPinned: isPinned, groupID: groupID)

        if let tagDict = dict["tag"] as? [String: Any],
           let text = tagDict["text"] as? String,
           let r = tagDict["r"] as? Double,
           let g = tagDict["g"] as? Double,
           let b = tagDict["b"] as? Double {
            let a = tagDict["a"] as? Double ?? 1.0
            file.tag = FileTag(text: text, r: r, g: g, b: b, a: a)
        }

        return file
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "path": path,
            "isCustom": isCustom,
            "isPinned": isPinned
        ]

        if let groupID = groupID {
            dict["groupID"] = groupID
        }

        if let tag = tag {
            dict["tag"] = [
                "text": tag.text,
                "r": tag.r,
                "g": tag.g,
                "b": tag.b,
                "a": tag.a
            ]
        }

        return dict
    }
}
