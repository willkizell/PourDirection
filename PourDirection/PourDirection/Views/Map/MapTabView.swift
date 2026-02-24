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

        ZStack(alignment: .bottomTrailing) {
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

            // ── Recenter button (bottom-trailing) ─────────────────────────
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
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 40, height: 40)
                    .background(AppColors.cardSurface.opacity(0.92))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppColors.primary.opacity(0.25), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.trailing, AppSpacing.lg)
            .padding(.bottom, recenterBottomPadding)
            .animation(.easeInOut(duration: 0.3), value: selectedItem != nil)
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
            guard newID != nil, let place = selectedItem else { return }
            clampDetent(for: place)
        }
        } // GeometryReader
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Data Fetch

    private func fetchPlaces() async {
        guard let loc = locationManager.currentLocation else { return }

        let lat = loc.coordinate.latitude
        let lng = loc.coordinate.longitude

        // Fetch all four categories in parallel
        async let barResults        = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "bar")
        async let restaurantResults = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "restaurant")
        async let clubResults       = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "night_club")
        async let dispoResults      = SupabaseManager.shared.fetchNearbyPlaces(lat: lat, lng: lng, type: "dispensary")

        var combined: [MapItem] = []

        if let bars = try? await barResults {
            combined += bars.map { MapItem(from: $0, category: .bar) }
        }
        if let restaurants = try? await restaurantResults {
            combined += restaurants.map { MapItem(from: $0, category: .restaurant) }
        }
        if let clubs = try? await clubResults {
            let filtered = clubs.filter {
                let t = Set($0.types)
                return t.contains("night_club") && !t.contains("restaurant")
            }
            combined += filtered.map { MapItem(from: $0, category: .club) }
        }
        if let dispos = try? await dispoResults {
            let filtered = dispos.filter {
                ($0.distance(from: loc) ?? .greatestFiniteMagnitude) <= 3000
            }
            combined += filtered.map { MapItem(from: $0, category: .dispensary) }
        }

        places = combined

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
