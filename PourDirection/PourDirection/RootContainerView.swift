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
    case editProfile
    case help
}

// MARK: - Mock Model
// Temporary stand-in for a real venue model.
// Replace with a proper domain model when backend is introduced.

struct MockPlace: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let vibe: String
    let distance: String
    let isOpen: Bool
    let rating: Double
    let closingTime: String
    let reviewCount: Int
    // Event-specific (nil for bars/clubs/stores)
    let eventTime: String?
    let venue: String?
    let priceRange: String?
    let isTonight: Bool

    static func generate(category: String, vibe: String) -> MockPlace {
        let distances    = ["0.2 mi", "0.4 mi", "0.6 mi", "0.9 mi", "1.2 mi", "1.5 mi"]
        let ratings      = [3.8, 4.0, 4.1, 4.2, 4.3, 4.5, 4.7, 4.8]
        let reviewCounts = [5, 12, 28, 47, 89, 134, 203, 389]

        if category == "Event" {
            let chillNames     = ["Live Jazz Night", "Acoustic Sessions", "Wine & Canvas", "Art Gallery Opening"]
            let energeticNames = ["Rooftop Sessions", "DJ Battle Night", "The Midnight Live", "Electronic Night"]
            let otherNames     = ["Comedy Open Mic", "Karaoke Night", "Trivia Night", "Stand-Up Showcase"]

            let pool: [String] = {
                switch vibe {
                case "Chill":     return chillNames
                case "Energetic": return energeticNames
                default:          return otherNames
                }
            }()

            let venues       = ["The Cellar Jazz Club", "Rooftop at The Ace", "Underground Lounge",
                                "The Grand Ballroom", "Velvet Room", "District Stage"]
            let tonightTimes = ["Tonight at 7:00 PM", "Tonight at 9:00 PM", "Tonight at 10:30 PM"]
            let upcomingTimes = ["Sat at 8:00 PM", "Sun at 7:30 PM", "Fri at 9:00 PM"]
            let prices       = ["$10–$20", "$15–$30", "$20–$40", "Free", "$25–$50"]

            let eventTime = (tonightTimes + upcomingTimes).randomElement()!
            let isTonight = eventTime.hasPrefix("Tonight")

            return MockPlace(
                name:        pool.randomElement()!,
                category:    "Event",
                vibe:        vibe,
                distance:    distances.randomElement()!,
                isOpen:      true,
                rating:      ratings.randomElement()!,
                closingTime: eventTime,
                reviewCount: reviewCounts.randomElement()!,
                eventTime:   eventTime,
                venue:       venues.randomElement()!,
                priceRange:  prices.randomElement()!,
                isTonight:   isTonight
            )
        }

        let barNames   = ["The Rusty Anchor", "Cellar No. 7", "The Copper Still", "Harbor Social"]
        let clubNames  = ["Neon Serenade", "Echo Lounge", "Apex Club", "Drift"]
        let storeNames = ["The Bottle Shop", "Reserve Liquors", "Corner Stock", "The Pour House"]
        let eventNames = ["Live Jazz Night", "Rooftop Sessions", "The Underground", "Velvet Social"]

        let pool: [String] = {
            switch category {
            case "Club":         return clubNames
            case "Liquor Store": return storeNames
            case "Event":        return eventNames
            default:             return barNames
            }
        }()

        let closingTimes = ["12:00 AM", "1:00 AM", "2:00 AM", "3:00 AM"]

        return MockPlace(
            name:        pool.randomElement()!,
            category:    category,
            vibe:        vibe,
            distance:    distances.randomElement()!,
            isOpen:      Bool.random(),
            rating:      ratings.randomElement()!,
            closingTime: closingTimes.randomElement()!,
            reviewCount: reviewCounts.randomElement()!,
            eventTime:   nil,
            venue:       nil,
            priceRange:  nil,
            isTonight:   false
        )
    }

    // Returns a fresh random place with the same category/vibe — used for "Not Feeling It"
    func regenerated() -> MockPlace {
        MockPlace.generate(category: category, vibe: vibe)
    }
}

// MARK: - Root Container View

struct RootContainerView: View {

    // ── Navigation & Flow State ───────────────────────────────────────────────
    @State private var selectedTab: AppTab             = .explore
    @State private var navigationPath                  = NavigationPath()
    @State private var isCompassActive: Bool           = false
    @State private var currentTargetPlace: MockPlace?  = nil
    // Drives fullScreenCover via item: — avoids the isPresented timing bug.
    @State private var compassPresentation: MockPlace? = nil
    // Tracks the currently visible pushed route for conditional UI (e.g. ad banner).
    @State private var activeRoute: AppRoute?          = nil

    private var shouldHideAdBanner: Bool {
        if selectedTab == .profile { return true }
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
                onChangeTarget: {
                    compassPresentation = nil
                    isCompassActive     = false
                    currentTargetPlace  = nil
                    navigationPath      = NavigationPath()
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
            comingSoonPlaceholder(label: "Map")
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
                initialPlace: MockPlace.generate(category: "Bar", vibe: vibe ?? "Any"),
                onLetsGo: { place in
                    currentTargetPlace  = place
                    isCompassActive     = true
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
                initialPlace: MockPlace.generate(category: "Event", vibe: vibe),
                onLetsGo: { place in
                    currentTargetPlace  = place
                    isCompassActive     = true
                    compassPresentation = place
                }
            )
            .onAppear    { activeRoute = .eventSuggestion(vibe: vibe) }
            .onDisappear { activeRoute = nil }
        case .mixedSuggestion:
            MixedSuggestionView(
                onSelectPlace: { place in
                    currentTargetPlace  = place
                    isCompassActive     = true
                    compassPresentation = place
                }
            )
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
        if isCompassActive, let place = currentTargetPlace {
            compassPresentation = place
        } else {
            navigationPath.append(AppRoute.barSuggestion(vibe: nil))
        }
    }
}

#Preview {
    RootContainerView()
}
