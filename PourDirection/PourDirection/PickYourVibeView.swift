//
//  PickYourVibeView.swift
//  PourDirection
//
//  Reached via "Find Something Else" from ExploreView.
//  Presents three tall vibe cards — tapping one pushes BarSuggestionView filtered by that vibe.
//  No navigation logic here — vibe selection delegated back to RootContainerView via closure.
//

import SwiftUI

struct PickYourVibeView: View {

    let onSelectVibe: (String) -> Void

    private struct Vibe {
        let label: String
        let subtitle: String
        let icon: String
    }

    private let vibes: [Vibe] = [
        Vibe(label: "Chill",          subtitle: "Lounges, speakeasies & jazzbars", icon: "moon.stars"),
        Vibe(label: "Energetic",      subtitle: "Clubs, live music & rooftops",    icon: "bolt.fill"),
        Vibe(label: "Something else?",subtitle: "Comedy shows, karaoke & more",   icon: "shuffle")
    ]

    var body: some View {
        ZStack {
            AppColors.gradientBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header (single line) ──────────────────────────────────────
                (Text("Pick your ")
                    .foregroundColor(AppColors.secondary)
                 + Text("vibe.")
                    .foregroundColor(AppColors.primary))
                    .font(AppTypography.titleSmall)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .padding(.top, AppSpacing.lg)

                // ── Tall Vibe Cards ───────────────────────────────────────────
                VStack(spacing: AppSpacing.md) {
                    ForEach(vibes, id: \.label) { vibe in
                        Button { onSelectVibe(vibe.label) } label: {
                            ZStack(alignment: .bottomLeading) {

                                // Card surface
                                RoundedRectangle(cornerRadius: AppRadius.lg)
                                    .fill(AppColors.cardSurface)

                                // Watermark icon — large, faded, top-trailing
                                Image(systemName: vibe.icon)
                                    .font(.system(size: 72, weight: .light))
                                    .foregroundColor(AppColors.primary.opacity(0.08))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                                           alignment: .topTrailing)
                                    .padding(AppSpacing.md)

                                // Bottom gradient for text legibility
                                LinearGradient(
                                    colors: [Color.clear, Color.black.opacity(0.55)],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))

                                // Text content — bottom leading
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(vibe.label)
                                        .font(AppTypography.header)
                                        .foregroundColor(AppColors.secondary)
                                    Text(vibe.subtitle)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.secondary.opacity(0.55))
                                }
                                .padding(AppSpacing.md)

                                // Arrow — bottom trailing
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(AppColors.primary.opacity(0.85))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                                           alignment: .bottomTrailing)
                                    .padding(AppSpacing.md)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.lg)
                                    .stroke(AppColors.secondary.opacity(0.1), lineWidth: 0.5)
                            )
                            .shadow(color: Color.black.opacity(0.4), radius: AppSpacing.xs,
                                    x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.top, AppSpacing.md)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        PickYourVibeView(onSelectVibe: { _ in })
        CustomTabBar(selectedTab: .constant(.explore))
    }
    .ignoresSafeArea(edges: .bottom)
    .preferredColorScheme(.dark)
}
