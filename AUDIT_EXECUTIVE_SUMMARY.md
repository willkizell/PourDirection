# PourDirection Data Integrity Audit - Executive Summary

**Assessment Date:** March 16, 2026
**Risk Level:** MEDIUM-HIGH
**Critical Issues Found:** 4
**High Issues Found:** 5
**Medium Issues Found:** 4

---

## Quick Risk Assessment

PourDirection persists all user data exclusively through **UserDefaults with JSON encoding**. While this approach is simple, it creates **significant data integrity risks**:

### Traffic Light Status

🔴 **CRITICAL RISKS (Must fix before production)**
- SavedPlaces add/remove race condition (duplicates possible)
- Supabase authentication key hardcoded in source
- Age gate denial not persisted (minors can bypass)
- Encoding failures silently lose all saved places

🟠 **HIGH RISKS (Fix soon)**
- HomeLocation updates not atomic (state corruption)
- City detection async callbacks out of order (timing issues)
- Sensitive data stored plaintext (privacy violation)
- No transaction boundaries in multi-step operations

🟡 **MEDIUM RISKS (Plan remediation)**
- No offline support or data sync
- No purchase status caching (ads appear offline)
- Preference updates not atomic
- App startup race conditions

---

## Data at Risk

### User Data Stored Without Encryption
- **Saved Places:** Names, addresses, exact GPS coordinates
- **Home Location:** Precise home coordinates
- **Age Verification:** One-time flag (not re-verified)
- **Location History:** Last city + arrival time
- **Preferences:** Walking distance, search radius

### Vulnerability: Plaintext in UserDefaults
On **jailbroken iOS devices**, any app can read UserDefaults of other apps. Your users' saved place coordinates and home location could be exposed.

---

## Top 5 Critical Fixes

### 1. Fix SavedPlaces Race Condition (2-3 hours)
**Risk:** Duplicate saved places if user taps rapidly
**Solution:** Add serial DispatchQueue for mutations
**File:** SavedPlacesManager.swift, lines 43-67
**Status:** See INTEGRITY_FIX_GUIDE.md for code

### 2. Move Supabase Key Out of Source (1 hour)
**Risk:** Key visible in app binary; backend compromise possible
**Solution:** Use Xcode Build Settings or environment variables
**File:** Config.swift, lines 15-18
**Status:** Add Config.xcconfig to .gitignore

### 3. Persist Age Denial (1 hour)
**Risk:** Minors can bypass age gate on app restart
**Solution:** Add @AppStorage for ageDenied flag
**File:** AgeGateView.swift, line 20
**Status:** See INTEGRITY_FIX_GUIDE.md for code

### 4. Make HomeLocation Atomic (2 hours)
**Risk:** Incomplete writes leave latitude/longitude mismatched
**Solution:** Write to UserDefaults first, then memory
**File:** HomeLocationManager.swift, lines 52-66
**Status:** See INTEGRITY_FIX_GUIDE.md for code

### 5. Encrypt Sensitive Data (4-6 hours)
**Risk:** Coordinates visible to other apps on jailbroken devices
**Solution:** Use Keychain for location data
**File:** New SecureStorage.swift
**Status:** See INTEGRITY_FIX_GUIDE.md for code

---

## Implementation Timeline

### Week 1 (Critical Fixes)
- [ ] Fix SavedPlaces race condition
- [ ] Move Supabase key to build settings
- [ ] Persist age denial
- [ ] Make HomeLocation atomic
- **Time Commitment:** 6-8 hours
- **Testing:** Unit tests for concurrent mutations

### Week 2 (High Priority Fixes)
- [ ] Implement SecureStorage (Keychain wrapper)
- [ ] Migrate sensitive data to Keychain
- [ ] Fix city detection race condition
- [ ] Add error logging to JSON persistence
- **Time Commitment:** 8-10 hours
- **Testing:** Integration tests for background location

### Week 3+ (Medium Priority)
- [ ] Add purchase status caching for offline
- [ ] Implement data validation checksums
- [ ] Add CloudKit sync option (optional)
- [ ] Create data export feature (CCPA)
- **Time Commitment:** 12+ hours

---

## Before Shipping to Production

**Mandatory Checklist:**
- [ ] SavedPlaces race condition fixed and tested
- [ ] Supabase key not in source code
- [ ] Age denial is persistent
- [ ] Home location updates are atomic
- [ ] Sensitive data encrypted in Keychain
- [ ] Error logging in place for encoding failures
- [ ] Unit tests added for concurrent mutations
- [ ] No hardcoded credentials in Config.swift
- [ ] Privacy Policy updated (Keychain usage)
- [ ] App Store submission includes .xcprivacy update

---

## Long-term Architectural Recommendations

### Current State (High Risk)
```
UserDefaults (plaintext JSON)
├── SavedPlaces (no uniqueness constraints)
├── HomeLocation (not atomic)
├── Preferences (not atomic)
├── City history (plaintext coordinates)
└── Age verification (one-time only)
```

### Recommended State (Production-Ready)
```
UserDefaults (preferences only)
├── walkingDistance
└── searchArea

Keychain (encrypted)
├── Home location coordinates
├── Last known city + arrival time
└── Age verification

SQLite (transactional)
├── Saved places (with UNIQUE constraint)
└── Metadata indexes

CloudKit (optional sync)
└── Saved places backup + restoration
```

### Benefits of Migration
- **ACID Guarantees:** Transactions prevent data corruption
- **Encryption at Rest:** Keychain handles encryption
- **Offline Fallback:** SQLite doesn't require network
- **Data Portability:** Export/import for CCPA
- **Offline Purchase Status:** Cache + timestamp

---

## Estimated Effort

| Phase | Tasks | Hours | Complexity |
|-------|-------|-------|-----------|
| Critical Fixes | 5 tasks | 6-8 | Low-Medium |
| High Priority | 4 tasks | 8-10 | Medium |
| Medium Priority | 4 tasks | 12+ | Medium-High |
| Migration to SQLite | Full persistence layer | 40+ | High |

**Total Time to Production-Ready:** 26-30 hours
**Total Time to Fully Resilient:** 66+ hours

---

## Compliance Impact

### Current State
- ✗ GDPR: No data export/deletion mechanism
- ✗ CCPA: No data export feature
- ✗ App Store: Potential rejection due to age gate bypass
- ✗ Privacy Manifest: Missing Keychain declaration

### After Critical Fixes
- ✓ Minimal compliance
- Requires: User account system for true GDPR/CCPA support

### After Full Migration
- ✓ Full GDPR compliance (export/delete)
- ✓ Full CCPA compliance (data portability)
- ✓ Stronger age verification
- ✓ Privacy-first architecture

---

## Testing Strategy

### Unit Tests (Critical)
```swift
// Test concurrent mutations don't create duplicates
func testSaveDoesNotCreateDuplicates()

// Test encoding failures don't lose data
func testEncodingFailureHandled()

// Test HomeLocation atomicity
func testHomeLocationIsAtomic()

// Test age denial is persistent
func testAgeDenialPersists()

// Test city detection handles callback race
func testCityDetectionOrder()
```

### Integration Tests
```swift
// Test background location wake
func testBackgroundLocationTriggersNotification()

// Test multi-step app startup
func testAppStartupRaceConditions()

// Test offline mode
func testPremiumStatusOffline()
```

### Manual Testing
- Force-quit during save operations
- Disable network and test
- Restart app mid-gesture
- Clear app data and reinstall
- Test on jailbroken device simulator (if possible)

---

## Questions for Product Team

1. **User Accounts:** Should users be able to restore saved places on new device?
   - If yes: Implement Supabase user auth + cloud sync
   - If no: Accept that reinstalls lose all data

2. **Age Verification:** How strict should enforcement be?
   - Current: One-time gate (can be bypassed on fresh install)
   - Recommended: Persistent denial OR server-side age check

3. **Location Privacy:** Should app collect city name + arrival time?
   - Current: Yes (for new city notification)
   - Alternative: Only notify on significant location change (no city tracking)

4. **Data Export:** Do you need to support GDPR/CCPA data export?
   - If yes: Implement data export feature
   - If no: Document no export capability

5. **Offline Support:** Should premium status work offline?
   - If yes: Cache purchase status with timestamp
   - If no: Document online-only requirement

---

## Contacts & Escalation

**For Code Review:** See INTEGRITY_FIX_GUIDE.md for specific implementations
**For Security Questions:** Review Config.swift Supabase key handling
**For Compliance Questions:** Review PrivacyInfo.xcprivacy declarations

---

## Conclusion

PourDirection has **solid foundational code** but **insufficient data safety mechanisms** for production. The app is at **elevated risk** of:
- Data corruption (race conditions in mutations)
- Data loss (silent JSON encoding failures)
- Security compromise (hardcoded API keys)
- Regulatory issues (age gate bypass, plaintext sensitive data)

**Estimated path to production-ready:** 26-30 hours of targeted fixes

All issues are **fixable with the provided code solutions**. No architectural redesign required for critical fixes; architectural migration (UserDefaults → Keychain/SQLite) is recommended for long-term resilience.

---

**Report:** DATA_INTEGRITY_AUDIT.md (comprehensive analysis)
**Fixes:** INTEGRITY_FIX_GUIDE.md (code implementations)
**Generated:** March 16, 2026
