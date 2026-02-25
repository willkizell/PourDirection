//
//  MapItemBottomSheet.swift
//  PourDirection
//
//  Expandable bottom sheet for map pin selection.
//  Compact: all key info + CTA visible. Expanded: hero photo at top.
//

import SwiftUI

struct MapItemBottomSheet: View {

    let place: MapItem
    let isExpanded: Bool
    let onLetsGo: () -> Void

    @Environment(LocationManager.self) private var locationManager

    private var accent: Color { place.category.color }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Hero Photo — only when expanded ──────────────────────────
                if isExpanded {
                    Group {
                        if let photoURL = place.photoURL {
                            AsyncImage(url: photoURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 200)
                                        .clipped()
                                default:
                                    photoPlaceholder
                                }
                            }
                            .frame(height: 200)
                        } else {
                            photoPlaceholder
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // ── Place Info ────────────────────────────────────────────────
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
                            .foregroundColor(place.category.color)
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, 3)
                            .background(place.category.color.opacity(0.15))
                            .cornerRadius(AppRadius.sm)
                    }

                    // Meta row: rating + distance
                    HStack(spacing: AppSpacing.xs) {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundColor(accent)
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
                    }

                    // Open/Closed status row
                    if let isOpen = place.isOpen {
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

                    Divider()
                        .background(AppColors.divider)
                        .padding(.vertical, AppSpacing.xxs)

                    // Star row
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: Double(i) <= (place.rating ?? 0) ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(accent)
                        }
                        if let count = place.reviewCount, count > 0 {
                            Text("(\(count))")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.5))
                        }
                    }

                    // Vibe tag — only shown when present
                    if let vibe = place.vibe {
                        HStack(spacing: AppSpacing.xs) {
                            Text("Vibe")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.4))
                            Text(vibe)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.primary)
                                .padding(.horizontal, AppSpacing.xs)
                                .padding(.vertical, 2)
                                .background(AppColors.primary.opacity(0.12))
                                .cornerRadius(AppRadius.sm)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)

                // ── CTA ───────────────────────────────────────────────────────
                PrimaryButton(title: "Let's Go!", color: accent, action: onLetsGo)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.md)
            }
            .animation(.easeInOut(duration: 0.25), value: isExpanded)
        }
        .frame(maxWidth: .infinity)
        .preferredColorScheme(.dark)
    }

    private var photoPlaceholder: some View {
        ZStack {
            AppColors.cardSurface.opacity(0.7)
            Image(systemName: "photo")
                .font(.system(size: 36))
                .foregroundColor(AppColors.secondary.opacity(0.10))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }
}

#Preview {
    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            MapItemBottomSheet(
                place: MapItem.mock(category: .bar, vibe: "Chill"),
                isExpanded: false,
                onLetsGo: {}
            )
            .presentationDetents([.height(300), .large])
            .presentationDragIndicator(.visible)
            .environment(LocationManager())
        }
}
