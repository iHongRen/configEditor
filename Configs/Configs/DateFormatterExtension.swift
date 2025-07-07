//
//  DateFormatterExtension.swift
//  Configs
//
//  Created by cxy on 2025/7/7.
//

import Foundation

extension Date {
    func formatModificationDate() -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            // Show only time for today's modifications
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: self)
        } else {
            // Show full date and time for other dates
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy HH:mm"
            return formatter.string(from: self)
        }
    }
}
