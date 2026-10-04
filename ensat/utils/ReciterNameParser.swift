//
//  ReciterNameParser.swift
//  naqaa
//
//  Created by Mazen on 30/08/2026.
//

import Foundation

enum ReciterNameParser {
    static func split(_ name: String) -> (first: String, last: String?) {
        let sanitized = name.replacingOccurrences(of: "Al-", with: "Al")
        let components = sanitized.split(separator: " ").map(String.init)
        guard components.count > 1, let last = components.last else { return (sanitized, nil) }
        return (components.dropLast().joined(separator: " "), last)

    }
}
