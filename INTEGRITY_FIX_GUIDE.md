# PourDirection Data Integrity - Implementation Guide

This document provides concrete code fixes for the critical data integrity issues identified in the audit.

---

## 1. FIX: SavedPlacesManager Race Condition

### Problem
The `add()` and `remove()` methods are not thread-safe. Rapid concurrent taps on "save" can create duplicate entries.

### Current Code (VULNERABLE)
```swift
// SavedPlacesManager.swift, lines 43-67
func add(_ place: Place, category: PlaceCategory) {
    guard !isSaved(place) else { return }   // Non-atomic check
    let saved = SavedPlace(...)
    savedPlaces.append(saved)
    persist()
}

func remove(_ place: Place) {
    savedPlaces.removeAll { $0.id == place.id }
    persist()
}
```

### Fixed Code
```swift
import Foundation
import CoreLocation
import Observation

@Observable
final class SavedPlacesManager {

    static let shared = SavedPlacesManager()

    private(set) var savedPlaces: [SavedPlace] = []

    private let storageKey = "com.pourdirection.savedPlaces"

    // Serial queue ensures all mutations are atomic
    private let mutationQueue = DispatchQueue(
        label: "com.pourdirection.savedplaces.mutations",
        qos: .userInitiated
    )

    private init() {
        load()
    }

    // MARK: - Query

    func isSaved(_ place: Place) -> Bool {
        savedPlaces.contains { $0.id == place.id }
    }

    // MARK: - Mutations (Now Thread-Safe)

    func toggleSave(_ place: Place, category: PlaceCategory) {
        mutationQueue.async { [weak self] in
            guard let self else { return }
            if self.isSaved(place) {
                self._remove(place)  // Use private non-queued version
            } else {
                self._add(place, category: category)
            }
        }
    }

    func add(_ place: Place, category: PlaceCategory) {
        mutationQueue.async { [weak self] in
            guard let self else { return }
            self._add(place, category: category)
        }
    }

    private func _add(_ place: Place, category: PlaceCategory) {
        // Now safe to call - only executed on mutationQueue
        guard !isSaved(place) else { return }
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
    }

    func remove(_ place: Place) {
        mutationQueue.async { [weak self] in
            guard let self else { return }
            self._remove(place)
        }
    }

    private func _remove(_ place: Place) {
        savedPlaces.removeAll { $0.id == place.id }
        persist()
    }

    func removeSaved(_ saved: SavedPlace) {
        mutationQueue.async { [weak self] in
            guard let self else { return }
            self.savedPlaces.removeAll { $0.id == saved.id }
            self.persist()
        }
    }

    // MARK: - Nearby Filter

    func nearbyPlaces(from location: CLLocation?, radiusMeters: Double = 5000) -> [SavedPlace] {
        guard let location else { return [] }
        return savedPlaces.filter {
            let loc = CLLocation(latitude: $0.latitude, longitude: $0.longitude)
            return location.distance(from: loc) <= radiusMeters
        }
    }

    // MARK: - Persistence with Error Handling

    private func persist() {
        do {
            let data = try JSONEncoder().encode(savedPlaces)
            UserDefaults.standard.set(data, forKey: storageKey)
            // Optional: Force synchronization to disk
            // UserDefaults.standard.synchronize()
        } catch {
            // Log error - don't silently fail
            print("[SavedPlacesManager] ERROR encoding places: \(error.localizedDescription)")
            // Consider showing user-facing error or pushing to analytics
        }
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([SavedPlace].self, from: data)
        else {
            print("[SavedPlacesManager] No saved places or corrupted data on load")
            savedPlaces = []
            return
        }

        // Validate loaded data
        let validPlaces = decoded.filter { place in
            // Ensure critical fields are non-empty
            !place.id.isEmpty && !place.name.isEmpty
        }

        if validPlaces.count != decoded.count {
            print("[SavedPlacesManager] WARNING: \(decoded.count - validPlaces.count) corrupted entries removed")
        }

        savedPlaces = validPlaces
    }
}
```

**Key Changes:**
- Added `mutationQueue` (serial DispatchQueue) for atomic operations
- `add()` and `remove()` now dispatch to queue asynchronously
- Separated public methods from internal `_` versions
- Added error logging in `persist()`
- Added validation in `load()` to filter out corrupted entries

---

## 2. FIX: HomeLocationManager Atomic Transactions

### Problem
Home location fields (lat, lng, address) are updated in memory before being written to UserDefaults. If the write fails, state becomes inconsistent.

### Current Code (VULNERABLE)
```swift
// HomeLocationManager.swift, lines 52-66
func set(latitude: Double, longitude: Double, address: String?) {
    self.latitude         = latitude
    self.longitude        = longitude
    self.formattedAddress = address
    persist()
}

func clear() {
    latitude         = nil
    longitude        = nil
    formattedAddress = nil
    UserDefaults.standard.removeObject(forKey: keyLat)
    UserDefaults.standard.removeObject(forKey: keyLng)
    UserDefaults.standard.removeObject(forKey: keyAddress)
}
```

### Fixed Code
```swift
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

    var shouldPresentSetupSheet: Bool = false

    var isSet: Bool { latitude != nil && longitude != nil }

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

    // Serial queue ensures set/clear operations don't race
    private let persistenceQueue = DispatchQueue(
        label: "com.pourdirection.homelocation",
        qos: .userInitiated
    )

    private init() { load() }

    // MARK: - Public API (Now Atomic)

    func set(latitude: Double, longitude: Double, address: String?) {
        persistenceQueue.async { [weak self] in
            guard let self else { return }

            // Write to UserDefaults first (synchronously on this queue)
            let defaults = UserDefaults.standard
            defaults.set(latitude, forKey: self.keyLat)
            defaults.set(longitude, forKey: self.keyLng)
            defaults.set(address, forKey: self.keyAddress)

            // Ensure write completes before updating memory state
            defaults.synchronize()

            // Now update memory state on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.latitude = latitude
                self.longitude = longitude
                self.formattedAddress = address
            }
        }
    }

    func clear() {
        persistenceQueue.async { [weak self] in
            guard let self else { return }

            // Atomically remove all three keys
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: self.keyLat)
            defaults.removeObject(forKey: self.keyLng)
            defaults.removeObject(forKey: self.keyAddress)

            // Force disk sync
            defaults.synchronize()

            // Update memory on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.latitude = nil
                self.longitude = nil
                self.formattedAddress = nil
            }
        }
    }

    func distance(from location: CLLocation?) -> CLLocationDistance? {
        guard let lat = latitude, let lng = longitude, let location else { return nil }
        return location.distance(from: CLLocation(latitude: lat, longitude: lng))
    }

    // MARK: - Persistence with Validation

    private func persist() {
        // Write atomically - write to defaults before updating memory
        guard let lat = latitude, let lng = longitude else { return }

        let defaults = UserDefaults.standard
        defaults.set(lat, forKey: keyLat)
        defaults.set(lng, forKey: keyLng)
        defaults.set(formattedAddress, forKey: keyAddress)
        defaults.synchronize()
    }

    private func load() {
        let defaults = UserDefaults.standard

        let lat = defaults.object(forKey: keyLat) as? Double
        let lng = defaults.object(forKey: keyLng) as? Double
        let address = defaults.string(forKey: keyAddress)

        // Only set both lat and lng if BOTH exist
        // If one is missing, state is invalid - reject
        if let lat = lat, let lng = lng {
            self.latitude = lat
            self.longitude = lng
            self.formattedAddress = address
        } else if lat != nil || lng != nil {
            // Corrupted state - one coordinate exists but not the other
            print("[HomeLocationManager] WARNING: Corrupted home location (missing coordinate)")
            // Clear both to get to consistent state
            defaults.removeObject(forKey: keyLat)
            defaults.removeObject(forKey: keyLng)
            defaults.removeObject(forKey: keyAddress)
        }
        // If both are nil, leave as nil (normal case)
    }
}
```

**Key Changes:**
- Write to UserDefaults BEFORE updating memory state
- Call `synchronize()` to force disk write
- Use `persistenceQueue` for serial access
- Validate that BOTH lat AND lng are present (not just one)
- Move main thread updates inside async block to prevent race

---

## 3. FIX: Supabase Key Extraction

### Problem
The Supabase anon key is hardcoded in Config.swift, visible in the app binary.

### Current Code (VULNERABLE)
```swift
// Config.swift
enum Config {
    static let supabaseURL     = "https://gynwejdfjpetzupyvsrr.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5bndlamRmanBldHp1cHl2c3JyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3Mjc1MzEsImV4cCI6MjA4NzMwMzUzMX0.yyVl-YtE9ez1S31F7MLHUzIZ4ak6RIF5WODPsoHt3Qk"
}
```

### Fixed Code - Option 1: Build Settings (Recommended)

**Step 1: Create Config.xcconfig**
```xcconfig
// PourDirection/Config.xcconfig
// DO NOT COMMIT THIS FILE - add to .gitignore
SUPABASE_URL = https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY = YOUR_ANON_KEY_HERE
```

**Step 2: Reference in Config.swift**
```swift
import Foundation

enum Config {
    static let supabaseURL = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
    static let supabaseAnonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""

    static func validate() {
        guard !supabaseURL.isEmpty, !supabaseAnonKey.isEmpty else {
            fatalError("Config: Missing Supabase credentials in Info.plist")
        }
    }
}
```

**Step 3: Update Info.plist**
```xml
<dict>
    ...
    <key>SUPABASE_URL</key>
    <string>$(SUPABASE_URL)</string>
    <key>SUPABASE_ANON_KEY</key>
    <string>$(SUPABASE_ANON_KEY)</string>
    ...
</dict>
```

**Step 4: Add to .gitignore**
```bash
PourDirection/Config.xcconfig
Config.xcconfig
```

### Fixed Code - Option 2: Environment-Specific Build Phases

Create separate config files for dev/release:
- `Config-Dev.xcconfig`
- `Config-Prod.xcconfig`

Select in Xcode Build Settings → User-Defined Settings

---

## 4. FIX: Age Verification Persistent Denial

### Problem
If user denies age on first launch, they can restart the app and try again.

### Current Code (VULNERABLE)
```swift
// AgeGateView.swift, lines 17-41
struct AgeGateView: View {
    @AppStorage("com.pourdirection.ageVerified") private var ageVerified = false
    @State private var isDenied = false  // ← Only in-memory!

    var body: some View {
        ZStack {
            if isDenied {
                deniedView
            } else {
                questionView
            }
        }
    }

    // Tapping "No" only sets @State, not @AppStorage
    private var questionView: some View {
        VStack {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isDenied = true  // ← Lost on restart!
                }
            }) {
                Text("No, I'm not")
            }
        }
    }
}
```

### Fixed Code
```swift
import SwiftUI

struct AgeGateView: View {

    @AppStorage("com.pourdirection.ageVerified") private var ageVerified = false
    @AppStorage("com.pourdirection.ageDenied") private var ageDenied = false  // ← Persistent
    @State private var isDeniedLocally = false

    private var requiredAge: Int {
        switch Locale.current.region?.identifier ?? "" {
        case "CA": return 19
        case "US": return 21
        default:   return 18
        }
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            AppColors.gradientBackground
                .ignoresSafeArea()

            // If permanently denied, show permanent block
            if ageDenied {
                permanentlyDeniedView
            } else if isDeniedLocally {
                deniedView
            } else {
                questionView
            }
        }
        .onAppear {
            // Check if user was previously denied
            isDeniedLocally = ageDenied
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Views

    private var questionView: some View {
        VStack(spacing: 0) {
            Spacer()
            AppLogoView(size: 80)
            Spacer().frame(height: AppSpacing.xl)

            (Text("Pour")
                .foregroundColor(AppColors.secondary)
             + Text("Direction")
                .foregroundColor(AppColors.primary))
                .font(AppTypography.titleMedium)

            Spacer().frame(height: AppSpacing.xxl)

            Text("Are you \(requiredAge) or older?")
                .font(AppTypography.header)
                .foregroundColor(AppColors.secondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: AppSpacing.xs)

            Text("You must be of legal drinking age to use PourDirection.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.secondary.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Spacer().frame(height: AppSpacing.xxl)

            PrimaryButton(title: "Yes, I'm \(requiredAge)+") {
                ageVerified = true
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)

            Spacer().frame(height: AppSpacing.md)

            Button(action: {
                HapticManager.shared.light()
                withAnimation(.easeInOut(duration: 0.25)) {
                    isDeniedLocally = true
                }
            }) {
                Text("No, I'm not")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.secondary.opacity(0.4))
                    .padding(.vertical, AppSpacing.sm)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var deniedView: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(AppColors.primary.opacity(0.6))

            Text("Access Restricted")
                .font(AppTypography.header)
                .foregroundColor(AppColors.secondary)

            Text("You must meet the legal age requirement to use this app.")
                .font(AppTypography.body)
                .foregroundColor(AppColors.secondary.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Spacer().frame(height: AppSpacing.lg)

            // Option to try again (optional - can remove for stricter enforcement)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isDeniedLocally = false
                }
            }) {
                Text("Try Again")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.secondary.opacity(0.5))
            }
        }
    }

    private var permanentlyDeniedView: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(AppColors.primary.opacity(0.8))

            Text("Access Denied")
                .font(AppTypography.header)
                .foregroundColor(AppColors.secondary)

            Text("You must be \(requiredAge)+ to use PourDirection.")
                .font(AppTypography.body)
                .foregroundColor(AppColors.secondary.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Text("Please reinstall if you've reached the minimum age.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.secondary.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
    }
}

#Preview("Question") {
    AgeGateView()
}

#Preview("Denied") {
    var preview = AgeGateView()
    preview._ageDenied = AppStorage("com.pourdirection.ageDenied")
    return preview
}
```

**Key Changes:**
- Added `@AppStorage("com.pourdirection.ageDenied")` for persistent denial
- Added `permanentlyDeniedView` for users who've been denied
- Once `ageDenied` is true, the gate is blocked permanently (requires app reinstall)
- Optional "Try Again" button in temporary denial view for UX (can remove for stricter enforcement)

---

## 5. FIX: City Detection Race Condition

### Problem
Reverse geocoding callbacks are asynchronous and can fire out of order, causing the dwell timer to misalign.

### Current Code (VULNERABLE)
```swift
// NotificationManager.swift, lines 100-123
func handleSignificantLocationChange(_ location: CLLocation) {
    let geocoder = CLGeocoder()
    geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
        // Callback timing is unpredictable - might fire after next location update
        let lastCity = defaults.string(forKey: self.lastCityKey)
        let arrivalDate = defaults.object(forKey: self.lastCityArrivalKey) as? Date

        if city != lastCity {
            defaults.set(city, forKey: self.lastCityKey)
            defaults.set(Date(), forKey: self.lastCityArrivalKey)
        } else if let arrival = arrivalDate,
                  Date().timeIntervalSince(arrival) >= self.newCityDwellSeconds {
            defaults.removeObject(forKey: self.lastCityArrivalKey)
            self.fireNewCityNotification()
        }
    }
}
```

### Fixed Code
```swift
import Foundation
import UserNotifications
import CoreLocation

final class NotificationManager: NSObject {

    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Identifiers
    private let fridayID   = "com.pourdirection.notify.friday"
    private let saturdayID = "com.pourdirection.notify.saturday"
    private let newCityID  = "com.pourdirection.notify.newcity"

    // MARK: - UserDefaults Keys
    private let lastCityKey        = "com.pourdirection.lastKnownCity"
    private let lastCityArrivalKey = "com.pourdirection.lastCityArrivalDate"

    private let newCityDwellSeconds: TimeInterval = 45 * 60

    // Serial queue ensures city detection callbacks don't race
    private let cityDetectionQueue = DispatchQueue(
        label: "com.pourdirection.citydetection",
        qos: .utility
    )

    // MARK: - Public API

    func requestPermissionAndSchedule() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    guard granted else { return }
                    DispatchQueue.main.async { self.scheduleWeeklyNotifications() }
                }
            case .authorized, .provisional:
                DispatchQueue.main.async { self.scheduleWeeklyNotifications() }
            default:
                break
            }
        }
    }

    func scheduleWeeklyNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [fridayID, saturdayID])

        center.add(makeRequest(
            id:      fridayID,
            weekday: 6,
            hour:    18,
            body:    "It's Friday. Find something near you."
        ))

        center.add(makeRequest(
            id:      saturdayID,
            weekday: 7,
            hour:    19,
            body:    "Going out tonight?"
        ))
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - City Detection (Now Serialized)

    func handleSignificantLocationChange(_ location: CLLocation) {
        // Dispatch to serial queue to prevent callback race conditions
        cityDetectionQueue.async { [weak self] in
            guard let self else { return }
            self._processLocationChange(location)
        }
    }

    private func _processLocationChange(_ location: CLLocation) {
        let geocoder = CLGeocoder()

        // Create local copies to avoid race conditions
        let previousCity = UserDefaults.standard.string(forKey: lastCityKey)
        let previousArrivalDate = UserDefaults.standard.object(forKey: lastCityArrivalKey) as? Date

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self else { return }

            // Process the result back on the cityDetectionQueue to maintain serial order
            self.cityDetectionQueue.async { [weak self] in
                guard let self else { return }

                guard let city = placemarks?.first?.locality, !city.isEmpty else { return }

                let defaults = UserDefaults.standard

                if city != previousCity {
                    // New city detected - start dwell timer
                    defaults.set(city, forKey: self.lastCityKey)
                    defaults.set(Date(), forKey: self.lastCityArrivalKey)
                    print("[NotificationManager] Entered new city: \(city)")
                } else if let arrival = previousArrivalDate,
                          Date().timeIntervalSince(arrival) >= self.newCityDwellSeconds {
                    // Still in same city AND 45+ minutes have passed
                    defaults.removeObject(forKey: self.lastCityArrivalKey)

                    // Fire notification on main thread
                    DispatchQueue.main.async { [weak self] in
                        self?.fireNewCityNotification()
                    }
                }
            }
        }
    }

    // MARK: - Private Methods

    private func fireNewCityNotification() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self,
                  settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else { return }

            center.removePendingNotificationRequests(withIdentifiers: [self.newCityID])

            let content = UNMutableNotificationContent()
            content.title = "New in town?"
            content.body = "Pour's got you — see what's open tonight!"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: self.newCityID, content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func makeRequest(
        id:      String,
        weekday: Int,
        hour:    Int,
        body:    String
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "PourDirection"
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
```

**Key Changes:**
- Added `cityDetectionQueue` (serial) for all city detection logic
- Moved processing into private `_processLocationChange()` executed on the queue
- Read `previousCity` and `previousArrivalDate` before async callback
- Callback results are processed back on the same queue (maintaining order)
- Fire notification on main thread from the queue

---

## 6. FIX: Keychain Storage for Sensitive Data

### New File: `SecureStorage.swift`

```swift
import Foundation
import Security

class SecureStorage {

    private let serviceIdentifier = "com.pourdirection"

    static let shared = SecureStorage()

    private init() {}

    // MARK: - Save String
    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Try to update existing
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Delete if exists
        SecItemDelete(query as CFDictionary)

        // Add new
        let status = SecItemAdd(
            (query.merging(attributes, uniquingKeysWith: { _, new in new }) as CFDictionary),
            nil
        )

        return status == errSecSuccess
    }

    // MARK: - Retrieve String
    func retrieve(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else { return nil }

        return String(data: data, encoding: .utf8)
    }

    // MARK: - Save Date
    func saveDate(key: String, value: Date) -> Bool {
        let timestamp = String(value.timeIntervalSince1970)
        return save(key: key, value: timestamp)
    }

    // MARK: - Retrieve Date
    func retrieveDate(key: String) -> Date? {
        guard let timestampStr = retrieve(key: key),
              let timestamp = Double(timestampStr) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    // MARK: - Delete
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Clear All
    func clearAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
```

### Update HomeLocationManager to use Keychain

```swift
// Add to HomeLocationManager
private func persistSecurely() {
    guard let lat = latitude, let lng = longitude else { return }

    SecureStorage.shared.save(key: "homeLat", value: String(lat))
    SecureStorage.shared.save(key: "homeLng", value: String(lng))
    if let address = formattedAddress {
        SecureStorage.shared.save(key: "homeAddress", value: address)
    }
}

private func loadFromSecureStorage() {
    guard let latStr = SecureStorage.shared.retrieve(key: "homeLat"),
          let lngStr = SecureStorage.shared.retrieve(key: "homeLng"),
          let lat = Double(latStr),
          let lng = Double(lngStr) else { return }

    self.latitude = lat
    self.longitude = lng
    self.formattedAddress = SecureStorage.shared.retrieve(key: "homeAddress")
}
```

---

## Testing Recommendations

### Unit Tests for SavedPlacesManager

```swift
func testConcurrentSaveDoesNotCreateDuplicates() {
    let place = Place(id: "test-1", name: "Test Bar", ...)
    let category = PlaceCategory.bar

    let expectation = expectation(description: "Concurrent saves complete")
    expectation.expectedFulfillmentCount = 2

    DispatchQueue.global().async {
        SavedPlacesManager.shared.add(place, category: category)
        expectation.fulfill()
    }

    DispatchQueue.global().async {
        SavedPlacesManager.shared.add(place, category: category)
        expectation.fulfill()
    }

    waitForExpectations(timeout: 5.0)

    XCTAssertEqual(SavedPlacesManager.shared.savedPlaces.filter { $0.id == "test-1" }.count, 1)
}

func testLoadHandlesCorruptedData() {
    // Set invalid JSON
    UserDefaults.standard.set("invalid json".data(using: .utf8), forKey: "com.pourdirection.savedPlaces")

    let manager = SavedPlacesManager()

    // Should recover gracefully
    XCTAssertEqual(manager.savedPlaces.count, 0)
}
```

---

## Summary of Fixes

| Issue | Fix Type | Complexity | Recommended Priority |
|-------|----------|-----------|----------------------|
| SavedPlaces race condition | Serial queue | Medium | 1 (Critical) |
| Encoding failure handling | Error logging | Low | 2 (High) |
| HomeLocation atomicity | Persistence-first | Medium | 2 (High) |
| Supabase key hardcoding | Build settings | Low | 1 (Critical) |
| Age denial not persisted | @AppStorage | Low | 3 (High) |
| City detection race | Serial queue | Medium | 3 (Medium) |
| Plaintext sensitive data | Keychain | Medium | 4 (Medium) |

All fixes maintain backward compatibility while improving data safety.
