//
//  UpgradeToProView.swift
//  PourDirection
//
//  Bottom sheet upsell for PourPro membership.
//  Presented as a .sheet from ProfileView when "Remove Ads" is tapped.
//  The tagline floats at the top of the sheet (inside, so it's never dimmed).
//  All actions are mock for now — wire to StoreKit when ready.
//

import SwiftUI

struct UpgradeToProView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer().frame(height: AppSpacing.xl)

                // ── Title ────────────────────────────────────────────────
                (Text("Ready for Pour")
                    .foregroundColor(AppColors.secondary)
                 + Text("Pro")
                    .foregroundColor(AppColors.primary)
                 + Text("?")
                    .foregroundColor(AppColors.secondary))
                    .font(AppTypography.titleMedium)
                    .padding(.bottom, AppSpacing.xxs)

                Text("Upgrade your nights.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.secondary.opacity(0.45))
                    .padding(.bottom, AppSpacing.xl)

                // ── Benefits ─────────────────────────────────────────────
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    benefitRow("No ads")
                    benefitRow("Unlimited suggestions")
                }
                .padding(.horizontal, AppSpacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .background(AppColors.divider)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.lg)

                // ── Pricing ──────────────────────────────────────────────
                HStack {
                    Text("For only!")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("$9.99 per year")
                            .font(AppTypography.header)
                            .foregroundColor(AppColors.secondary)
                        Text("That's less than one drink.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary.opacity(0.4))
                    }
                }
                .padding(.horizontal, AppSpacing.xl)

                Spacer()

                // ── CTA ──────────────────────────────────────────────────
                PrimaryButton(title: "Upgrade to Pro") {
                    // Future phase — StoreKit purchase flow
                    dismiss()
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)

                // ── Cancel anytime ───────────────────────────────────────
                Text("Cancel anytime.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.secondary.opacity(0.35))
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.xl)
            }

        }
        .preferredColorScheme(.dark)
    }

    // ── Benefit Row ──────────────────────────────────────────────────────
    private func benefitRow(_ text: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(AppColors.primary)
            Text(text)
                .font(AppTypography.body)
                .foregroundColor(AppColors.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    UpgradeToProView()
}
