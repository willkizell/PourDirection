//
//  HomeLocationSheet.swift
//  PourDirection
//
//  Bottom sheet for setting or changing the user's home location.
//  Options: use current GPS location (reverse geocoded) or search an address.
//  Shows "Remove Home" when a location is already saved.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Search Completer Coordinator

/// Bridges MKLocalSearchCompleter's delegate callbacks to SwiftUI via ObservableObject.
private final class SearchCompleterCoordinator: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {

    @Published var completions: [MKLocalSearchCompletion] = []
    let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate    = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            completions = []
            return
        }
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = Array(completer.results.prefix(5))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        completions = []
    }
}

// MARK: - HomeLocationSheet

struct HomeLocationSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(LocationManager.self) private var locationManager

    private let homeManager = HomeLocationManager.shared

    @State private var searchText           = ""
    @State private var isGeocodingCurrent   = false
    @State private var isGeocodingSelection = false
    @State private var errorMessage: String? = nil
    @StateObject private var completer      = SearchCompleterCoordinator()

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // ── Title ──────────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(homeManager.isSet ? "Change Home" : "Set Home Location")
                        .font(AppTypography.titleSmall)
                        .foregroundColor(AppColors.secondary)
                    if let address = homeManager.formattedAddress, homeManager.isSet {
                        Text(address)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary.opacity(0.45))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)

                // ── Use Current Location ───────────────────────────────────────
                Button(action: useCurrentLocation) {
                    HStack(spacing: AppSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(AppColors.primary.opacity(0.15))
                                .frame(width: 40, height: 40)
                            if isGeocodingCurrent {
                                ProgressView()
                                    .tint(AppColors.primary)
                                    .scaleEffect(0.75)
                            } else {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use My Current Location")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.secondary)
                            Text("Best when you're at home right now")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.45))
                        }
                        Spacer()
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.cardSurface.opacity(0.85))
                    .cornerRadius(AppRadius.md)
                }
                .buttonStyle(.plain)
                .disabled(isGeocodingCurrent || isGeocodingSelection)
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)

                // ── Divider ────────────────────────────────────────────────────
                HStack {
                    VStack { Divider() }
                    Text("or search")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary.opacity(0.3))
                        .fixedSize()
                    VStack { Divider() }
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.vertical, AppSpacing.md)

                // ── Search Field ───────────────────────────────────────────────
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.secondary.opacity(0.4))
                    TextField("Search an address...", text: $searchText)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.secondary)
                        .tint(AppColors.primary)
                        .autocorrectionDisabled()
                        .onChange(of: searchText) { _, q in completer.update(query: q) }
                    if !searchText.isEmpty {
                        Button(action: { searchText = ""; completer.update(query: "") }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.secondary.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppSpacing.md)
                .background(AppColors.cardSurface.opacity(0.85))
                .cornerRadius(AppRadius.md)
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)

                // ── Autocomplete Results ───────────────────────────────────────
                if !completer.completions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(completer.completions, id: \.title) { result in
                            Button(action: { selectCompletion(result) }) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "mappin")
                                        .font(.system(size: 13))
                                        .foregroundColor(AppColors.secondary.opacity(0.4))
                                        .frame(width: 18)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.title)
                                            .font(AppTypography.bodySmall)
                                            .foregroundColor(AppColors.secondary)
                                            .lineLimit(1)
                                        if !result.subtitle.isEmpty {
                                            Text(result.subtitle)
                                                .font(AppTypography.caption)
                                                .foregroundColor(AppColors.secondary.opacity(0.45))
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    if isGeocodingSelection {
                                        ProgressView()
                                            .tint(AppColors.primary)
                                            .scaleEffect(0.65)
                                    }
                                }
                                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                                .padding(.vertical, AppSpacing.sm)
                            }
                            .buttonStyle(.plain)
                            .disabled(isGeocodingSelection)

                            if result.title != completer.completions.last?.title {
                                Divider()
                                    .padding(.leading, AppSpacing.screenHorizontalPadding + 18 + AppSpacing.sm)
                            }
                        }
                    }
                    .background(AppColors.cardSurface.opacity(0.85))
                    .cornerRadius(AppRadius.md)
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .padding(.top, AppSpacing.xs)
                }

                Spacer()

                // ── Error ──────────────────────────────────────────────────────
                if let error = errorMessage {
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.clubRed.opacity(0.8))
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        .padding(.bottom, AppSpacing.xs)
                }

                // ── Remove Home ────────────────────────────────────────────────
                if homeManager.isSet {
                    Button(action: {
                        HapticManager.shared.light()
                        homeManager.clear()
                        dismiss()
                    }) {
                        Text("Remove Home Location")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.clubRed.opacity(0.75))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .padding(.bottom, AppSpacing.lg)
                }
            }
        }
    }

    // MARK: - Actions

    private func useCurrentLocation() {
        guard let loc = locationManager.currentLocation else {
            errorMessage = "Location not available. Make sure location services are enabled."
            return
        }
        isGeocodingCurrent = true
        errorMessage       = nil
        HapticManager.shared.light()

        CLGeocoder().reverseGeocodeLocation(loc) { placemarks, _ in
            DispatchQueue.main.async {
                isGeocodingCurrent = false
                let parts = [
                    placemarks?.first?.subThoroughfare,
                    placemarks?.first?.thoroughfare,
                    placemarks?.first?.locality
                ].compactMap { $0 }
                let address = parts.isEmpty ? nil : parts.joined(separator: " ")
                homeManager.set(
                    latitude:  loc.coordinate.latitude,
                    longitude: loc.coordinate.longitude,
                    address:   address
                )
                dismiss()
            }
        }
    }

    private func selectCompletion(_ result: MKLocalSearchCompletion) {
        guard !isGeocodingSelection else { return }
        isGeocodingSelection = true
        errorMessage         = nil
        HapticManager.shared.light()

        MKLocalSearch(request: MKLocalSearch.Request(completion: result)).start { response, _ in
            DispatchQueue.main.async {
                isGeocodingSelection = false
                guard let item = response?.mapItems.first else {
                    errorMessage = "Couldn't find that address. Try another."
                    return
                }
                let coord   = item.placemark.coordinate
                let address = [result.title, result.subtitle]
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
                homeManager.set(
                    latitude:  coord.latitude,
                    longitude: coord.longitude,
                    address:   address.isEmpty ? nil : address
                )
                dismiss()
            }
        }
    }
}
