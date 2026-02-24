//
//  HapticManager.swift
//  PourDirection
//
//  Centralized haptic feedback. Pre-allocated generators avoid per-tap overhead.
//  All haptics fire asynchronously on a background queue to avoid blocking gestures.
//

import UIKit

final class HapticManager {

    static let shared = HapticManager()

    // Pre-allocated generators — reused across the app lifetime.
    private let lightImpact  = UIImpactFeedbackGenerator(style: .light)
    private let heavyImpact  = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpact   = UIImpactFeedbackGenerator(style: .soft)

    private init() {}

    /// Light tap — tab navigation, category buttons.
    func light() {
        lightImpact.impactOccurred()
    }

    /// Heavy tap — "Let's Go" primary CTA.
    func heavy() {
        heavyImpact.impactOccurred()
    }

    /// Soft nudge — compass directional correction pulse.
    func soft() {
        softImpact.impactOccurred()
    }

    /// Variable-intensity nudge for veering off course (0.0–1.0).
    func veer(intensity: Float) {
        softImpact.impactOccurred(intensity: CGFloat(intensity))
    }
}
