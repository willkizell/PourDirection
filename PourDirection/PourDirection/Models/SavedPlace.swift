//
//  SavedPlace.swift
//  PourDirection
//
//  Minimal Codable snapshot of a Place saved by the user.
//  Stored via SavedPlacesManager (UserDefaults + JSONEncoder).
//  CLLocationCoordinate2D is non-Codable, so lat/lng are stored separately.
//

import Foundation
import CoreLocation

struct SavedPlace: Identifiable, Codable, Equatable {
    let id:               String
    let name:             String
    let latitude:         Double
    let longitude:        Double
    let categoryRaw:      String
    let photoURLString:   String?
    let formattedAddress: String?
    let rating:           Double?

    // MARK: - Helpers

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var category: PlaceCategory? {
        PlaceCategory(rawValue: categoryRaw)
    }

    func distance(from location: CLLocation?) -> CLLocationDistance? {
        guard let location else { return nil }
        return location.distance(from: CLLocation(latitude: latitude, longitude: longitude))
    }

    /// Reconstruct a Place for compass navigation.
    func toPlace() -> Place {
        Place(
            id:               id,
            name:             name,
            formattedAddress: formattedAddress,
            coordinate:       coordinate,
            rating:           rating,
            photoURL:         photoURLString.flatMap { URL(string: $0) }
        )
    }
}
