//
//  ProfileView.swift
//  PourDirection
//
//  Your Profile screen — settings hub with user info, security toggles,
//  account actions, and PourPro upsell. All values are mock for now.
//  Navigation delegated to RootContainerView via closures.
//

import SwiftUI

// MARK: - Profile View

struct ProfileView: View {

    // Mock state — replace with real user model when backend is ready
    @State private var user = MockUser()
    @State private var notificationsEnabled  = true
    @State private var locationEnabled       = true
    @State private var faceIDEnabled         = true
    @State private var showUpgradeSheet      = false

    let onEditProfile: () -> Void
    let onHelp: () -> Void

    var body: some View {
        ZStack {
            AppColors.gradientBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Fixed Header ────────────────────────────────────────────
                (Text("Your")
                    .foregroundColor(AppColors.primary)
                 + Text("Profile")
                    .foregroundColor(AppColors.secondary))
                    .font(AppTypography.titleSmall)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.md)
                    .background(AppColors.background.ignoresSafeArea(edges: .top))

                // ── Scrollable Content ──────────────────────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // ── User Card ───────────────────────────────────────
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: user.avatarSystemName)
                                .font(.system(size: 44))
                                .foregroundColor(AppColors.secondary.opacity(0.6))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.fullName)
                                    .font(AppTypography.header)
                                    .foregroundColor(AppColors.secondary)
                                Text(user.email)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.secondary.opacity(0.45))
                            }

                            Spacer()

                            Button(action: onEditProfile) {
                                Text("Edit Profile")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.secondary)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, AppSpacing.xs)
                                    .background(AppColors.primary.opacity(0.7))
                                    .cornerRadius(AppRadius.sm)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        .padding(.top, AppSpacing.md)
                        .padding(.bottom, AppSpacing.lg)

                        // ── Security Section ────────────────────────────────
                        sectionHeader("Security")

                        SettingsToggleRow(
                            icon: "bell",
                            title: "Enable Notifications",
                            isOn: $notificationsEnabled
                        )

                        SettingsToggleRow(
                            icon: "location",
                            title: "Enable Location Services",
                            isOn: $locationEnabled
                        )

                        // ── Account Section ─────────────────────────────────
                        sectionHeader("Account")

                        SettingsNavRow(icon: "lock", title: "Change Password") {
                            // Future phase — password change flow
                        }

                        SettingsToggleRow(
                            icon: "faceid",
                            title: "Login with Face ID",
                            isOn: $faceIDEnabled
                        )

                        // ── Actions ─────────────────────────────────────────
                        VStack(spacing: 0) {
                            SettingsNavRow(icon: "crown", title: "Remove Ads") {
                                showUpgradeSheet = true
                            }

                            SettingsNavRow(icon: "questionmark.circle", title: "Help", action: onHelp)

                            SettingsNavRow(icon: "rectangle.portrait.and.arrow.right", title: "Logout") {
                                // Future phase — logout flow
                            }
                        }
                        .padding(.top, AppSpacing.sm)

                        Spacer().frame(height: AppSpacing.xxxl)
                    }
                }
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeToProView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // ── Section Header ──────────────────────────────────────────────────
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.secondary.opacity(0.4))
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, AppSpacing.xs)
    }
}

// MARK: - Settings Row Components

/// Toggle row — icon + label + switch with haptic feedback
struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.secondary.opacity(0.6))
                .frame(width: 24, alignment: .center)
            Text(title)
                .font(AppTypography.body)
                .foregroundColor(AppColors.secondary)
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(AppColors.primary)
                .labelsHidden()
        }
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.cardSurface.opacity(0.85))
        .cornerRadius(AppRadius.md)
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.vertical, 2)
        .onChange(of: isOn) { _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

/// Navigation row — icon + label + chevron, tappable
struct SettingsNavRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.secondary.opacity(0.6))
                    .frame(width: 24, alignment: .center)
                Text(title)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.secondary.opacity(0.3))
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.cardSurface.opacity(0.85))
            .cornerRadius(AppRadius.md)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview {
    ZStack(alignment: .bottom) {
        ProfileView(onEditProfile: {}, onHelp: {})
        CustomTabBar(selectedTab: .constant(.profile))
    }
    .ignoresSafeArea(edges: .bottom)
    .preferredColorScheme(.dark)
}
