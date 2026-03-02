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
    private let distancePrefs = DistancePreferences.shared

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
                    Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
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
                        .shadow(color: Color.black.opacity(0.4), radius: 4, y: 2)
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
        .sheet(item: $selectedItem) { place in
            MapItemBottomSheet(
                place: place,
                isExpanded: isSheetExpanded,
                onLetsGo: {
                    let target = place
                    selectedItem = nil
                    onLetsGo(target)
                }
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
        .onChange(of: selectedItem?.id) { _, newID in
            if let newID, let place = selectedItem {
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

        // Two-pass fetch: walking radius (nearby) + search area (wide).
        // Google returns max 20 per request — a large radius spreads results
        // across the whole area, missing nearby venues. The walking-radius
        // fetch guarantees close-by results always appear.
        async let nearbyBars        = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "bar",          radius: walkRadius)
        async let nearbyRestaurants = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "restaurant",    radius: walkRadius)
        async let nearbyDispos      = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "dispensary",    radius: walkRadius)
        async let nearbyLiquor      = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "liquor_store",  radius: walkRadius)
        async let wideBars          = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "bar",          radius: searchRadius)
        async let wideRestaurants   = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "restaurant",    radius: searchRadius)
        async let wideClubs         = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "night_club",    radius: searchRadius)
        async let wideDispos        = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "dispensary",    radius: searchRadius)
        async let wideLiquor        = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "liquor_store",  radius: searchRadius)

        var seen = Set<String>()
        var combined: [MapItem] = []

        func addUnique(_ places: [Place], category: PlaceCategory) {
            for place in places {
                guard !seen.contains(place.id) else { continue }
                seen.insert(place.id)
                combined.append(MapItem(from: place, category: category))
            }
        }

        // Nearby results first — they take priority
        if let bars = try? await nearbyBars           { addUnique(bars, category: .bar) }
        if let restaurants = try? await nearbyRestaurants { addUnique(restaurants, category: .restaurant) }
        if let dispos = try? await nearbyDispos {
            let filtered = dispos.filter { ($0.distance(from: loc) ?? .greatestFiniteMagnitude) <= walkRadius }
            addUnique(filtered, category: .dispensary)
        }
        if let liquor = try? await nearbyLiquor {
            let filtered = liquor.filter { ($0.distance(from: loc) ?? .greatestFiniteMagnitude) <= walkRadius }
            addUnique(filtered, category: .liquorStore)
        }

        // Wide results — fill in farther venues
        if let bars = try? await wideBars             { addUnique(bars, category: .bar) }
        if let restaurants = try? await wideRestaurants { addUnique(restaurants, category: .restaurant) }
        if let clubs = try? await wideClubs {
            let filtered = clubs.filter {
                let t = Set($0.types)
                return t.contains("night_club") && !t.contains("restaurant")
            }
            addUnique(filtered, category: .club)
        }
        if let dispos = try? await wideDispos {
            let filtered = dispos.filter { ($0.distance(from: loc) ?? .greatestFiniteMagnitude) <= searchRadius }
            addUnique(filtered, category: .dispensary)
        }
        if let liquor = try? await wideLiquor {
            let filtered = liquor.filter { ($0.distance(from: loc) ?? .greatestFiniteMagnitude) <= searchRadius }
            addUnique(filtered, category: .liquorStore)
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
