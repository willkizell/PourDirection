//
//  AppTypography.swift
//  PourDirection
//
//  Design System — Typography Tokens
//  All font usage routes through this file. Never use raw Font or string names in views.
//
//  ── POPPINS SETUP ──────────────────────────────────────────────────────────────────────
//
//  Step 1 — Download
//  ─────────────────
//  Download Poppins from Google Fonts:
//  https://fonts.google.com/specimen/Poppins
//
//  Extract the ZIP. Add these .ttf files to your project:
//    • Poppins-Regular.ttf
//    • Poppins-Medium.ttf
//    • Poppins-SemiBold.ttf
//    • Poppins-Bold.ttf
//    • Poppins-Light.ttf
//
//  Step 2 — Add to Xcode
//  ──────────────────────
//  1. In Xcode, right-click on the PourDirection group in the Project Navigator.
//  2. Select "Add Files to PourDirection..."
//  3. Select all Poppins .ttf files.
//  4. CRITICAL: Check "Add to target: PourDirection" in the dialog before clicking Add.
//  5. The font files will appear in your project navigator.
//
//  Step 3 — Register in Info.plist
//  ─────────────────────────────────
//  1. Open Info.plist.
//  2. Add a new row with key: "Fonts provided by application" (raw: UIAppFonts), type Array.
//  3. Add one String item for each font file:
//       • Poppins-Regular.ttf
//       • Poppins-Medium.ttf
//       • Poppins-SemiBold.ttf
//       • Poppins-Bold.ttf
//       • Poppins-Light.ttf
//
//  Step 4 — Verify PostScript Names
//  ──────────────────────────────────
//  Add this debug function temporarily in your App struct or a debug view to print all
//  registered fonts and confirm the exact names Xcode loaded:
//
//      import UIKit
//      func debugPrintFonts() {
//          for family in UIFont.familyNames.sorted() {
//              for name in UIFont.fontNames(forFamilyName: family) {
//                  print("  \(name)")
//              }
//          }
//      }
//
//  Expected output for Poppins:
//    Poppins-Bold, Poppins-SemiBold, Poppins-Medium, Poppins-Regular, Poppins-Light
//
//  If the printed names differ from the PoppinsFont enum below, update the enum rawValues
//  to match exactly.
//
//  Step 5 — Done
//  ──────────────
//  Once registered, all AppTypography fonts will render with Poppins automatically.
//  If the font is not found, SwiftUI silently falls back to the system font.
//
// ──────────────────────────────────────────────────────────────────────────────────────

import SwiftUI

// MARK: - Poppins Font Face Names

enum PoppinsFont: String {
    case light    = "Poppins-Light"
    case regular  = "Poppins-Regular"
    case medium   = "Poppins-Medium"
    case semiBold = "Poppins-SemiBold"
    case bold     = "Poppins-Bold"
}

// MARK: - Font Extension

extension Font {
    /// Returns a Poppins font at the given size. Falls back to system font if
    /// Poppins is not yet registered in the project.
    static func poppins(_ style: PoppinsFont, size: CGFloat) -> Font {
        .custom(style.rawValue, size: size)
    }
}

// MARK: - App Typography Scale

struct AppTypography {

    /// Splash / hero display — largest text in the app, used only on SplashView
    /// Poppins Medium / 46pt
    static let splashTitle = Font.poppins(.medium,   size: 46)

    /// Large display title — hero headers, major section titles (ExploreView)
    /// Poppins Bold / 34pt
    static let titleLarge  = Font.poppins(.bold,     size: 34)

    /// Small display title — sub-page two-line headers (BarSuggestion, PickYourVibe, etc.)
    /// Poppins SemiBold / 26pt
    static let titleSmall  = Font.poppins(.semiBold, size: 26)

    /// Medium title — screen-level headings
    /// Poppins SemiBold / 24pt
    static let titleMedium = Font.poppins(.semiBold, size: 24)

    /// Section header — grouping labels, nav titles
    /// Poppins SemiBold / 18pt
    static let header      = Font.poppins(.semiBold, size: 18)

    /// Standard body — default reading text
    /// Poppins Regular / 16pt
    static let body        = Font.poppins(.regular,  size: 16)

    /// Emphasized body — interactive labels, button text
    /// Poppins Medium / 16pt
    static let bodyMedium  = Font.poppins(.medium,   size: 16)

    /// Small body — secondary actions / muted buttons
    /// Poppins Medium / 14pt
    static let bodySmall   = Font.poppins(.medium,   size: 14)

    /// Caption — metadata, secondary labels, timestamps
    /// Poppins Regular / 12pt
    static let caption     = Font.poppins(.regular,  size: 12)
}
