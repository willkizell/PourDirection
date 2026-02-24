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

// MARK: - SupabaseManager

final class SupabaseManager {

    // MARK: Singleton

    static let shared = SupabaseManager()

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
    }

    /// Fetches nearby places from the "nearby-places" Edge Function.
    /// `type` maps to Google Places API `includedTypes` (e.g. "bar", "restaurant").
    /// Returns decoded `Place` values ready for display.
    func fetchNearbyPlaces(lat: Double, lng: Double, type: String = "bar") async throws -> [Place] {
        let response: NearbyPlacesResponse = try await invokeFunction(
            name: "nearby-places",
            body: NearbyPlacesPayload(lat: lat, lng: lng, type: type)
        )
        let places = response.places.map { Place(from: $0) }
        if let first = places.first {
            print("[NearbyPlaces] \(type) — \(first.name) — isOpenNow: \(String(describing: first.isOpenNow)) — todayHours: \(String(describing: first.todayHours)) — weekdayDesc count: \(first.weekdayDescriptions?.count ?? 0)")
        }
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
