//
//  Slug.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import Foundation

enum Slug {
    static func make(_ input: String) -> String {
        let lowered = input.lowercased()
        let allowed = CharacterSet.alphanumerics
        var output = ""
        var previousWasDash = false

        for scalar in lowered.unicodeScalars {
            if allowed.contains(scalar) {
                output.unicodeScalars.append(scalar)
                previousWasDash = false
            } else if !previousWasDash {
                output.append("-")
                previousWasDash = true
            }
        }

        return output.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    static func paddedNumber(_ raw: String, width: Int = 3) -> String {
        guard let number = Int(raw) else { return raw }
        return String(format: "%0\(width)d", number)
    }
}
