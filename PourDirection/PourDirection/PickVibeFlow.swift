//
//  PickVibeFlow.swift
//  PourDirection
//
//  3-step full-screen modal for selecting category and vibe before finding a spot.
//  Self-contained: manages its own step state and dismisses itself on confirm.
//  Calls onConfirm(MapItem) before dismissing so the parent can update its state first.
//

import SwiftUI

struct PickVibeFlow: View {

    let onConfirm: (MapItem) -> Void

    @Environment(\.dismiss) private var dismiss

    // ── Internal Step State ───────────────────────────────────────────────────
    private enum Step { case category, vibe, confirm }

    @State private var step: Step              = .category
    @State private var selectedCategory: String = ""
    @State private var selectedVibe: String     = ""

    // ── Data ─────────────────────────────────────────────────────────────────
    private let categories = ["Bar", "Club", "Liquor Store", "Event"]
    private let vibes      = ["Chill", "Lively", "Party", "Date Night", "Sports"]

    // ── Body ─────────────────────────────────────────────────────────────────
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            // Background gradient — less intense in modal context
            AppColors.gradientBackground
                .opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Top Bar: Close + Progress ─────────────────────────────────
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.secondary.opacity(0.5))
                            .padding(AppSpacing.sm)
                    }

                    Spacer()

                    // Step progress dots
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(0..<3, id: \.self) { index in
                            Capsule()
                                .fill(stepIndex >= index ? AppColors.primary : AppColors.secondary.opacity(0.2))
                                .frame(width: stepIndex == index ? 20 : 8, height: 4)
                                .animation(.spring(response: 0.4), value: stepIndex)
                        }
                    }

                    Spacer()

                    // Mirror of close button for centering
                    Color.clear
                        .frame(width: 40, height: 40)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)

                // ── Step Content ──────────────────────────────────────────────
                // Each step slides in from the right and out to the left.
                ZStack {
                    if step == .category {
                        categoryStep
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal:   .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else if step == .vibe {
                        vibeStep
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal:   .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        confirmStep
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal:   .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }

    // ── Step 1: Category ─────────────────────────────────────────────────────
    private var categoryStep: some View {
        VStack(spacing: 0) {
            stepHeader(title: "What are you\nlooking for?")

            Spacer()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.md) {
                ForEach(categories, id: \.self) { category in
                    VibeOptionButton(
                        title:      category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                step = .vibe
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)

            Spacer()
        }
    }

    // ── Step 2: Vibe ─────────────────────────────────────────────────────────
    private var vibeStep: some View {
        VStack(spacing: 0) {
            stepHeader(title: "What's the vibe?")

            Spacer()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.md) {
                ForEach(vibes, id: \.self) { vibe in
                    VibeOptionButton(
                        title:      vibe,
                        isSelected: selectedVibe == vibe
                    ) {
                        selectedVibe = vibe
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                step = .confirm
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)

            Spacer()

            // Back button
            Button {
                withAnimation(.easeInOut(duration: 0.3)) { step = .category }
            } label: {
                Text("Back")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.secondary.opacity(0.4))
            }
            .padding(.bottom, AppSpacing.xl)
        }
    }

    // ── Step 3: Confirm ───────────────────────────────────────────────────────
    private var confirmStep: some View {
        VStack(spacing: 0) {
            stepHeader(title: "Ready to find\nyour spot?")

            Spacer()

            // Summary card
            CardView {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.xs) {
                        Text("Looking for")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary.opacity(0.5))
                        Text(selectedCategory)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.primary)
                    }
                    HStack(spacing: AppSpacing.xs) {
                        Text("Vibe")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary.opacity(0.5))
                        Text(selectedVibe)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.secondary)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)

            Spacer()

            // Actions
            VStack(spacing: AppSpacing.md) {
                PrimaryButton(title: "Find My Spot") {
                    let place = MapItem.mock(
                        category: PlaceCategory(rawValue: selectedCategory) ?? .bar,
                        vibe: selectedVibe
                    )
                    onConfirm(place)
                    dismiss()
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { step = .vibe }
                } label: {
                    Text("Back")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary.opacity(0.4))
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
            .padding(.bottom, AppSpacing.xl)
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    private func stepHeader(title: String) -> some View {
        Text(title)
            .font(AppTypography.titleLarge)
            .foregroundColor(AppColors.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
            .padding(.top, AppSpacing.xl)
    }

    private var stepIndex: Int {
        switch step {
        case .category: return 0
        case .vibe:     return 1
        case .confirm:  return 2
        }
    }
}

// MARK: - Vibe Option Button
// Local to this flow — not added to AppComponents since it's flow-specific selection UI.

private struct VibeOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.bodyMedium)
                .foregroundColor(isSelected ? AppColors.background : AppColors.secondary.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .fill(isSelected ? AppColors.primary : AppColors.cardSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(
                            isSelected ? AppColors.primary : AppColors.secondary.opacity(0.12),
                            lineWidth: 0.5
                        )
                )
                .scaleEffect(isSelected ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PickVibeFlow { _ in }
}
