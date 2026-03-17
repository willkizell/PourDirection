# PourDirection Data Integrity Audit - Quick Reference Card

**Print this and keep it visible during development**

---

## CRITICAL ISSUES - FIX BEFORE ANY RELEASE

### Issue 1: SavedPlaces Race Condition
**File:** SavedPlacesManager.swift, lines 43-67
**Problem:** Two rapid "save" taps create duplicates
**Fix Time:** 2-3 hours
**What to do:** Add DispatchQueue for serial mutations
```swift
private let queue = DispatchQueue(label: "...", qos: .userInitiated)
// Wrap add() and remove() calls with queue.async
```
**Status:** [ ] DONE

---

### Issue 2: Supabase Key Hardcoded
**File:** Config.swift, line 18
**Problem:** API key visible in IPA binary
**Fix Time:** 1 hour
**What to do:** Move to Xcode Build Settings
```swift
// Create Config.xcconfig (NOT committed to git)
// Reference in Info.plist via $(SUPABASE_ANON_KEY)
```
**Status:** [ ] DONE

---

### Issue 3: Age Gate Bypass on Restart
**File:** AgeGateView.swift, line 20
**Problem:** Users tap "No" → force quit → restart → can try again
**Fix Time:** 1 hour
**What to do:** Add persistent denial flag
```swift
@AppStorage("com.pourdirection.ageDenied") private var ageDenied = false
// If denied once, block permanently (or require reinstall)
```
**Status:** [ ] DONE

---

### Issue 4: Silent JSON Encoding Failure
**File:** SavedPlacesManager.swift, line 84
**Problem:** Encoding fails → data lost → no error shown
**Fix Time:** 30 minutes
**What to do:** Add error logging
```swift
guard let data = try? JSONEncoder().encode(savedPlaces) else {
    print("ERROR: SavedPlaces encoding failed - data may be lost")
    return
}
```
**Status:** [ ] DONE

---

## HIGH PRIORITY ISSUES - FIX THIS WEEK

### Issue 5: HomeLocation Not Atomic
**File:** HomeLocationManager.swift, lines 52-57
**Problem:** Set coordinates in memory, then write to UserDefaults → if write fails, state corrupted
**Fix Time:** 2 hours
**What to do:** Write to UserDefaults FIRST, then memory
```swift
func set(latitude: Double, longitude: Double, address: String?) {
    // Write to UserDefaults first
    let defaults = UserDefaults.standard
    defaults.set(latitude, forKey: keyLat)
    // ... then update memory
    self.latitude = latitude
}
```
**Status:** [ ] DONE

---

### Issue 6: Plaintext Location Data
**Files:** HomeLocationManager.swift, NotificationManager.swift
**Problem:** Home coordinates + city name stored plaintext in UserDefaults
**Fix Time:** 4-6 hours
**What to do:** Implement SecureStorage (Keychain wrapper)
**Status:** [ ] DONE

---

### Issue 7: City Detection Race
**File:** NotificationManager.swift, lines 100-123
**Problem:** Reverse geocode callbacks fire out of order → dwell timer fails
**Fix Time:** 2 hours
**What to do:** Serial DispatchQueue for all city state mutations
```swift
private let cityQueue = DispatchQueue(label: "...", qos: .utility)
// Process all geocoding callbacks on this queue
```
**Status:** [ ] DONE

---

### Issue 8: HomeLocation Missing Validation
**File:** HomeLocationManager.swift, line 82-86
**Problem:** One coordinate loads but not the other → invalid state
**Fix Time:** 1 hour
**What to do:** Validate BOTH lat AND lng exist
```swift
if let lat = lat, let lng = lng {
    self.latitude = lat
    self.longitude = lng
} else if lat != nil || lng != nil {
    // Corrupted - clear both
}
```
**Status:** [ ] DONE

---

## MEDIUM PRIORITY - FIX BEFORE MAJOR RELEASE

### Issue 9: Offline Purchase Status
**File:** PurchaseManager.swift
**Problem:** If offline, isPremium is lost → ads reappear
**Fix Time:** 1 hour
**What to do:** Cache premium status with timestamp
**Status:** [ ] DONE

---

### Issue 10: App Startup Race Conditions
**File:** PourDirectionApp.swift, lines 57-113
**Problem:** Multiple async operations without coordination
**Fix Time:** 2-3 hours
**What to do:** Use Task groups or structured concurrency
**Status:** [ ] DONE

---

## TESTING CHECKLIST

### Unit Tests
- [ ] SavedPlaces: Concurrent save doesn't create duplicates
- [ ] SavedPlaces: Encoding failure is handled
- [ ] HomeLocation: Both coordinates exist or both nil
- [ ] AgeGate: Denial persists across restarts
- [ ] NotificationManager: City detection handles out-of-order callbacks

### Integration Tests
- [ ] Force-quit during save
- [ ] Disable network → test offline mode
- [ ] Clear app data + reinstall → age gate appears
- [ ] Background location triggers → notification fires correctly

### Manual Tests
- [ ] Rapid taps on save button (no duplicates)
- [ ] Restart app mid-gesture (no data loss)
- [ ] Network failure during home location set (no corruption)
- [ ] Age deny → force quit → restart (gate appears, can't bypass)

---

## BEFORE SHIPPING CHECKLIST

**MANDATORY:**
- [ ] All CRITICAL issues (1-4) fixed and tested
- [ ] Supabase key NOT in source code (in build settings)
- [ ] Age denial is persistent
- [ ] Home location updates are atomic
- [ ] Sensitive data encrypted in Keychain
- [ ] Unit tests added
- [ ] No hardcoded credentials anywhere
- [ ] PrivacyInfo.xcprivacy updated
- [ ] Review commit history for exposed keys

**RECOMMENDED:**
- [ ] All HIGH issues (5-8) fixed and tested
- [ ] Error logging added to all persistence operations
- [ ] Data validation checksums added
- [ ] Privacy Policy updated (Keychain usage)
- [ ] App Store submission prepared

---

## FILE LOCATIONS

| File | Issue | Line # |
|------|-------|--------|
| Config.swift | Hardcoded key | 18 |
| SavedPlacesManager.swift | Race condition | 43-67 |
| SavedPlacesManager.swift | Silent failure | 84 |
| HomeLocationManager.swift | Not atomic | 52-57 |
| HomeLocationManager.swift | Missing validation | 82-86 |
| AgeGateView.swift | Not persistent | 20 |
| NotificationManager.swift | Race condition | 100-123 |
| PurchaseManager.swift | No cache | 111-122 |
| PourDirectionApp.swift | Async coordination | 57-113 |

---

## TIME ESTIMATE

**Critical Only:** 6-8 hours
**Critical + High:** 14-18 hours
**All Issues:** 26-30 hours
**Full Migration to Keychain/SQLite:** 66+ hours

---

## EMERGENCY FIXES (If Production Issue Reported)

### Saved Places Duplication in Wild
1. Add migration code to load() that deduplicates
2. Use `.reduce([:])` to build dict keyed by ID, then convert back to array

### Age Gate Bypass in Wild
1. Force app update via version check
2. Or: Add server-side age verification

### Leaked Supabase Key in Wild
1. Rotate key in Supabase dashboard immediately
2. Release patched app version within 24 hours
3. Notify affected users via in-app message

---

## DOCUMENTATION LINKS

- **Full Audit:** DATA_INTEGRITY_AUDIT.md
- **Implementation Guide:** INTEGRITY_FIX_GUIDE.md
- **Executive Summary:** AUDIT_EXECUTIVE_SUMMARY.md
- **Files Analyzed:** AUDIT_FILES_ANALYZED.md

---

**Last Updated:** March 16, 2026
**Print Date:** ___________
**Completion Status:** CRITICAL: [ ] HIGH: [ ] MEDIUM: [ ]
