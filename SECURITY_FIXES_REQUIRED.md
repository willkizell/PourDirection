# URGENT: Security Fixes Required Before App Store Submission

**Status**: 🔴 CRITICAL ISSUES FOUND
**Timeline**: 1-2 weeks recommended
**Must Complete Before**: App Store submission (1-2 weeks)

---

## 1. CRITICAL: Encrypt Location & Saved Places Data

### Files to Fix
- `Managers/HomeLocationManager.swift`
- `Managers/SavedPlacesManager.swift`
- `AgeGateView.swift`

### Issue
Currently stored in plaintext UserDefaults:
- Home location (latitude, longitude, address)
- Saved places (bars, clubs you've visited)
- Age verification status

Anyone with device access can read this data. It's also backed up unencrypted in device backups.

### How to Fix

**Step 1: Create a Keychain helper**

```swift
// NEW FILE: Managers/KeychainManager.swift
import Foundation
import CryptoKit

final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.pourdirection.keychain"

    func save<T: Encodable>(_ value: T, forKey key: String) throws {
        let encoded = try JSONEncoder().encode(value)
        let encrypted = try encrypt(encoded)
        try setPassword(encrypted, account: key)
    }

    func load<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let encrypted = try getPassword(account: key) else { return nil }
        let decoded = try decrypt(encrypted)
        return try JSONDecoder().decode(T.self, from: decoded)
    }

    private func encrypt(_ data: Data) throws -> Data {
        let key = try loadOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else { throw KeychainError.encryptionFailed }
        return combined
    }

    private func decrypt(_ data: Data) throws -> Data {
        let key = try loadOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    private func loadOrCreateKey() throws -> SymmetricKey {
        let keyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "encryption-key",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(keyQuery as CFDictionary, &result)

        if status == errSecSuccess {
            if let keyData = result as? Data {
                return SymmetricKey(data: keyData)
            }
        }

        // Create new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "encryption-key",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.creationFailed }

        return newKey
    }

    private func setPassword(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed }
    }

    private func getPassword(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            return result as? Data
        }
        if status == errSecItemNotFound {
            return nil
        }
        throw KeychainError.loadFailed
    }
}

enum KeychainError: Error {
    case encryptionFailed
    case decryptionFailed
    case creationFailed
    case saveFailed
    case loadFailed
}
```

**Step 2: Update HomeLocationManager.swift**

```swift
// Replace persist() and load() methods
private func persist() {
    do {
        let data = HomeLocationData(
            latitude: latitude ?? 0,
            longitude: longitude ?? 0,
            address: formattedAddress ?? ""
        )
        try KeychainManager.shared.save(data, forKey: "home-location")
    } catch {
        print("[HomeLocationManager] Failed to persist: \(error)")
    }
}

private func load() {
    do {
        if let data = try KeychainManager.shared.load(HomeLocationData.self, forKey: "home-location") {
            latitude = data.latitude != 0 ? data.latitude : nil
            longitude = data.longitude != 0 ? data.longitude : nil
            formattedAddress = data.address.isEmpty ? nil : data.address
        }
    } catch {
        print("[HomeLocationManager] Failed to load: \(error)")
    }
}

private struct HomeLocationData: Codable {
    let latitude: Double
    let longitude: Double
    let address: String
}
```

**Step 3: Update SavedPlacesManager.swift**

Same pattern - replace persist() and load() to use KeychainManager.

**Step 4: Update AgeGateView.swift**

```swift
// OLD: @AppStorage("com.pourdirection.ageVerified") private var ageVerified = false

// NEW:
@State private var ageVerified = false

@AppStorage("com.pourdirection.ageVerified-timestamp")
private var verificationTimestamp: Double = 0

override init() {
    super.init()
    // Load from Keychain on init
    do {
        if let verified = try KeychainManager.shared.load(AgeVerification.self, forKey: "age-gate") {
            ageVerified = verified.isVerified
            verificationTimestamp = verified.timestamp
        }
    } catch {
        print("[AgeGateView] Failed to load verification: \(error)")
    }
}
```

### Priority: 🔴 CRITICAL - Must complete before App Store

---

## 2. CRITICAL: Fix Age-Gate Server-Side Verification

### Current Problem
Users can bypass age-gate by:
1. Deleting the app
2. Reinstalling it
3. Claim they're of legal age again

This is a major App Store rejection risk.

### How to Fix

**Add Supabase-backed verification:**

```swift
// NEW FILE: Managers/AgeVerificationManager.swift
import Foundation
import Supabase

@MainActor
class AgeVerificationManager {
    static let shared = AgeVerificationManager()

    @Published var isVerified = false
    @Published var verifiedAt: Date?

    private init() {
        loadVerificationStatus()
    }

    func verify(acceptedAt: Date = Date()) async -> Bool {
        do {
            // Store in Supabase (encrypted)
            let _ = try await SupabaseManager.shared.client
                .from("age_verifications")
                .insert([
                    "device_id": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
                    "verified_at": ISO8601DateFormatter().string(from: acceptedAt),
                    "region": Locale.current.region?.identifier ?? "unknown"
                ])
                .execute()

            isVerified = true
            verifiedAt = acceptedAt

            // Also store timestamp locally in Keychain
            try KeychainManager.shared.save(
                AgeVerificationData(verifiedAt: acceptedAt),
                forKey: "age-verification"
            )

            return true
        } catch {
            print("[AgeVerificationManager] Verification failed: \(error)")
            return false
        }
    }

    private func loadVerificationStatus() {
        do {
            if let data = try KeychainManager.shared.load(AgeVerificationData.self, forKey: "age-verification") {
                isVerified = true
                verifiedAt = data.verifiedAt
            }
        } catch {
            print("[AgeVerificationManager] Failed to load: \(error)")
        }
    }
}

struct AgeVerificationData: Codable {
    let verifiedAt: Date
}
```

**Create Supabase table:**

```sql
CREATE TABLE age_verifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_id TEXT NOT NULL,
  verified_at TIMESTAMP NOT NULL,
  region TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE age_verifications ENABLE ROW LEVEL SECURITY;

-- Only allow inserts
CREATE POLICY "allow_age_verification_insert"
ON age_verifications
FOR INSERT
WITH CHECK (true);

-- Don't allow reads (prevent checking others' data)
CREATE POLICY "no_select"
ON age_verifications
FOR SELECT
USING (false);
```

### Priority: 🔴 CRITICAL - Must complete before App Store

---

## 3. HIGH: Remove Hardcoded Test Device ID

### File: `PourDirectionApp.swift`, Line 75

### Current Code
```swift
MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
    "1b3dc40f450db15529430fa5a35ef648"
]
```

### Fix
```swift
#if DEBUG
MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
    "1b3dc40f450db15529430fa5a35ef648"
]
#endif
```

### Priority: 🔴 HIGH - Must complete before App Store

**Time to fix: 5 minutes**

---

## 4. HIGH: Remove Personal Data from EditProfileView

### File: `EditProfileView.swift`, Lines 13-17

### Current Code
```swift
@State private var fullName: String     = "William Kizell"
@State private var gender: String       = "Male"
@State private var birthday: String     = "09-22-2003"
@State private var email: String        = "wkizell@gmail.com"
```

### Fix
```swift
@State private var fullName: String     = "John Doe"
@State private var gender: String       = "Prefer not to say"
@State private var birthday: String     = "01-15-1990"
@State private var email: String        = "user@example.com"
```

### Priority: 🔴 HIGH - Must complete before App Store

**Time to fix: 5 minutes**

---

## 5. HIGH: Create Privacy Manifest

### File to Create: `PourDirection/PrivacyInfo.xcprivacy`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypePreciseLocation</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeCoarseLocation</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeUserID</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacySecondarySignatureTypes</key>
    <array>
        <dict>
            <key>NSPrivacySecondarySignatureType</key>
            <string>NSPrivacyCollectedDataTypeUserID</string>
            <key>NSPrivacySecondarySignatureTypeLinked</key>
            <true/>
            <key>NSPrivacySecondarySignatureTypeTracking</key>
            <false/>
            <key>NSPrivacySecondarySignatureTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
                <string>NSPrivacyCollectedDataTypePurposeAdvertising</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

### Priority: 🔴 HIGH - Required for App Store

**Time to fix: 30 minutes**

---

## 6. HIGH: Verify Privacy Policy

### Check: https://pourdirection.carrd.co

Ensure privacy policy includes:
- [ ] Location data collection and usage
- [ ] Background location monitoring explanation
- [ ] Age verification process
- [ ] Data retention and deletion procedures
- [ ] List of third-party services (Google Ads, Supabase)
- [ ] User data rights (GDPR, CCPA)
- [ ] How to contact you with privacy concerns

### Priority: 🔴 HIGH - Required for App Store

**Time to fix: 2-4 hours**

---

## 7. MEDIUM: Wrap Debug Logging in #if DEBUG

### Files to Update
- `Managers/SupabaseManager.swift` (line 121)
- Any other print() statements with data

### Current
```swift
if let first = places.first {
    print("[NearbyPlaces] \(type) — \(first.name) — ...")
}
```

### Fix
```swift
if let first = places.first {
    #if DEBUG
    print("[NearbyPlaces] \(type) — \(first.name) — ...")
    #endif
}
```

### Priority: 🟡 MEDIUM - Should fix before shipping

**Time to fix: 30 minutes**

---

## 8. MEDIUM: Verify Config.swift Not in Git

### Check with:
```bash
git log --all --full-history -- "**/Config.swift"
git log --all --full-history -- "PourDirection/PourDirection/Config.swift"
```

Should return nothing. If it returns commits, the Supabase credentials are exposed in history.

**If exposed in history:**
```bash
# Remove from history (requires rewriting history)
git filter-branch --tree-filter 'rm -f PourDirection/PourDirection/Config.swift' HEAD

# Force push (only if this is not shared repo)
git push origin --force
```

### Priority: 🔴 CRITICAL if exposed, otherwise 🟡 MEDIUM

**Time to check: 5 minutes**

---

## Implementation Priority

### Week 1 (Days 1-3): CRITICAL Fixes
1. Create KeychainManager.swift
2. Update HomeLocationManager to use Keychain
3. Update SavedPlacesManager to use Keychain
4. Update AgeGateView to use Keychain

### Week 1 (Days 4-5): HIGH Fixes
5. Remove hardcoded test device ID
6. Remove personal data from EditProfileView
7. Create Privacy Manifest
8. Verify privacy policy

### Week 2: Testing & Submission
9. Full app testing with encrypted storage
10. Verify no regressions
11. Build final version for App Store
12. Submit

---

## Testing Checklist

After implementing fixes, verify:

- [ ] App launches without crashing
- [ ] Age gate works and persists across app restarts
- [ ] Home location saves and loads correctly
- [ ] Saved places persist across sessions
- [ ] Location permissions still work
- [ ] Notifications still trigger
- [ ] In-app purchases still work
- [ ] No personal data in logs
- [ ] Privacy manifest displays correctly

---

## Files Affected

| File | Changes | Priority |
|------|---------|----------|
| NEW: `KeychainManager.swift` | Create | Critical |
| `HomeLocationManager.swift` | Update persist/load | Critical |
| `SavedPlacesManager.swift` | Update persist/load | Critical |
| `AgeGateView.swift` | Move to Keychain | Critical |
| `PourDirectionApp.swift` | Remove test device ID | High |
| `EditProfileView.swift` | Replace test data | High |
| NEW: `PrivacyInfo.xcprivacy` | Create | High |
| `Info.plist` | Add privacy manifest | High |
| Various `.swift` files | Wrap prints in #if DEBUG | Medium |

---

## Questions?

Reach out to security auditor if you need clarification on any fixes.

**Estimated Total Time**: 1-2 weeks (depending on team size and experience)
**Deadline**: Before App Store submission (1-2 weeks)
