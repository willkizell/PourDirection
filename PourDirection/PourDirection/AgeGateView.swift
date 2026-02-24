//
//  AgeGateView.swift
//  PourDirection
//
//  Age verification gate shown once on first launch, before SplashView.
//  Detects country via Locale.current.regionCode:
//    CA  → 19+
//    US  → 21+
//    else → 18+
//
//  Acceptance is persisted to UserDefaults under "com.pourdirection.ageVerified".
//  Once accepted the gate never appears again.
//

import SwiftUI

struct AgeGateView: View {

    @AppStorage("com.pourdirection.ageVerified") private var ageVerified = false
    @State private var isDenied = false

    private var requiredAge: Int {
        switch Locale.current.region?.identifier ?? "" {
        case "CA": return 19
        case "US": return 21
        default:   return 18
        }
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            AppColors.gradientBackground
                .ignoresSafeArea()

            if isDenied {
                deniedView
            } else {
                questionView
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Question

    private var questionView: some View {
        VStack(spacing: 0) {
            Spacer()

            AppLogoView(size: 80)

            Spacer().frame(height: AppSpacing.xl)

            (Text("Pour")
                .foregroundColor(AppColors.secondary)
             + Text("Direction")
                .foregroundColor(AppColors.primary))
                .font(AppTypography.titleMedium)

            Spacer().frame(height: AppSpacing.xxl)

            Text("Are you \(requiredAge) or older?")
                .font(AppTypography.header)
                .foregroundColor(AppColors.secondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: AppSpacing.xs)

            Text("You must be of legal drinking age to use PourDirection.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.secondary.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Spacer().frame(height: AppSpacing.xxl)

            PrimaryButton(title: "Yes, I'm \(requiredAge)+") {
                ageVerified = true
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)

            Spacer().frame(height: AppSpacing.md)

            Button(action: {
                HapticManager.shared.light()
                withAnimation(.easeInOut(duration: 0.25)) {
                    isDenied = true
                }
            }) {
                Text("No, I'm not")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.secondary.opacity(0.4))
                    .padding(.vertical, AppSpacing.sm)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Denied (blocking)

    private var deniedView: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(AppColors.primary.opacity(0.6))

            Text("Access Restricted")
                .font(AppTypography.header)
                .foregroundColor(AppColors.secondary)

            Text("You must meet the legal age requirement to use this app.")
                .font(AppTypography.body)
                .foregroundColor(AppColors.secondary.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
    }
}

// MARK: - Preview

#Preview("Question") {
    AgeGateView()
}
