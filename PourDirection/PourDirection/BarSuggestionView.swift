//
//  BarSuggestionView.swift
//  PourDirection
//
//  Reached via "Find a Bar" or after vibe selection in PickYourVibeView.
//  Owns its own place and saved state so both regeneration and heart tap work inline.
//  Navigation forward (Let's Go) delegated to RootContainerView via closure.
//

import SwiftUI

struct BarSuggestionView: View {

    @State private var place: MapItem
    @State private var isSaved: Bool = false
    let onLetsGo: (MapItem) -> Void

    @Environment(LocationManager.self) private var locationManager

    init(initialPlace: MapItem, onLetsGo: @escaping (MapItem) -> Void) {
        self._place = State(initialValue: initialPlace)
        self.onLetsGo = onLetsGo
    }

    var body: some View {
        ZStack {
            AppColors.gradientBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Header row ────────────────────────────────────────────────
                    HStack(alignment: .firstTextBaseline) {
                        (Text("How ")
                            .foregroundColor(AppColors.secondary)
                         + Text("about?")
                            .foregroundColor(AppColors.primary))
                            .font(AppTypography.titleSmall)
                        Spacer()
                        HStack(spacing: AppSpacing.xxs) {
                            Circle()
                                .fill(AppColors.primary)
                                .frame(width: 6, height: 6)
                            Text(place.category == .event
                                 ? (place.isTonight ? "Tonight" : "Upcoming")
                                 : ((place.isOpen ?? false) ? "Open now" : "Closed"))
                                .font(AppTypography.caption)
                                .foregroundColor(
                                    (place.isOpen ?? false)
                                        ? AppColors.primary
                                        : AppColors.secondary.opacity(0.5)
                                )
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .padding(.top, AppSpacing.sm)

                    // ── Unified venue card ─────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {

                        // Photo area
                        ZStack {
                            AppColors.cardSurface.opacity(0.7)
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundColor(AppColors.secondary.opacity(0.10))

                            // Tonight! badge — events happening today
                            if place.isTonight {
                                Text("Tonight!")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppColors.secondary)
                                    .padding(.horizontal, AppSpacing.xs)
                                    .padding(.vertical, 4)
                                    .background(AppColors.primary)
                                    .cornerRadius(AppRadius.sm)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                                           alignment: .topLeading)
                                    .padding(AppSpacing.sm)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)

                        // Info section
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {

                            // Name + heart
                            HStack(alignment: .firstTextBaseline) {
                                Text(place.name)
                                    .font(AppTypography.header)
                                    .foregroundColor(AppColors.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Spacer()
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isSaved.toggle()
                                    }
                                } label: {
                                    Image(systemName: isSaved ? "heart.fill" : "heart")
                                        .font(.system(size: 18))
                                        .foregroundColor(
                                            isSaved
                                                ? AppColors.primary
                                                : AppColors.secondary.opacity(0.45)
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            // Star rating + review count
                            HStack(spacing: 3) {
                                ForEach(1...5, id: \.self) { i in
                                    Image(systemName: Double(i) <= (place.rating ?? 0)
                                          ? "star.fill" : "star")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppColors.primary)
                                }
                                Text("(\(place.reviewCount ?? 0))")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.secondary.opacity(0.5))
                            }

                            // Event fields vs bar fields
                            if place.category == .event {
                                // Time + price on one row
                                HStack {
                                    if let t = place.eventTime {
                                        Label(t, systemImage: "clock")
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.secondary.opacity(0.6))
                                    }
                                    Spacer()
                                    if let p = place.priceRange {
                                        Label(p, systemImage: "ticket")
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.secondary.opacity(0.6))
                                    }
                                }
                                // Venue on its own row
                                if let v = place.venue {
                                    Label(v, systemImage: "mappin.and.ellipse")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.secondary.opacity(0.6))
                                }

                                // View Tickets — boxy, 50% brand color
                                Button("View Tickets") {
                                    // Ticket integration — future phase
                                }
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.sm)
                                .background(AppColors.primary.opacity(0.5))
                                .cornerRadius(AppRadius.sm)
                                .padding(.top, AppSpacing.xs)

                            } else {
                                Label(
                                    MapItem.formatDistance(place.distance(from: locationManager.currentLocation)) + " away",
                                    systemImage: "location.fill"
                                )
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.6))

                                Label("Closes at \(place.closingTime ?? "N/A")", systemImage: "clock")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.secondary.opacity(0.6))
                            }
                        }
                        .padding(AppSpacing.cardPadding)
                    }
                    .background(AppColors.cardSurface.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(AppColors.secondary.opacity(0.1), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: AppSpacing.sm, x: 0, y: 4)
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .padding(.top, AppSpacing.md)

                    // ── Actions ───────────────────────────────────────────────────
                    VStack(spacing: AppSpacing.xs) {
                        PrimaryButton(title: "Let's Go!") { onLetsGo(place) }
                        Button("Nah, something else") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                place   = place.regenerated()
                                isSaved = false
                            }
                        }
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.secondary.opacity(0.4))
                        .padding(.vertical, AppSpacing.xs)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.lg)
                }
            }
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        BarSuggestionView(
            initialPlace: MapItem.mock(category: .bar, vibe: "Chill"),
            onLetsGo: { _ in }
        )
        CustomTabBar(selectedTab: .constant(.explore))
    }
    .ignoresSafeArea(edges: .bottom)
    .preferredColorScheme(.dark)
    .environment(LocationManager())
}
