//
//  MapItem.swift
//  PourDirection
//
//  Core venue/event model. Replaces MockPlace with typed category enum
//  and real coordinate support. Distance is never stored — always derived
//  from LocationManager at display time.
//

import Foundation
import CoreLocation

// MARK: - Place Category

enum PlaceCategory: String, CaseIterable, Codable {
    case bar         = "Bar"
    case club        = "Club"
    case liquorStore = "Liquor Store"
    case event       = "Event"
}

// MARK: - MapItem

struct MapItem: Identifiable, Hashable {

    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
    let category: PlaceCategory
    let vibe: String
    let rating: Double?
    let isOpen: Bool?
    let closingTime: String?
    let reviewCount: Int?
    // Event-specific (nil for bars/clubs/stores)
    let eventTime: String?
    let venue: String?
    let priceRange: String?
    let isTonight: Bool

    // MARK: - Hashable (CLLocationCoordinate2D is not Hashable)

    static func == (lhs: MapItem, rhs: MapItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // MARK: - Display Helpers

    var displayCategory: String { category.rawValue }

    /// Compute distance from a user location — never stored.
    func distance(from location: CLLocation?) -> CLLocationDistance? {
        guard let location else { return nil }
        let itemLocation = CLLocation(latitude: coordinate.latitude,
                                      longitude: coordinate.longitude)
        return location.distance(from: itemLocation)
    }

    /// Format a distance value for UI display.
    /// Uses MeasurementFormatter for locale-aware units (km in Canada, mi in US).
    static func formatDistance(_ meters: CLLocationDistance?) -> String {
        guard let meters, meters >= 100 else { return "Nearby" }
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        formatter.unitStyle = .short
        return formatter.string(from: measurement)
    }

    /// Compute bearing from one coordinate to another (degrees, 0 = north, clockwise).
    static func bearing(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> Double {
        let lat1 = origin.latitude * .pi / 180
        let lat2 = destination.latitude * .pi / 180
        let dLon = (destination.longitude - origin.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)
        return (radians * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: - Mock Factory

    /// Random mock MapItem — ports logic from the old MockPlace.generate().
    static func mock(category: PlaceCategory, vibe: String) -> MapItem {
        let ratings      = [3.8, 4.0, 4.1, 4.2, 4.3, 4.5, 4.7, 4.8]
        let reviewCounts = [5, 12, 28, 47, 89, 134, 203, 389]

        // Random coordinate near Vancouver (49.2827, -123.1207)
        let baseLat = 49.2827
        let baseLng = -123.1207
        let coord = CLLocationCoordinate2D(
            latitude:  baseLat  + Double.random(in: -0.02...0.02),
            longitude: baseLng + Double.random(in: -0.02...0.02)
        )

        if category == .event {
            let chillNames     = ["Live Jazz Night", "Acoustic Sessions", "Wine & Canvas", "Art Gallery Opening"]
            let energeticNames = ["Rooftop Sessions", "DJ Battle Night", "The Midnight Live", "Electronic Night"]
            let otherNames     = ["Comedy Open Mic", "Karaoke Night", "Trivia Night", "Stand-Up Showcase"]

            let pool: [String] = {
                switch vibe {
                case "Chill":     return chillNames
                case "Energetic": return energeticNames
                default:          return otherNames
                }
            }()

            let venues       = ["The Cellar Jazz Club", "Rooftop at The Ace", "Underground Lounge",
                                "The Grand Ballroom", "Velvet Room", "District Stage"]
            let tonightTimes = ["Tonight at 7:00 PM", "Tonight at 9:00 PM", "Tonight at 10:30 PM"]
            let upcomingTimes = ["Sat at 8:00 PM", "Sun at 7:30 PM", "Fri at 9:00 PM"]
            let prices       = ["$10–$20", "$15–$30", "$20–$40", "Free", "$25–$50"]

            let eventTime = (tonightTimes + upcomingTimes).randomElement()!
            let isTonight = eventTime.hasPrefix("Tonight")

            return MapItem(
                id:          UUID(),
                name:        pool.randomElement()!,
                coordinate:  coord,
                category:    .event,
                vibe:        vibe,
                rating:      ratings.randomElement()!,
                isOpen:      true,
                closingTime: eventTime,
                reviewCount: reviewCounts.randomElement()!,
                eventTime:   eventTime,
                venue:       venues.randomElement()!,
                priceRange:  prices.randomElement()!,
                isTonight:   isTonight
            )
        }

        // Bar / Club / Liquor Store
        let barNames   = ["The Rusty Anchor", "Cellar No. 7", "The Copper Still", "Harbor Social"]
        let clubNames  = ["Neon Serenade", "Echo Lounge", "Apex Club", "Drift"]
        let storeNames = ["The Bottle Shop", "Reserve Liquors", "Corner Stock", "The Pour House"]

        let pool: [String] = {
            switch category {
            case .club:        return clubNames
            case .liquorStore: return storeNames
            case .event:       return []   // handled above
            case .bar:         return barNames
            }
        }()

        let closingTimes = ["12:00 AM", "1:00 AM", "2:00 AM", "3:00 AM"]

        return MapItem(
            id:          UUID(),
            name:        pool.randomElement()!,
            coordinate:  coord,
            category:    category,
            vibe:        vibe,
            rating:      ratings.randomElement()!,
            isOpen:      Bool.random(),
            closingTime: closingTimes.randomElement()!,
            reviewCount: reviewCounts.randomElement()!,
            eventTime:   nil,
            venue:       nil,
            priceRange:  nil,
            isTonight:   false
        )
    }

    /// Fresh random item with the same category/vibe — used for "Not Feeling It".
    func regenerated() -> MapItem {
        MapItem.mock(category: category, vibe: vibe)
    }
}
