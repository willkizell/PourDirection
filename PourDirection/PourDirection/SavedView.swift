//
//  SavedView.swift
//  PourDirection
//
//  Saved places screen — two segments per design spec:
//  • All     — every place the user has ever saved (all-time history)
//  • Nearby  — saved places within 5 km of current location
//  Tap a card to navigate (Let's Go). Heart icon to unsave.
//

import SwiftUI
import CoreLocation

struct SavedView: View {

    let onLetsGo: (Place) -> Void
    var onSetHome: (() -> Void)? = nil

    @Environment(LocationManager.self) private var locationManager
    private let manager     = SavedPlacesManager.shared
    private let homeManager = HomeLocationManager.shared

    @State private var filter:        SavedFilter = .all
    @State private var showHomeSheet: Bool        = false
    @State private var distanceCache: [String: CLLocationDistance] = [:]
    @State private var cachedLocationKey: String = ""

    private enum SavedFilter: String, CaseIterable {
        case all    = "All"
        case nearby = "Nearby"
    }

    private func cacheKey(for location: CLLocation?) -> String {
        guard let location else { return "none" }
        return "\(Int(location.coordinate.latitude * 1000)),\(Int(location.coordinate.longitude * 1000))"
    }

    private var displayedPlaces: [SavedPlace] {
        switch filter {
        case .all:
            return manager.savedPlaces
        case .nearby:
            return manager.nearbyPlaces(from: locationManager.currentLocation)
        }
    }

    private let adBannerHeight: CGFloat = 50 + (AppSpacing.xs * 2)

    var body: some View {
        ZStack(alignment: .top) {
            AppColors.gradientBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────────────
                HStack(alignment: .bottom) {
                    (Text("Saved ")
                        .foregroundColor(AppColors.primary)
                     + Text("Places")
                        .foregroundColor(AppColors.secondary))
                        .font(AppTypography.titleSmall)

                    Spacer()

                    // ── Segment picker ────────────────────────────────────
                    HStack(spacing: 2) {
                        ForEach(SavedFilter.allCases, id: \.self) { option in
                            Button(action: {
                                HapticManager.shared.light()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    filter = option
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: option == .all ? "scope" : "figure.walk")
                                        .font(.system(size: 11, weight: .medium))
                                    Text(option.rawValue)
                                        .font(AppTypography.caption)
                                }
                                .foregroundColor(
                                    filter == option
                                        ? AppColors.background
                                        : AppColors.secondary.opacity(0.5)
                                )
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(filter == option ? AppColors.primary : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(
                        Capsule()
                            .fill(AppColors.cardSurface.opacity(0.85))
                    )
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)

                // ── List — home card always first ─────────────────────────
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: AppSpacing.sm) {

                        // Home card — always pinned at top
                        homeCard

                        if displayedPlaces.isEmpty {
                            emptyState
                        } else {
                            ForEach(displayedPlaces) { saved in
                                savedRow(saved)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, CustomTabBar.height + adBannerHeight + AppSpacing.md)
                }
            }
        }
        .sheet(isPresented: $showHomeSheet) {
            HomeLocationSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: locationManager.currentLocation) { _, newLocation in
            let newKey = cacheKey(for: newLocation)
            // Recalculate distances only if location changed significantly
            if newKey != cachedLocationKey {
                cachedLocationKey = newKey
                distanceCache.removeAll()
                for saved in manager.savedPlaces {
                    distanceCache[saved.id] = saved.distance(from: newLocation)
                }
            }
        }
    }

    // MARK: - Saved Row

    private func savedRow(_ saved: SavedPlace) -> some View {
        let accent = saved.category?.color ?? AppColors.primary
        let dist   = distanceCache[saved.id] ?? saved.distance(from: locationManager.currentLocation)
        let isWalking = dist.map { $0 <= DistancePreferences.shared.walkingDistanceMeters } ?? false

        return Button(action: {
            HapticManager.shared.heavy()
            onLetsGo(saved.toPlace())
        }) {
            HStack(spacing: AppSpacing.sm) {

                // Category dot — vertically centered
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                    .frame(maxHeight: .infinity)

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(saved.displayName)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.secondary)
                        .lineLimit(1)

                    if let address = saved.formattedAddress {
                        Text(address)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary.opacity(0.45))
                            .lineLimit(1)
                    }

                    HStack(spacing: AppSpacing.xs) {
                        if let category = saved.category {
                            Text(category.rawValue)
                                .font(AppTypography.caption)
                                .foregroundColor(accent.opacity(0.8))
                        }

                        if let dist {
                            Text("·")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.3))
                            HStack(spacing: 3) {
                                Image(systemName: isWalking ? "figure.walk" : "scope")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(accent.opacity(0.7))
                                Text(Place.formatDistance(dist))
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.secondary.opacity(0.45))
                            }
                        }

                        if let rating = saved.rating {
                            Text("·")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.3))
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(accent)
                                Text(String(format: "%.1f", rating))
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.secondary.opacity(0.45))
                            }
                        }
                    }
                }

                Spacer()

                // Unsave button
                Button(action: {
                    HapticManager.shared.light()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                        manager.removeSaved(saved)
                    }
                }) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18))
                        .foregroundColor(accent)
                }
                .buttonStyle(.plain)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardSurface.opacity(0.92))
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.secondary.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Home Card

    private var homeCard: some View {
        let isSet = homeManager.isSet
        let dist  = homeManager.distance(from: locationManager.currentLocation)
        let isWalking = dist.map { $0 <= DistancePreferences.shared.walkingDistanceMeters } ?? false

        return Button(action: {
            HapticManager.shared.heavy()
            if let place = homeManager.homePlace {
                onLetsGo(place)
            } else {
                onSetHome?()
            }
        }) {
            HStack(spacing: AppSpacing.sm) {

                Image(systemName: "house.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSet ? AppColors.background : AppColors.primary.opacity(0.55))
                    .frame(width: 26, alignment: .center)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Home")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(isSet ? AppColors.background : AppColors.secondary)

                    if isSet {
                        HStack(spacing: AppSpacing.xs) {
                            if let address = homeManager.formattedAddress {
                                Text(address)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.background.opacity(0.7))
                                    .lineLimit(1)
                            }
                            if let dist {
                                if homeManager.formattedAddress != nil {
                                    Text("·")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.background.opacity(0.4))
                                }
                                HStack(spacing: 3) {
                                    Image(systemName: isWalking ? "figure.walk" : "car.fill")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(AppColors.background.opacity(0.6))
                                    Text(Place.formatDistance(dist))
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.background.opacity(0.7))
                                }
                            }
                        }
                    } else {
                        Text("Tap to set your home location")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary.opacity(0.45))
                    }
                }

                Spacer()

                if isSet {
                    // Edit button opens sheet directly
                    Button(action: {
                        HapticManager.shared.light()
                        showHomeSheet = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.background.opacity(0.65))
                            .frame(width: 30, height: 30)
                            .background(AppColors.background.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.secondary.opacity(0.3))
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSet ? AppColors.primary : AppColors.cardSurface.opacity(0.92))
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(
                        isSet ? Color.clear : AppColors.primary.opacity(0.3),
                        lineWidth: 0.75
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State (inline, not full-screen)

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: "heart")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(AppColors.primary.opacity(0.35))
                .padding(.bottom, AppSpacing.xs)
                .padding(.top, AppSpacing.xl)

            switch filter {
            case .all:
                Text("No saved places yet")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.secondary.opacity(0.5))
                Text("Tap the heart on any suggestion to save it")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.secondary.opacity(0.3))
            case .nearby:
                Text("No saved places nearby")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.secondary.opacity(0.5))
                Text("Your saved places within 5 km will appear here")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.secondary.opacity(0.3))
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        SavedView(onLetsGo: { _ in })
        CustomTabBar(selectedTab: .constant(.saved))
    }
    .ignoresSafeArea(edges: .bottom)
    .preferredColorScheme(.dark)
    .environment(LocationManager())
}
