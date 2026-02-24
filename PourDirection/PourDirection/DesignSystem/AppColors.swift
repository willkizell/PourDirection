//
//  AppColors.swift
//  PourDirection
//
//  Design System — Color Tokens
//  All color values are defined here. Never use raw Color literals in views.
//

import SwiftUI

// MARK: - Hex Color Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - App Colors

struct AppColors {

    // Brand Primaries
    /// Teal brand color — #1A9F86
    static let primary         = Color(hex: "1A9F86")

    // Category Colors
    /// Bar category color — teal brand color (alias of primary)
    static var barTeal:          Color { primary }

    /// Restaurant category color — cornflower blue — #4B8EF1
    static let restaurantBlue  = Color(hex: "4B8EF1")

    /// Club category color — crimson red — #E92F57
    static let clubRed         = Color(hex: "E92F57")

    /// Dispensary category color — warm gold — #AC896A
    static let dispensaryGold  = Color(hex: "AC896A")

    /// White — used for primary text and high-emphasis elements
    static let secondary       = Color(hex: "FFFFFF")

    /// Dark grey — used for surfaces, borders, and low-emphasis elements — #2A2A2A
    static let accent          = Color(hex: "2A2A2A")

    // Backgrounds
    /// Pure black — base background for all screens
    static let background      = Color(hex: "000000")

    /// Card background — slightly lifted dark surface
    static let cardBackground  = Color(hex: "111827")

    /// Card surface — near-black with a hair of warmth, used for primary cards — #0A0F0F
    static let cardSurface     = Color(hex: "0A0F0F")

    /// Ad banner placeholder — subtle dark surface to indicate ad slot
    static let adPlaceholder   = Color(hex: "1C1C1E")

    /// Divider — subtle separator between UI sections
    static let divider         = Color(hex: "2A2A2A")

    // Gradient
    /// Full-screen radial gradient: visible teal glow from center fading to pure black.
    /// Use as `.background(AppColors.gradientBackground)` on root containers.
    static var gradientBackground: RadialGradient {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: Color(hex: "1A9F86").opacity(0.45), location: 0.0),
                .init(color: Color(hex: "1A9F86").opacity(0.10), location: 0.45),
                .init(color: background,                          location: 0.75)
            ]),
            center: .center,
            startRadius: 1,
            endRadius: 420
        )
    }
}
