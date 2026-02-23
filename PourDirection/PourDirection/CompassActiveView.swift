//
//  CompassActiveView.swift
//  PourDirection
//
//  Placeholder compass navigation screen.
//  No MapKit or real compass logic — structure only.
//  Presented as a fullScreenCover from RootContainerView.
//

import SwiftUI

struct CompassActiveView: View {

    let place: MockPlace
    let onOpenInMaps: () -> Void
    let onChangeTarget: () -> Void

    // Needle wobble — simulates an active compass seeking a heading
    @State private var needleAngle: Double = 38

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            AppColors.gradientBackground
                .opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────────────────
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Navigating")
                            .font(AppTypography.header)
                            .foregroundColor(AppColors.secondary.opacity(0.5))
                        Text(place.name)
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.secondary)
                    }
                    Spacer()
                    // Distance badge
                    Text(place.distance)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xxs)
                        .background(
                            Capsule()
                                .fill(AppColors.primary.opacity(0.12))
                        )
                        .overlay(
                            Capsule()
                                .stroke(AppColors.primary.opacity(0.3), lineWidth: 0.5)
                        )
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.top, AppSpacing.xxl)

                Spacer()

                // ── Compass Placeholder ───────────────────────────────────────
                ZStack {
                    // Outer glow ring
                    Circle()
                        .stroke(AppColors.primary.opacity(0.06), lineWidth: 1)
                        .frame(width: 280, height: 280)

                    // Middle ring
                    Circle()
                        .stroke(AppColors.primary.opacity(0.12), lineWidth: 1)
                        .frame(width: 210, height: 210)

                    // Inner active ring
                    Circle()
                        .stroke(AppColors.primary.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 140, height: 140)

                    // Cardinal direction labels
                    compassLabel("N", offset: CGSize(width: 0,    height: -125))
                    compassLabel("E", offset: CGSize(width: 125,  height: 0))
                    compassLabel("S", offset: CGSize(width: 0,    height: 125))
                    compassLabel("W", offset: CGSize(width: -125, height: 0))

                    // Needle
                    ZStack {
                        // Tail (muted)
                        Capsule()
                            .fill(AppColors.secondary.opacity(0.15))
                            .frame(width: 3, height: 50)
                            .offset(y: 28)

                        // Head (brand teal)
                        Capsule()
                            .fill(AppColors.primary)
                            .frame(width: 3, height: 60)
                            .offset(y: -32)

                        // Center pivot
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: 10, height: 10)
                    }
                    .rotationEffect(.degrees(needleAngle))

                    // Inner circle fill
                    Circle()
                        .fill(AppColors.background.opacity(0.6))
                        .frame(width: 30, height: 30)
                }

                Spacer()

                // ── Actions ───────────────────────────────────────────────────
                VStack(spacing: AppSpacing.md) {
                    PrimaryButton(title: "Open in Maps", action: onOpenInMaps)
                    SecondaryButton(title: "Change Target", action: onChangeTarget)
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Needle gently seeks heading — eases back and forth to signal active state
            withAnimation(
                .easeInOut(duration: 2.4)
                .repeatForever(autoreverses: true)
            ) {
                needleAngle = 52
            }
        }
    }

    // ── Cardinal Label Helper ─────────────────────────────────────────────────
    private func compassLabel(_ text: String, offset: CGSize) -> some View {
        Text(text)
            .font(AppTypography.caption)
            .foregroundColor(AppColors.secondary.opacity(0.25))
            .offset(offset)
    }
}

#Preview {
    CompassActiveView(
        place: MockPlace.generate(category: "Bar", vibe: "Lively"),
        onOpenInMaps: {},
        onChangeTarget: {}
    )
}
