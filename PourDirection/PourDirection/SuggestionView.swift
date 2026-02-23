//
//  SuggestionView.swift
//  PourDirection
//
//  Shows nearby bars one at a time, sorted closest-first.
//  "Nah, Next One" advances through the list; "Let's Go" opens the compass.
//

import SwiftUI
import CoreLocation

struct SuggestionView: View {

    let onLetsGo: (Place) -> Void
    let onNotFeelingIt: () -> Void

    @Environment(LocationManager.self) private var locationManager

    @State private var places: [Place]       = []
    @State private var currentIndex: Int     = 0
    @State private var isLoading: Bool       = true   // start true — avoid "no results" flash
    @State private var errorMessage: String? = nil
    @State private var hasLoaded:    Bool    = false  // prevents onChange from re-firing after load
    @State private var isReversing:  Bool    = false  // controls card transition direction
    private let adBannerHeight: CGFloat      = 50 + (AppSpacing.xs * 2)

    private var currentPlace: Place? {
        guard currentIndex < places.count else { return nil }
        return places[currentIndex]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            AppColors.gradientBackground
                .ignoresSafeArea()

            // ── Fixed Header ────────────────────────────────────────────────
            (Text("How ")
                .foregroundColor(AppColors.secondary)
             + Text("About")
                .foregroundColor(AppColors.primary))
                .font(AppTypography.titleSmall)
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.top, AppSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

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

                    } else if let place = currentPlace {
                        placeCard(place)
                    } else if !places.isEmpty {
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 36))
                                .foregroundColor(AppColors.primary.opacity(0.6))
                            Text("You've seen all nearby bars.")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.5))
                        }
                    } else {
                        Text("No places found nearby.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary.opacity(0.4))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.top, 0)

                // ── Bottom Actions ────────────────────────────────────────────
                VStack(spacing: AppSpacing.sm) {
                    if let place = currentPlace {
                        PrimaryButton(title: "Let's Go") { onLetsGo(place) }
                    } else if !places.isEmpty {
                        Button(action: {
                            isReversing = false
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

    private func placeCard(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Hero Photo ────────────────────────────────────────────────────
            AsyncImage(url: place.photoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipped()
                case .failure:
                    photoPlaceholder
                default:
                    photoPlaceholder
                        .overlay(ProgressView().tint(AppColors.primary))
                }
            }
            .frame(height: 220)

            // ── Info ──────────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: AppSpacing.sm) {

                Text(place.name)
                    .font(AppTypography.header)
                    .foregroundColor(AppColors.secondary)

                if let address = place.formattedAddress {
                    Label(address, systemImage: "mappin")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary.opacity(0.55))
                        .lineLimit(2)
                }

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
                    }

                    Spacer()

                    if places.count > 1 {
                        Text("\(currentIndex + 1) of \(places.count)")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary.opacity(0.3))
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
        }
        .frame(maxWidth: 340)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(AppColors.cardSurface.opacity(0.92))
        .cornerRadius(AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.secondary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.5), radius: AppSpacing.sm, x: 0, y: 4)
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .gesture(
            DragGesture().onEnded { value in
                let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                let shouldGoBack = value.translation.width > 40 && abs(value.translation.height) < 40
                let shouldGoNext = value.translation.width < -40 && abs(value.translation.height) < 40

                if isHorizontal && shouldGoBack && currentIndex > 0 {
                    isReversing = true
                    withAnimation(.spring(response: 0.12, dampingFraction: 0.8)) {
                        currentIndex -= 1
                    }
                } else if isHorizontal && shouldGoNext && currentIndex + 1 < places.count {
                    isReversing = false
                    withAnimation(.spring(response: 0.12, dampingFraction: 0.8)) {
                        currentIndex += 1
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

    private func load() async {
        // If location isn't ready yet the spinner is already showing (isLoading starts true).
        // onChange will call load() again once the first fix arrives.
        guard let loc = locationManager.currentLocation else { return }
        isLoading    = true
        errorMessage = nil
        do {
            let fetched = try await SupabaseManager.shared.fetchNearbyPlaces(
                lat: loc.coordinate.latitude,
                lng: loc.coordinate.longitude
            )
            places = fetched.sorted {
                let d0 = $0.distance(from: loc) ?? .greatestFiniteMagnitude
                let d1 = $1.distance(from: loc) ?? .greatestFiniteMagnitude
                return d0 < d1
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
            onLetsGo: { place in print("Let's go to \(place.name)") },
            onNotFeelingIt: {}
        )
        CustomTabBar(selectedTab: .constant(.explore))
    }
    .ignoresSafeArea(edges: .bottom)
    .preferredColorScheme(.dark)
    .environment(LocationManager())
}
