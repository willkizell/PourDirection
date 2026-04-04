//
//  SuggestionView.swift
//  PourDirection
//
//  Shows nearby places one at a time for a category or mixed feed, sorted closest-first per category.
//  "Let's Go" opens the compass. Swipe left/right to navigate cards.
//

import SwiftUI
import CoreLocation

// MARK: - Cached Async Image

struct CachedAsyncImage: View {
    let url: URL?
    let contentMode: ContentMode
    let photoPlaceholder: AnyView
    let cardPhotoHeight: CGFloat

    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: cardPhotoHeight)
                    .clipped()
            } else if isLoading {
                photoPlaceholder
                    .frame(maxWidth: .infinity)
                    .frame(height: cardPhotoHeight)
                    .overlay(ProgressView().tint(AppColors.primary))
            } else {
                photoPlaceholder
                    .frame(maxWidth: .infinity)
                    .frame(height: cardPhotoHeight)
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url else {
            isLoading = false
            return
        }

        // Check memory cache first
        if let cachedImage = await ImageCacheManager.shared.cachedImage(for: url) {
            self.image = cachedImage
            self.isLoading = false
            return
        }

        // Download from network
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                // Cache the image
                await ImageCacheManager.shared.cache(image: uiImage, for: url)
                self.image = uiImage
            }
        } catch {
            // Image failed to load
        }

        isLoading = false
    }
}

struct SuggestionView: View {

    enum Mode {
        case category(PlaceCategory)
        case mixed
    }

    let mode: Mode
    let onLetsGo: (Place) -> Void
    let onAccentChange: ((Color) -> Void)?
    let onOpenMap: (() -> Void)?

    init(category: PlaceCategory, onLetsGo: @escaping (Place) -> Void, onAccentChange: ((Color) -> Void)? = nil, onOpenMap: (() -> Void)? = nil) {
        self.mode = .category(category)
        self.onLetsGo = onLetsGo
        self.onAccentChange = onAccentChange
        self.onOpenMap = onOpenMap
    }

    static func mixed(onLetsGo: @escaping (Place) -> Void, onAccentChange: ((Color) -> Void)? = nil, onOpenMap: (() -> Void)? = nil) -> SuggestionView {
        SuggestionView(mode: .mixed, onLetsGo: onLetsGo, onAccentChange: onAccentChange, onOpenMap: onOpenMap)
    }

    private init(mode: Mode, onLetsGo: @escaping (Place) -> Void, onAccentChange: ((Color) -> Void)? = nil, onOpenMap: (() -> Void)? = nil) {
        self.mode = mode
        self.onLetsGo = onLetsGo
        self.onAccentChange = onAccentChange
        self.onOpenMap = onOpenMap
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
    @State private var isReversing:      Bool    = false  // controls card transition direction
    @State private var dragOffset:       CGFloat = 0      // horizontal drag for snap feel
    @State private var showDistanceSheet: Bool   = false
    @State private var distanceSnapshotWalking: Double = 0
    @State private var distanceSnapshotSearch:  Double = 0
    private let savedManager  = SavedPlacesManager.shared
    private let distancePrefs = DistancePreferences.shared
    private let adBannerHeight: CGFloat      = 50 + (AppSpacing.xs * 2)
    private let cardMaxHeight: CGFloat       = 420
    private let cardPhotoHeight: CGFloat     = 200
    private var cardWidth: CGFloat {
        UIScreen.main.bounds.width - (AppSpacing.screenHorizontalPadding * 2)
    }

    private var currentItem: SuggestionItem? {
        guard currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    private var locationDenied: Bool {
        locationManager.authorizationStatus == .denied ||
        locationManager.authorizationStatus == .restricted
    }

    private var activeCategory: PlaceCategory? {
        if let item = currentItem { return item.category }
        if case let .category(category) = mode { return category }
        return nil
    }

    /// Accent color — matches current card's category. Falls back to brand for mixed before load.
    private var accent: Color {
        activeCategory?.color ?? AppColors.primary
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
            return "the couch?"
        case .liquorStore:
            return "da liquor store?"
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
                        .foregroundColor(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .animation(.easeInOut(duration: 0.25), value: activeCategory)
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.top, AppSpacing.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)

                // ── Content ───────────────────────────────────────────────────
                ZStack(alignment: .top) {
                    if locationDenied {
                        locationDeniedView
                    } else if isLoading {
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
                        endOfSuggestionsCard(exhausted: true)
                    } else {
                        endOfSuggestionsCard(exhausted: false)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.top, AppSpacing.sm)

                // ── Bottom Actions ────────────────────────────────────────────
                VStack(spacing: AppSpacing.sm) {
                    if let item = currentItem {
                        PrimaryButton(title: "Let's Go", color: accent) { onLetsGo(item.place) }
                    } else if !items.isEmpty {
                        // Start over link below the end card
                        Button(action: {
                            isReversing = true
                            dragOffset = 0
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                                currentIndex = 0
                            }
                        }) {
                            Text("Start Over")
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.secondary.opacity(0.35))
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
            // Fire initial accent for single-category modes
            onAccentChange?(accent)
        }
        .task { await load() }
        // One-shot retry: if location wasn't ready when .task fired, load once it arrives
        .onChange(of: locationManager.currentLocation) { _, newLocation in
            guard newLocation != nil, !hasLoaded, !isLoading else { return }
            Task { await load() }
        }
        // Notify parent when accent changes (mixed mode swiping, or after load)
        .onChange(of: currentIndex) { _, _ in
            onAccentChange?(accent)
        }
        .sheet(isPresented: $showDistanceSheet, onDismiss: {
            let changed = distancePrefs.walkingDistanceMeters != distanceSnapshotWalking
                       || distancePrefs.searchAreaMeters      != distanceSnapshotSearch
            if changed {
                hasLoaded = false
                Task { await load() }
            }
        }) {
            DistancePreferencesView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Place Card

    private func placeCard(_ place: Place, category: PlaceCategory) -> some View {
        VStack(alignment: .leading, spacing: 0) {


            // ── Hero Photo ────────────────────────────────────────────────────
            CachedAsyncImage(
                url: place.photoURL,
                contentMode: .fill,
                photoPlaceholder: AnyView(photoPlaceholder),
                cardPhotoHeight: cardPhotoHeight
            )
            .layoutPriority(0)

            // ── Info ──────────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: AppSpacing.xs) {

                HStack(alignment: .center, spacing: AppSpacing.xs) {
                    Text(place.displayName)
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
                            .foregroundColor(savedManager.isSaved(place) ? accent : AppColors.secondary.opacity(0.35))
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
                                .foregroundColor(accent)
                            Text(String(format: "%.1f", rating))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.7))
                        }
                    }

                    let dist = place.distance(from: locationManager.currentLocation)
                    let beyondWalking = (dist ?? 0) > distancePrefs.walkingDistanceMeters
                    let isDriving = category == .club && beyondWalking
                    let distIcon = isDriving ? "car.fill" : "figure.walk"
                    HStack(spacing: 4) {
                        Image(systemName: distIcon)
                            .font(.system(size: 11))
                            .foregroundColor(accent)
                        Text(Place.formatWalkingTime(dist, driving: isDriving))
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
                            .fill(isOpen ? accent : AppColors.clubRed)
                            .frame(width: 6, height: 6)
                        Text(isOpen ? "Open" : "Closed")
                            .font(AppTypography.caption)
                            .foregroundColor(isOpen ? accent : AppColors.clubRed)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
                .frame(width: cardWidth)
                .background(AppColors.cardSurface.opacity(0.92))
                .cornerRadius(AppRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .stroke(AppColors.secondary.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.5), radius: AppSpacing.sm, x: 0, y: 4)
                .frame(maxWidth: .infinity, alignment: .center)
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
                } else if shouldGoNext && currentIndex + 1 <= items.count {
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

    // MARK: - Location Denied View

    private var locationDeniedView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "location.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(accent.opacity(0.7))
            VStack(spacing: AppSpacing.xs) {
                Text("Location Access Required")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.secondary.opacity(0.9))
                    .multilineTextAlignment(.center)
                Text("PourDirection needs your location to find nearby places.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.secondary.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .medium))
                    Text("Enable in Settings")
                        .font(AppTypography.bodySmall)
                }
                .foregroundColor(accent)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .frame(maxWidth: .infinity)
                .background(accent.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(accent.opacity(0.35), lineWidth: 0.75)
                )
                .cornerRadius(AppRadius.md)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
            Spacer()
        }
    }

    // MARK: - End of Suggestions Card

    private func endOfSuggestionsCard(exhausted: Bool) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: exhausted ? "checkmark.circle" : "moon.zzz")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(accent.opacity(0.7))

            VStack(spacing: AppSpacing.xs) {
                Text(exhausted ? "You've seen it all nearby." : "Nothing open near you right now.")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.secondary.opacity(0.9))
                    .multilineTextAlignment(.center)
                Text(exhausted ? "Try the map to search a wider area." : "Expand your distance or check the map.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.secondary.opacity(0.55))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: AppSpacing.sm) {
                // Adjust distance
                Button(action: {
                    HapticManager.shared.light()
                    distanceSnapshotWalking = distancePrefs.walkingDistanceMeters
                    distanceSnapshotSearch  = distancePrefs.searchAreaMeters
                    showDistanceSheet = true
                }) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .medium))
                        Text("Adjust Distance")
                            .font(AppTypography.bodySmall)
                    }
                    .foregroundColor(accent)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(accent.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(accent.opacity(0.35), lineWidth: 0.75)
                    )
                    .cornerRadius(AppRadius.md)
                }
                .buttonStyle(.plain)

                // Open map
                Button(action: {
                    HapticManager.shared.light()
                    onOpenMap?()
                }) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("Open Map")
                            .font(AppTypography.bodySmall)
                    }
                    .foregroundColor(AppColors.secondary.opacity(0.85))
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.cardSurface.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(AppColors.secondary.opacity(0.2), lineWidth: 0.75)
                    )
                    .cornerRadius(AppRadius.md)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer()
        }
        .frame(width: cardWidth)
        .frame(height: cardMaxHeight)
        .background(AppColors.cardSurface.opacity(0.5))
        .cornerRadius(AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(accent.opacity(0.15), lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.3), radius: AppSpacing.sm, x: 0, y: 4)
        .frame(maxWidth: .infinity, alignment: .center)
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

    private func fetchPlaces(for category: PlaceCategory, at loc: CLLocation) async throws -> [Place] {
        let searchRadius = category == .club
            ? distancePrefs.searchAreaMeters
            : distancePrefs.walkingDistanceMeters

        var fetched = try await SupabaseManager.shared.fetchNearbyPlaces(
            lat: loc.coordinate.latitude,
            lng: loc.coordinate.longitude,
            type: category.googleIncludedType,
            radius: searchRadius,
            openNow: true
        )

        if category == .club {
            fetched = fetched.filter { place in
                let typeSet = Set(place.types)
                return typeSet.contains("night_club") && !typeSet.contains("restaurant")
            }
        }

        // Text Search doesn't enforce a hard radius — trim dispensary/liquor store results.
        if category == .dispensary || category == .liquorStore {
            let maxDist = max(distancePrefs.walkingDistanceMeters, 3000)
            fetched = fetched.filter { ($0.distance(from: loc) ?? .greatestFiniteMagnitude) <= maxDist }
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

    /// Max distance allowed in SuggestionView for a given category.
    /// Bars/restaurants/dispensaries → walking. Clubs → driving.
    private func suggestionMaxDistance(for category: PlaceCategory) -> Double {
        category == .club
            ? distancePrefs.searchAreaMeters
            : distancePrefs.walkingDistanceMeters
    }

    private func filterByDistance(_ places: [Place], category: PlaceCategory, from loc: CLLocation) -> [Place] {
        let maxDist = suggestionMaxDistance(for: category)
        return places.filter { ($0.distance(from: loc) ?? .greatestFiniteMagnitude) <= maxDist }
    }

    private func load() async {
        guard let loc = locationManager.currentLocation else {
            if locationDenied { isLoading = false }
            return
        }
        isLoading    = true
        errorMessage = nil
        do {
            switch mode {
            case .category(let category):
                let fetched = try await fetchPlaces(for: category, at: loc)
                let open = fetched.filter { $0.isOpenNow != false }
                let filtered = filterByDistance(open, category: category, from: loc)
                items = filtered.map {
                    SuggestionItem(
                        id: "\(category.rawValue)-\($0.id)",
                        place: $0,
                        category: category
                    )
                }
            case .mixed:
                let categories: [PlaceCategory] = [.bar, .restaurant, .club, .dispensary, .liquorStore]
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
                // Apply per-category distance caps
                var cappedBuckets: [PlaceCategory: [Place]] = [:]
                for (category, places) in openBuckets {
                    cappedBuckets[category] = filterByDistance(places, category: category, from: loc)
                }
                items = interleavedItems(from: cappedBuckets)
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
