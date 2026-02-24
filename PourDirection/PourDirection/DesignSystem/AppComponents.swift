//
//  AppComponents.swift
//  PourDirection
//
//  Design System — Reusable UI Components
//  All components consume design tokens exclusively. No raw colors, fonts, or numbers.
//

import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
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
    let iconName: String?
    let verticalPadding: CGFloat
    let action: () -> Void

    init(
        title: String,
        iconName: String? = nil,
        verticalPadding: CGFloat = AppSpacing.md,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconName = iconName
        self.verticalPadding = verticalPadding
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.heavy()
            action()
        }) {
            HStack(spacing: AppSpacing.iconLabelSpacing) {
                if let iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
            }
            .font(AppTypography.bodyMedium)
            .foregroundColor(AppColors.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
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
    let iconName: String?
    let verticalPadding: CGFloat
    let action: () -> Void

    init(
        title: String,
        iconName: String? = nil,
        verticalPadding: CGFloat = AppSpacing.md,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconName = iconName
        self.verticalPadding = verticalPadding
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.iconLabelSpacing) {
                if let iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
            }
            .font(AppTypography.bodyMedium)
            .foregroundColor(AppColors.secondary.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
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

// MARK: - Ad Banner View

/// 50pt tall banner slot. Shows AdMob when available, otherwise a placeholder.
struct AdBannerPlaceholderView: View {
    let adUnitID: String
    @State private var isLoaded: Bool = false

    init(adUnitID: String = "ca-app-pub-6036298682734506/7829757936") {
        self.adUnitID = adUnitID
    }

    private var effectiveAdUnitID: String {
        #if DEBUG
        // Guaranteed-fill test banner from Google for development.
        return "ca-app-pub-3940256099942544/2435281174"
        #else
        return adUnitID
        #endif
    }

    var body: some View {
        #if canImport(GoogleMobileAds)
        ZStack {
            AppColors.adPlaceholder
            if !isLoaded {
                Text("Ad Banner")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.secondary.opacity(0.35))
            }
            AdMobBannerView(adUnitID: effectiveAdUnitID, isLoaded: $isLoaded)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .cornerRadius(AppRadius.sm)
        #else
        ZStack {
            AppColors.adPlaceholder
            Text("Ad Banner")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.secondary.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .cornerRadius(AppRadius.sm)
        #endif
    }
}

#if canImport(GoogleMobileAds)
private struct AdMobBannerView: UIViewRepresentable {
    let adUnitID: String
    @Binding var isLoaded: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoaded: $isLoaded)
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = AdMobBannerView.rootViewController()
        context.coordinator.loadIfNeeded(banner)
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        if uiView.rootViewController == nil {
            uiView.rootViewController = AdMobBannerView.rootViewController()
        }
        context.coordinator.loadIfNeeded(uiView)
    }

    private static func rootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
        if let root = keyWindow?.rootViewController {
            return root
        }
        return scenes.flatMap { $0.windows }.first?.rootViewController
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding var isLoaded: Bool
        var didLoad: Bool = false

        init(isLoaded: Binding<Bool>) {
            self._isLoaded = isLoaded
        }

        func loadIfNeeded(_ banner: BannerView) {
            guard !didLoad else { return }
            if banner.rootViewController == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak banner, weak self] in
                    guard let banner, let self else { return }
                    if banner.rootViewController == nil {
                        banner.rootViewController = AdMobBannerView.rootViewController()
                    }
                    self.loadIfNeeded(banner)
                }
                return
            }
            print("[AdMob] loading banner...")
            banner.load(Request())
            didLoad = true
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("[AdMob] banner loaded")
            isLoaded = true
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("[AdMob] banner failed: \(error.localizedDescription)")
            isLoaded = false
        }
    }
}
#endif

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
        case .profile: return "Settings"
        }
    }

    var defaultIcon: String {
        switch self {
        case .explore: return "dot.radiowaves.left.and.right"
        case .saved:   return "heart"
        case .map:     return "map"
        case .profile: return "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .explore: return "dot.radiowaves.left.and.right"
        case .saved:   return "heart.fill"
        case .map:     return "map.fill"
        case .profile: return "gearshape.fill"
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
        Button(action: {
            HapticManager.shared.light()
            selectedTab = tab
            onTap()
        }) {
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
                Button(action: {
                    HapticManager.shared.light()
                    onCompassTap()
                }) {
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
