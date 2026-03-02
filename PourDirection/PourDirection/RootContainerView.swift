//
//  RootContainerView.swift
//  PourDirection
//
//  App shell. Owns all top-level navigation state.
//  All screen transitions originate here — subviews receive closures, never navigate themselves.
//

import SwiftUI
import CoreLocation

// MARK: - App Route

/// Typed destinations pushed onto the NavigationStack path.
/// All route transitions are initiated by RootContainerView.
enum AppRoute: Hashable {
    case suggestions(category: PlaceCategory)
    case suggestionsMixed
    case compass(Place)
    case editProfile
    case help
}

// MARK: - Root Container View

struct RootContainerView: View {

    // ── Navigation & Flow State ───────────────────────────────────────────────
    @State private var selectedTab: AppTab          = .explore
    @State private var navigationPath               = NavigationPath()
    // Drives fullScreenCover via item: — avoids the isPresented timing bug.
    @State private var compassPresentation: Place?  = nil
    /// Accent color driven by the current content — flows to tab bar.
    @State private var tabBarAccent: Color          = AppColors.primary

    private var shouldHideAdBanner: Bool {
        if selectedTab == .profile { return true }
        if selectedTab == .map { return true }
        if case .editProfile = activeRoute { return true }
        if case .help = activeRoute { return true }
        return false
    }

    @State private var activeRoute: AppRoute? = nil

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
                    accentColor:  tabBarAccent,
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
                onOpenInMaps: {
                    let lat  = place.coordinate.latitude
                    let lng  = place.coordinate.longitude
                    let name = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "maps://?daddr=\(lat),\(lng)&dirflg=w&q=\(name)") {
                        UIApplication.shared.open(url)
                    }
                },
                selectedTab:  $selectedTab,
                onDismiss: {
                    compassPresentation = nil
                }
            )
        }
        // Reset push stack and accent when the user switches tabs
        .onChange(of: selectedTab) { _ in
            navigationPath = NavigationPath()
            activeRoute    = nil
            tabBarAccent   = AppColors.primary
        }
        // Reset accent to brand when user swipes back to root
        .onChange(of: navigationPath) { _, newPath in
            if newPath.isEmpty {
                tabBarAccent = AppColors.primary
            }
        }
        .preferredColorScheme(.dark)
    }

    // ── Tab Content ───────────────────────────────────────────────────────────

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .explore:
            ExploreView(
                onFindBar:        { navigationPath.append(AppRoute.suggestions(category: .bar)) },
                onFindRestaurant: { navigationPath.append(AppRoute.suggestions(category: .restaurant)) },
                onFindClub:       { navigationPath.append(AppRoute.suggestions(category: .club)) },
                onFindDispensary: { navigationPath.append(AppRoute.suggestions(category: .dispensary)) }
            )
        case .saved:
            SavedView(onLetsGo: { place in
                compassPresentation = place
            })
        case .map:
            MapTabView(
                onLetsGo: { mapItem in
                    compassPresentation = Place(
                        id:               mapItem.id,
                        name:             mapItem.name,
                        formattedAddress: nil,
                        coordinate:       mapItem.coordinate,
                        rating:           mapItem.rating
                    )
                },
                onAccentChange: { tabBarAccent = $0 }
            )
        case .profile:
            ProfileView(
                onHelp: { navigationPath.append(AppRoute.help) }
            )
        }
    }

    // ── Navigation Destinations ────────────────────────────────────────────────

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .suggestions(let category):
            SuggestionView(
                category: category,
                onLetsGo: { place in
                    compassPresentation = place
                },
                onAccentChange: { tabBarAccent = $0 },
                onOpenMap: {
                    navigationPath = NavigationPath()
                    selectedTab = .map
                }
            )
        case .suggestionsMixed:
            SuggestionView.mixed(
                onLetsGo: { place in
                    compassPresentation = place
                },
                onAccentChange: { tabBarAccent = $0 },
                onOpenMap: {
                    navigationPath = NavigationPath()
                    selectedTab = .map
                }
            )
        case .compass(let place):
            // Compass is presented via fullScreenCover(item:), not as a pushed destination.
            let _ = place
            EmptyView()
        case .editProfile:
            EditProfileView(onBack: { navigationPath.removeLast() })
                .onAppear    { activeRoute = .editProfile }
                .onDisappear { activeRoute = nil }
        case .help:
            HelpView(onBack: { navigationPath.removeLast() })
                .onAppear    { activeRoute = .help }
                .onDisappear { activeRoute = nil }
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
            navigationPath.append(AppRoute.suggestionsMixed)
        }
    }
}

#Preview {
    RootContainerView()
        .environment(LocationManager())
        .environmentObject(AdsManager.previewReady)
}
