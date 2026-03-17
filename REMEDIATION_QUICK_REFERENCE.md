# PourDirection Security Remediation - Quick Reference Guide

**TL;DR:** Fix these 6 critical issues before App Store submission (1-2 weeks).

---

## IMMEDIATE ACTIONS (Before Next Build)

### 1. ROTATE SUPABASE API KEY
```
1. Go to https://app.supabase.com/project/gynwejdfjpetzupyvsrr
2. Settings → API → Service Role Key (or generate new Anon Key)
3. Copy new key
4. Save in secure password manager
5. Update CI/CD environment variables
6. DO NOT commit to source code
```

### 2. REMOVE HARDCODED CONFIG FROM SOURCE
**File:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Config.swift`

**Current (INSECURE):**
```swift
enum Config {
    static let supabaseURL     = "https://gynwejdfjpetzupyvsrr.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Replace with environment-based loading:**
```swift
enum Config {
    static let supabaseURL = ProcessInfo.processInfo.environment["SUPABASE_URL"]
        ?? "https://placeholder.supabase.co"

    static let supabaseAnonKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
        ?? "placeholder_key"
}
```

**Then add to .gitignore:**
```
Config.swift
*.xcconfig
.env
.env.local
```

### 3. REMOVE GOOGLE ADMOB TEST DEVICE ID
**File:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/PourDirectionApp.swift` (Lines 73-76)

**Current (INSECURE):**
```swift
MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
    "1b3dc40f450db15529430fa5a35ef648"
]
```

**Replace with:**
```swift
// Remove these lines entirely OR gate behind build config
#if DEBUG
// Only set test devices in debug builds
MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
    "1b3dc40f450db15529430fa5a35ef648"
]
#endif
```

### 4. REMOVE MOCK USER DATA
**File:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/EditProfileView.swift` (Lines 13-17)

**Current (INSECURE):**
```swift
@State private var fullName: String     = "William Kizell"
@State private var gender: String       = "Male"
@State private var birthday: String     = "09-22-2003"
@State private var email: String        = "wkizell@gmail.com"
```

**Replace with:**
```swift
@State private var fullName: String     = ""
@State private var gender: String       = ""
@State private var birthday: String     = ""
@State private var email: String        = ""
```

---

## HIGH PRIORITY (Before App Store Submission)

### 5. MIGRATE LOCATION DATA TO KEYCHAIN
**Files:**
- `HomeLocationManager.swift` (home location)
- `SavedPlacesManager.swift` (saved places list)

**Example Implementation:**
```swift
import Security

class KeychainHelper {
    static let shared = KeychainHelper()

    func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: "Keychain", code: Int(status)) }
    }

    func retrieve(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }
}
```

### 6. IMPLEMENT CERTIFICATE PINNING FOR SUPABASE
**File:** `SupabaseManager.swift`

```swift
import CryptoKit

class PinnedURLSessionDelegate: NSURLSessionDelegate {
    let pinnedPublicKeyHashes = [
        // Get from: openssl s_client -connect gynwejdfjpetzupyvsrr.supabase.co:443 -showcerts
        // Then extract and hash the leaf certificate public key
        "sha256/J8niVW4z2z+bcHKywKGd0yoIZqHdmfMLy6FrTFqfp3I="
    ]

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Verify certificate chain
        var secResult = SecTrustResultType.invalid
        let status = SecTrustEvaluate(serverTrust, &secResult)

        guard status == errSecSuccess else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Check pinned keys
        let publicKeyCount = SecTrustGetCertificateCount(serverTrust)
        for i in 0..<publicKeyCount {
            if let certificate = SecTrustGetCertificateAtIndex(serverTrust, i),
               let publicKey = SecCertificateCopyKey(certificate) {
                let keyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? ?? Data()
                let hash = SHA256.hash(data: keyData)
                let hashString = "sha256/\(Data(hash).base64EncodedString())"

                if pinnedPublicKeyHashes.contains(hashString) {
                    completionHandler(.useCredential, URLCredential(trust: serverTrust))
                    return
                }
            }
        }

        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}
```

### 7. FIX AGE GATE BYPASS (Interim)
Migrate age verification to Keychain:

```swift
// AgeGateView.swift - Replace @AppStorage with Keychain

class AgeVerificationManager {
    static let shared = AgeVerificationManager()

    var ageVerified: Bool {
        get {
            guard let data = KeychainHelper.shared.retrieve(for: "ageVerified") else { return false }
            return (data.first ?? 0) == 1
        }
        set {
            let data = Data([newValue ? 1 : 0])
            try? KeychainHelper.shared.save(data, for: "ageVerified")
        }
    }
}
```

---

## VALIDATION CHECKLIST

After applying fixes, verify:

```
□ Config.swift has no hardcoded API keys
□ No test device IDs in release builds
□ No mock user data (William Kizell) in EditProfileView
□ Location data uses Keychain, not UserDefaults
□ Saved places uses Keychain or encrypted storage
□ Debug logging wrapped in #DEBUG
□ Certificate pinning implemented for Supabase
□ All user-facing error messages are sanitized
□ Input validation added to fetchNearbyPlaces()
□ .gitignore updated with sensitive files
□ Privacy manifest lists all data types
□ Build succeeds with all fixes applied
```

---

## TESTING AFTER REMEDIATION

1. **Build for Release:**
   ```bash
   xcodebuild -scheme PourDirection -configuration Release archive
   ```

2. **Test on Device:**
   - Verify location tracking still works
   - Verify saved places persist (now in Keychain)
   - Verify age gate appears
   - Check console for debug logs (should be minimal)

3. **Security Verification:**
   - Proxy through Burp Suite to confirm HTTPS
   - Verify certificate pinning (should reject MITM attempts)
   - Check device logs: `grep -i "William\|Kizell" /var/log/*` (should return nothing)

4. **Archive & Validate:**
   ```bash
   xcodebuild -exportArchive -archivePath PourDirection.xcarchive \
     -exportOptionsPlist exportOptions.plist -exportPath output/
   ```

---

## FILES THAT NEED CHANGES

| File | Issue | Fix |
|------|-------|-----|
| Config.swift | Hardcoded API key | Use environment variables |
| PourDirectionApp.swift | Test device ID | Remove or gate with #DEBUG |
| EditProfileView.swift | Mock user data | Clear/empty strings |
| HomeLocationManager.swift | Unencrypted location | Migrate to Keychain |
| SavedPlacesManager.swift | Unencrypted saved places | Migrate to Keychain |
| SupabaseManager.swift | No certificate pinning | Implement pinning |
| AgeGateView.swift | Client-side bypass | Migrate to Keychain (interim) |

---

## ESTIMATED TIMELINE

- **Today:** Rotate API key, remove hardcoded secrets (30 min)
- **Tomorrow:** Migrate to Keychain, add certificate pinning (2-3 hours)
- **Next day:** Testing & validation (1 hour)
- **Ready for App Store:** Within 24-48 hours

---

## RESOURCES

- [Apple Keychain Documentation](https://developer.apple.com/documentation/security/keychain_services)
- [Network Security Configuration](https://developer.apple.com/documentation/security/preventing_insecure_network_connections)
- [Privacy Manifest Requirements](https://developer.apple.com/app-store/app-privacy-details/)
- [OWASP Mobile Security Top 10](https://owasp.org/www-project-mobile-top-10/)

---

**Questions?** Refer to the full `SECURITY_AUDIT_REPORT.md` for detailed explanation of each issue.
