//
//  ProfileView.swift
//  PourDirection
//
//  Settings hub. Toggles reflect real iOS permission state.
//  Tapping a toggle when permission is undetermined → system dialog.
//  Tapping when already determined → opens iOS Settings app.
//  State refreshes on scenePhase .active so toggles update after returning from Settings.
//

import SwiftUI
import UserNotifications
import CoreLocation

// MARK: - Profile View

struct ProfileView: View {

    @Environment(LocationManager.self) private var locationManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var showUpgradeSheet = false

    let onHelp: () -> Void

    // MARK: - Computed Bindings

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { notifStatus == .authorized },
            set: { _ in
                HapticManager.shared.light()
                switch notifStatus {
                case .notDetermined:
                    UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
                            DispatchQueue.main.async { checkNotificationStatus() }
                        }
                default:
                    openSettings()
                }
            }
        )
    }

    private var locationBinding: Binding<Bool> {
        Binding(
            get: {
                locationManager.authorizationStatus == .authorizedWhenInUse ||
                locationManager.authorizationStatus == .authorizedAlways
            },
            set: { _ in
                HapticManager.shared.light()
                switch locationManager.authorizationStatus {
                case .notDetermined:
                    locationManager.requestPermission()
                default:
                    openSettings()
                }
            }
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColors.gradientBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Fixed Header ────────────────────────────────────────────
                (Text("Pour's ")
                    .foregroundColor(AppColors.primary)
                 + Text("Settings")
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

                        // ── Preferences ───────────────────────────────────
                        sectionHeader("Preferences")

                        SettingsToggleRow(
                            icon: "bell",
                            title: "Enable Notifications",
                            isOn: notificationsBinding
                        )

                        SettingsToggleRow(
                            icon: "location",
                            title: "Enable Location Services",
                            isOn: locationBinding
                        )

                        // ── Actions ───────────────────────────────────────
                        VStack(spacing: 0) {
                            SettingsNavRow(icon: "crown", title: "Remove Ads") {
                                showUpgradeSheet = true
                            }
                            SettingsNavRow(icon: "questionmark.circle", title: "Help", action: onHelp)
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
        .onAppear {
            checkNotificationStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                checkNotificationStatus()
            }
        }
    }

    // MARK: - Helpers

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notifStatus = settings.authorizationStatus
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
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

/// Toggle row — icon + label + switch. Haptic handled by the binding setter.
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
        ProfileView(onHelp: {})
        CustomTabBar(selectedTab: .constant(.profile))
    }
    .ignoresSafeArea(edges: .bottom)
    .preferredColorScheme(.dark)
    .environment(LocationManager())
}
