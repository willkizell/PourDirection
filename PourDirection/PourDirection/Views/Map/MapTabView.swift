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

    // Mock pins — generated once, stable across re-renders
    private static let mockPlaces: [MapItem] = MapTabView.generateMockPlaces()
    @State private var places: [MapItem] = MapTabView.mockPlaces

    /// Compact detent height varies by category — events have more rows.
    private func compactHeight(for place: MapItem) -> CGFloat {
        place.category == .event ? 340 : 300
    }

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
                        MapItemAnnotationView(
                            category: place.category,
                            isSelected: selectedItem?.id == place.id
                        )
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

    // MARK: - Mock Data Generator

    private static func generateMockPlaces() -> [MapItem] {
        let categories: [(PlaceCategory, String)] = [
            (.bar,         "Chill"),
            (.bar,         "Energetic"),
            (.bar,         "Lively"),
            (.club,        "Energetic"),
            (.club,        "Party"),
            (.event,       "Chill"),
            (.event,       "Energetic"),
            (.liquorStore, "Chill"),
            (.bar,         "Date Night"),
            (.bar,         "Sports"),
            (.club,        "Lively"),
            (.event,       "Chill"),
        ]

        return categories.map { category, vibe in
            MapItem.mock(category: category, vibe: vibe)
        }
    }
}

#Preview {
    MapTabView(onLetsGo: { _ in })
        .environment(LocationManager())
        .preferredColorScheme(.dark)
}
