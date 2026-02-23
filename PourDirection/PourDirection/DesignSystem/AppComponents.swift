//
//  AppComponents.swift
//  PourDirection
//
//  Design System — Reusable UI Components
//  All components consume design tokens exclusively. No raw colors, fonts, or numbers.
//

import SwiftUI
import UIKit

// MARK: - Swipe-Back Gesture Support

/// Re-enables the interactive pop (swipe-back) gesture when the navigation bar is hidden.
/// SwiftUI disables it by default when `.navigationBarBackButtonHidden(true)` is set.
struct EnableSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackController()
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private class SwipeBackController: UIViewController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Walk up to the hosting UINavigationController and re-enable the gesture
        if let nav = navigationController {
            nav.interactivePopGestureRecognizer?.isEnabled = true
            nav.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

extension View {
    /// Attach to any pushed view to allow swipe-back even with the nav bar hidden.
    func enableSwipeBack() -> some View {
        background(EnableSwipeBack())
    }
}

// MARK: - Primary Button

/// Full-width pill button using brand primary color.
/// Use for the most important call-to-action on a screen.
struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Secondary Button

/// Full-width outlined pill button with muted grey styling.
/// Use for low-emphasis secondary actions (e.g. "Sign In", "Cancel").
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.secondary.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppColors.secondary.opacity(0.2), lineWidth: 1.0)
                )
        }
    }
}

// MARK: - App Header View

/// Top-of-screen navigation header with a title.
/// Designed to sit below the status bar; pair with `.navigationBarHidden(true)` when needed.
struct AppHeaderView: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(AppTypography.titleMedium)
                .foregroundColor(AppColors.secondary)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.vertical, AppSpacing.sm)
    }
}

// MARK: - Card View

/// Generic dark surface container with brand-standard styling.
/// Fills available width. Pair with a leading-aligned VStack inside for content.
struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.cardPadding)
            .background(AppColors.cardSurface.opacity(0.92))
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.secondary.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.5), radius: AppSpacing.sm, x: 0, y: 4)
    }
}

// MARK: - Ad Banner Placeholder View

/// 50pt tall placeholder used on screens that will carry ad inventory.
/// Replace with the real AdMob / ad SDK view when integrating advertising.
struct AdBannerPlaceholderView: View {
    var body: some View {
        ZStack {
            AppColors.adPlaceholder
            Text("Ad Banner")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.secondary.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .cornerRadius(AppRadius.sm)
    }
}

// MARK: - App Logo View

/// Renders the AppLogo vector asset from Assets.xcassets.
/// Asset name: "AppLogo" — imported as a PDF with Preserve Vector Data enabled.
struct AppLogoView: View {
    let size: CGFloat

    init(size: CGFloat = 100) {
        self.size = size
    }

    var body: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

// MARK: - Tab Definition

/// The four main destinations in the app.
/// The center compass action is handled separately via `onCompassTap` on CustomTabBar.
enum AppTab: Int, CaseIterable {
    case explore
    case saved
    case map
    case profile

    var label: String {
        switch self {
        case .explore: return "Explore"
        case .saved:   return "Saved"
        case .map:     return "Map"
        case .profile: return "Profile"
        }
    }

    var defaultIcon: String {
        switch self {
        case .explore: return "dot.radiowaves.left.and.right"
        case .saved:   return "heart"
        case .map:     return "map"
        case .profile: return "person"
        }
    }

    var selectedIcon: String {
        switch self {
        case .explore: return "dot.radiowaves.left.and.right"
        case .saved:   return "heart.fill"
        case .map:     return "map.fill"
        case .profile: return "person.fill"
        }
    }
}

// MARK: - Tab Bar Item

private struct TabBarItem: View {
    let tab: AppTab
    @Binding var selectedTab: AppTab
    var onTap: () -> Void = {}

    private var isSelected: Bool { selectedTab == tab }

    var body: some View {
        Button {
            selectedTab = tab
            onTap()
        } label: {
            Image(systemName: isSelected ? tab.selectedIcon : tab.defaultIcon)
                .font(.system(size: 24))
                .foregroundColor(isSelected ? AppColors.primary : AppColors.secondary.opacity(0.4))
                .shadow(
                    color: isSelected ? AppColors.primary.opacity(0.5) : .clear,
                    radius: 6, x: 0, y: 0
                )
                .padding(.top, 4)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Tab Bar

/// Five-slot tab bar with the compass as the prominent center action.
///
/// Usage — attach to the bottom of your root screen:
///
///     .safeAreaInset(edge: .bottom, spacing: 0) {
///         VStack(spacing: 0) {
///             AdBannerPlaceholderView()
///                 .padding(.horizontal, AppSpacing.screenHorizontalPadding)
///             CustomTabBar(selectedTab: $selectedTab) { /* compass action */ }
///         }
///     }
struct CustomTabBar: View {
    static let height: CGFloat = 52

    @Binding var selectedTab: AppTab
    var onCompassTap: () -> Void = {}
    var onTabTap: (AppTab) -> Void = { _ in }

    private let barHeight: CGFloat    = CustomTabBar.height
    private let compassCircle: CGFloat = 44

    var body: some View {
        ZStack {

            // ── Bar Background ──────────────────────────────────────────────
            VStack(spacing: 0) {
                Rectangle()
                    .fill(AppColors.secondary.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: 0.5)
                AppColors.background
            }
            .frame(height: barHeight)

            // ── All Five Slots ──────────────────────────────────────────────
            HStack(spacing: 0) {
                TabBarItem(tab: .explore, selectedTab: $selectedTab, onTap: { onTabTap(.explore) })
                TabBarItem(tab: .saved,   selectedTab: $selectedTab, onTap: { onTabTap(.saved) })

                // ── Center Compass Slot ─────────────────────────────────────
                Button(action: onCompassTap) {
                    ZStack {
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: compassCircle, height: compassCircle)
                            .shadow(color: AppColors.primary.opacity(0.45), radius: 10, x: 0, y: 0)

                        Image(systemName: "location.north.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColors.background)
                            .rotationEffect(.degrees(45))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                TabBarItem(tab: .map,     selectedTab: $selectedTab, onTap: { onTabTap(.map) })
                TabBarItem(tab: .profile, selectedTab: $selectedTab, onTap: { onTabTap(.profile) })
            }
            .padding(.horizontal, AppSpacing.xs)
            .frame(height: barHeight)
        }
        .frame(height: barHeight)
    }
}

// MARK: - Previews

#Preview("Primary Button") {
    VStack(spacing: AppSpacing.md) {
        PrimaryButton(title: "Find Bars Near Me") {}
        SecondaryButton(title: "Sign In") {}
    }
    .padding(AppSpacing.md)
    .background(AppColors.background)
}

#Preview("Card View") {
    CardView {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("The Local Tap Room")
                .font(AppTypography.header)
                .foregroundColor(AppColors.secondary)
            Text("0.3 mi away • Open now")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.secondary.opacity(0.6))
        }
    }
    .padding(AppSpacing.md)
    .background(AppColors.background)
}

#Preview("Ad Banner") {
    AdBannerPlaceholderView()
        .padding(AppSpacing.md)
        .background(AppColors.background)
}

#Preview("App Logo") {
    AppLogoView(size: 120)
        .padding(AppSpacing.xl)
        .background(AppColors.background)
}

#Preview("Custom Tab Bar") {
    ZStack(alignment: .bottom) {
        AppColors.gradientBackground
            .ignoresSafeArea()

        // Sample content above bar
        VStack {
            CardView {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Live Jazz Night")
                        .font(AppTypography.header)
                        .foregroundColor(AppColors.secondary)
                    Text("Tonight at 9:00 PM  •  The Cellar Jazz Club")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary.opacity(0.6))
                }
            }
            .padding(.horizontal, AppSpacing.md)
            Spacer()
        }
        .padding(.top, AppSpacing.xl)

        CustomTabBar(selectedTab: .constant(.profile))
    }
    .ignoresSafeArea(edges: .bottom)
    .preferredColorScheme(.dark)
}
