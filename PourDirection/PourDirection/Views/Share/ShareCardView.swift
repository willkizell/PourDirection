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
            LinearGradient(
                colors: [
                    AppColors.background,
                    accent.opacity(0.35),
                    AppColors.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [accent.opacity(0.25), .clear],
                center: .center,
                startRadius: 80,
                endRadius: 700
            )

            // ── Content ────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 60) {

                // Header
                VStack(alignment: .leading, spacing: 16) {
                    Text("TONIGHT'S")
                        .font(.system(size: 52, weight: .regular, design: .default))
                        .foregroundColor(AppColors.secondary.opacity(0.45))
                        .tracking(8)
                    Text("Pour Direction")
                        .font(.system(size: 92, weight: .bold, design: .serif))
                        .foregroundColor(AppColors.secondary)
                        .italic()
                }

                Spacer(minLength: 0)

                // Venue card
                VStack(alignment: .leading, spacing: 32) {
                    if let category {
                        HStack(spacing: 20) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 54, weight: .semibold))
                                .foregroundColor(accent)
                            Text(category.displayTitle.uppercased())
                                .font(.system(size: 42, weight: .bold))
                                .foregroundColor(accent)
                                .tracking(4)
                        }
                    }

                    Text(place.name)
                        .font(.system(size: 120, weight: .heavy, design: .serif))
                        .foregroundColor(AppColors.secondary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.5)
                        .fixedSize(horizontal: false, vertical: true)

                    if let address = place.formattedAddress {
                        HStack(spacing: 16) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(accent.opacity(0.8))
                            Text(address)
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(AppColors.secondary.opacity(0.7))
                                .lineLimit(2)
                        }
                    }
                }

                Spacer(minLength: 0)

                // Footer
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PourDirection")
                            .font(.system(size: 44, weight: .bold, design: .serif))
                            .foregroundColor(AppColors.primary)
                            .italic()
                        Text("Find yours tonight.")
                            .font(.system(size: 30, weight: .regular))
                            .foregroundColor(AppColors.secondary.opacity(0.5))
                    }
                    Spacer()
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 60, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .rotationEffect(.degrees(45))
                }
            }
            .padding(90)
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
