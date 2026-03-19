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
    var categoryIndex: Int?  = nil
    var categoryTotal: Int?  = nil
    var onSwipeLeft:  (() -> Void)? = nil
    var onSwipeRight: (() -> Void)? = nil

    @Environment(LocationManager.self) private var locationManager
    @GestureState private var dragOffset: CGFloat = 0
    @State private var swipeTriggered = false

    private var accent: Color { place.category.color }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Hero Photo — only when expanded ──────────────────────────
                if isExpanded {
                    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                        .fill(AppColors.cardSurface)
                        .frame(height: 200)
                        .overlay(
                            Group {
                                if let photoURL = place.photoURL {
                                    AsyncImage(url: photoURL) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        default:
                                            photoPlaceholder
                                        }
                                    }
                                } else {
                                    photoPlaceholder
                                }
                            }
                        )
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
                        Text(place.displayName)
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

                // ── Counter + CTA ─────────────────────────────────────────────
                if let idx = categoryIndex, let total = categoryTotal, total > 1 {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(accent.opacity(idx > 0 ? 0.6 : 0.2))
                        Text("\(idx + 1) of \(total)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.secondary.opacity(0.4))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(accent.opacity(idx < total - 1 ? 0.6 : 0.2))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.sm)
                }

                PrimaryButton(title: "Let's Go!", color: accent, action: onLetsGo)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, (categoryIndex != nil && (categoryTotal ?? 0) > 1) ? AppSpacing.sm : AppSpacing.xl)
                    .padding(.bottom, AppSpacing.md)
            }
            .animation(.easeInOut(duration: 0.25), value: isExpanded)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 40)
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.width
                }
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical   = value.translation.height
                    // Only trigger if swipe is mostly horizontal
                    guard abs(horizontal) > abs(vertical) * 1.5,
                          abs(horizontal) > 60 else { return }
                    if horizontal < 0 {
                        onSwipeRight?()    // swipe left → next
                    } else {
                        onSwipeLeft?()     // swipe right → previous
                    }
                }
        )
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
