//
//  NearbyPlace.swift
//  PourDirection
//
//  Codable models for the Google Places API v1 response
//  as proxied through the "nearby-places" Supabase Edge Function.
//

import Foundation
import CoreLocation

// MARK: - Top-Level Response

struct NearbyPlacesResponse: Decodable {
    let places: [NearbyPlaceResult]
}

// MARK: - Individual Place Result

struct NearbyPlaceResult: Decodable {
    let id:                  String
    let displayName:         PlaceDisplayName
    let formattedAddress:    String?
    let location:            PlaceLocation
    let rating:              Double?
    let photoUri:            String?
    let types:               [String]?
    let userRatingCount:     Int?
    let isOpenNow:           Bool?
    let weekdayDescriptions: [String]?
}

struct PlaceDisplayName: Decodable {
    let text: String
}

struct PlaceLocation: Decodable {
    let latitude:  Double
    let longitude: Double
}

// MARK: - Map-Ready Place

/// Flat, map-friendly struct derived from a `NearbyPlaceResult`.
/// `Identifiable` by Google's place `id`.
struct Place: Identifiable, Hashable {
    static func == (lhs: Place, rhs: Place) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id:                  String
    let name:                String
    let formattedAddress:    String?
    let coordinate:          CLLocationCoordinate2D
    let rating:              Double?
    let photoURL:            URL?
    let types:               [String]
    let userRatingCount:     Int?
    let isOpenNow:           Bool?
    let weekdayDescriptions: [String]?

    /// Decode from API result.
    init(from result: NearbyPlaceResult) {
        id                  = result.id
        name                = result.displayName.text
        formattedAddress    = result.formattedAddress
        coordinate          = CLLocationCoordinate2D(
            latitude:  result.location.latitude,
            longitude: result.location.longitude
        )
        rating              = result.rating
        photoURL            = result.photoUri.flatMap { URL(string: $0) }
        types               = result.types ?? []
        userRatingCount     = result.userRatingCount
        isOpenNow           = result.isOpenNow
        weekdayDescriptions = result.weekdayDescriptions
    }

    /// Direct memberwise init — use when constructing a `Place` outside of an API response
    /// (e.g. bridging from a `MapItem` map pin).
    init(id: String, name: String, formattedAddress: String?,
         coordinate: CLLocationCoordinate2D, rating: Double?, photoURL: URL? = nil,
         types: [String] = [], userRatingCount: Int? = nil, isOpenNow: Bool? = nil,
         weekdayDescriptions: [String]? = nil) {
        self.id                  = id
        self.name                = name
        self.formattedAddress    = formattedAddress
        self.coordinate          = coordinate
        self.rating              = rating
        self.photoURL            = photoURL
        self.types               = types
        self.userRatingCount     = userRatingCount
        self.isOpenNow           = isOpenNow
        self.weekdayDescriptions = weekdayDescriptions
    }

    // MARK: - Opening Hours Helpers

    /// Today's hours extracted from weekdayDescriptions (e.g. "11:00 AM – 2:00 AM").
    /// Returns nil if no hours data is available or if the place is closed all day.
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
    /// Returns e.g. "11:00 AM" (today) or "Mon 11:00 AM" (future day).
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

    /// Split "11:00 AM – 2:00 AM" into (open, close) components.
    /// Handles en-dash (U+2013), em-dash (U+2014), and hyphen regardless of surrounding whitespace.
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

    // MARK: - Navigation Helpers

    /// Distance from a `CLLocation` to this place's coordinate.
    func distance(from location: CLLocation?) -> CLLocationDistance? {
        guard let location else { return nil }
        return location.distance(from: CLLocation(
            latitude:  coordinate.latitude,
            longitude: coordinate.longitude
        ))
    }

    /// Locale-aware distance string. Returns "Nearby" when distance is unavailable or < 100 m.
    /// Automatically uses km (metric locales) or mi (imperial locales) based on device region.
    static func formatDistance(_ meters: CLLocationDistance?) -> String {
        guard let meters, meters >= 100 else { return "Nearby" }
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        formatter.unitStyle = .short
        return formatter.string(from: measurement)
    }

    /// True bearing (degrees clockwise from north) from `from` to `to`.
    static func bearing(from: CLLocationCoordinate2D,
                        to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude  * .pi / 180
        let lat2 = to.latitude    * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}
