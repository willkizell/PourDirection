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
    let id:               String
    let displayName:      PlaceDisplayName
    let formattedAddress: String?
    let location:         PlaceLocation
    let rating:           Double?
    let photoUri:         String?
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
    let id:               String
    let name:             String
    let formattedAddress: String?
    let coordinate:       CLLocationCoordinate2D
    let rating:           Double?
    let photoURL:         URL?

    /// Decode from API result.
    init(from result: NearbyPlaceResult) {
        id               = result.id
        name             = result.displayName.text
        formattedAddress = result.formattedAddress
        coordinate       = CLLocationCoordinate2D(
            latitude:  result.location.latitude,
            longitude: result.location.longitude
        )
        rating   = result.rating
        photoURL = result.photoUri.flatMap { URL(string: $0) }
    }

    /// Direct memberwise init — use when constructing a `Place` outside of an API response
    /// (e.g. bridging from a `MapItem` map pin).
    init(id: String, name: String, formattedAddress: String?,
         coordinate: CLLocationCoordinate2D, rating: Double?, photoURL: URL? = nil) {
        self.id               = id
        self.name             = name
        self.formattedAddress = formattedAddress
        self.coordinate       = coordinate
        self.rating           = rating
        self.photoURL         = photoURL
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

    /// Locale-aware distance string. Returns "Nearby" when distance is unavailable or < 0.1 mi.
    static func formatDistance(_ meters: CLLocationDistance?) -> String {
        guard let meters else { return "Nearby" }
        let miles = meters / 1609.34
        if miles < 0.1 { return "Nearby" }
        return String(format: "%.1f mi", miles)
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
