//
//  ShareCardView.swift
//  PourDirection
//
//  Renderable share card — "Tonight's Pour Direction" for Instagram/iMessage.
//  Rendered to UIImage via ImageRenderer, then handed to ShareLink.
//  Sized 1080×1920 (Instagram story) for crisp social output.
//

import SwiftUI
import CoreLocation

struct ShareCardView: View {

    let place: Place
    let category: PlaceCategory?

    private var accent: Color { category?.color ?? AppColors.primary }

    var body: some View {
        ZStack {
            // ── Background ─────────────────────────────────────────────
            AppColors.background
                .ignoresSafeArea()

            // Soft accent glow from top
            RadialGradient(
                colors: [accent.opacity(0.45), accent.opacity(0.15), .clear],
                center: UnitPoint(x: 0.5, y: 0.15),
                startRadius: 40,
                endRadius: 900
            )
            .ignoresSafeArea()

            // Subtle bottom vignette
            LinearGradient(
                colors: [.clear, AppColors.background.opacity(0.95)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // ── Content ────────────────────────────────────────────────
            VStack(spacing: 0) {

                // Logo mark
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(.top, 80)

                // Wordmark
                Text("PourDirection")
                    .font(.system(size: 56, weight: .bold, design: .serif))
                    .italic()
                    .foregroundColor(AppColors.secondary)
                    .padding(.top, 8)

                Spacer(minLength: 40)

                // Tonight's tag
                Text("TONIGHT'S POUR")
                    .font(.system(size: 36, weight: .semibold))
                    .tracking(10)
                    .foregroundColor(AppColors.secondary.opacity(0.5))
                    .padding(.bottom, 32)

                // Category chip
                if let category {
                    HStack(spacing: 18) {
                        Image(systemName: category.iconName)
                            .font(.system(size: 42, weight: .semibold))
                        Text(category.displayTitle.uppercased())
                            .font(.system(size: 38, weight: .bold))
                            .tracking(4)
                    }
                    .foregroundColor(accent)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 20)
                    .background(
                        Capsule()
                            .fill(accent.opacity(0.15))
                    )
                    .overlay(
                        Capsule()
                            .stroke(accent.opacity(0.5), lineWidth: 2)
                    )
                    .padding(.bottom, 48)
                }

                // Venue name — hero
                Text(place.name)
                    .font(.system(size: 128, weight: .heavy, design: .serif))
                    .foregroundColor(AppColors.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 60)

                // Address
                if let address = place.formattedAddress {
                    HStack(spacing: 14) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(accent.opacity(0.85))
                        Text(address)
                            .font(.system(size: 34, weight: .medium))
                            .foregroundColor(AppColors.secondary.opacity(0.65))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.top, 36)
                    .padding(.horizontal, 80)
                }

                Spacer(minLength: 0)

                // Footer
                VStack(spacing: 12) {
                    Rectangle()
                        .fill(AppColors.secondary.opacity(0.15))
                        .frame(width: 160, height: 2)

                    HStack(spacing: 16) {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                            .rotationEffect(.degrees(45))
                        Text("Find yours tonight.")
                            .font(.system(size: 34, weight: .medium, design: .serif))
                            .italic()
                            .foregroundColor(AppColors.secondary.opacity(0.6))
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .frame(width: 1080, height: 1920)
    }
}

// MARK: - PlaceCategory display title fallback

private extension PlaceCategory {
    var displayTitle: String {
        switch self {
        case .bar:         return "Bar"
        case .restaurant:  return "Restaurant"
        case .club:        return "Club"
        case .dispensary:  return "Dispensary"
        case .liquorStore: return "Liquor"
        case .casino:      return "Casino"
        case .patio:       return "Patio"
        case .brunch:      return "Brunch"
        case .coffee:      return "Coffee"
        case .dayDrinks:   return "Day Drinks"
        case .parks:       return "Park"
        case .dessert:     return "Dessert"
        }
    }
}

// MARK: - Renderer

enum ShareCardRenderer {

    /// Render a `ShareCardView` to UIImage on the main actor.
    /// Returns nil if rendering fails (extremely rare, logged by SwiftUI).
    @MainActor
    static func render(place: Place, category: PlaceCategory?) -> UIImage? {
        let card = ShareCardView(place: place, category: category)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0   // retina-sharp at 1080×1920 source
        renderer.proposedSize = .init(width: 1080, height: 1920)
        return renderer.uiImage
    }
}

#Preview {
    ShareCardView(
        place: Place(
            id: "preview",
            name: "The Golden Tap",
            formattedAddress: "123 Granville St, Vancouver",
            coordinate: .init(latitude: 49.28, longitude: -123.12),
            rating: 4.6
        ),
        category: .bar
    )
    .scaleEffect(0.2)
}
