//
//  SuggestionView.swift
//  PourDirection
//
//  Shows nearby places one at a time for a category or mixed feed, sorted closest-first per category.
//  "Let's Go" opens the compass. Swipe left/right to navigate cards.
//

import SwiftUI
import CoreLocation

struct SuggestionView: View {

    enum Mode {
        case category(PlaceCategory)
        case mixed
    }

    let mode: Mode
    let onLetsGo: (Place) -> Void

    init(category: PlaceCategory, onLetsGo: @escaping (Place) -> Void) {
        self.mode = .category(category)
        self.onLetsGo = onLetsGo
    }

    static func mixed(onLetsGo: @escaping (Place) -> Void) -> SuggestionView {
        SuggestionView(mode: .mixed, onLetsGo: onLetsGo)
    }

    private init(mode: Mode, onLetsGo: @escaping (Place) -> Void) {
        self.mode = mode
        self.onLetsGo = onLetsGo
    }

    @Environment(LocationManager.self) private var locationManager

    private struct SuggestionItem: Identifiable {
        let id: String
        let place: Place
        let category: PlaceCategory
    }

    @State private var items: [SuggestionItem] = []
    @State private var currentIndex: Int     = 0
    @State private var isLoading: Bool       = true   // start true — avoid "no results" flash
    @State private var errorMessage: String? = nil
    @State private var hasLoaded:    Bool    = false  // prevents onChange from re-firing after load
    @State private var isReversing:  Bool    = false  // controls card transition direction
    @State private var dragOffset:   CGFloat = 0      // horizontal drag for snap feel
    private let savedManager = SavedPlacesManager.shared
    private let adBannerHeight: CGFloat      = 50 + (AppSpacing.xs * 2)
    private let cardMaxHeight: CGFloat       = 420

    private var currentItem: SuggestionItem? {
        guard currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    private var activeCategory: PlaceCategory? {
        if let item = currentItem { return item.category }
        if case let .category(category) = mode { return category }
        return nil
    }

    private var headerSubtitle: String {
        guard let category = activeCategory else { return "something fun?" }
        switch category {
        case .bar:
            return "some drinks?"
        case .restaurant:
            return "some food?"
        case .club:
            return "some music?"
        case .dispensary:
            return "the couch (lol)?"
        }
    }

    var body: some View {
        ZStack {
            AppColors.gradientBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 2) {
                    Text("How About")
                        .font(AppTypography.titleSmallLarge)
                        .foregroundColor(AppColors.secondary)
                        .lineLimit(1)
                    Text(headerSubtitle)
                        .font(AppTypography.titleSmallLarge)
                        .foregroundColor(AppColors.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.top, AppSpacing.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)

                // ── Content ───────────────────────────────────────────────────
                ZStack(alignment: .top) {
                    if isLoading {
                        ProgressView()
                            .tint(AppColors.primary)

                    } else if let error = errorMessage {
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundColor(AppColors.primary.opacity(0.6))
                            Text(error)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                            Button("Try Again") { Task { await load() } }
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.primary)
                        }

                    } else if let item = currentItem {
                        placeCard(item.place, category: item.category)
                    } else if !items.isEmpty {
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 36))
                                .foregroundColor(AppColors.primary.opacity(0.6))
                            Text({
                                if case .mixed = mode {
                                    return "You've seen all nearby places."
                                }
                                let label = activeCategory?.rawValue.lowercased() ?? "places"
                                return "You've seen all nearby \(label)s."
                            }())
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.5))
                        }
                    } else {
                        VStack(spacing: AppSpacing.xs) {
                            Text("Nothing open nearby")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.secondary.opacity(0.5))
                            Text("Try expanding your radius or checking back later")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.3))
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.top, AppSpacing.sm)

                // ── Bottom Actions ────────────────────────────────────────────
                VStack(spacing: AppSpacing.sm) {
                    if let item = currentItem {
                        PrimaryButton(title: "Let's Go") { onLetsGo(item.place) }
                    } else if !items.isEmpty {
                        Button(action: {
                            isReversing = false
                            dragOffset = 0
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                                currentIndex = 0
                            }
                        }) {
                            Text("Start Over")
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.top, 25)
                .padding(.bottom, CustomTabBar.height + adBannerHeight + AppSpacing.sm)
            }
        }
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdating()
        }
        .task { await load() }
        // One-shot retry: if location wasn't ready when .task fired, load once it arrives
        .onChange(of: locationManager.currentLocation) { _, newLocation in
            guard newLocation != nil, !hasLoaded, !isLoading else { return }
            Task { await load() }
        }
    }

    // MARK: - Place Card

    private func placeCard(_ place: Place, category: PlaceCategory) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Hero Photo ────────────────────────────────────────────────────
            AsyncImage(url: place.photoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 120, maxHeight: 220)
                        .clipped()
                case .failure:
                    photoPlaceholder
                default:
                    photoPlaceholder
                        .overlay(ProgressView().tint(AppColors.primary))
                }
            }
            .frame(minHeight: 120, maxHeight: 220)
            .layoutPriority(0)

            // ── Info ──────────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: AppSpacing.xs) {

                HStack(alignment: .center, spacing: AppSpacing.xs) {
                    Text(place.name)
                        .font(AppTypography.header)
                        .foregroundColor(AppColors.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer()
                    Button(action: {
                        HapticManager.shared.light()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                            savedManager.toggleSave(place, category: category)
                        }
                    }) {
                        Image(systemName: savedManager.isSaved(place) ? "heart.fill" : "heart")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(savedManager.isSaved(place) ? AppColors.primary : AppColors.secondary.opacity(0.35))
                            .scaleEffect(savedManager.isSaved(place) ? 1.15 : 1.0)
                    }
                    .buttonStyle(.plain)
                }

                if let address = place.formattedAddress {
                    Label(address, systemImage: "mappin")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary.opacity(0.55))
                        .lineLimit(1)
                }

                // ── Rating + Distance row ────────────────────────────
                HStack(spacing: AppSpacing.md) {
                    if let rating = place.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.primary)
                            Text(String(format: "%.1f", rating))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.7))
                        }
                    }

                    let dist = place.distance(from: locationManager.currentLocation)
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.primary)
                        Text(Place.formatDistance(dist))
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary.opacity(0.7))
                            .lineLimit(1)
                    }

                    Spacer()

                    if items.count > 1 {
                        Text("\(currentIndex + 1) of \(items.count)")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary.opacity(0.3))
                    }
                }

                // ── Open/Closed status row ───────────────────────────
                if let isOpen = place.isOpenNow {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isOpen ? AppColors.primary : AppColors.clubRed)
                            .frame(width: 6, height: 6)
                        Text(isOpen ? "Open" : "Closed")
                            .font(AppTypography.caption)
                            .foregroundColor(isOpen ? AppColors.primary : AppColors.clubRed)
                        if isOpen, let closes = place.closesAt {
                            Text("· Closes \(closes)")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.4))
                                .lineLimit(1)
                        } else if !isOpen, let opens = place.opensAt {
                            Text("· Opens \(opens)")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.4))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .layoutPriority(1)
        }
        .frame(maxWidth: 340)
        .frame(maxHeight: cardMaxHeight)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(AppColors.cardSurface.opacity(0.92))
        .cornerRadius(AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.secondary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.5), radius: AppSpacing.sm, x: 0, y: 4)
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .offset(x: dragOffset)
        .rotationEffect(.degrees(Double(dragOffset / 30)))
        .gesture(
            DragGesture()
                .onChanged { value in
                    let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                    guard isHorizontal else { return }
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                    guard isHorizontal else {
                        withAnimation(.spring(response: 0.12, dampingFraction: 0.82)) {
                            dragOffset = 0
                        }
                        return
                    }

                    let projected = value.predictedEndTranslation.width
                    let finalX = projected != 0 ? projected : value.translation.width
                    let shouldGoBack = finalX > 35
                    let shouldGoNext = finalX < -35

                    if shouldGoBack && currentIndex > 0 {
                        isReversing = true
                        withAnimation(.spring(response: 0.12, dampingFraction: 0.82)) {
                            dragOffset = 0
                            currentIndex -= 1
                        }
                } else if shouldGoNext && currentIndex + 1 < items.count {
                        isReversing = false
                        withAnimation(.spring(response: 0.12, dampingFraction: 0.82)) {
                            dragOffset = 0
                            currentIndex += 1
                        }
                    } else {
                        withAnimation(.spring(response: 0.12, dampingFraction: 0.82)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .id(currentIndex)
        .transition(
            isReversing
                ? .asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal:   .move(edge: .trailing).combined(with: .opacity)
                )
                : .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                )
        )
    }

    private var photoPlaceholder: some View {
        AppColors.cardSurface
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundColor(AppColors.secondary.opacity(0.15))
            )
    }

    // MARK: - Load

    // Resolve the type string to send to the Edge Function.
    // Restaurants after 11 pm switch to a late-night type that includes fast food
    // and filters to open-now places.
    private func resolvedTypeString(for category: PlaceCategory) -> String {
        guard category == .restaurant else { return category.googleIncludedType }
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 23 ? "restaurantLateNight" : category.googleIncludedType
    }

    private func fetchPlaces(for category: PlaceCategory, at loc: CLLocation) async throws -> [Place] {
        var fetched = try await SupabaseManager.shared.fetchNearbyPlaces(
            lat: loc.coordinate.latitude,
            lng: loc.coordinate.longitude,
            type: resolvedTypeString(for: category)
        )

        if category == .club {
            fetched = fetched.filter { place in
                let typeSet = Set(place.types)
                return typeSet.contains("night_club") && !typeSet.contains("restaurant")
            }
        }

        // Text Search doesn't enforce a hard radius — trim dispensary results to 3 km.
        if category == .dispensary {
            fetched = fetched.filter { ($0.distance(from: loc) ?? .greatestFiniteMagnitude) <= 3000 }
        }

        return fetched.sorted {
            let d0 = $0.distance(from: loc) ?? .greatestFiniteMagnitude
            let d1 = $1.distance(from: loc) ?? .greatestFiniteMagnitude
            return d0 < d1
        }
    }

    private func interleavedItems(from buckets: [PlaceCategory: [Place]]) -> [SuggestionItem] {
        var indices: [PlaceCategory: Int] = [:]
        var available = buckets.filter { !$0.value.isEmpty }.map(\.key)
        var rng = SystemRandomNumberGenerator()
        var result: [SuggestionItem] = []

        while !available.isEmpty {
            let category = available.randomElement(using: &rng) ?? available[0]
            let idx = indices[category, default: 0]
            guard let list = buckets[category], idx < list.count else {
                available.removeAll { $0 == category }
                continue
            }
            let place = list[idx]
            indices[category] = idx + 1
            result.append(
                SuggestionItem(
                    id: "\(category.rawValue)-\(place.id)",
                    place: place,
                    category: category
                )
            )
            if idx + 1 >= list.count {
                available.removeAll { $0 == category }
            }
        }

        return result
    }

    private func load() async {
        guard let loc = locationManager.currentLocation else { return }
        isLoading    = true
        errorMessage = nil
        do {
            switch mode {
            case .category(let category):
                let fetched = try await fetchPlaces(for: category, at: loc)
                let open = fetched.filter { $0.isOpenNow != false }
                items = open.map {
                    SuggestionItem(
                        id: "\(category.rawValue)-\($0.id)",
                        place: $0,
                        category: category
                    )
                }
            case .mixed:
                let categories: [PlaceCategory] = [.bar, .restaurant, .club, .dispensary]
                let buckets: [PlaceCategory: [Place]] = try await withThrowingTaskGroup(
                    of: (PlaceCategory, [Place]).self
                ) { group in
                    for category in categories {
                        group.addTask {
                            let fetched = try await fetchPlaces(for: category, at: loc)
                            return (category, fetched)
                        }
                    }
                    var dict: [PlaceCategory: [Place]] = [:]
                    for try await (category, fetched) in group {
                        dict[category] = fetched
                    }
                    return dict
                }

                let openBuckets = buckets.mapValues { $0.filter { $0.isOpenNow != false } }
                items = interleavedItems(from: openBuckets)
            }
            currentIndex = 0
        } catch {
            errorMessage = "Couldn't load suggestions. Check your connection and try again."
            print("[SuggestionView] fetchNearbyPlaces error: \(error)")
        }
        hasLoaded = true
        isLoading = false
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        SuggestionView(
            category: .bar,
            onLetsGo: { place in print("Let's go to \(place.name)") }
        )
        CustomTabBar(selectedTab: .constant(.explore))
    }
    .ignoresSafeArea(edges: .bottom)
    .preferredColorScheme(.dark)
    .environment(LocationManager())
}
