//
//  CompassActiveView.swift
//  PourDirection
//
//  Compass navigation screen with two-indicator system:
//  - Inner needle: rotates with device heading (where user is pointing)
//  - Outer triangle marker: fixed at top, compass face rotates so destination aligns to top
//  Alignment feedback: green (<15°), yellow (15-45°), red (>45°).
//  Alignment state is debounced (0.3s) to reduce jitter.
//  Presented as a fullScreenCover from RootContainerView.
//

import SwiftUI
import CoreLocation

struct CompassActiveView: View {

    let place: MapItem
    let onOpenInMaps: () -> Void
    @Binding var selectedTab: AppTab
    let onDismiss: () -> Void

    @Environment(LocationManager.self) private var locationManager

    // Wobble fallback when real heading is unavailable
    @State private var needleAngle: Double = 38
    // Pulse animation for alignment feedback
    @State private var alignedPulse: Bool = false
    // Debounced alignment level — updated with 0.3s delay
    @State private var displayedAlignment: AlignmentLevel = .off
    // Timer for debounce
    @State private var debounceTask: Task<Void, Never>?

    // MARK: - Computed Navigation State

    /// Device heading in degrees (0 = north). Falls back to wobble.
    private var deviceHeading: Double {
        locationManager.heading?.trueHeading ?? needleAngle
    }

    /// Bearing from current location to target (degrees from north).
    private var targetBearing: Double? {
        guard let loc = locationManager.currentLocation else { return nil }
        return MapItem.bearing(from: loc.coordinate, to: place.coordinate)
    }

    /// Angle difference between device heading and target bearing (0-180).
    private var headingDelta: Double {
        guard let bearing = targetBearing else { return 90 }
        var delta = abs(deviceHeading - bearing)
        if delta > 180 { delta = 360 - delta }
        return delta
    }

    /// Relative heading vs target (signed, -180...180).
    /// 0° means the phone is pointing directly at the destination.
    private var relativeHeadingToTarget: Double {
        guard let bearing = targetBearing else { return 0 }
        var diff = deviceHeading - bearing
        if diff > 180 { diff -= 360 }
        if diff < -180 { diff += 360 }
        return diff
    }

    /// Raw alignment level (before debounce).
    private var rawAlignment: AlignmentLevel {
        if headingDelta < 15 { return .aligned }
        if headingDelta < 45 { return .close }
        return .off
    }

    /// Rotation for compass face: rotates so bearing points to top.
    /// Face rotation = -(bearing - heading) so destination is always at 12 o'clock.
    private var compassFaceRotation: Double {
        guard let bearing = targetBearing else { return -needleAngle }
        return -(bearing - deviceHeading)
    }

    // MARK: - Alignment Level

    enum AlignmentLevel {
        case aligned, close, off

        var color: Color {
            switch self {
            case .aligned: return Color(hex: "34D399") // green
            case .close:   return Color(hex: "FBBF24") // yellow
            case .off:     return Color(hex: "EF4444") // red
            }
        }

        var glowOpacity: Double {
            switch self {
            case .aligned: return 0.25
            case .close:   return 0.10
            case .off:     return 0.05
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Dynamic gradient background — shifts with alignment accuracy
            dynamicBackground

            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────────────────────
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
                    Text(MapItem.formatDistance(place.distance(from: locationManager.currentLocation)))
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

                // ── Compass ─────────────────────────────────────────────────
                ZStack {
                    // Alignment glow ring
                    Circle()
                        .fill(displayedAlignment.color.opacity(displayedAlignment.glowOpacity))
                        .frame(width: 300, height: 300)
                        .blur(radius: 30)
                        .scaleEffect(alignedPulse && displayedAlignment == .aligned ? 1.06 : 1.0)

                    // ── Compass face (rotates so destination = top) ─────────
                    compassFace
                        .rotationEffect(.degrees(compassFaceRotation))

                    // ── Outer destination triangle (fixed at top) ───────────
                    destinationMarker

                    // ── Inner heading needle (rotates with device) ──────────
                    headingNeedle
                        .rotationEffect(.degrees(relativeHeadingToTarget))

                    // Center pivot
                    Circle()
                        .fill(displayedAlignment.color)
                        .frame(width: 10, height: 10)
                        .shadow(color: displayedAlignment.color.opacity(0.4), radius: 3)

                    Circle()
                        .fill(AppColors.background.opacity(0.5))
                        .frame(width: 6, height: 6)
                }
                .animation(.linear(duration: 0.15), value: deviceHeading)
                .animation(.linear(duration: 0.15), value: compassFaceRotation)
                .animation(.easeInOut(duration: 0.4), value: displayedAlignment.color)

                // ── Alignment label ─────────────────────────────────────────
                Text(alignmentLabel)
                    .font(AppTypography.caption)
                    .foregroundColor(displayedAlignment.color.opacity(0.7))
                    .padding(.top, AppSpacing.md)

                Spacer()

                // ── Actions ─────────────────────────────────────────────────
                Button(action: onOpenInMaps) {
                    Text("Open in Maps")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(
                selectedTab: $selectedTab,
                onCompassTap: onDismiss,
                onTabTap: { _ in
                    onDismiss()
                }
            )
            .background(AppColors.background.ignoresSafeArea(edges: .bottom))
        }
        .preferredColorScheme(.dark)
        .onAppear {
            locationManager.startUpdating()
            // Wobble fallback for simulator
            if locationManager.heading == nil {
                withAnimation(
                    .easeInOut(duration: 2.4)
                    .repeatForever(autoreverses: true)
                ) {
                    needleAngle = 52
                }
            }
            // Pulse animation for aligned state
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
            ) {
                alignedPulse = true
            }
            // Initialize alignment
            displayedAlignment = rawAlignment
        }
        .onChange(of: rawAlignment) { _, newValue in
            // Debounce alignment state changes (0.3s)
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.4)) {
                    displayedAlignment = newValue
                }
            }
        }
    }

    // MARK: - Subviews

    /// Compass face — concentric rings and cardinal labels.
    /// Rotates so the bearing-to-destination always points to 12 o'clock.
    private var compassFace: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(displayedAlignment.color.opacity(0.10), lineWidth: 1)
                .frame(width: 280, height: 280)

            // Middle ring
            Circle()
                .stroke(displayedAlignment.color.opacity(0.14), lineWidth: 1)
                .frame(width: 210, height: 210)

            // Inner ring
            Circle()
                .stroke(displayedAlignment.color.opacity(0.22), lineWidth: 1.5)
                .frame(width: 140, height: 140)

            // Cardinal direction labels (rotate with face)
            compassLabel("N", offset: CGSize(width: 0,    height: -125))
            compassLabel("E", offset: CGSize(width: 125,  height: 0))
            compassLabel("S", offset: CGSize(width: 0,    height: 125))
            compassLabel("W", offset: CGSize(width: -125, height: 0))
        }
    }

    /// Outer destination triangle — fixed at top of compass, points inward.
    private var destinationMarker: some View {
        VStack(spacing: 0) {
            Image(systemName: "triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(displayedAlignment.color)
                .rotationEffect(.degrees(0))
                .shadow(color: displayedAlignment.color.opacity(0.3), radius: 3)
            Spacer()
        }
        .frame(height: 280)
        .offset(y: -25)
    }

    /// Inner heading needle — shows where device is pointing.
    /// Thin white line, no "N" label.
    private var headingNeedle: some View {
        ZStack {
            // Trailing half (behind center)
            Capsule()
                .fill(AppColors.secondary.opacity(0.06))
                .frame(width: 2, height: 35)
                .offset(y: 20)

            // Leading half (above center — where device points)
            Capsule()
                .fill(AppColors.secondary.opacity(0.25))
                .frame(width: 2, height: 45)
                .offset(y: -26)
        }
    }

    /// Dynamic background gradient that shifts with alignment
    private var dynamicBackground: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: displayedAlignment.color.opacity(0.15), location: 0.0),
                    .init(color: displayedAlignment.color.opacity(0.04), location: 0.4),
                    .init(color: AppColors.background, location: 0.75)
                ]),
                center: .center,
                startRadius: 1,
                endRadius: 420
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: displayedAlignment.color)
        }
    }

    private var alignmentLabel: String {
        switch displayedAlignment {
        case .aligned: return "On track — keep going!"
        case .close:   return "Almost there — adjust slightly"
        case .off:     return "Turn to align with destination"
        }
    }

    // ── Cardinal Label Helper ─────────────────────────────────────────────
    private func compassLabel(_ text: String, offset: CGSize) -> some View {
        Text(text)
            .font(AppTypography.caption)
            .foregroundColor(AppColors.secondary.opacity(0.20))
            .offset(offset)
    }
}

#Preview {
    CompassActiveView(
        place: MapItem.mock(category: .bar, vibe: "Lively"),
        onOpenInMaps: {},
        selectedTab: .constant(.map),
        onDismiss: {}
    )
    .environment(LocationManager())
}
