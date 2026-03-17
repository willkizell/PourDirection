# PourDirection iOS App - Data Integrity Audit Report

**Date:** March 16, 2026
**Scope:** Data persistence, synchronization, consistency, privacy, and transaction safety
**Risk Level:** MEDIUM-HIGH (Several critical issues identified)

---

## Executive Summary

PourDirection relies primarily on **UserDefaults for all local data persistence** without any CoreData, SQLite, or transaction-based storage. While this approach simplifies development, it introduces **significant data integrity risks**:

1. **No transaction boundaries** - Concurrent modifications can corrupt saved places
2. **Race conditions in location-based logic** - New city detection has timing vulnerabilities
3. **Silent data loss scenarios** - JSON encoding failures don't trigger alerts
4. **Limited atomicity** - Multi-step operations (age verification + notification setup) lack rollback
5. **Privacy exposure** - Sensitive data stored in plaintext in UserDefaults
6. **Age gate bypass potential** - One-time verification can be manipulated

All critical user data (age verification, saved places, preferences, home location) are persisted exclusively via UserDefaults JSON encoding with no backup, encryption, or validation checksums.

---

## 1. LOCAL DATA PERSISTENCE ANALYSIS

### 1.1 Saved Places Storage

**File:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Managers/SavedPlacesManager.swift`

#### Data Integrity Risks

**CRITICAL: Race Condition in Add/Remove Operations**
- **Location:** Lines 43-67
- **Issue:** No transaction safety or mutual exclusion
- **Scenario:** If user taps "save" twice rapidly while network is slow:
  1. First request: `isSaved()` returns false → proceeds to `add()`
  2. Second request (nearly simultaneous): `isSaved()` still returns false (not yet persisted)
  3. Result: **Duplicate SavedPlace entries** with identical IDs in the array

```swift
func add(_ place: Place, category: PlaceCategory) {
    guard !isSaved(place) else { return }   // ← Only checks memory, not atomic
    let saved = SavedPlace(...)
    savedPlaces.append(saved)
    persist()                               // ← Asynchronous encode/write
}
```

**CRITICAL: Silent Encoding Failures**
- **Location:** Lines 83-86
- **Issue:** JSON encoding errors are silently ignored
```swift
private func persist() {
    guard let data = try? JSONEncoder().encode(savedPlaces) else { return }
    UserDefaults.standard.set(data, forKey: storageKey)
    // If encoding fails, savedPlaces remains in memory but NOT persisted
    // User loses changes on app restart with no error message
}
```

**HIGH: No Validation on Load**
- **Location:** Lines 88-94
- **Issue:** Corrupted JSON silently reverts to empty array
```swift
private func load() {
    guard
        let data    = UserDefaults.standard.data(forKey: storageKey),
        let decoded = try? JSONDecoder().decode([SavedPlace].self, from: data)
    else { return }  // ← Silently returns empty if decoding fails
    savedPlaces = decoded
}
```
If SavedPlace struct changes (field added/removed) and UserDefaults has old data, user loses all saved places without warning.

**MEDIUM: No Uniqueness Constraints**
- The `isSaved()` check uses `.contains()` on memory state, not checking for duplicates on load
- If UserDefaults was directly edited or corrupted, duplicates could exist

#### Data Loss Scenarios

| Scenario | Impact | Detection |
|----------|--------|-----------|
| User saves place, immediately force-quits app | Medium | Next app launch loads from UserDefaults (should be OK) |
| Multiple rapid taps on save button | High | Duplicate entries created |
| JSON encoding fails (malformed place data) | Critical | Silent data loss on restart |
| User has 1000+ saved places | Medium | JSONEncoder might fail or be very slow |
| App crashes during persist() | High | Race condition between append() and encode() |

---

### 1.2 Home Location Storage

**File:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Managers/HomeLocationManager.swift`

#### Data Integrity Risks

**HIGH: Incomplete Transaction in set()**
- **Location:** Lines 52-57
- **Issue:** Properties updated in memory before being persisted
```swift
func set(latitude: Double, longitude: Double, address: String?) {
    self.latitude         = latitude      // ← Memory updated
    self.longitude        = longitude     // ← Memory updated
    self.formattedAddress = address       // ← Memory updated
    persist()                             // ← Writes to UserDefaults
}
```
If `persist()` fails (encoding error, disk full), the app state is corrupt - coordinates are in memory but not in storage.

**MEDIUM: Inconsistent State on Clear**
- **Location:** Lines 59-66
- **Issue:** Three separate UserDefaults operations without atomicity
```swift
func clear() {
    latitude         = nil               // ← State 1: memory cleared
    longitude        = nil
    formattedAddress = nil
    UserDefaults.standard.removeObject(forKey: keyLat)     // ← State 2: one key removed
    UserDefaults.standard.removeObject(forKey: keyLng)     // ← State 3: second key removed
    UserDefaults.standard.removeObject(forKey: keyAddress) // ← State 4: third key removed
    // If app crashes between removals, orphaned UserDefaults keys remain
}
```

**MEDIUM: No Validation on Load**
- **Location:** Lines 82-86
- **Issue:** Missing latitude AND longitude results in invalid state
```swift
private func load() {
    latitude         = UserDefaults.standard.object(forKey: keyLat) as? Double
    longitude        = UserDefaults.standard.object(forKey: keyLng) as? Double
    formattedAddress = UserDefaults.standard.string(forKey: keyAddress)
}
// If latitude loads but longitude doesn't (or vice versa), homePlace returns nil
// but the app doesn't know which coordinate is missing
```

---

### 1.3 Distance Preferences Storage

**File:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Models/DistancePreferences.swift`

#### Data Integrity Risks

**MEDIUM: didSet Property Observers Without Atomicity**
- **Location:** Lines 37-43
- **Issue:** Each property persists independently
```swift
var walkingDistanceMeters: Double {
    didSet { UserDefaults.standard.set(walkingDistanceMeters, forKey: walkingKey) }
}

var searchAreaMeters: Double {
    didSet { UserDefaults.standard.set(searchAreaMeters, forKey: searchAreaKey) }
}
```
If both properties are set in sequence and the second write fails, they become out of sync (walking max != search min).

**LOW: Default Value Initialization**
- **Location:** Lines 52-57
- **Issue:** Uses `double(forKey:)` which defaults to 0, not distinguished from actual 0 value
```swift
let w = UserDefaults.standard.double(forKey: walkingKey)
walkingDistanceMeters = w > 0 ? w : Self.defaultWalkingMeters
// If user legitimately sets walking distance to a very small value, it might be treated as missing
```

---

## 2. REMOTE DATA SYNCHRONIZATION ANALYSIS

### 2.1 Supabase Connection & Caching

**File:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Managers/SupabaseManager.swift`

#### Architecture Observations

**GOOD: Actor-based cache for thread safety**
- **Location:** Lines 20-41
- **Assessment:** PlacesCache uses Swift actor to prevent race conditions ✓
- The actor pattern correctly serializes cache access

**MEDIUM: No offline support or fallback**
- **Issue:** If Supabase is unreachable, no cached results are available for previous sessions
- The cache is in-memory only and expires after 5 minutes - no persistent fallback

**MEDIUM: 5-minute TTL may cause inconsistency**
- **Location:** Line 28
```swift
private let ttl: TimeInterval = 300   // 5 minutes
```
- User could get different results if:
  1. Fetches bars at 12:00 PM (caches result)
  2. Location changes significantly
  3. Fetches bars again at 12:04 PM (returns old cached result)
  4. No location update trigger occurs

**LOW: No cache invalidation on error**
- **Location:** Lines 107-126
- **Issue:** Failed API calls still hit the network, bypassing cache
- Successful results are cached, but the app doesn't distinguish "fresh" from "potentially stale"

#### Data Loss Scenarios

| Scenario | Impact |
|----------|--------|
| Supabase API returns malformed response | Decoding error (LINE 84-89), throws, request fails |
| User has zero network connectivity | All place searches fail, no offline mode |
| Place data changes on backend | Client continues showing cached data for 5 minutes |
| Cache actor experiences concurrent access storm | Safe (actor protects), but may queue up requests |

---

### 2.2 Authentication & Keys

**File:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Config.swift`

#### CRITICAL SECURITY ISSUES

**CRITICAL: Public Anon Key Exposed in Source Code**
- **Location:** Lines 15-18
- **Issue:** Supabase anon key is hardcoded in the app binary (visible in IPA)
```swift
static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5bndlamRmanBldHp1cHl2c3JyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3Mjc1MzEsImV4cCI6MjA4NzMwMzUzMX0.yyVl-YtE9ez1S31F7MLHUzIZ4ak6RIF5WODPsoHt3Qk"
```
- **Risk:** Anyone decompiling the app can access your Supabase project (if not RLS protected)
- **Recommendation:** Use environment variables or secure enclave, never hardcode in source
- **Current Status:** The comment on line 7 acknowledges this but it's still in production code

---

## 3. LOCAL-REMOTE DATA CONSISTENCY

### 3.1 No Sync Protocol

**CRITICAL: No Sync Strategy**
- PourDirection uses **local-only persistence for user data** (saved places, preferences, home location)
- **No backend sync exists** - users cannot restore data if they:
  - Reinstall the app
  - Switch to a new device
  - Clear app data
- **Result:** First-time users are always empty; no data recovery possible

### 3.2 Remote Data (Supabase) Is Read-Only

**MEDIUM: One-way data flow**
- App reads place data from Supabase (nearby places endpoint)
- App writes NO data back to Supabase for user customization
- **Implication:** If backend place data is incorrect/stale, users cannot report it

---

## 4. USER DATA PRIVACY & PROTECTION

### 4.1 Plaintext Storage

**CRITICAL: Sensitive Data Stored in Plaintext UserDefaults**

| Data Type | Storage | Privacy Risk | File |
|-----------|---------|--------------|------|
| Age verification | UserDefaults plain text | Can be read by other apps on jailbroken devices | AgeGateView.swift line 19 |
| Saved places (names, addresses, coords) | UserDefaults JSON | Plaintext with location data | SavedPlacesManager.swift |
| Home location (exact coordinates) | UserDefaults plain doubles | Plaintext coordinates can pinpoint home | HomeLocationManager.swift |
| Distance preferences | UserDefaults plain doubles | Low sensitivity |  DistancePreferences.swift |
| Notification state | UserDefaults strings | Contains city name and arrival timestamp | NotificationManager.swift |
| Purchase status | StoreKit transactions (encrypted by Apple) | Apple handles this correctly ✓ | PurchaseManager.swift |

**Recommendation:** Encrypt sensitive fields using Keychain or iOS Data Protection class.

### 4.2 Age Verification Storage

**File:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/AgeGateView.swift`

**HIGH: One-Time Verification, No Re-verification**
- **Location:** Lines 19, 26-27, 79-80
```swift
@AppStorage("com.pourdirection.ageVerified") private var ageVerified = false
// Once set to true, never checked again
// No expiration, no periodic re-verification
```

**Issue:** Age verification only happens on first app launch. After that:
- If minor's parent buys app on family sharing, child can access after first launch
- No way to re-verify age without reinstalling
- Age gate cannot be bypassed during app use (once cleared, gate appears again)

**MEDIUM: Locale-Based Age Detection**
- **Location:** Lines 22-27
```swift
private var requiredAge: Int {
    switch Locale.current.region?.identifier ?? "" {
    case "CA": return 19
    case "US": return 21
    default:   return 18
    }
}
```
- **Issue:** User can change device locale to lower the age requirement
- **Mitigation:** The gate only appears once (on first launch), so changing locale later doesn't bypass it
- **Risk:** Still, on fresh install, user can set locale to a 18+ country even if they're 16

### 4.3 Location Data Handling

**File:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Managers/LocationManager.swift`

**MEDIUM: Significant Location Change Monitoring**
- **Location:** Lines 58-63
- **Issue:** Significant location change (≥500m) triggers background app launch and reverse geocoding
- **Privacy:** Latitude/longitude is stored in NotificationManager's UserDefaults
  - Last city: `com.pourdirection.lastKnownCity` (plaintext string)
  - Arrival time: `com.pourdirection.lastCityArrivalDate` (plaintext date)
- **Scenario:** If device is stolen/accessed by unauthorized person, they can see:
  - Last known city where user was
  - When they arrived there
  - Every saved place's exact coordinates and address

### 4.4 Privacy Manifest Compliance

**File:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/PrivacyInfo.xcprivacy`

**GOOD: Privacy declarations present** ✓
- Tracks ATT + AdMob correctly
- Declares precise location usage (not linked to identity)
- Declares UserDefaults access for required functionality (CA92.1)

**MISSING: No Keychain declaration**
- App should declare Keychain access under NSPrivacyAccessedAPICategoryUserDefaults
- Or use FileSecurityPolicy API for encrypted data protection

---

## 5. AGE VERIFICATION DATA SAFETY

### 5.1 Verification Flow

**File:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/PourDirectionApp.swift`

**Location:** Lines 51-55, 97-109

**Flow:**
1. First launch: `ageVerified` is false → AgeGateView appears (above splash)
2. User selects "Yes" or "No"
3. If "Yes": `ageVerified = true` → gate never appears again
4. If "No": `isDenied = true` → blocking screen shown

**CRITICAL: No persistent block on age denial**
- **Issue:** If user taps "No, I'm not", app shows permanent blocking screen BUT:
  - The `isDenied` state is **only in-memory** (SwiftUI @State)
  - If user force-quits and relaunches, `ageVerified` is still false
  - AgeGateView appears again (user gets another chance)
  - No enforcement that prevents re-entry

**Scenario:** 16-year-old denies age → blocked screen → force quit → app relaunches → AgeGateView appears again → selects "Yes" → gains access

**Recommended Fix:** Store denial persistently
```swift
@AppStorage("com.pourdirection.ageDenied") private var ageDenied = false
// If ageDenied, block access permanently (or require some additional verification)
```

---

## 6. NOTIFICATION STATE PERSISTENCE

### 6.1 New City Detection Race Condition

**File:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Managers/NotificationManager.swift`

**MEDIUM: Race Condition in City Change Detection**
- **Location:** Lines 100-123
```swift
func handleSignificantLocationChange(_ location: CLLocation) {
    let geocoder = CLGeocoder()
    geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
        guard let self else { return }
        let lastCity    = defaults.string(forKey: self.lastCityKey)        // ← Read 1
        let arrivalDate = defaults.object(forKey: self.lastCityArrivalKey) as? Date  // ← Read 2

        if city != lastCity {
            defaults.set(city, forKey: self.lastCityKey)         // ← Write 1 (async callback)
            defaults.set(Date(), forKey: self.lastCityArrivalKey) // ← Write 2
        } else if let arrival = arrivalDate,
                  Date().timeIntervalSince(arrival) >= self.newCityDwellSeconds {
            defaults.removeObject(forKey: self.lastCityArrivalKey) // ← Write 3
            self.fireNewCityNotification()
        }
    }
}
```

**Scenario - Data Loss:**
1. App wakes at 12:00 PM in Boston (lastCity = "Boston", lastArrivalDate = 12:00)
2. Reverse geocode is in-flight (asynchronous)
3. **Before callback completes**, app wakes again in New York at 12:30 PM
4. Second reverse geocode starts
5. First callback fires: overwrites lastCity to... Boston (still), lastArrivalDate to 12:00 (still)
6. Second callback fires: sees lastCity = Boston, new city = New York
   - Sets lastArrivalDate to 12:30
7. At 1:15 PM (45 min dwell): fires notification ✓
8. **Problem:** If callback order reversed, first write sets Boston arrival to 12:30, then second write resets to 12:00 → notification never fires

**Better approach:** Use atomic `synchronize()` or wrap in a serial DispatchQueue

### 6.2 Notification Permission State

**MEDIUM: No Persistence of Permission Denial**
- **Location:** Lines 52-68
- **Issue:** If user denies notification permission on second launch, it's never asked again (correct)
- But the app doesn't **locally cache** the denial state
- On each app launch, it checks `getNotificationSettings()` (asynchronous)
- If Notification Center is momentarily unavailable, callback never fires

---

## 7. IN-APP PURCHASE STATE

### 7.1 PurchaseManager Transaction Safety

**File:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Managers/PurchaseManager.swift`

**GOOD: StoreKit 2 Handles Transactions** ✓
- Apple's StoreKit 2 manages purchase verification and state
- Transactions are signed and verified by Apple

**MEDIUM: Entitlement Refresh Not Persisted Locally**
- **Location:** Lines 111-122
```swift
func refreshPurchaseStatus() async {
    var hasPremium = false
    for await result in Transaction.currentEntitlements {
        if case .verified(let transaction) = result,
           transaction.productID == productID,
           transaction.revocationDate == nil {
            hasPremium = true
            break
        }
    }
    isPremium = hasPremium  // ← Only in @Published property, not persisted
}
```
- **Issue:** If device is offline, `Transaction.currentEntitlements` may fail
- User loses premium status UI (ads reappear) even though they're entitled
- **Recommendation:** Cache premium status with timestamp for offline fallback

**MEDIUM: Background Transaction Listener Weak Self**
- **Location:** Lines 126-135
```swift
private func listenForTransactionUpdates() -> Task<Void, Never> {
    Task(priority: .background) { [weak self] in
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await self?.refreshPurchaseStatus()
            }
        }
    }
}
```
- If PurchaseManager is deallocated (rare but possible), transaction updates are ignored
- **Risk:** Low, because PurchaseManager is a singleton, but the `[weak self]` pattern isn't ideal for essential tasks

---

## 8. TRANSACTION BOUNDARIES & ATOMICITY

### 8.1 App Launch Multi-Step Initialization

**File:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/PourDirectionApp.swift`

**Location:** Lines 57-113

**CRITICAL: Multiple Asynchronous Operations Without Coordination**

```swift
.onAppear {
    // Step 1: Location permission (async)
    locationManager.requestPermission()
    locationManager.startUpdating()

    // Step 2: Splash fade (async animation)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
        // Step 3: Ad tracking + SDK init (async)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                MobileAds.shared.start { _ in
                    Task { @MainActor in
                        adsManager.refreshEntitlements()
                    }
                }
            }
        }
    }

    // Step 4: Purchase status (async)
    Task { await PurchaseManager.shared.refreshPurchaseStatus() }

    // Step 5: Notifications (conditional)
    if ageVerified && hasLaunchedBefore {
        NotificationManager.shared.requestPermissionAndSchedule()
        // Step 6: Location upgrade (conditional)
        if locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.requestAlwaysPermission()
            locationManager.startSignificantLocationMonitoring()
        }
    }
    hasLaunchedBefore = true  // ← Persisted
}
```

**Issues:**

1. **No guarantee of execution order** - Step 4 (purchases) might complete before Step 3 (ads)
   - If ads check before they're initialized, incorrect state shown
   - **Mitigation:** AdsManager.isReady flag helps, but race condition still possible

2. **Steps 5 & 6 race with AgeGateView**
   - Age gate appears at .zIndex(2)
   - If notifications are requested while age gate is visible, user sees permission prompt behind gate

3. **hasLaunchedBefore write is unatomic**
   - Line 109: `hasLaunchedBefore = true` persists immediately
   - If any earlier async step crashes, this flag is already set
   - Next launch, app thinks it's not first launch anymore (skips age gate re-entry check)

---

## 9. RISK MATRIX & SEVERITY

| Severity | Category | Issue | Impact | File/Line |
|----------|----------|-------|--------|-----------|
| CRITICAL | Race Condition | SavedPlaces add() race | Duplicate entries | SavedPlacesManager.swift:43-67 |
| CRITICAL | Data Loss | Silent JSON encode failure | Lost saved places | SavedPlacesManager.swift:84-86 |
| CRITICAL | Exposure | Supabase key hardcoded | Project compromise | Config.swift:18 |
| CRITICAL | Age Denial | Not persisted | Minors can re-bypass | AgeGateView.swift:89 |
| HIGH | Transaction | HomeLocation incomplete | State corruption | HomeLocationManager.swift:52-57 |
| HIGH | Consistency | Home location clear() not atomic | Orphaned keys | HomeLocationManager.swift:59-66 |
| HIGH | Location Privacy | City/arrival time plaintext | Location tracking exposure | NotificationManager.swift:107-115 |
| HIGH | Data Loss | Corrupted JSON reverts to empty | Complete data loss | SavedPlacesManager.swift:88-94 |
| MEDIUM | Cache | No offline support | App broken offline | SupabaseManager.swift:107-126 |
| MEDIUM | Race Condition | City detection async callback order | Notification timing fails | NotificationManager.swift:100-123 |
| MEDIUM | Storage | Home location missing latitude OR longitude | Invalid state | HomeLocationManager.swift:82-86 |
| MEDIUM | Preferences | didSet not atomic | Inconsistent state | DistancePreferences.swift:37-43 |
| MEDIUM | Purchase | Premium status not cached | Offline loss of entitlement UI | PurchaseManager.swift:111-122 |
| MEDIUM | Initialization | Multi-step app launch uncoordinated | Race conditions on startup | PourDirectionApp.swift:57-113 |
| LOW | Privacy | Age verification can be changed via locale | Bypass at first launch | AgeGateView.swift:22-27 |
| LOW | Validation | Default value detection using 0 | Edge case data loss | DistancePreferences.swift:53-57 |

---

## 10. SPECIFIC RECOMMENDATIONS

### Immediate (Critical) Fixes

1. **SavedPlaces Add/Remove Race Condition**
   ```swift
   // Add DispatchQueue for serial access
   private let queue = DispatchQueue(label: "com.pourdirection.savedplaces", attributes: .initiallyInactive)

   func add(_ place: Place, category: PlaceCategory) {
       queue.async { [weak self] in
           guard let self, !self.isSaved(place) else { return }
           let saved = SavedPlace(...)
           self.savedPlaces.append(saved)
           self.persist()
       }
   }
   ```

2. **Handle Encoding Failures**
   ```swift
   private func persist() {
       guard let data = try? JSONEncoder().encode(savedPlaces) else {
           print("ERROR: Failed to encode saved places - data may be lost")
           return  // Or show user-facing error
       }
       UserDefaults.standard.set(data, forKey: storageKey)
   }
   ```

3. **Move Supabase Key Out of Source**
   - Use environment variables or Xcode Build Settings
   - Never commit Config.swift with real keys to git

4. **Persist Age Denial**
   ```swift
   @AppStorage("com.pourdirection.ageDenied") private var ageDenied = false

   if isDenied {
       ageDenied = true
       // Prevent further re-entry
   }
   ```

### Short-term (High Priority) Fixes

5. **Make HomeLocation Transactions Atomic**
   ```swift
   func set(latitude: Double, longitude: Double, address: String?) {
       let defaults = UserDefaults.standard
       defaults.set(latitude, forKey: keyLat)
       defaults.set(longitude, forKey: keyLng)
       defaults.set(address, forKey: keyAddress)
       defaults.synchronize()  // Force disk write before updating memory

       self.latitude = latitude
       self.longitude = longitude
       self.formattedAddress = address
   }
   ```

6. **Encrypt Sensitive Data in UserDefaults**
   - Move home location, saved places, and city data to Keychain
   - Use `SecureStorage` wrapper for encryption

7. **Add Offline Purchase Caching**
   ```swift
   private func cachePremiumStatus(_ isPremium: Bool) {
       UserDefaults.standard.set(isPremium, forKey: "com.pourdirection.cachedPremium")
       UserDefaults.standard.set(Date(), forKey: "com.pourdirection.premiumCacheTime")
   }
   ```

8. **Fix City Detection Race Condition**
   ```swift
   private let cityDetectionQueue = DispatchQueue(label: "com.pourdirection.citydetection")

   func handleSignificantLocationChange(_ location: CLLocation) {
       cityDetectionQueue.async { [weak self] in
           // All UserDefaults reads/writes for city logic happen serially
       }
   }
   ```

### Medium-term (Process) Fixes

9. **Add Data Validation Checksums**
   - Store CRC32 checksum with each saved place array
   - Verify on load

10. **Implement Sync Protocol**
    - If users reinstall, at minimum offer to restore from iCloud
    - Or implement Supabase user accounts for data backup

11. **Add Transaction Logging**
    - Log all UserDefaults writes for debugging
    - Include timestamp and reason

12. **Unit Tests for Data Persistence**
    - Test concurrent save/load scenarios
    - Test encoding/decoding edge cases

---

## 11. COMPLIANCE NOTES

### GDPR (Right to Deletion)
- **Current Status:** No user account system, so deletion is device-local only
- **Issue:** No way to delete from server backend (no backend account)
- **Recommendation:** If you add user accounts, implement server-side deletion

### CCPA (Data Access)
- **Current Status:** No data export feature
- **Recommendation:** Add ability for users to export saved places as JSON

### App Store Guidelines (Age Gate)
- **Current Status:** Age gate implemented, but can be bypassed on app reinstall
- **Risk:** Apple may reject if they test with locale change
- **Recommendation:** Server-side age verification (requires user account)

---

## 12. CONCLUSION

PourDirection's data persistence model is **lightweight but brittle**. UserDefaults is convenient for simple preference storage, but the app's use of saved places, location data, and purchase state requires more robust protection:

**Top 3 Risks to Fix First:**
1. SavedPlaces race condition (could cause duplicates)
2. Supabase key exposure (could compromise backend)
3. Unserialized HomeLocation operations (could cause state corruption)

**Architectural Recommendation:** Migrate to a hybrid model:
- **UserDefaults:** Preferences (walk distance, search area)
- **Keychain:** Sensitive data (age verification, home location, city history)
- **Lightweight SQLite:** Saved places (transactional, indexed)
- **iCloud Sync:** Optional cloud backup for saved places (CloudKit or Supabase RLS with user auth)

This would provide ACID guarantees, offline capability, and better privacy.

---

**Report Generated:** March 16, 2026
**Auditor:** Data Integrity Guardian
