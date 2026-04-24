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
    case help
}

// MARK: - Root Container View

struct RootContainerView: View {

    @Environment(LocationManager.self) private var locationManager
    @Environment(ThemeManager.self)   private var themeManager
    private let notificationRouting = NotificationRoutingManager.shared

    // ── Navigation & Flow State ───────────────────────────────────────────────
    @State private var selectedTab: AppTab          = .explore
    @State private var navigationPath               = NavigationPath()
    // Drives fullScreenCover via item: — avoids the isPresented timing bug.
    @State private var compassPresentation: Place?  = nil
    /// Accent color driven by the current content — flows to tab bar.
    @State private var tabBarAccent: Color          = AppColors.primary
    /// Prevents the prefetch task from firing more than once per session.
    @State private var hasPrewarmed: Bool           = false
    /// Increments on every tab switch or screen push — forces ad banner to reload.
    @State private var adReloadTrigger: Int         = 0
    @State private var savedHomeSetupTrigger: Int   = 0

    private var shouldHideAdBanner: Bool {
        if selectedTab == .map { return true }
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
                        .id(adReloadTrigger)
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
        .onChange(of: selectedTab) { _, _ in
            navigationPath = NavigationPath()
            activeRoute    = nil
            tabBarAccent   = AppColors.primary
            adReloadTrigger += 1
        }
        // Reload ad on every navigation push/pop
        .onChange(of: navigationPath) { _, newPath in
            if newPath.isEmpty {
                tabBarAccent = AppColors.primary
            }
            adReloadTrigger += 1
        }
        .onAppear {
            // Start location as early as possible so it's ready when views appear
            locationManager.requestPermission()
            locationManager.startUpdating()
            NotificationManager.shared.refreshHomeContextNotifications(currentLocation: locationManager.currentLocation)
            handlePendingNotificationActionIfNeeded()
        }
        // Once location arrives for the first time, pre-warm the cache for all
        // categories so the first tap on any suggestion view is near-instant.
        .onChange(of: locationManager.currentLocation) { _, loc in
            NotificationManager.shared.refreshHomeContextNotifications(currentLocation: loc)

            guard let loc, !hasPrewarmed else { return }
            hasPrewarmed = true
            let lat  = loc.coordinate.latitude
            let lng  = loc.coordinate.longitude
            let walk = DistancePreferences.shared.walkingDistanceMeters
            let wide = DistancePreferences.shared.searchAreaMeters
            Task {
                // Night categories
                async let bars      = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "bar",          radius: walk)
                async let rests     = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "restaurant",   radius: walk)
                async let dispos    = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "dispensary",   radius: walk)
                async let liquor    = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "liquor_store", radius: walk)
                async let clubs     = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "night_club",   radius: wide)
                async let casino    = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "casino",       radius: wide)
                // Day categories
                async let patio     = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "patio",        radius: walk)
                async let brunch    = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "brunch",       radius: walk)
                async let coffee    = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "coffee",       radius: walk)
                async let dayDrinks = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "day_drinks",   radius: wide)
                async let parks     = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "park",         radius: walk)
                async let dessert   = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "dessert",      radius: walk)
                _ = try? await bars
                _ = try? await rests
                _ = try? await dispos
                _ = try? await liquor
                _ = try? await clubs
                _ = try? await casino
                _ = try? await patio
                _ = try? await brunch
                _ = try? await coffee
                _ = try? await dayDrinks
                _ = try? await parks
                _ = try? await dessert
            }
        }
        .onChange(of: notificationRouting.pendingAction) { _, _ in
            handlePendingNotificationActionIfNeeded()
        }
        .preferredColorScheme(themeManager.preferredColorScheme)
    }

    // ── Tab Content ───────────────────────────────────────────────────────────

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .explore:
            ExploreView(onCategoryTap: { category in
                navigationPath.append(AppRoute.suggestions(category: category))
            })
        case .saved:
            SavedView(
                onLetsGo: { place in
                    compassPresentation = place
                },
                forceHomeSetupTrigger: savedHomeSetupTrigger,
                onSetHome: {
                    // Switch to Settings and open the home sheet
                    selectedTab = .profile
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        HomeLocationManager.shared.shouldPresentSetupSheet = true
                    }
                }
            )
        case .map:
            MapTabView(
                onLetsGo: { mapItem in
                    compassPresentation = Place(
                        id:               mapItem.id,
                        name:             mapItem.name,
                        formattedAddress: nil,
                        coordinate:       mapItem.coordinate,
                        rating:           mapItem.rating,
                        isOpenNow:        mapItem.isOpen
                    )
                },
                onAccentChange: { tabBarAccent = $0 },
                onHomeTap: {
                    if let homePlace = HomeLocationManager.shared.homePlace {
                        compassPresentation = homePlace
                    }
                }
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

    private func handlePendingNotificationActionIfNeeded() {
        guard let action = notificationRouting.pendingAction else { return }
        notificationRouting.clearPending()

        navigationPath = NavigationPath()

        switch action {
        case .openSavedForHomeSetup:
            selectedTab = .saved
            compassPresentation = nil
            savedHomeSetupTrigger += 1
        case .openHomeCompass:
            selectedTab = .saved
            if let home = HomeLocationManager.shared.homePlace {
                DispatchQueue.main.async {
                    compassPresentation = home
                }
            } else {
                savedHomeSetupTrigger += 1
            }
        }
    }
}

#Preview {
    RootContainerView()
        .environment(LocationManager())
        .environmentObject(AdsManager.previewReady)
}
