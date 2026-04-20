//
//  MapItem.swift
//  PourDirection
//
//  Core venue model. Distance is never stored — always derived
//  from LocationManager at display time.
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - Place Category

enum PlaceCategory: String, CaseIterable, Codable {
    // Night categories
    case bar         = "Bar"
    case restaurant  = "Restaurant"
    case club        = "Club"
    case dispensary  = "Dispensary"
    case liquorStore = "Liquor Store"
    case casino      = "Casino"

    // Day categories
    case patio       = "Patio"
    case brunch      = "Brunch"
    case coffee      = "Coffee"
    case dayDrinks   = "Day Drinks"
    case parks       = "Parks"
    case dessert     = "Dessert"

    /// Google Places API `includedTypes` value for this category.
    var googleIncludedType: String {
        switch self {
        case .bar:         return "bar"
        case .restaurant:  return "restaurant"
        case .club:        return "night_club"
        case .dispensary:  return "dispensary"
        case .liquorStore: return "liquor_store"
        case .casino:      return "casino"
        case .patio:       return "patio"
        case .brunch:      return "brunch"
        case .coffee:      return "coffee"
        case .dayDrinks:   return "day_drinks"
        case .parks:       return "park"
        case .dessert:     return "dessert"
        }
    }

    /// Brand color for this category — single source of truth across the app.
    var color: Color {
        switch self {
        case .bar:         return AppColors.barTeal
        case .restaurant:  return AppColors.restaurantBlue
        case .club:        return AppColors.clubRed
        case .dispensary:  return AppColors.dispensaryGold
        case .liquorStore: return AppColors.liquorStoreAmber
        case .casino:      return AppColors.casinoGold
        case .patio:       return AppColors.primary
        case .brunch:      return AppColors.brunchOrange
        case .coffee:      return AppColors.coffeeBrown
        case .dayDrinks:   return AppColors.liquorStoreAmber
        case .parks:       return AppColors.parksGreen
        case .dessert:     return AppColors.dessertPink
        }
    }

    /// SF Symbol name for this category. Empty string = use CasinoIconView instead.
    var iconName: String {
        switch self {
        case .bar:         return "wineglass"
        case .restaurant:  return "fork.knife"
        case .club:        return "music.note"
        case .dispensary:  return "leaf"
        case .liquorStore: return "cart"
        case .casino:      return ""
        case .patio:       return ""
        case .brunch:      return "fork.knife.circle"
        case .coffee:      return "cup.and.saucer.fill"
        case .dayDrinks:   return "wineglass"
        case .parks:       return ""
        case .dessert:     return "birthday.cake"
        }
    }

    // MARK: - Category Grouping

    var isNightCategory: Bool {
        [.bar, .casino, .restaurant, .liquorStore, .club, .dispensary].contains(self)
    }

    var isDayCategory: Bool { !isNightCategory }

    static var nightCategories: [PlaceCategory] {
        [.bar, .casino, .restaurant, .liquorStore, .club, .dispensary]
    }

    static var dayCategories: [PlaceCategory] {
        [.patio, .brunch, .coffee, .dayDrinks, .parks, .dessert]
    }
}

// MARK: - MapItem

struct MapItem: Identifiable, Hashable {

    let id: String                      // Google place ID for API items; UUID string for mocks
    let name: String
    let coordinate: CLLocationCoordinate2D
    let category: PlaceCategory
    let vibe: String?                   // nil for API-sourced items
    let rating: Double?
    let isOpen: Bool?
    let closingTime: String?
    let reviewCount: Int?
    let photoURL: URL?                  // populated from Google Places photo API
    let weekdayDescriptions: [String]?  // from Google Places currentOpeningHours

    // MARK: - Hashable (CLLocationCoordinate2D is not Hashable)

    static func == (lhs: MapItem, rhs: MapItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // MARK: - Display Helpers

    var displayCategory: String { category.rawValue }

    /// Name shown in the UI. Returns a mock name when screenshot mode is active.
    var displayName: String {
        guard AdsManager.screenshotMode else { return name }
        return Place.mockName(forID: id, category: category)
    }

    /// Compute distance from a user location — never stored.
    func distance(from location: CLLocation?) -> CLLocationDistance? {
        guard let location else { return nil }
        let itemLocation = CLLocation(latitude: coordinate.latitude,
                                      longitude: coordinate.longitude)
        return location.distance(from: itemLocation)
    }

    /// Format a distance value for UI display.
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

    // MARK: - Opening Hours Helpers

    /// Today's hours extracted from weekdayDescriptions (e.g. "11:00 AM – 2:00 AM").
    var todayHours: String? {
        guard let descriptions = weekdayDescriptions, !descriptions.isEmpty else { return nil }
        let weekday = Calendar.current.component(.weekday, from: Date())
        let dayName = Calendar.current.weekdaySymbols[weekday - 1]
        guard let entry = descriptions.first(where: { $0.localizedCaseInsensitiveContains(dayName) }) else { return nil }
        if let range = entry.range(of: ": ") {
            let hours = String(entry[range.upperBound...])
            if hours.localizedCaseInsensitiveContains("closed") { return nil }
            return hours
        }
        return nil
    }

    /// Closing time for today (e.g. "2:00 AM"). Only meaningful when the place is open.
    var closesAt: String? {
        guard let hours = todayHours else { return nil }
        return Self.splitHoursRange(hours)?.close
    }

    /// Next opening time. Scans today then subsequent days.
    var opensAt: String? {
        guard let descriptions = weekdayDescriptions, !descriptions.isEmpty else { return nil }
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let symbols = calendar.weekdaySymbols
        for offset in 0..<7 {
            let dayIndex = (weekday - 1 + offset) % 7
            let dayName = symbols[dayIndex]
            guard let entry = descriptions.first(where: {
                $0.localizedCaseInsensitiveContains(dayName)
            }) else { continue }
            guard let colonRange = entry.range(of: ": ") else { continue }
            let hoursStr = String(entry[colonRange.upperBound...])
            if hoursStr.localizedCaseInsensitiveContains("closed") { continue }
            guard let times = Self.splitHoursRange(hoursStr) else { continue }
            if offset == 0 {
                return times.open
            } else {
                let shortDay = calendar.shortWeekdaySymbols[dayIndex]
                return "\(shortDay) \(times.open)"
            }
        }
        return nil
    }

    private static func splitHoursRange(_ hours: String) -> (open: String, close: String)? {
        let dashes: [Character] = ["\u{2013}", "\u{2014}", "-"]
        for dash in dashes {
            if let idx = hours.firstIndex(of: dash) {
                let openPart = String(hours[hours.startIndex..<idx])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let closePart = String(hours[hours.index(after: idx)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !openPart.isEmpty, !closePart.isEmpty {
                    return (openPart, closePart)
                }
            }
        }
        return nil
    }

    // MARK: - Mock Factory

    /// Random mock MapItem — used in Xcode previews.
    static func mock(category: PlaceCategory, vibe: String) -> MapItem {
        let ratings      = [3.8, 4.0, 4.1, 4.2, 4.3, 4.5, 4.7, 4.8]
        let reviewCounts = [5, 12, 28, 47, 89, 134, 203, 389]

        let baseLat = 49.2827
        let baseLng = -123.1207
        let coord = CLLocationCoordinate2D(
            latitude:  baseLat  + Double.random(in: -0.02...0.02),
            longitude: baseLng + Double.random(in: -0.02...0.02)
        )

        let barNames         = ["The Rusty Anchor", "Cellar No. 7", "The Copper Still", "Harbor Social"]
        let restaurantNames  = ["The Larder", "Olive & Salt", "East Side Kitchen", "The Table"]
        let clubNames        = ["Neon Serenade", "Echo Lounge", "Apex Club", "Drift"]
        let dispensaryNames  = ["Green Room", "The Vault", "Elevated", "Canopy"]
        let liquorStoreNames = ["BevMo!", "Total Wine", "The Liquor Barn", "Spirits & Co"]
        let casinoNames      = ["Royal Flush", "The Golden Chip", "Ace High", "Lucky Seven's"]
        let patioNames       = ["The Sun Deck", "Garden Social", "Terrace & Co", "Alfresco"]
        let brunchNames      = ["Sunny Side Up", "The Brunch Club", "Morning Glory", "Eggs & Co"]
        let coffeeNames      = ["Common Grounds", "The Daily Grind", "Brew & Co", "Roast Social"]
        let dayDrinksNames   = ["The Afternoon Bar", "Sundown Social", "Day Tripper", "The Patio Tap"]
        let parksNames       = ["Riverside Park", "The Commons", "Greenway Gardens", "City Park"]
        let dessertNames     = ["Sweet Surrender", "The Creamery", "Sugar & Spice", "Dessert Bar"]

        let pool: [String] = {
            switch category {
            case .bar:         return barNames
            case .restaurant:  return restaurantNames
            case .club:        return clubNames
            case .dispensary:  return dispensaryNames
            case .liquorStore: return liquorStoreNames
            case .casino:      return casinoNames
            case .patio:       return patioNames
            case .brunch:      return brunchNames
            case .coffee:      return coffeeNames
            case .dayDrinks:   return dayDrinksNames
            case .parks:       return parksNames
            case .dessert:     return dessertNames
            }
        }()

        let closingTimes = ["12:00 AM", "1:00 AM", "2:00 AM", "3:00 AM"]

        return MapItem(
            id:          UUID().uuidString,
            name:        pool.randomElement()!,
            coordinate:  coord,
            category:    category,
            vibe:        vibe,
            rating:      ratings.randomElement()!,
            isOpen:      Bool.random(),
            closingTime: closingTimes.randomElement()!,
            reviewCount: reviewCounts.randomElement()!,
            photoURL:    nil,
            weekdayDescriptions: nil
        )
    }

    /// Fresh random item with the same category/vibe — used for "Not Feeling It".
    func regenerated() -> MapItem {
        MapItem.mock(category: category, vibe: vibe ?? "Chill")
    }
}

// MARK: - API Initializer
// In an extension so the compiler-synthesised memberwise init is preserved.

extension MapItem {
    /// Create a MapItem directly from a Google Places API result.
    init(from place: Place, category: PlaceCategory) {
        self.id                  = place.id
        self.name                = place.name
        self.coordinate          = place.coordinate
        self.category            = category
        self.vibe                = nil
        self.rating              = place.rating
        self.isOpen              = place.isOpenNow
        self.closingTime         = nil
        self.reviewCount         = nil
        self.photoURL            = place.photoURL
        self.weekdayDescriptions = place.weekdayDescriptions
    }
}
