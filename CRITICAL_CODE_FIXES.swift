// CRITICAL CODE FIXES FOR POURDIRECTION SECURITY AUDIT
// Apply these changes immediately before App Store submission

// ============================================================================
// FIX #1: REMOVE HARDCODED SUPABASE API KEY
// ============================================================================
// FILE: Config.swift
// SEVERITY: CRITICAL

// BEFORE (INSECURE):
/*
enum Config {
    static let supabaseURL     = "https://gynwejdfjpetzupyvsrr.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5bndlamRmanBldHp1cHl2c3JyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3Mjc1MzEsImV4cCI6MjA4NzMwMzUzMX0.yyVl-YtE9ez1S31F7MLHUzIZ4ak6RIF5WODPsoHt3Qk"
}
*/

// AFTER (SECURE):
enum Config {
    static let supabaseURL: String = {
        // Priority: Environment variable > Xcode build setting > default
        if let url = ProcessInfo.processInfo.environment["SUPABASE_URL"], !url.isEmpty {
            return url
        }
        // For local development, use placeholder
        return "https://placeholder.supabase.co"
    }()

    static let supabaseAnonKey: String = {
        if let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"], !key.isEmpty {
            return key
        }
        return "placeholder_key"
    }()
}

// Add to .gitignore:
// Config.swift
// config.xcconfig
// .env
// .env.local
// secrets.*


// ============================================================================
// FIX #2: REMOVE GOOGLE ADMOB TEST DEVICE ID
// ============================================================================
// FILE: PourDirectionApp.swift (lines 73-76)
// SEVERITY: CRITICAL

// BEFORE (INSECURE):
/*
MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
    "1b3dc40f450db15529430fa5a35ef648"
]
*/

// AFTER (SECURE):
// Option A: Remove entirely (recommended for production)
// Option B: Gate behind DEBUG configuration

#if DEBUG
// Only set test device identifiers in DEBUG builds
MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
    "1b3dc40f450db15529430fa5a35ef648"
]
#else
// Production builds: empty or not set
#endif


// ============================================================================
// FIX #3: REMOVE MOCK USER DATA
// ============================================================================
// FILE: EditProfileView.swift (lines 13-17)
// SEVERITY: CRITICAL

// BEFORE (INSECURE):
/*
@State private var fullName: String     = "William Kizell"
@State private var gender: String       = "Male"
@State private var birthday: String     = "09-22-2003"
@State private var email: String        = "wkizell@gmail.com"
*/

// AFTER (SECURE):
@State private var fullName: String     = ""
@State private var gender: String       = ""
@State private var birthday: String     = ""
@State private var email: String        = ""


// ============================================================================
// FIX #4: KEYCHAIN HELPER FOR SENSITIVE DATA
// ============================================================================
// FILE: Managers/KeychainHelper.swift (NEW FILE)
// SEVERITY: CRITICAL - Required for all remaining fixes
// Add this file to your project

import Foundation
import Security

enum KeychainError: Error {
    case failedToStore
    case failedToRetrieve
    case failedToDelete
    case notFound
}

final class KeychainHelper {
    static let shared = KeychainHelper()

    private let queue = DispatchQueue(label: "com.pourdirection.keychain", attributes: .concurrent)

    // MARK: - Store

    func save(_ data: Data, for key: String) throws {
        try queue.sync {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            ]

            // Delete existing entry first
            SecItemDelete(query as CFDictionary)

            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw KeychainError.failedToStore
            }
        }
    }

    func save(string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.failedToStore
        }
        try save(data, for: key)
    }

    func save(double: Double, for key: String) throws {
        var value = double
        let data = withUnsafeBytes(of: &value) { Data($0) }
        try save(data, for: key)
    }

    // MARK: - Retrieve

    func retrieve(for key: String) -> Data? {
        var result: AnyObject?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess ? (result as? Data) : nil
    }

    func retrieveString(for key: String) -> String? {
        guard let data = retrieve(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func retrieveDouble(for key: String) -> Double? {
        guard let data = retrieve(for: key), data.count == MemoryLayout<Double>.size else {
            return nil
        }
        return data.withUnsafeBytes { $0.load(as: Double.self) }
    }

    // MARK: - Delete

    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.failedToDelete
        }
    }

    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.failedToDelete
        }
    }
}


// ============================================================================
// FIX #5: MIGRATE HOME LOCATION TO KEYCHAIN
// ============================================================================
// FILE: Managers/HomeLocationManager.swift
// SEVERITY: CRITICAL
// Replace persist() and load() methods

import Foundation
import CoreLocation
import Observation

@Observable
final class HomeLocationManager {

    static let shared = HomeLocationManager()

    private(set) var latitude: Double?
    private(set) var longitude: Double?
    private(set) var formattedAddress: String?

    var shouldPresentSetupSheet: Bool = false
    var isSet: Bool { latitude != nil && longitude != nil }

    var homePlace: Place? {
        guard let lat = latitude, let lng = longitude else { return nil }
        return Place(
            id: "com.pourdirection.home",
            name: "Home",
            formattedAddress: formattedAddress,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            rating: nil
        )
    }

    private let keyLat = "com.pourdirection.homeLat"
    private let keyLng = "com.pourdirection.homeLng"
    private let keyAddress = "com.pourdirection.homeAddress"

    private init() {
        load()
    }

    func set(latitude: Double, longitude: Double, address: String?) {
        self.latitude = latitude
        self.longitude = longitude
        self.formattedAddress = address
        persist()
    }

    func clear() {
        latitude = nil
        longitude = nil
        formattedAddress = nil
        try? KeychainHelper.shared.delete(for: keyLat)
        try? KeychainHelper.shared.delete(for: keyLng)
        try? KeychainHelper.shared.delete(for: keyAddress)
    }

    func distance(from location: CLLocation?) -> CLLocationDistance? {
        guard let lat = latitude, let lng = longitude, let location else { return nil }
        return location.distance(from: CLLocation(latitude: lat, longitude: lng))
    }

    // MARK: - Persistence (UPDATED TO USE KEYCHAIN)

    private func persist() {
        do {
            if let lat = latitude {
                try KeychainHelper.shared.save(double: lat, for: keyLat)
            }
            if let lng = longitude {
                try KeychainHelper.shared.save(double: lng, for: keyLng)
            }
            if let address = formattedAddress {
                try KeychainHelper.shared.save(string: address, for: keyAddress)
            }
        } catch {
            print("[HomeLocationManager] Failed to persist to Keychain: \(error)")
        }
    }

    private func load() {
        latitude = KeychainHelper.shared.retrieveDouble(for: keyLat)
        longitude = KeychainHelper.shared.retrieveDouble(for: keyLng)
        formattedAddress = KeychainHelper.shared.retrieveString(for: keyAddress)
    }
}


// ============================================================================
// FIX #6: MIGRATE SAVED PLACES TO KEYCHAIN
// ============================================================================
// FILE: Managers/SavedPlacesManager.swift
// SEVERITY: CRITICAL
// Replace persist() and load() methods

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

    func isSaved(_ place: Place) -> Bool {
        savedPlaces.contains { $0.id == place.id }
    }

    func toggleSave(_ place: Place, category: PlaceCategory) {
        if isSaved(place) {
            remove(place)
        } else {
            add(place, category: category)
        }
    }

    func add(_ place: Place, category: PlaceCategory) {
        guard !isSaved(place) else { return }
        let saved = SavedPlace(
            id: place.id,
            name: place.name,
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude,
            categoryRaw: category.rawValue,
            photoURLString: place.photoURL?.absoluteString,
            formattedAddress: place.formattedAddress,
            rating: place.rating
        )
        savedPlaces.append(saved)
        persist()
    }

    func remove(_ place: Place) {
        savedPlaces.removeAll { $0.id == place.id }
        persist()
    }

    func removeSaved(_ saved: SavedPlace) {
        savedPlaces.removeAll { $0.id == saved.id }
        persist()
    }

    func nearbyPlaces(from location: CLLocation?, radiusMeters: Double = 5000) -> [SavedPlace] {
        guard let location else { return [] }
        return savedPlaces.filter {
            let loc = CLLocation(latitude: $0.latitude, longitude: $0.longitude)
            return location.distance(from: loc) <= radiusMeters
        }
    }

    // MARK: - Persistence (UPDATED TO USE KEYCHAIN)

    private func persist() {
        do {
            let data = try JSONEncoder().encode(savedPlaces)
            try KeychainHelper.shared.save(data, for: storageKey)
        } catch {
            print("[SavedPlacesManager] Failed to persist to Keychain: \(error)")
        }
    }

    private func load() {
        guard let data = KeychainHelper.shared.retrieve(for: storageKey) else { return }
        do {
            savedPlaces = try JSONDecoder().decode([SavedPlace].self, from: data)
        } catch {
            print("[SavedPlacesManager] Failed to decode from Keychain: \(error)")
        }
    }
}


// ============================================================================
// FIX #7: FIX AGE VERIFICATION (INTERIM - Use Keychain)
// ============================================================================
// FILE: Managers/AgeVerificationManager.swift (NEW FILE)
// SEVERITY: CRITICAL
// This is an interim fix until server-side age verification is implemented

import Foundation

final class AgeVerificationManager {
    static let shared = AgeVerificationManager()

    private let keyAgeVerified = "com.pourdirection.ageVerified"

    var ageVerified: Bool {
        get {
            guard let data = KeychainHelper.shared.retrieve(for: keyAgeVerified) else { return false }
            return data.first == 1
        }
        set {
            let data = Data([newValue ? 1 : 0])
            try? KeychainHelper.shared.save(data, for: keyAgeVerified)
        }
    }

    func clearVerification() {
        try? KeychainHelper.shared.delete(for: keyAgeVerified)
    }
}

// Update AgeGateView.swift to use:
/*
@State private var ageManager = AgeVerificationManager.shared

// In questionView button:
Button(action: {
    ageManager.ageVerified = true
}) {
    Text("Yes, I'm \(requiredAge)+")
}
*/


// ============================================================================
// FIX #8: VALIDATE INPUT COORDINATES
// ============================================================================
// FILE: Managers/SupabaseManager.swift
// SEVERITY: HIGH
// Add this validation function and call it in fetchNearbyPlaces()

import Foundation

enum LocationValidationError: Error {
    case invalidLatitude
    case invalidLongitude
    case invalidType
    case invalidRadius
}

extension SupabaseManager {

    private func validateCoordinates(lat: Double, lng: Double) throws {
        guard !lat.isNaN && !lat.isInfinite && (-90...90).contains(lat) else {
            throw LocationValidationError.invalidLatitude
        }
        guard !lng.isNaN && !lng.isInfinite && (-180...180).contains(lng) else {
            throw LocationValidationError.invalidLongitude
        }
    }

    private func validateType(_ type: String) throws {
        let validTypes = Set(["bar", "restaurant", "night_club", "dispensary", "liquor_store"])
        guard validTypes.contains(type) else {
            throw LocationValidationError.invalidType
        }
    }

    private func validateRadius(_ radius: Double?) throws {
        guard let radius = radius else { return }
        guard !radius.isNaN && !radius.isInfinite && (100...50000).contains(radius) else {
            throw LocationValidationError.invalidRadius
        }
    }

    // Update fetchNearbyPlaces to validate inputs:
    /*
    func fetchNearbyPlaces(lat: Double, lng: Double, type: String = "bar", radius: Double? = nil) async throws -> [Place] {
        // Add validation
        try validateCoordinates(lat: lat, lng: lng)
        try validateType(type)
        try validateRadius(radius)

        // ... rest of function
    }
    */
}


// ============================================================================
// FIX #9: SANITIZE ERROR MESSAGES
// ============================================================================
// FILE: Managers/SupabaseManager.swift
// SEVERITY: MEDIUM
// Update error descriptions to not expose implementation details

enum SupabaseManagerError: LocalizedError {
    case decodingFailed(function: String, underlying: Error, rawResponse: String?)

    var errorDescription: String? {
        switch self {
        case .decodingFailed(let function, let underlying, _):
            // Don't expose raw API response to user
            // Log detailed error server-side instead
            return "Unable to load venues. Please try again."
        }
    }

    // For server-side logging (not shown to user):
    var detailedDescription: String? {
        switch self {
        case let .decodingFailed(function, underlying, raw):
            let preview = raw.map { "Raw: \($0.prefix(100))" } ?? "No response"
            return "Decode error in \(function): \(underlying) - \(preview)"
        }
    }
}


// ============================================================================
// FIX #10: REMOVE DEBUG LOGGING
// ============================================================================
// FILE: Managers/SupabaseManager.swift (Line 121)
// SEVERITY: MEDIUM

// BEFORE (INSECURE):
/*
if let first = places.first {
    print("[NearbyPlaces] \(type) — \(first.name) — isOpenNow: \(String(describing: first.isOpenNow)) — todayHours: \(String(describing: first.todayHours)) — weekdayDesc count: \(first.weekdayDescriptions?.count ?? 0)")
}
*/

// AFTER (SECURE):
import os

if let first = places.first {
    #if DEBUG
    print("[NearbyPlaces] fetched \(places.count) places of type \(type)")
    #else
    os_log("[NearbyPlaces] fetched %d places", type: .info, places.count)
    #endif
}


// ============================================================================
// SUMMARY OF CHANGES
// ============================================================================
/*
 Critical Fixes Required:
 ✅ 1. Config.swift: Remove hardcoded API key
 ✅ 2. PourDirectionApp.swift: Remove test device ID or gate with #DEBUG
 ✅ 3. EditProfileView.swift: Remove mock user data
 ✅ 4. Create KeychainHelper.swift (new file)
 ✅ 5. Update HomeLocationManager.swift: Use Keychain
 ✅ 6. Update SavedPlacesManager.swift: Use Keychain
 ✅ 7. Create AgeVerificationManager.swift (new file)
 ✅ 8. Add input validation to SupabaseManager.swift
 ✅ 9. Sanitize error messages in SupabaseManager.swift
 ✅ 10. Remove/gate debug logging

 Testing:
 - Build for Release and verify no errors
 - Test on device: location tracking, saved places, age gate
 - Check console for no William Kizell or other sensitive data
 - Verify Keychain integration works correctly

 Timeline: 2-3 hours to implement all fixes
 */
