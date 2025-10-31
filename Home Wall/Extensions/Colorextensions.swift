//
//  ColorExtensions.swift
//  Home Wall
//
//  Extension to get color based on climb grade and hex colors
//

import SwiftUI

extension Color {
    /// Get gradient color for climb grades V0-V15
    static func gradeColor(for grade: String) -> Color {
        // Extract numeric value from grade string (e.g., "V0" -> 0, "V10" -> 10)
        let numericString = grade.filter { $0.isNumber }
        guard let gradeNumber = Int(numericString) else {
            return .gray // Default color if grade can't be parsed
        }
        
        // Map V0-V15 to a color gradient from green to red
        let normalizedGrade = min(max(Double(gradeNumber), 0), 15) / 15.0
        
        // Create smooth color transition: green -> yellow -> orange -> red
        if normalizedGrade < 0.33 {
            // Green to Yellow (V0-V5)
            let ratio = normalizedGrade / 0.33
            return Color(
                red: ratio,
                green: 1.0,
                blue: 0
            )
        } else if normalizedGrade < 0.66 {
            // Yellow to Orange (V6-V10)
            let ratio = (normalizedGrade - 0.33) / 0.33
            return Color(
                red: 1.0,
                green: 1.0 - (ratio * 0.5), // Stay somewhat yellow
                blue: 0
            )
        } else {
            // Orange to Red (V11-V15)
            let ratio = (normalizedGrade - 0.66) / 0.34
            return Color(
                red: 1.0,
                green: 0.5 - (ratio * 0.5), // Fade out green component
                blue: 0
            )
        }
    }
    
    /// Initialize Color from hex string
    /// - Parameter hex: Hex color string (e.g., "#FF5733" or "FF5733")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
