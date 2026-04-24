//
//  MapTabView.swift
//  PourDirection
//
//  Map tab — MapKit map with user location, branded venue pins, and expandable
//  bottom sheet. Navigation delegated to RootContainerView via closure.
//

import SwiftUI
import MapKit

struct MapTabView: View {

    let onLetsGo: (MapItem) -> Void
    var onAccentChange: ((Color) -> Void)? = nil
    var onHomeTap: (() -> Void)? = nil

    private let homeManager = HomeLocationManager.shared

    @Environment(LocationManager.self) private var locationManager
    @Environment(ThemeManager.self)   private var themeManager

    private var shadowOpacity: Double { themeManager.isDayMode ? 0.12 : 0.40 }

    // Single source of truth for selected pin — drives sheet via .sheet(item:)
    @State private var selectedItem: MapItem? = nil
    // Tracks which detent the sheet is currently at
    @State private var selectedDetent: PresentationDetent = .height(340)
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 49.2827, longitude: -123.1207),
            span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)
        )
    )

    @State private var places: [MapItem] = []
    @State private var hasLoadedPlaces = false
    @State private var showDistanceSheet = false
    @State private var placesByCategory: [PlaceCategory: [MapItem]] = [:]
    @State private var distanceCache: [String: CLLocationDistance] = [:]
    @State private var cachedLocationKey: String = ""
    private let distancePrefs = DistancePreferences.shared

    private func cacheKey(for location: CLLocation?) -> String {
        guard let location else { return "none" }
        return "\(Int(location.coordinate.latitude * 1000)),\(Int(location.coordinate.longitude * 1000))"
    }

    /// Accent color for map controls — matches selected pin's category, or brand default.
    private var controlTint: Color {
        selectedItem?.category.color ?? AppColors.primary
    }

    private func compactHeight(for place: MapItem) -> CGFloat { 300 }

    /// True when sheet is dragged to full-page detent.
    private var isSheetExpanded: Bool { selectedDetent == .large }

    private func clampDetent(for place: MapItem) {
        let compact = compactHeight(for: place)
        let id = place.id
        selectedDetent = .height(compact)
        DispatchQueue.main.async {
            guard selectedItem?.id == id else { return }
            selectedDetent = .height(compact)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            guard selectedItem?.id == id else { return }
            selectedDetent = .height(compact)
        }
    }

    /// Same-category places sorted by distance (closest first) — uses cached category grouping and distances.
    private func sameCategoryPlaces(for item: MapItem) -> [MapItem] {
        guard let categoryPlaces = placesByCategory[item.category] else { return [] }

        return categoryPlaces.sorted { place1, place2 in
            let dist1 = distanceCache[place1.id] ?? place1.distance(from: locationManager.currentLocation) ?? .greatestFiniteMagnitude
            let dist2 = distanceCache[place2.id] ?? place2.distance(from: locationManager.currentLocation) ?? .greatestFiniteMagnitude
            return dist1 < dist2
        }
    }

    /// Navigate to the next/previous place of the same category.
    private func navigateSheet(direction: Int) {
        guard let current = selectedItem else { return }
        let sorted = sameCategoryPlaces(for: current)
        guard let idx = sorted.firstIndex(where: { $0.id == current.id }) else { return }
        let newIdx = idx + direction
        guard newIdx >= 0, newIdx < sorted.count else { return }
        let next = sorted[newIdx]

        // Use the existing selectItem dance (brief dismiss → re-present)
        selectItem(next)

        // Pan map to the new place
        withAnimation(.easeInOut(duration: 0.4)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: next.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                )
            )
        }
    }

    private func selectItem(_ place: MapItem) {
        if selectedItem?.id == place.id { return }
        if selectedItem != nil {
            withTransaction(Transaction(animation: nil)) {
                selectedItem = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                selectedDetent = .height(compactHeight(for: place))
                withTransaction(Transaction(animation: nil)) {
                    selectedItem = place
                }
            }
            return
        }
        selectedDetent = .height(compactHeight(for: place))
        withTransaction(Transaction(animation: nil)) {
            selectedItem = place
        }
    }

    var body: some View {
        GeometryReader { geo in
        let safeBottom = geo.safeAreaInsets.bottom
        let baseBottomInset = safeBottom > CustomTabBar.height
            ? safeBottom
            : safeBottom + CustomTabBar.height
        let sheetHeight = selectedItem.map { compactHeight(for: $0) } ?? 0
        let noSheetPadding = baseBottomInset + AppSpacing.lg + 15
        let sheetPadding = sheetHeight + AppSpacing.sm + 20
        let recenterBottomPadding = selectedItem != nil
            ? sheetPadding
            : noSheetPadding

        ZStack {
            // ── Map ─────────────────────────────────────────────────────────
            Map(position: $cameraPosition) {
                UserAnnotation()

                ForEach(places) { place in
                    Annotation(place.displayName, coordinate: place.coordinate, anchor: .bottom) {
                        MapPinView(
                            category: place.category,
                            isClosed: !(place.isOpen ?? true)
                        )
                        .scaleEffect(selectedItem?.id == place.id ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7),
                                   value: selectedItem?.id == place.id)
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                selectItem(place)
                            }
                        )
                    }
                }

                // ── Home pin ─────────────────────────────────────────────
                if homeManager.isSet,
                   let lat = homeManager.latitude,
                   let lng = homeManager.longitude {
                    Annotation("Home", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng), anchor: .bottom) {
                        HomePinView()
                            .highPriorityGesture(
                                TapGesture().onEnded { onHomeTap?() }
                            )
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .mapControls { }
            .ignoresSafeArea(edges: .top)
            .tint(AppColors.primary)
            .gesture(
                TapGesture().onEnded {
                    if selectedItem != nil {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedItem = nil
                        }
                    }
                },
                including: .gesture
            )

            // ── Branded radial overlay ──────────────────────────────────────
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.clear, location: 0.0),
                    .init(color: AppColors.primary.opacity(0.04), location: 0.6),
                    .init(color: AppColors.background.opacity(0.15), location: 1.0)
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // ── Distance info pill (bottom-leading) ─────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Button {
                    if selectedItem != nil {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedItem = nil }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            showDistanceSheet = true
                        }
                    } else {
                        showDistanceSheet = true
                    }
                } label: {
                    distanceInfoPill
                }
                .buttonStyle(.plain)
                .padding(.leading, AppSpacing.lg)
                .padding(.bottom, recenterBottomPadding)
                .animation(.easeInOut(duration: 0.3), value: selectedItem != nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // ── Recenter button (bottom-trailing) ─────────────────────────
            VStack {
                Spacer()
                Button {
                    if let loc = locationManager.currentLocation {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            cameraPosition = .region(
                                MKCoordinateRegion(
                                    center: loc.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
                                )
                            )
                        }
                    }
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(controlTint)
                        .frame(width: 44, height: 44)
                        .background(AppColors.cardSurface.opacity(0.92))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(controlTint.opacity(0.25), lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(shadowOpacity), radius: 4, y: 2)
                        .animation(.easeInOut(duration: 0.25), value: selectedItem?.id)
                }
                .buttonStyle(.plain)
                .padding(.trailing, AppSpacing.lg)
                .padding(.bottom, recenterBottomPadding)
                .animation(.easeInOut(duration: 0.3), value: selectedItem != nil)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdating()
        }
        .task { await fetchPlaces() }
        // One-shot retry once location arrives (e.g. permission granted after task fires)
        .onChange(of: locationManager.currentLocation) { _, newLocation in
            guard newLocation != nil, !hasLoadedPlaces else { return }
            Task { await fetchPlaces() }
        }
        // Refetch when Day/Night mode changes
        .onChange(of: themeManager.mode) { _, _ in
            hasLoadedPlaces = false
            Task { await fetchPlaces() }
        }
        // Update category grouping and distance cache when places change
        .onChange(of: places) { _, newPlaces in
            placesByCategory = Dictionary(grouping: newPlaces) { $0.category }
            distanceCache.removeAll()
        }
        // Recalculate distances when location changes significantly
        .onChange(of: locationManager.currentLocation) { _, newLocation in
            let newKey = cacheKey(for: newLocation)
            if newKey != cachedLocationKey {
                cachedLocationKey = newKey
                distanceCache.removeAll()
                for place in places {
                    distanceCache[place.id] = place.distance(from: newLocation)
                }
            }
        }
        .sheet(item: $selectedItem) { place in
            MapItemBottomSheet(
                place: place,
                isExpanded: isSheetExpanded,
                onLetsGo: {
                    let target = place
                    selectedItem = nil
                    onLetsGo(target)
                },
                categoryIndex: {
                    let sorted = sameCategoryPlaces(for: place)
                    return sorted.firstIndex(where: { $0.id == place.id })
                }(),
                categoryTotal: sameCategoryPlaces(for: place).count,
                onSwipeLeft:  { navigateSheet(direction: -1) },
                onSwipeRight: { navigateSheet(direction:  1) }
            )
            .id(selectedItem?.id)
            .presentationDetents(
                [.height(compactHeight(for: place)), .large],
                selection: $selectedDetent
            )
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .height(compactHeight(for: place))))
            .presentationBackground(AppColors.background)
            .interactiveDismissDisabled(false)
        }
        // Reset detent to compact when a new pin is selected
        .onChange(of: selectedItem?.id) { _, _ in
            if let place = selectedItem {
                clampDetent(for: place)
            }
            onAccentChange?(controlTint)
        }
        .sheet(isPresented: $showDistanceSheet, onDismiss: {
            // Refetch with updated distance preferences
            Task { await fetchPlaces() }
        }) {
            DistancePreferencesView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppColors.background)
        }
        } // GeometryReader
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Distance Info Pill

    private var distanceInfoPill: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(controlTint)
                Text(DistancePreferences.formatMetersAsDistance(distancePrefs.walkingDistanceMeters))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.secondary.opacity(0.6))
            }
            HStack(spacing: 5) {
                Image(systemName: "scope")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(controlTint)
                Text(DistancePreferences.formatMetersAsDistance(distancePrefs.searchAreaMeters))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.secondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppColors.cardSurface.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(controlTint.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 4, y: 2)
        .animation(.easeInOut(duration: 0.25), value: selectedItem?.id)
    }

    // MARK: - Data Fetch

    private func fetchPlaces() async {
        guard let loc = locationManager.currentLocation else { return }

        let lat = loc.coordinate.latitude
        let lng = loc.coordinate.longitude

        let walkRadius   = distancePrefs.walkingDistanceMeters
        let searchRadius = distancePrefs.searchAreaMeters

        var seen = Set<String>()
        var combined: [MapItem] = []

        func addUnique(_ places: [Place], category: PlaceCategory) {
            for place in places {
                guard !seen.contains(place.id) else { continue }
                seen.insert(place.id)
                combined.append(MapItem(from: place, category: category))
            }
        }

        if themeManager.isDayMode {
            // Day mode: fetch patio, brunch, coffee, day drinks, parks, dessert
            async let nearbyPatio     = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "patio",      radius: walkRadius)
            async let nearbyBrunch    = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "brunch",     radius: walkRadius)
            async let nearbyCoffee    = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "coffee",     radius: walkRadius)
            async let nearbyParks     = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "park",       radius: walkRadius)
            async let nearbyDessert   = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "dessert",    radius: walkRadius)
            async let wideDayDrinks   = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "day_drinks", radius: searchRadius)

            if let p = try? await nearbyPatio   { addUnique(p, category: .patio) }
            if let p = try? await nearbyBrunch  { addUnique(p, category: .brunch) }
            if let p = try? await nearbyCoffee  { addUnique(p, category: .coffee) }
            if let p = try? await nearbyParks   { addUnique(p, category: .parks) }
            if let p = try? await nearbyDessert { addUnique(p, category: .dessert) }
            if let p = try? await wideDayDrinks { addUnique(p, category: .dayDrinks) }
        } else {
            // Night mode: single wide fetch per category, sorted closest-first client-side.
            async let wideBars        = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "bar",          radius: searchRadius)
            async let wideRestaurants = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "restaurant",   radius: searchRadius)
            async let wideClubs       = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "night_club",   radius: searchRadius)
            async let wideDispos      = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "dispensary",   radius: searchRadius)
            async let wideLiquor      = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "liquor_store", radius: searchRadius)
            async let wideCasino      = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "casino",       radius: searchRadius)

            if let bars = try? await wideBars         { addUnique(bars, category: .bar) }
            if let restaurants = try? await wideRestaurants { addUnique(restaurants, category: .restaurant) }
            if let clubs = try? await wideClubs {
                let filtered = clubs.filter {
                    let t = Set($0.types)
                    return t.contains("night_club") && !t.contains("restaurant")
                }
                addUnique(filtered, category: .club)
            }
            if let dispos = try? await wideDispos     { addUnique(dispos, category: .dispensary) }
            if let liquor = try? await wideLiquor     { addUnique(liquor, category: .liquorStore) }
            if let casinos = try? await wideCasino    { addUnique(casinos, category: .casino) }
        }

        // Final filter to search area
        places = combined.filter {
            ($0.distance(from: loc) ?? .greatestFiniteMagnitude) <= searchRadius
        }

        // Center map on user location once places arrive
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
                )
            )
        }

        hasLoadedPlaces = true
    }
}

#Preview {
    MapTabView(onLetsGo: { _ in })
        .environment(LocationManager())
        .preferredColorScheme(.dark)
}
