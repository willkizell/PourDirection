//
//  MapItemBottomSheet.swift
//  PourDirection
//
//  Expandable bottom sheet for map pin selection.
//  Compact: no photo, all key info + CTA visible. Height varies by category.
//  Expanded (.large): padded rounded photo at top, full detail below.
//

import SwiftUI

struct MapItemBottomSheet: View {

    let place: MapItem
    let isExpanded: Bool
    let onLetsGo: () -> Void

    @Environment(LocationManager.self) private var locationManager

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Photo — only shown when expanded, padded & rounded ────
                if isExpanded {
                    ZStack {
                        AppColors.cardSurface.opacity(0.7)
                        Image(systemName: "photo")
                            .font(.system(size: 36))
                            .foregroundColor(AppColors.secondary.opacity(0.10))

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
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // ── Place Info ────────────────────────────────────────────
                VStack(alignment: .leading, spacing: AppSpacing.xs) {

                    // Name + category badge
                    HStack(alignment: .top) {
                        Text(place.name)
                            .font(AppTypography.header)
                            .foregroundColor(AppColors.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Text(place.displayCategory)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.primary)
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, 3)
                            .background(AppColors.primary.opacity(0.12))
                            .cornerRadius(AppRadius.sm)
                    }

                    // Meta row: rating + distance + open status
                    HStack(spacing: AppSpacing.xs) {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.primary)
                            Text(String(format: "%.1f", place.rating ?? 0))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.7))
                        }

                        Text("·")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary.opacity(0.25))

                        Label(
                            MapItem.formatDistance(place.distance(from: locationManager.currentLocation)),
                            systemImage: "location.fill"
                        )
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary.opacity(0.6))

                        Spacer()

                        HStack(spacing: AppSpacing.xxs) {
                            Circle()
                                .fill((place.isOpen ?? false)
                                      ? AppColors.primary
                                      : AppColors.secondary.opacity(0.3))
                                .frame(width: 6, height: 6)
                            Text((place.isOpen ?? false) ? "Open" : "Closed")
                                .font(AppTypography.caption)
                                .foregroundColor(
                                    (place.isOpen ?? false)
                                        ? AppColors.primary
                                        : AppColors.secondary.opacity(0.4)
                                )
                        }
                    }

                    // Event-specific or bar-specific info
                    if place.category == .event {
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
                        if let v = place.venue {
                            Label(v, systemImage: "mappin.and.ellipse")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.6))
                        }
                    } else {
                        if let closingTime = place.closingTime {
                            Label("Closes at \(closingTime)", systemImage: "clock")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.6))
                        }
                    }

                    Divider()
                        .background(AppColors.divider)
                        .padding(.vertical, AppSpacing.xxs)

                    // Star row
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

                    // Vibe tag
                    HStack(spacing: AppSpacing.xs) {
                        Text("Vibe")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary.opacity(0.4))
                        Text(place.vibe)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.primary)
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, 2)
                            .background(AppColors.primary.opacity(0.12))
                            .cornerRadius(AppRadius.sm)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)

                // ── CTA ──────────────────────────────────────────────────
                PrimaryButton(title: "Let's Go!", action: onLetsGo)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.md)
            }
            .animation(.easeInOut(duration: 0.25), value: isExpanded)
        }
        .frame(maxWidth: .infinity)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            MapItemBottomSheet(
                place: MapItem.mock(category: .event, vibe: "Chill"),
                isExpanded: false,
                onLetsGo: {}
            )
            .presentationDetents([.height(380), .large])
            .presentationDragIndicator(.visible)
            .environment(LocationManager())
        }
}
