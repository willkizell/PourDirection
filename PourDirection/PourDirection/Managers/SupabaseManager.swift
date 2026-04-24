//
//  SupabaseManager.swift
//  PourDirection
//
//  Singleton wrapper around the Supabase Swift client.
//  Responsibilities:
//    - Initialize the SupabaseClient once using Config constants
//    - Expose a generic invokeFunction() for calling Edge Functions
//    - Provide typed fetch methods for each deployed Edge Function
//

import Foundation
import Supabase

// MARK: - Places Cache

/// Thread-safe two-tier cache for nearby places results:
///  - In-memory layer for instant hits within a session
///  - Disk layer (JSON file) for persistence across app launches
///
/// Keys are rounded to a ~1 km grid so nearby movement reuses results.
/// Entries expire after `ttl` seconds (24 hours). Stale entries are
/// purged lazily on read.
private actor PlacesCache {

    private struct Entry: Codable {
        let places: [Place]
        let expiry: Date
    }

    private var store: [String: Entry] = [:]
    private let ttl: TimeInterval = 60 * 60 * 24   // 24 hours

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("pourdirection-places-cache.json")
    }()

    private var didLoadFromDisk = false

    // MARK: - Read

    func get(key: String) -> [Place]? {
        loadFromDiskIfNeeded()
        guard let entry = store[key], Date() < entry.expiry else {
            if store[key] != nil {
                store.removeValue(forKey: key)
                persistToDisk()
            }
            return nil
        }
        return entry.places
    }

    // MARK: - Write

    func set(key: String, places: [Place]) {
        loadFromDiskIfNeeded()
        store[key] = Entry(places: places, expiry: Date().addingTimeInterval(ttl))
        persistToDisk()
    }

    // MARK: - Disk

    private func loadFromDiskIfNeeded() {
        guard !didLoadFromDisk else { return }
        didLoadFromDisk = true

        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data)
        else { return }

        let now = Date()
        store = decoded.filter { $0.value.expiry > now }
    }

    private func persistToDisk() {
        guard let data = try? JSONEncoder().encode(store) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - SupabaseManager

final class SupabaseManager {

    // MARK: Singleton

    static let shared = SupabaseManager()

    // MARK: Cache

    private let placesCache = PlacesCache()

    // MARK: Client

    let client: SupabaseClient

    private init() {
        guard let url = URL(string: Config.supabaseURL) else {
            fatalError("SupabaseManager: invalid supabaseURL in Config.swift – check your project URL.")
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: Config.supabaseAnonKey
        )
    }

    // MARK: - Generic Edge Function Invocation

    func invokeFunction<T: Decodable>(
        name: String,
        body: some Encodable
    ) async throws -> T {
        // Let the Supabase SDK decode the response directly into T.
        // Decoding through Data first fails because Data expects a base64 string
        // in JSON, but Edge Functions return JSON objects.
        do {
            return try await client.functions.invoke(
                name,
                options: FunctionInvokeOptions(body: body)
            )
        } catch let error as DecodingError {
            throw SupabaseManagerError.decodingFailed(
                function: name,
                underlying: error,
                rawResponse: nil
            )
        }
    }

    // MARK: - Nearby Places

    private struct NearbyPlacesPayload: Encodable {
        let lat: Double
        let lng: Double
        let type: String
        let radius: Double?
        let openNow: Bool?
    }

    /// Fetches nearby places from the "nearby-places" Edge Function.
    /// `type` maps to Google Places API `includedTypes` (e.g. "bar", "restaurant").
    /// `radius` overrides the server-side default search radius (meters).
    /// `openNow` filters to currently-open places only (used by SuggestionView).
    /// Returns decoded `Place` values ready for display.
    /// Results are cached for 5 minutes keyed by type + ~1 km location grid + radius + openNow.
    func fetchNearbyPlaces(lat: Double, lng: Double, type: String = "bar", radius: Double? = nil, openNow: Bool = false) async throws -> [Place] {
        // Round to 2 decimal places (~1.1 km grid) for cache key
        let key = "\(type)-\(String(format: "%.2f", lat))-\(String(format: "%.2f", lng))-\(Int(radius ?? 0))-\(openNow)"

        if let cached = await placesCache.get(key: key) {
            return cached
        }

        let response: NearbyPlacesResponse = try await invokeFunction(
            name: Config.nearbyPlacesFunction,
            body: NearbyPlacesPayload(lat: lat, lng: lng, type: type, radius: radius, openNow: openNow ? true : nil)
        )
        let places = response.places.map { Place(from: $0) }
        if let first = places.first {
            print("[NearbyPlaces] \(type) — \(first.name) — isOpenNow: \(String(describing: first.isOpenNow)) — todayHours: \(String(describing: first.todayHours)) — weekdayDesc count: \(first.weekdayDescriptions?.count ?? 0)")
        }

        await placesCache.set(key: key, places: places)
        return places
    }

    // MARK: - Connection Test

    func testConnection() async {
        struct HealthPayload: Encodable { let ping = "test" }
        struct HealthResponse: Decodable { let status: String }

        do {
            let response: HealthResponse = try await invokeFunction(
                name: "health-check",
                body: HealthPayload()
            )
            print("[SupabaseManager] ✅ health-check OK — status: \(response.status)")
        } catch {
            print("[SupabaseManager] ⚠️  health-check error (expected — function not deployed yet): \(error)")
        }
    }
}

// MARK: - Errors

enum SupabaseManagerError: LocalizedError {
    case decodingFailed(function: String, underlying: Error, rawResponse: String?)

    var errorDescription: String? {
        switch self {
        case let .decodingFailed(function, underlying, raw):
            let preview = raw.map { "Raw response: \($0)" } ?? "No response body"
            return "SupabaseManager: failed to decode response from '\(function)'. \(underlying.localizedDescription). \(preview)"
        }
    }
}
