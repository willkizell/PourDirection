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

    /// Liquor store category color — amber orange — #E97800
    static let liquorStoreAmber = Color(hex: "E97800")

    /// Casino category color — gold — #D5A11F
    static let casinoGold      = Color(hex: "D5A11F")

    /// Brunch category color — warm orange — #E8884A
    static let brunchOrange    = Color(hex: "E8884A")

    /// Coffee category color — brown — #8B5E3C
    static let coffeeBrown     = Color(hex: "8B5E3C")

    /// Parks category color — green — #34A853
    static let parksGreen      = Color(hex: "34A853")

    /// Dessert category color — pink — #D5619C
    static let dessertPink     = Color(hex: "D5619C")

    /// Primary text — white in dark mode, black in light mode
    static var secondary: Color {
        ThemeManager.shared.isDayMode ? Color(hex: "000000") : Color(hex: "FFFFFF")
    }

    /// Dark grey — used for surfaces, borders, and low-emphasis elements
    static var accent: Color {
        ThemeManager.shared.isDayMode ? Color(hex: "D1D1D6") : Color(hex: "2A2A2A")
    }

    // Backgrounds
    /// Base background — black in dark mode, off-white in light mode
    static var background: Color {
        ThemeManager.shared.isDayMode ? Color(hex: "F7FFFE") : Color(hex: "000000")
    }

    /// Card background — slightly lifted surface
    static var cardBackground: Color {
        ThemeManager.shared.isDayMode ? Color(hex: "EBF7F6") : Color(hex: "111827")
    }

    /// Card surface — primary card color
    static var cardSurface: Color {
        ThemeManager.shared.isDayMode ? Color(hex: "FFFFFF") : Color(hex: "0A0F0F")
    }

    /// Ad banner placeholder
    static var adPlaceholder: Color {
        ThemeManager.shared.isDayMode ? Color(hex: "F2F2F7") : Color(hex: "000000")
    }

    /// Divider — subtle separator between UI sections
    static var divider: Color {
        ThemeManager.shared.isDayMode ? Color(hex: "E5E5EA") : Color(hex: "2A2A2A")
    }

    // Gradient
    /// Full-screen radial gradient: visible teal glow from center fading to background.
    /// Use as `.background(AppColors.gradientBackground)` on root containers.
    static var gradientBackground: RadialGradient {
        if ThemeManager.shared.isDayMode {
            return RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: "1A9F86").opacity(0.32), location: 0.0),
                    .init(color: Color(hex: "1A9F86").opacity(0.12), location: 0.50),
                    .init(color: Color(hex: "F7FFFE"),               location: 0.80)
                ]),
                center: .center,
                startRadius: 1,
                endRadius: 460
            )
        } else {
            return RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: "1A9F86").opacity(0.65), location: 0.0),
                    .init(color: Color(hex: "1A9F86").opacity(0.18), location: 0.50),
                    .init(color: Color(hex: "000000"),               location: 0.80)
                ]),
                center: .center,
                startRadius: 1,
                endRadius: 460
            )
        }
    }
}
