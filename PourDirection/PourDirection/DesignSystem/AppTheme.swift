//
//  AppTheme.swift
//  PourDirection
//
//  Design System — Central Theme Access Point
//
//  AppTheme is the single import point for all design tokens.
//  Reference sub-systems directly (AppColors, AppTypography, etc.)
//  or use AppTheme.colors, AppTheme.typography, etc. for namespaced access.
//

import SwiftUI

// MARK: - App Theme Namespace

/// Aggregates all design system namespaces under one roof.
/// Prevents instantiation — use static members only.
enum AppTheme {
    static let colors     = AppColors.self
    static let typography = AppTypography.self
    static let spacing    = AppSpacing.self
    static let radius     = AppRadius.self
}

/*
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 LOGO INTEGRATION — FULL INSTRUCTIONS
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 SwiftUI cannot render .svg files natively. The correct approach is to convert
 your SVG layers to a PDF vector asset and import it into Assets.xcassets.
 PDF assets remain fully vector (no pixelation) on all retina displays.

 ── Method A: Single Composed Logo (Recommended) ─────────────────────────────

 Use this if both SVG layers (icon + wordmark) should always appear together.

 1. Open both SVG layers in Figma (or Sketch / Affinity Designer).
 2. Place them on a single artboard sized to the logo's natural proportions.
    Confirm alignment matches the mockup.
 3. Select the entire artboard and export as PDF.
    In Figma: right-click → Export → PDF format.
    In Sketch: File → Export → select artboard → format PDF.
 4. In Xcode, open Assets.xcassets.
 5. Right-click → New Image Set → name it exactly: AppLogo
 6. Drag the exported PDF into the "1x" slot (leave 2x and 3x empty).
 7. Select the "AppLogo" image set and open the Attributes Inspector:
       Scales        → Single Scale
       Render As     → Original Image  (preserves full color)
       Preserve Vector Data → ON  ← Required for crisp retina rendering
 8. Open AppComponents.swift and update AppLogoView.body to:

        Image("AppLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)

 ── Method B: Separate Layers (Use for independent tinting per layer) ─────────

 1. Export each SVG layer as its own PDF:
       • AppLogoIcon.pdf     — the beer mug / icon circle
       • AppLogoWordmark.pdf — the "Pour Direction" text
 2. Add both as individual image sets in Assets.xcassets (same settings as above).
 3. Replace AppLogoView.body with:

        VStack(spacing: AppSpacing.iconLabelSpacing) {
            Image("AppLogoIcon")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
            Image("AppLogoWordmark")
                .resizable()
                .scaledToFit()
                .frame(height: size * 0.28)
        }

 ── Retina / Display Scaling Notes ──────────────────────────────────────────

 • PDF + "Preserve Vector Data" = Xcode rasterizes at the exact display scale
   at runtime, so the logo will be pixel-perfect on 1x, 2x, and 3x displays.
 • Never export PNG for a logo — it will be blurry on newer devices.
 • If Xcode 15+ is used, SVG import is available natively. Drag the .svg
   directly into the image set. It behaves identically to the PDF method above.

 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 APP ICON — FULL INSTRUCTIONS
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 1. In your design tool, create a 1024×1024pt artboard.
       • Background: solid color — use #000000 (brand black) or #1A9F86 (brand teal).
         The App Store rejects icons with transparency (no alpha channel).
       • Place the logo centered with generous padding (~180px from each edge is safe).
       • Do NOT include rounded corners — iOS applies the squircle mask automatically.

 2. Export as PNG at 1x (not @2x/@3x — Xcode handles this):
       • Format: PNG
       • Dimensions: exactly 1024×1024 pixels
       • No transparency (PNG-24 with white or brand-color background)

 3. In Xcode:
       • Open Assets.xcassets → AppIcon
       • In Xcode 15+, a single slot is shown. Drag your 1024×1024 PNG into it.
         Xcode generates all required sizes (20pt through 1024pt) automatically.
       • For Xcode 14 or earlier, use https://makeappicon.com to generate a full
         icon set. Drag the generated AppIcon.appiconset folder into Assets.xcassets.

 4. Build and run. The icon appears on the simulator home screen.

 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ADDING DesignSystem FILES TO XCODE PROJECT
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 The DesignSystem files were created on disk inside the PourDirection source folder.
 Xcode does not automatically detect new files — you must add them to the project:

 1. In Xcode's Project Navigator, right-click on the PourDirection group (the
    yellow folder icon, not the blue project icon).
 2. Select "Add Files to PourDirection..."
 3. Navigate into the DesignSystem folder and select all 5 .swift files, OR
    select the DesignSystem folder itself.
 4. IMPORTANT: In the dialog options:
       • "Added folders" → select "Create groups" (not "Create folder references")
       • "Add to targets" → check PourDirection
 5. Click Add. A DesignSystem group will appear in the navigator.

 After this step, all design system files are part of the build target and
 their types/structs are globally available without import statements.
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
*/
