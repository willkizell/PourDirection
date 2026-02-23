//
//  AppSpacing.swift
//  PourDirection
//
//  Design System — Spacing & Radius Tokens
//  All layout measurements are defined here. Never use inline magic numbers in views.
//

import CoreGraphics

// MARK: - App Spacing

/// Spacing system built on a 4pt base unit.
/// Use semantic aliases wherever possible for maintainability.
struct AppSpacing {

    // Base scale
    static let xxs:  CGFloat = 4
    static let xs:   CGFloat = 8
    static let sm:   CGFloat = 12
    static let md:   CGFloat = 16
    static let lg:   CGFloat = 24
    static let xl:   CGFloat = 32
    static let xxl:  CGFloat = 48
    static let xxxl: CGFloat = 64

    // Semantic aliases
    /// Horizontal inset for full-screen content
    static let screenHorizontalPadding: CGFloat = md

    /// Internal padding for card surfaces
    static let cardPadding: CGFloat = lg

    /// Vertical spacing between major page sections
    static let sectionSpacing: CGFloat = xl

    /// Spacing between sibling components within a section
    static let componentSpacing: CGFloat = md

    /// Spacing between icon/image and adjacent label
    static let iconLabelSpacing: CGFloat = xs
}

// MARK: - App Corner Radius

struct AppRadius {
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 24

    /// Use for pill-shaped elements (buttons, tags)
    static let full: CGFloat = 999
}
