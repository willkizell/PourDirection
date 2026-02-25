//
//  DistancePreferences.swift
//  PourDirection
//
//  Stores user-preferred walking distance and search area thresholds.
//  Persisted via UserDefaults. Walking max == search area min (no overlap).
//
//  Conversion rates:
//    Walking: 1 min ≈ 84 m
//    Driving: 1 min ≈ 667 m (~40 km/h city average)
//

import Foundation
import Observation

@Observable
final class DistancePreferences {

    static let shared = DistancePreferences()

    // MARK: - Constants

    static let metersPerWalkingMinute: Double = 84
    static let metersPerDrivingMinute: Double = 667

    // Slider bounds
    static let walkingMinMeters: Double     = 420    // 5 min
    static let walkingMaxMeters: Double     = 3780   // 45 min
    static let searchAreaMaxMeters: Double  = 50_000 // 50 km

    // Defaults
    static let defaultWalkingMeters: Double     = 2520   // 30 min
    static let defaultSearchAreaMeters: Double  = 10_000 // 10 km

    // MARK: - Stored Values

    var walkingDistanceMeters: Double {
        didSet { UserDefaults.standard.set(walkingDistanceMeters, forKey: walkingKey) }
    }

    var searchAreaMeters: Double {
        didSet { UserDefaults.standard.set(searchAreaMeters, forKey: searchAreaKey) }
    }

    // MARK: - Keys

    private let walkingKey    = "com.pourdirection.walkingDistanceMeters"
    private let searchAreaKey = "com.pourdirection.drivingDistanceMeters" // kept for migration

    // MARK: - Init

    private init() {
        let w = UserDefaults.standard.double(forKey: walkingKey)
        walkingDistanceMeters = w > 0 ? w : Self.defaultWalkingMeters
        let s = UserDefaults.standard.double(forKey: searchAreaKey)
        searchAreaMeters = s > 0 ? s : Self.defaultSearchAreaMeters
    }

    // MARK: - Computed Helpers

    var walkingMinutes: Int {
        max(1, Int(round(walkingDistanceMeters / Self.metersPerWalkingMinute)))
    }

    /// Approximate driving minutes for the search area radius.
    var searchAreaDrivingMinutes: Int {
        max(1, Int(round(searchAreaMeters / Self.metersPerDrivingMinute)))
    }

    /// Search area min is always pegged to walking max (no overlap).
    var searchAreaMinMeters: Double { walkingDistanceMeters }

    /// True if the locale uses miles (US).
    static var usesMiles: Bool {
        Locale.current.measurementSystem == .us
    }

    // MARK: - Formatting

    static func formatMetersAsDistance(_ meters: Double) -> String {
        if usesMiles {
            let miles = meters / 1609.34
            return miles < 0.1 ? "<0.1 mi" : String(format: "%.1f mi", miles)
        } else {
            let km = meters / 1000
            return km < 0.1 ? "<0.1 km" : String(format: "%.1f km", km)
        }
    }

    static func walkingMinutesFromMeters(_ meters: Double) -> Int {
        max(1, Int(round(meters / metersPerWalkingMinute)))
    }

    // MARK: - Reset

    func resetToDefaults() {
        walkingDistanceMeters = Self.defaultWalkingMeters
        searchAreaMeters = Self.defaultSearchAreaMeters
    }

    /// True if either value differs from default.
    var isModified: Bool {
        walkingDistanceMeters != Self.defaultWalkingMeters ||
        searchAreaMeters != Self.defaultSearchAreaMeters
    }
}
