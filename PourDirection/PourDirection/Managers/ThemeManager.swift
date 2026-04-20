//
//  ThemeManager.swift
//  PourDirection
//
//  Owns the Day / Night mode preference.
//  Auto-detects mode from current hour (5 AM–5 PM = day, else night).
//  User can manually override via the Home toggle or Settings — override persists.
//  Inject via .environment(themeManager) at the app root.
//

import SwiftUI

enum AppMode: String { case day, night }

private let kAppMode  = "com.pourdirection.appMode"
private let kOverride = "com.pourdirection.isUserOverride"

@Observable
final class ThemeManager {

    static let shared = ThemeManager()

    var mode: AppMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: kAppMode) }
    }

    var isUserOverride: Bool {
        didSet { UserDefaults.standard.set(isUserOverride, forKey: kOverride) }
    }

    var isDayMode: Bool { mode == .day }

    var preferredColorScheme: ColorScheme { mode == .day ? .light : .dark }

    init() {
        let savedOverride = UserDefaults.standard.bool(forKey: kOverride)
        if savedOverride,
           let raw   = UserDefaults.standard.string(forKey: kAppMode),
           let saved = AppMode(rawValue: raw) {
            self.mode           = saved
            self.isUserOverride = true
        } else {
            self.mode           = ThemeManager.autoMode()
            self.isUserOverride = false
        }
    }

    /// User taps the Day/Night toggle. Persists override.
    func setMode(_ newMode: AppMode) {
        mode           = newMode
        isUserOverride = true
    }

    /// Auto-derive mode from current hour.
    /// 5:00 – 16:59 → .day,  17:00 – 4:59 → .night
    private static func autoMode() -> AppMode {
        let hour = Calendar.current.component(.hour, from: Date())
        return (hour >= 5 && hour < 17) ? .day : .night
    }
}
