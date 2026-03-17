# Data Integrity Audit - Files Analyzed

**Audit Date:** March 16, 2026
**Total Files Reviewed:** 17 Swift files + 3 configuration files
**Scope:** Data persistence, synchronization, privacy, and transaction safety

---

## Files Analyzed by Category

### Critical Data Persistence Files

#### 1. SavedPlacesManager.swift
**Location:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Managers/SavedPlacesManager.swift`
**Lines:** 95 lines
**Purpose:** Manages saved places (UserDefaults + JSON)
**Issues Found:**
- CRITICAL: Race condition in add() - no mutual exclusion
- CRITICAL: Silent JSON encoding failures (line 84)
- HIGH: No validation on load (line 88-94)
- MEDIUM: No uniqueness constraint enforcement
**Risk Level:** CRITICAL
**Fix Required:** Yes (serial DispatchQueue for mutations)

#### 2. HomeLocationManager.swift
**Location:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Managers/HomeLocationManager.swift`
**Lines:** 88 lines
**Purpose:** Persists home location (UserDefaults doubles)
**Issues Found:**
- HIGH: Incomplete transaction in set() (line 52-57)
- HIGH: Non-atomic clear() operations (line 59-66)
- MEDIUM: No validation that both lat AND lng exist (line 82-86)
- MEDIUM: didSet issues if operations interleave
**Risk Level:** HIGH
**Fix Required:** Yes (write-first atomicity)

#### 3. DistancePreferences.swift
**Location:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Models/DistancePreferences.swift`
**Lines:** 107 lines
**Purpose:** User distance preferences
**Issues Found:**
- MEDIUM: didSet property observers not atomic (line 37-43)
- LOW: Default value detection using 0 threshold (line 53-57)
**Risk Level:** MEDIUM
**Fix Required:** Optional (atomic writes preferred)

---

### Remote Data & Synchronization Files

#### 4. SupabaseManager.swift
**Location:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Managers/SupabaseManager.swift`
**Lines:** 159 lines
**Purpose:** Supabase client + nearby places API
**Issues Found:**
- CRITICAL: Hardcoded Supabase key visible in binary (lines 59-67)
- GOOD: Actor-based cache for thread safety (lines 20-41)
- MEDIUM: No offline fallback (in-memory cache only)
- MEDIUM: 5-minute TTL may cause stale data
- LOW: No cache invalidation on error
**Risk Level:** CRITICAL (for key), MEDIUM (for data)
**Fix Required:** Yes (move key to build settings)

#### 5. Config.swift
**Location:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Config.swift`
**Lines:** 20 lines
**Purpose:** App-level configuration constants
**Issues Found:**
- CRITICAL: Supabase anon key hardcoded (line 18)
- Comment acknowledges risk but not mitigated (line 7)
**Risk Level:** CRITICAL
**Fix Required:** YES - MANDATORY before production

---

### Age Verification & User State Files

#### 6. AgeGateView.swift
**Location:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/AgeGateView.swift`
**Lines:** 129 lines
**Purpose:** Age verification gate (first launch)
**Issues Found:**
- CRITICAL: Age denial not persisted (isDenied is @State only, line 20)
- HIGH: Users can bypass on app restart
- MEDIUM: Locale-based age detection (can be changed at install time, line 22-27)
- GOOD: One-time verification prevents mid-session bypass
**Risk Level:** CRITICAL
**Fix Required:** Yes (add @AppStorage for ageDenied)

---

### Location & Notification Files

#### 7. LocationManager.swift
**Location:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Managers/LocationManager.swift`
**Lines:** 79 lines
**Purpose:** Core Location management
**Issues Found:**
- GOOD: Delegates properly managed
- No data persistence issues (state-only manager)
- MEDIUM: Background location monitoring triggers async callbacks
**Risk Level:** LOW
**Fix Required:** No (but coordinate with NotificationManager fixes)

#### 8. NotificationManager.swift
**Location:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Managers/NotificationManager.swift`
**Lines:** 183 lines
**Purpose:** Local push notifications + city detection
**Issues Found:**
- MEDIUM: Race condition in handleSignificantLocationChange() (lines 100-123)
  - Reverse geocode callbacks are asynchronous, can fire out of order
  - Dwell timer state can misalign if multiple locations detected quickly
- HIGH: Plain text storage of city name + arrival date (lines 107-115)
- MEDIUM: No persistence of permission denial state
**Risk Level:** MEDIUM-HIGH
**Fix Required:** Yes (serial queue for city detection logic)

---

### Purchase & Premium State

#### 9. PurchaseManager.swift
**Location:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Managers/PurchaseManager.swift`
**Lines:** 148 lines
**Purpose:** StoreKit 2 in-app purchase handling
**Issues Found:**
- GOOD: Apple handles transaction verification ✓
- MEDIUM: Premium status not cached locally (line 111-122)
  - If offline, app loses entitlement UI state
  - Required for offline ads suppression
- MEDIUM: Background transaction listener uses [weak self] (line 127)
  - Rare but possible memory leak if manager deallocates
**Risk Level:** MEDIUM
**Fix Required:** Optional (cache + timestamp for offline)

#### 10. AdsManager.swift
**Location:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Managers/AdsManager.swift`
**Lines:** 46 lines
**Purpose:** Ad eligibility tracking
**Issues Found:**
- GOOD: Observes PurchaseManager for real-time updates ✓
- GOOD: isReady flag prevents early ad requests ✓
- LOW: No persistence of ads state (follows PurchaseManager)
**Risk Level:** LOW
**Fix Required:** No (depends on PurchaseManager fixes)

---

### App-Level Initialization & Navigation

#### 11. PourDirectionApp.swift
**Location:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/PourDirectionApp.swift`
**Lines:** 157 lines
**Purpose:** App entry point + background launch handling
**Issues Found:**
- MEDIUM: Multiple async operations without coordination (lines 57-113)
  - Splash fade, ATT request, AdMob init, purchase refresh all async
  - Possible race between ads init and ad display
  - hasLaunchedBefore written before all async steps complete
- MEDIUM: Steps 5-6 (notifications) may race with age gate
- GOOD: AppDelegate handles background location launch (lines 123-156) ✓
**Risk Level:** MEDIUM
**Fix Required:** Optional (coordinate async steps)

#### 12. RootContainerView.swift
**Location:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/RootContainerView.swift`
**Lines:** 273 lines
**Purpose:** App shell and navigation state
**Issues Found:**
- GOOD: Clean navigation stack management ✓
- GOOD: Prefetch cache population with location (lines 121-140) ✓
- LOW: No persistence of UI state (by design, acceptable)
**Risk Level:** LOW
**Fix Required:** No

---

### Data Models

#### 13. SavedPlace.swift
**Location:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Models/SavedPlace.swift`
**Lines:** 55 lines
**Purpose:** Codable saved place model
**Issues Found:**
- LOW: No validation of id/name non-empty (line 13-21)
- LOW: photoURLString can be invalid URL
**Risk Level:** LOW
**Fix Required:** No (SavedPlacesManager should validate)

#### 14. NearbyPlace.swift
**Location:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Models/NearbyPlace.swift`
**Lines:** 280 lines
**Purpose:** API models + Place struct
**Issues Found:**
- GOOD: Proper optional handling ✓
- GOOD: No persistence at model layer ✓
- LOW: Mock name lookup deterministic but collision possible
**Risk Level:** LOW
**Fix Required:** No

---

### Configuration & Metadata Files

#### 15. Info.plist
**Location:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/Info.plist`
**Lines:** 244 lines
**Purpose:** App configuration manifest
**Issues Found:**
- GOOD: Location permissions documented ✓
- GOOD: Background modes enabled for location ✓
- GOOD: SKAdNetwork identifiers configured ✓
**Risk Level:** LOW
**Fix Required:** No (update Keychain declaration after fixes)

#### 16. PrivacyInfo.xcprivacy
**Location:** `/Users/williamkizell/Documents/PourDirection/PourDirection/PourDirection/PrivacyInfo.xcprivacy`
**Lines:** 56 lines
**Purpose:** Privacy manifest for App Store
**Issues Found:**
- GOOD: Declares precise location usage (not linked to identity) ✓
- GOOD: Declares UserDefaults access (CA92.1) ✓
- MISSING: No Keychain declaration (will need after migration)
**Risk Level:** MEDIUM (needs update for Keychain)
**Fix Required:** Yes (update after Keychain implementation)

---

### Supporting Files Reviewed

#### 17. Other Views (data impact assessment only)
- **EditProfileView.swift** - No data persistence
- **ProfileView.swift** - Reads from managers, no writes
- **SavedView.swift** - Reads saved places, calls toggleSave()
- **SuggestionView.swift** - Reads places, no persistence
- **CompassActiveView.swift** - No data persistence
- **HelpView.swift** - No data persistence
- **UpgradeToProView.swift** - Calls PurchaseManager
- **ExploreView.swift** - No persistence

---

## Summary Statistics

### Files by Risk Level
| Level | Count | Files |
|-------|-------|-------|
| CRITICAL | 2 | Config.swift, AgeGateView.swift (age denial) |
| HIGH | 3 | SavedPlacesManager.swift (race), HomeLocationManager.swift, NotificationManager.swift |
| MEDIUM | 5 | SupabaseManager.swift (cache), DistancePreferences.swift, PurchaseManager.swift, PourDirectionApp.swift, PrivacyInfo.xcprivacy |
| LOW | 7 | LocationManager.swift, AdsManager.swift, RootContainerView.swift, SavedPlace.swift, NearbyPlace.swift, Info.plist, all views |

### Issues by Category
| Category | Count | Severity |
|----------|-------|----------|
| Race conditions | 2 | Critical-High |
| Atomic transactions | 2 | High |
| Encoding/validation | 2 | Critical-High |
| Hardcoded secrets | 1 | Critical |
| Privacy/encryption | 1 | High |
| Persistence/caching | 3 | Medium |
| Async coordination | 1 | Medium |

---

## Audit Artifacts Generated

1. **DATA_INTEGRITY_AUDIT.md** (comprehensive analysis)
   - 400+ lines
   - Detailed risk assessment for each file
   - Specific line numbers and vulnerable code patterns
   - GDPR/CCPA compliance notes

2. **INTEGRITY_FIX_GUIDE.md** (implementation guide)
   - 600+ lines
   - Complete code fixes with explanations
   - Before/after code comparisons
   - Unit test examples

3. **AUDIT_EXECUTIVE_SUMMARY.md** (high-level overview)
   - 300+ lines
   - Risk matrix and prioritization
   - Timeline and effort estimates
   - Compliance checklist

4. **AUDIT_FILES_ANALYZED.md** (this document)
   - Index of all files reviewed
   - Issue locations and line numbers
   - Quick reference guide

---

## How to Use These Documents

### For Developers
1. Start with **AUDIT_EXECUTIVE_SUMMARY.md** to understand priorities
2. Read **DATA_INTEGRITY_AUDIT.md** for detailed analysis of your code areas
3. Use **INTEGRITY_FIX_GUIDE.md** for specific code implementations

### For Product/Project Managers
1. Read **AUDIT_EXECUTIVE_SUMMARY.md** for risk assessment
2. Review the "Timeline" section for effort estimates
3. Use "Mandatory Checklist" before production launch

### For Security Review
1. Review Config.swift section (hardcoded keys)
2. Review HomeLocationManager & NotificationManager (plaintext coordinates)
3. Review PrivacyInfo.xcprivacy for compliance gaps

### For Code Review
1. Use this document as a checklist
2. Verify each issue in INTEGRITY_FIX_GUIDE.md is implemented
3. Run unit tests provided in fix guide

---

## Next Steps

1. **Immediately:** Move Supabase key to build settings (Config.swift)
2. **This Week:** Fix SavedPlaces race condition and age denial persistence
3. **Next Week:** Make HomeLocation atomic and implement city detection fix
4. **Following Week:** Implement Keychain storage for sensitive data
5. **Before Launch:** Run full test suite and validate all fixes

---

**Generated:** March 16, 2026
**Auditor:** Data Integrity Guardian
**Status:** Ready for implementation
