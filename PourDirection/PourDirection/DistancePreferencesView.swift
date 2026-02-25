//
//  DistancePreferencesView.swift
//  PourDirection
//
//  Bottom sheet for adjusting walking distance and search area preferences.
//  Walking max == search area min (no overlap).
//  Changes autosave — no Save button needed.
//  A tick mark on each slider shows where the default was.
//

import SwiftUI

struct DistancePreferencesView: View {

    @Bindable private var prefs = DistancePreferences.shared

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer().frame(height: AppSpacing.xl)

                // ── Title ────────────────────────────────────────────
                (Text("Distance ")
                    .foregroundColor(AppColors.secondary)
                 + Text("Preferences")
                    .foregroundColor(AppColors.primary))
                    .font(AppTypography.titleMedium)
                    .padding(.bottom, AppSpacing.xxs)

                Text("How far is too far?")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.secondary.opacity(0.45))
                    .padding(.bottom, AppSpacing.xxl)

                // ── Walking ──────────────────────────────────────────
                walkingSection
                    .padding(.bottom, AppSpacing.xl)

                // ── Search Area ──────────────────────────────────────
                searchAreaSection

                Spacer()

                // ── Revert ───────────────────────────────────────────
                Button(action: {
                    HapticManager.shared.light()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        prefs.resetToDefaults()
                    }
                }) {
                    Text("Revert to Default")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.secondary.opacity(0.4))
                        .padding(.vertical, AppSpacing.sm)
                }
                .buttonStyle(.plain)

                Spacer().frame(height: AppSpacing.lg)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: prefs.walkingDistanceMeters) { _, newWalking in
            // Enforce: search area min == walking max
            if prefs.searchAreaMeters < newWalking {
                prefs.searchAreaMeters = newWalking
            }
        }
    }

    // MARK: - Walking Section

    private var walkingSection: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 20, alignment: .center)
                Text("Walking Distance")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("~\(prefs.walkingMinutes) min")
                        .font(AppTypography.header)
                        .foregroundColor(AppColors.secondary)
                    Text(DistancePreferences.formatMetersAsDistance(prefs.walkingDistanceMeters))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary.opacity(0.35))
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)

            SliderWithDefaultTick(
                value: $prefs.walkingDistanceMeters,
                range: DistancePreferences.walkingMinMeters...DistancePreferences.walkingMaxMeters,
                defaultValue: DistancePreferences.defaultWalkingMeters
            )
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        }
    }

    // MARK: - Search Area Section

    private var searchAreaSection: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "scope")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 20, alignment: .center)
                Text("Search Area")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(DistancePreferences.formatMetersAsDistance(prefs.searchAreaMeters))
                        .font(AppTypography.header)
                        .foregroundColor(AppColors.secondary)
                    Text("~\(prefs.searchAreaDrivingMinutes) min drive")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary.opacity(0.35))
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)

            SliderWithDefaultTick(
                value: $prefs.searchAreaMeters,
                range: prefs.walkingDistanceMeters...DistancePreferences.searchAreaMaxMeters,
                defaultValue: DistancePreferences.defaultSearchAreaMeters
            )
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        }
    }
}

// MARK: - Custom Slider with Default Tick

private struct SliderWithDefaultTick: View {

    @Binding var value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double

    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return (value - range.lowerBound) / span
    }

    private var defaultFraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        let f = (defaultValue - range.lowerBound) / span
        return min(max(f, 0), 1)
    }

    private let trackHeight: CGFloat = 4
    private let thumbSize: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let thumbX = fraction * (width - thumbSize)
            let defaultX = defaultFraction * (width - thumbSize) + thumbSize / 2

            ZStack(alignment: .leading) {

                // Track background
                Capsule()
                    .fill(AppColors.secondary.opacity(0.12))
                    .frame(height: trackHeight)

                // Track fill
                Capsule()
                    .fill(AppColors.primary)
                    .frame(width: thumbX + thumbSize / 2, height: trackHeight)

                // Default tick mark
                if defaultFraction > 0 && defaultFraction < 1 {
                    Rectangle()
                        .fill(AppColors.secondary.opacity(0.3))
                        .frame(width: 2, height: 12)
                        .position(x: defaultX, y: geo.size.height / 2)
                }

                // Thumb
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: Color.black.opacity(0.3), radius: 3, y: 1)
                    .offset(x: thumbX)
            }
            .frame(height: thumbSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let pct = min(max(drag.location.x / width, 0), 1)
                        let span = range.upperBound - range.lowerBound
                        value = range.lowerBound + pct * span
                    }
            )
        }
        .frame(height: 22)
    }
}

// MARK: - Preview

#Preview {
    DistancePreferencesView()
}
