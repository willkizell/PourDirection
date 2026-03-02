//
//  PourDirectionApp.swift
//  PourDirection
//
//  Entry point. Shows SplashView briefly on launch, then fades into RootContainerView.
//  All downstream navigation is managed by RootContainerView.
//

import SwiftUI
import CoreLocation
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct PourDirectionApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var showSplash  = true
    @State private var mainOpacity = 0.0
    @State private var locationManager = LocationManager()
    @StateObject private var adsManager = AdsManager()

    @AppStorage("com.pourdirection.ageVerified")      private var ageVerified      = false
    @AppStorage("com.pourdirection.hasLaunchedBefore") private var hasLaunchedBefore = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Persistent background — same gradient as both screens,
                // so there is never a black flash between transitions.
                AppColors.gradientBackground
                    .ignoresSafeArea()

                // Main app shell — fades in after splash is clear
                RootContainerView()
                    .environment(locationManager)
                    .environmentObject(adsManager)
                    .opacity(mainOpacity)

                // Splash — fades out first
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }

                // Age gate — shown above everything on first launch
                if !ageVerified {
                    AgeGateView()
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
            .onAppear {
                // Single cross-dissolve: splash fades out while main fades in
                // simultaneously, so combined opacity stays near 1.0 throughout.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        showSplash  = false
                        mainOpacity = 1.0
                    }
                }

                #if canImport(GoogleMobileAds)
                MobileAds.shared.start { _ in }
                // Register this device for test ads (update if reinstalling the app).
                MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
                    "1b3dc40f450db15529430fa5a35ef648"
                ]
                #endif

                adsManager.refreshEntitlements()

                // Register notification delegate early
                _ = NotificationManager.shared

                // ── Local notifications ──────────────────────────────────────
                // Only request permission on second launch and beyond.
                // First launch: hasLaunchedBefore = false → skip, then mark true.
                // Second launch: ageVerified = true AND hasLaunchedBefore = true → request.
                if ageVerified && hasLaunchedBefore {
                    NotificationManager.shared.requestPermissionAndSchedule()

                    // After notification permission is set, upgrade to Always location
                    // so significant-location-change monitoring can wake the app in the background.
                    if locationManager.authorizationStatus == .authorizedWhenInUse ||
                       locationManager.authorizationStatus == .authorizedAlways {
                        locationManager.requestAlwaysPermission()
                        locationManager.startSignificantLocationMonitoring()
                    }
                }
                hasLaunchedBefore = true
                // ── Supabase connection test ─────────────────────────────────
                // Remove once real Edge Functions are deployed.
                Task { await SupabaseManager.shared.testConnection() }
            }
        }
    }
}

// MARK: - Background location launch handling

/// When iOS relaunches the app in the background due to a significant location change,
/// it passes UIApplication.LaunchOptionsKey.location in launchOptions.
/// SwiftUI apps use UIApplicationDelegateAdaptor for this.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if launchOptions?[.location] != nil {
            // App was woken by a significant location change.
            // Create a temporary location manager to get the latest location and process it.
            BackgroundLocationHandler.shared.handleBackgroundLaunch()
        }
        return true
    }
}

/// Thin wrapper that processes a background location event without the full SwiftUI environment.
final class BackgroundLocationHandler: NSObject, CLLocationManagerDelegate {
    static let shared = BackgroundLocationHandler()
    private let manager = CLLocationManager()

    private override init() {
        super.init()
        manager.delegate = self
    }

    func handleBackgroundLaunch() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else { return }
        manager.startMonitoringSignificantLocationChanges()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        NotificationManager.shared.handleSignificantLocationChange(location)
    }
}
