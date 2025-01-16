//
//  DateExtensions.swift
//  eegraw
//
//  Created by Elijah R on 2025/1/15.
//

import Foundation

extension Date {
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS" // Customize format as needed
        return formatter.string(from: self)
    }
}
