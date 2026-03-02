//
//  CompassActiveView.swift
//  PourDirection
//
//  Compass navigation screen.
//  - Compass face: rotates so cardinal labels (N/E/S/W) match the real world.
//  - Destination triangle: static at top — visual "forward" reference.
//  - Inner needle: rotates to point toward the target place.
//  Alignment: green (<15°), yellow (15–45°), red (>45°).
//  Heading: trueHeading with continuous (unwrapped) tracking; SwiftUI animation smooths.
//  Presented as a fullScreenCover from RootContainerView.
//

import SwiftUI
import CoreLocation

struct CompassActiveView: View {

    let place: Place
    let onOpenInMaps: () -> Void
    @Binding var selectedTab: AppTab
    let onDismiss: () -> Void

    @Environment(LocationManager.self) private var locationManager

    // ── Heading State ─────────────────────────────────────────────────────────
    /// Continuous (unwrapped) heading for rotation — never jumps at 0/360 boundary.
    @State private var displayHeading: Double = 0
    /// Last raw heading (0–360) for bearing math.
    @State private var rawHeading: Double = 0
    @State private var hasInitialHeading: Bool = false

    // ── UI State ──────────────────────────────────────────────────────────────
    @State private var displayedAlignment: AlignmentLevel = .misaligned
    @State private var alignedPulse: Bool = false
    @State private var showRideButton: Bool = false

    // ── Haptic ───────────────────────────────────────────────────────────────
    @State private var prevDelta: Double = 180
    @State private var lastHaptic: Date = .distantPast

    // MARK: - Computed Navigation State

    /// Bearing from current location to destination (0–360, clockwise from north).
    private var targetBearing: Double? {
        guard let loc = locationManager.currentLocation else { return nil }
        return Place.bearing(from: loc.coordinate, to: place.coordinate)
    }

    /// Signed angle from current heading to target (−180…+180).
    private var normalizedDifference: Double {
        guard let bearing = targetBearing else { return 0 }
        return fmod((bearing - rawHeading + 540), 360) - 180
    }

    /// Absolute misalignment (0–180).
    private var headingDelta: Double {
        abs(normalizedDifference)
    }

    /// Alignment level derived from headingDelta.
    private var currentAlignment: AlignmentLevel {
        if headingDelta < 15 { return .aligned }
        if headingDelta < 45 { return .near }
        return .misaligned
    }

    /// Distance from user to place in meters.
    private var distanceMeters: CLLocationDistance? {
        place.distance(from: locationManager.currentLocation)
    }

    // MARK: - Alignment Level

    enum AlignmentLevel: Equatable {
        case aligned, near, misaligned

        var color: Color {
            switch self {
            case .aligned:    return Color(hex: "34D399")    // green — on track
            case .near:       return Color(hex: "F5C518")    // yellow — off track
            case .misaligned: return Color(hex: "EF4444")    // red — way off
            }
        }

        var glowOpacity: Double {
            switch self {
            case .aligned:    return 0.25
            case .near:       return 0.10
            case .misaligned: return 0.05
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            dynamicBackground

            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Navigating")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.secondary.opacity(0.5))
                        Spacer()
                        Text(Place.formatDistance(place.distance(from: locationManager.currentLocation)))
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.primary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(AppColors.primary.opacity(0.12))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(AppColors.primary.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    Text(place.name)
                        .font(AppTypography.titleSmall)
                        .foregroundColor(AppColors.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    // Closed status — subtle indicator, does not block navigation
                    if place.isOpenNow == false {
                        HStack(spacing: 4) {
                            Text("Closed right now")
                                .font(AppTypography.caption)
                                .foregroundColor(Color(hex: "EF4444").opacity(0.7))
                            if let opens = place.opensAt {
                                Text("· Opens \(opens)")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.secondary.opacity(0.35))
                            }
                        }
                    }
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
                        .animation(.easeInOut(duration: 0.4), value: displayedAlignment)

                    // ── Compass face — rotates so NSEW matches real world ────
                    compassFace
                        .rotationEffect(.degrees(-displayHeading))
                        .animation(.linear(duration: 0.2), value: displayHeading)

                    // ── Destination triangle — static forward reference ──────
                    destinationMarker

                    // ── Inner needle — rotates toward target ─────────────────
                    headingNeedle
                        .rotationEffect(.degrees(normalizedDifference))
                        .animation(.linear(duration: 0.2), value: normalizedDifference)

                    // Center pivot — pulses when tightly aligned (<8°)
                    Circle()
                        .fill(displayedAlignment.color)
                        .frame(width: 10, height: 10)
                        .shadow(
                            color: displayedAlignment.color.opacity(
                                headingDelta < 8 && alignedPulse ? 0.8 : 0.4
                            ),
                            radius: headingDelta < 8 && alignedPulse ? 10 : 3
                        )
                        .scaleEffect(headingDelta < 8 && alignedPulse ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.4), value: displayedAlignment)

                    Circle()
                        .fill(AppColors.background.opacity(0.5))
                        .frame(width: 6, height: 6)
                }

                // ── Alignment label ─────────────────────────────────────────
                Text(alignmentLabel)
                    .font(AppTypography.caption)
                    .foregroundColor(displayedAlignment.color.opacity(0.7))
                    .padding(.top, AppSpacing.md)
                    .animation(.easeInOut(duration: 0.3), value: displayedAlignment)

                Spacer()

                // ── Actions ─────────────────────────────────────────────────
                VStack(spacing: AppSpacing.sm) {
                    Button(action: onOpenInMaps) {
                        Text("Open in Maps")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)

                    if showRideButton {
                        Button(action: {
                            HapticManager.shared.light()
                            openUber()
                        }) {
                            HStack(spacing: AppSpacing.iconLabelSpacing) {
                                Image(systemName: "car.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Get a Ride with Uber?")
                            }
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(Color.clear)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppColors.secondary.opacity(0.2), lineWidth: 1.0)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
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
            // Pulse animation for aligned state
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
            ) {
                alignedPulse = true
            }
            // Check ride button after compass settles
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                updateRideButtonVisibility()
            }
        }
        .onChange(of: locationManager.heading?.trueHeading) { _, _ in
            processHeadingUpdate(locationManager.heading)
        }
        .onChange(of: locationManager.currentLocation) { _, _ in
            updateRideButtonVisibility()
            // Recompute alignment when location changes (bearing shifts)
            displayedAlignment = currentAlignment
        }
    }

    // MARK: - Heading Processing

    /// Continuous heading: accumulate shortest-arc deltas so the value never
    /// wraps at 0/360. SwiftUI animation handles all smoothing.
    private func processHeadingUpdate(_ newHeading: CLHeading?) {
        guard let h = newHeading, h.trueHeading >= 0 else { return }
        let raw = h.trueHeading

        if !hasInitialHeading {
            displayHeading = raw
            rawHeading = raw
            hasInitialHeading = true
        } else {
            var delta = raw - rawHeading
            if delta >  180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            rawHeading = raw
            displayHeading += delta
        }

        displayedAlignment = currentAlignment

        // Haptic only when veering OFF course (delta growing + past green zone)
        let delta = headingDelta
        defer { prevDelta = delta }
        if delta > prevDelta && delta > 15 {
            let now = Date()
            if now.timeIntervalSince(lastHaptic) >= 0.5 {
                lastHaptic = now
                let intensity = min(delta / 90.0, 1.0)
                HapticManager.shared.veer(intensity: Float(intensity))
            }
        }
    }

    // MARK: - Ride Button

    private func updateRideButtonVisibility() {
        let shouldShow = (distanceMeters ?? 0) > DistancePreferences.shared.walkingDistanceMeters
        guard shouldShow != showRideButton else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            showRideButton = shouldShow
        }
    }

    // MARK: - Uber

    private func openUber() {
        let lat  = place.coordinate.latitude
        let lng  = place.coordinate.longitude
        let name = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let appURL = URL(string: "uber://?action=setPickup&dropoff[latitude]=\(lat)&dropoff[longitude]=\(lng)&dropoff[nickname]=\(name)")
        let webURL = URL(string: "https://m.uber.com/ul/?action=setPickup&dropoff[latitude]=\(lat)&dropoff[longitude]=\(lng)&dropoff[nickname]=\(name)")

        if let appURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL {
            UIApplication.shared.open(webURL)
        }
    }

    // MARK: - Subviews

    /// Compass face — concentric rings and cardinal labels.
    /// Rotated externally by -displayHeading so NSEW always matches the real world.
    private var compassFace: some View {
        ZStack {
            Circle()
                .stroke(displayedAlignment.color.opacity(0.10), lineWidth: 1)
                .frame(width: 280, height: 280)

            Circle()
                .stroke(displayedAlignment.color.opacity(0.14), lineWidth: 1)
                .frame(width: 210, height: 210)

            Circle()
                .stroke(displayedAlignment.color.opacity(0.22), lineWidth: 1.5)
                .frame(width: 140, height: 140)

            compassLabel("N", offset: CGSize(width: 0,    height: -125))
            compassLabel("E", offset: CGSize(width: 125,  height: 0))
            compassLabel("S", offset: CGSize(width: 0,    height: 125))
            compassLabel("W", offset: CGSize(width: -125, height: 0))
        }
    }

    /// Destination triangle — static forward reference at top of compass.
    private var destinationMarker: some View {
        VStack(spacing: 0) {
            Image(systemName: "triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(displayedAlignment.color)
                .shadow(
                    color: displayedAlignment.color.opacity(
                        displayedAlignment == .aligned ? 0.6 : 0.3
                    ),
                    radius: displayedAlignment == .aligned ? 6 : 3
                )
                .animation(.easeInOut(duration: 0.4), value: displayedAlignment)
            Spacer()
        }
        .frame(height: 280)
        .offset(y: -25)
    }

    /// Inner needle — rotates by normalizedDifference to point toward target.
    /// When this needle aligns with the static triangle at top, the user is on track.
    private var headingNeedle: some View {
        ZStack {
            Capsule()
                .fill(AppColors.secondary.opacity(0.06))
                .frame(width: 2, height: 35)
                .offset(y: 20)
            Capsule()
                .fill(AppColors.secondary.opacity(0.25))
                .frame(width: 2, height: 45)
                .offset(y: -26)
        }
    }

    /// Dynamic background gradient that shifts with alignment state.
    private var dynamicBackground: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: displayedAlignment.color.opacity(0.15), location: 0.0),
                    .init(color: displayedAlignment.color.opacity(0.04), location: 0.4),
                    .init(color: AppColors.background,                   location: 0.75)
                ]),
                center: .center,
                startRadius: 1,
                endRadius: 420
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: displayedAlignment)
        }
    }

    private var alignmentLabel: String {
        switch displayedAlignment {
        case .aligned:    return "You're facing it"
        case .near:       return "Almost there"
        case .misaligned: return "Turn toward destination"
        }
    }

    private func compassLabel(_ text: String, offset: CGSize) -> some View {
        Text(text)
            .font(AppTypography.caption)
            .foregroundColor(AppColors.secondary.opacity(0.20))
            .offset(offset)
    }
}

#Preview {
    CompassActiveView(
        place: Place(
            id: "preview",
            name: "The Local Tap Room",
            formattedAddress: "123 Main St, Vancouver, BC",
            coordinate: CLLocationCoordinate2D(latitude: 49.2827, longitude: -123.1207),
            rating: 4.5
        ),
        onOpenInMaps: {},
        selectedTab: .constant(.map),
        onDismiss: {}
    )
    .environment(LocationManager())
}
