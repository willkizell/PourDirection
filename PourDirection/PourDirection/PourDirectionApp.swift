//
//  PourDirectionApp.swift
//  PourDirection
//
//  Entry point. Shows SplashView briefly on launch, then fades into RootContainerView.
//  All downstream navigation is managed by RootContainerView.
//

import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct PourDirectionApp: App {

    @State private var showSplash  = true
    @State private var mainOpacity = 0.0
    @State private var locationManager = LocationManager()

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
                    .opacity(mainOpacity)

                // Splash — fades out first
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
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

                // ── Supabase connection test ─────────────────────────────────
                // Remove once real Edge Functions are deployed.
                Task { await SupabaseManager.shared.testConnection() }
            }
        }
    }
}
