//
//  RootContainerView.swift
//  PourDirection
//
//  App shell. Owns all top-level navigation state.
//  All screen transitions originate here — subviews receive closures, never navigate themselves.
//

import SwiftUI

// MARK: - App Route

/// Typed destinations pushed onto the NavigationStack path.
/// All route transitions are initiated by RootContainerView.
enum AppRoute: Hashable {
    case barSuggestion(vibe: String?)
    case eventSuggestion(vibe: String)
    case pickYourVibe
    case mixedSuggestion
    case compass(MapItem)
    case editProfile
    case help
}

// MARK: - Root Container View

struct RootContainerView: View {

    // ── Navigation & Flow State ───────────────────────────────────────────────
    @State private var selectedTab: AppTab             = .explore
    @State private var navigationPath                  = NavigationPath()
    // Drives fullScreenCover via item: — avoids the isPresented timing bug.
    @State private var compassPresentation: MapItem?   = nil
    // Tracks the currently visible pushed route for conditional UI (e.g. ad banner).
    @State private var activeRoute: AppRoute?          = nil

    private var shouldHideAdBanner: Bool {
        if selectedTab == .profile { return true }
        if selectedTab == .map { return true }
        if case .eventSuggestion = activeRoute { return true }
        if case .editProfile = activeRoute { return true }
        if case .help = activeRoute { return true }
        return false
    }

    // ── Body ─────────────────────────────────────────────────────────────────
    var body: some View {
        NavigationStack(path: $navigationPath) {
            tabContent
                .navigationBarBackButtonHidden(true)
                .navigationDestination(for: AppRoute.self) { route in
                    destinationView(for: route)
                        .navigationBarBackButtonHidden(true)
                        .enableSwipeBack()
                }
        }
        // safeAreaInset directly on NavigationStack so pushed views inherit the inset
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if !shouldHideAdBanner {
                    AdBannerPlaceholderView()
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColors.background)
                }
                CustomTabBar(
                    selectedTab:  $selectedTab,
                    onCompassTap: handleCompassTap,
                    onTabTap: { tapped in
                        if tapped == selectedTab {
                            navigationPath = NavigationPath()
                            activeRoute    = nil
                        }
                    }
                )
            }
            .background(AppColors.background.ignoresSafeArea(edges: .bottom))
        }
        // CompassActiveView — item: guarantees the place is available when content renders
        .fullScreenCover(item: $compassPresentation) { place in
            CompassActiveView(
                place:        place,
                onOpenInMaps: { /* Maps integration — future phase */ },
                selectedTab:  $selectedTab,
                onDismiss: {
                    compassPresentation = nil
                }
            )
        }
        // Reset push stack when the user switches tabs
        .onChange(of: selectedTab) { _ in
            navigationPath = NavigationPath()
            activeRoute    = nil
        }
        .preferredColorScheme(.dark)
    }

    // ── Tab Content ───────────────────────────────────────────────────────────

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .explore:
            ExploreView(
                onFindBar:           { navigationPath.append(AppRoute.barSuggestion(vibe: nil)) },
                onFindSomethingElse: { navigationPath.append(AppRoute.pickYourVibe) },
                onSurpriseMe:        { navigationPath.append(AppRoute.mixedSuggestion) }
            )
        case .saved:
            comingSoonPlaceholder(label: "Saved")
        case .map:
            MapTabView(onLetsGo: { place in
                compassPresentation = place
            })
        case .profile:
            ProfileView(
                onEditProfile: { navigationPath.append(AppRoute.editProfile) },
                onHelp:        { navigationPath.append(AppRoute.help) }
            )
        }
    }

    // ── Navigation Destinations ────────────────────────────────────────────────

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .barSuggestion(let vibe):
            BarSuggestionView(
                initialPlace: MapItem.mock(category: .bar, vibe: vibe ?? "Any"),
                onLetsGo: { place in
                    compassPresentation = place
                }
            )
        case .pickYourVibe:
            PickYourVibeView(
                onSelectVibe: { vibe in
                    navigationPath.append(AppRoute.eventSuggestion(vibe: vibe))
                }
            )
        case .eventSuggestion(let vibe):
            BarSuggestionView(
                initialPlace: MapItem.mock(category: .event, vibe: vibe),
                onLetsGo: { place in
                    compassPresentation = place
                }
            )
            .onAppear    { activeRoute = .eventSuggestion(vibe: vibe) }
            .onDisappear { activeRoute = nil }
        case .mixedSuggestion:
            MixedSuggestionView(
                onSelectPlace: { place in
                    compassPresentation = place
                }
            )
        case .compass:
            // Compass is presented via fullScreenCover, not as a pushed destination.
            // This case exists for routing centralization — future phases may push it.
            EmptyView()
        case .editProfile:
            EditProfileView(onBack: { navigationPath.removeLast() })
        case .help:
            HelpView(onBack: { navigationPath.removeLast() })
        }
    }

    private func comingSoonPlaceholder(label: String) -> some View {
        ZStack {
            AppColors.gradientBackground
                .ignoresSafeArea()
            VStack(spacing: AppSpacing.xs) {
                Text(label)
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.secondary.opacity(0.15))
                Text("Coming soon")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.secondary.opacity(0.08))
            }
        }
    }

    // ── Compass Button Logic ─────────────────────────────────────────────────

    private func handleCompassTap() {
        if let place = compassPresentation {
            // Re-open existing compass target
            compassPresentation = nil
            DispatchQueue.main.async {
                compassPresentation = place
            }
        } else {
            navigationPath.append(AppRoute.barSuggestion(vibe: nil))
        }
    }
}

#Preview {
    RootContainerView()
        .environment(LocationManager())
}
