//
//  SavedPlacesManager.swift
//  PourDirection
//
//  @Observable singleton — persists saved places to UserDefaults via JSON.
//  Access anywhere with SavedPlacesManager.shared.
//  No backend, no auth, no Supabase.
//

import Foundation
import CoreLocation
import Observation

@Observable
final class SavedPlacesManager {

    static let shared = SavedPlacesManager()

    private(set) var savedPlaces: [SavedPlace] = []

    private let storageKey = "com.pourdirection.savedPlaces"

    private init() {
        load()
    }

    // MARK: - Query

    func isSaved(_ place: Place) -> Bool {
        savedPlaces.contains { $0.id == place.id }
    }

    // MARK: - Mutations

    /// Set to true by `toggleSave`/`add` when a save was blocked by the free-tier cap.
    /// Views observe this to present the paywall.
    var hitSaveLimit: Bool = false

    /// Toggle save state. Returns true if the place was newly saved; false if it was
    /// removed, already saved, or blocked by the free-tier limit.
    @MainActor @discardableResult
    func toggleSave(_ place: Place, category: PlaceCategory) -> Bool {
        if isSaved(place) {
            remove(place)
            return false
        }
        return add(place, category: category)
    }

    @MainActor @discardableResult
    func add(_ place: Place, category: PlaceCategory) -> Bool {
        guard !isSaved(place) else { return false }   // no duplicates
        guard PremiumGates.canSaveMore(currentCount: savedPlaces.count) else {
            hitSaveLimit = true
            return false
        }
        let saved = SavedPlace(
            id:               place.id,
            name:             place.name,
            latitude:         place.coordinate.latitude,
            longitude:        place.coordinate.longitude,
            categoryRaw:      category.rawValue,
            photoURLString:   place.photoURL?.absoluteString,
            formattedAddress: place.formattedAddress,
            rating:           place.rating
        )
        savedPlaces.append(saved)
        persist()
        return true
    }

    func remove(_ place: Place) {
        savedPlaces.removeAll { $0.id == place.id }
        persist()
    }

    func removeSaved(_ saved: SavedPlace) {
        savedPlaces.removeAll { $0.id == saved.id }
        persist()
    }

    // MARK: - Nearby Filter

    /// Returns saved places within `radiusMeters` of `location`.
    /// Used by SavedView's "Nearby" segment.
    func nearbyPlaces(from location: CLLocation?, radiusMeters: Double = 5000) -> [SavedPlace] {
        guard let location else { return [] }
        return savedPlaces.filter {
            let loc = CLLocation(latitude: $0.latitude, longitude: $0.longitude)
            return location.distance(from: loc) <= radiusMeters
        }
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(savedPlaces) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data    = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([SavedPlace].self, from: data)
        else { return }
        savedPlaces = decoded
    }
}
