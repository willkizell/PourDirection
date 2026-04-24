//
//  HomeLocationManager.swift
//  PourDirection
//
//  @Observable singleton — persists the user's home location in UserDefaults.
//  Provides homePlace for compass navigation and distance calculations.
//  Setting shouldPresentSetupSheet = true triggers ProfileView to open the sheet.
//

import Foundation
import CoreLocation
import Observation

@Observable
final class HomeLocationManager {

    static let shared = HomeLocationManager()

    // MARK: - State

    private(set) var latitude:         Double?
    private(set) var longitude:        Double?
    private(set) var formattedAddress: String?

    /// Set to true from SavedView to signal ProfileView to open the home setup sheet.
    var shouldPresentSetupSheet: Bool = false

    var isSet: Bool { latitude != nil && longitude != nil }

    /// A `Place` for home — pass to CompassActiveView for navigation.
    var homePlace: Place? {
        guard let lat = latitude, let lng = longitude else { return nil }
        return Place(
            id:               "com.pourdirection.home",
            name:             "Home",
            formattedAddress: formattedAddress,
            coordinate:       CLLocationCoordinate2D(latitude: lat, longitude: lng),
            rating:           nil
        )
    }

    // MARK: - UserDefaults Keys

    private let keyLat     = "com.pourdirection.homeLat"
    private let keyLng     = "com.pourdirection.homeLng"
    private let keyAddress = "com.pourdirection.homeAddress"

    private init() { load() }

    // MARK: - Public API

    func set(latitude: Double, longitude: Double, address: String?) {
        self.latitude         = latitude
        self.longitude        = longitude
        self.formattedAddress = address
        persist()
        NotificationManager.shared.refreshHomeContextNotifications(currentLocation: nil)
    }

    func clear() {
        latitude         = nil
        longitude        = nil
        formattedAddress = nil
        UserDefaults.standard.removeObject(forKey: keyLat)
        UserDefaults.standard.removeObject(forKey: keyLng)
        UserDefaults.standard.removeObject(forKey: keyAddress)
        NotificationManager.shared.refreshHomeContextNotifications(currentLocation: nil)
    }

    /// Distance from home to a given location, or nil if home isn't set or location is unavailable.
    func distance(from location: CLLocation?) -> CLLocationDistance? {
        guard let lat = latitude, let lng = longitude, let location else { return nil }
        return location.distance(from: CLLocation(latitude: lat, longitude: lng))
    }

    // MARK: - Persistence

    private func persist() {
        if let lat = latitude  { UserDefaults.standard.set(lat, forKey: keyLat) }
        if let lng = longitude { UserDefaults.standard.set(lng, forKey: keyLng) }
        UserDefaults.standard.set(formattedAddress, forKey: keyAddress)
    }

    private func load() {
        latitude         = UserDefaults.standard.object(forKey: keyLat) as? Double
        longitude        = UserDefaults.standard.object(forKey: keyLng) as? Double
        formattedAddress = UserDefaults.standard.string(forKey: keyAddress)
    }
}
