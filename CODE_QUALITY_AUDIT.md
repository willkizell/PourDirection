# PourDirection iOS App — Code Quality & Design Patterns Audit

**Audit Date:** March 16, 2026
**Codebase Size:** ~7,174 lines of Swift code
**Scope:** SwiftUI views, managers, models, design system

---

## Executive Summary

The PourDirection codebase is **well-structured and follows modern Swift/SwiftUI conventions**. It demonstrates solid architectural practices with clear separation of concerns, consistent design patterns, and thoughtful error handling. However, there are opportunities for improvement in async/await migration, magic number extraction, timing logic consistency, and some state management redundancies.

**Overall Quality Grade:** B+ (Strong foundation with targeted improvements needed)

---

## 1. Anti-Patterns & Code Smells

### 1.1 DispatchQueue Usage (Medium Severity)

**Files Affected:**
- `PourDirectionApp.swift` (lines 60, 70)
- `MapTabView.swift` (lines 52, 56, 99, 195)
- `CompassActiveView.swift` (line 273)
- `HomeLocationSheet.swift` (lines 245, 270)
- `RootContainerView.swift` (lines 165, 259)
- `ProfileView.swift` (lines 41, 171)
- `DesignSystem/AppComponents.swift` (line 281)
- `Managers/NotificationManager.swift` (lines 60, 63)

**Issue:** Heavy use of `DispatchQueue.main.asyncAfter()` for timing delays and state transitions instead of using structured concurrency with `Task` and `try? await Task.sleep()`.

**Example (PourDirectionApp.swift, lines 60-65):**
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
    withAnimation(.easeInOut(duration: 0.8)) {
        showSplash  = false
        mainOpacity = 1.0
    }
}
```

**Recommendation:** Migrate to Swift 5.9+ structured concurrency:
```swift
Task {
    try? await Task.sleep(nanoseconds: 1_700_000_000)
    withAnimation(.easeInOut(duration: 0.8)) {
        showSplash = false
        mainOpacity = 1.0
    }
}
```

**Benefits:**
- More readable and maintainable
- Automatic cancellation on view deallocation
- Better integration with async/await throughout the codebase

---

### 1.2 Magic Numbers in Timing & Geometry (High Severity)

**Files Affected:** Multiple view files

**Issue:** Hardcoded numeric values for delays, durations, and dimensions scattered throughout without clear semantic meaning.

**Examples:**

**MapTabView.swift (lines 52-59):**
```swift
DispatchQueue.main.async {
    guard selectedItem?.id == id else { return }
    selectedDetent = .height(compact)
}
DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {  // Magic: 0.12 seconds
    guard selectedItem?.id == id else { return }
    selectedDetent = .height(compact)
}
```

**CompassActiveView.swift (lines 316, 322):**
```swift
if delta > prevDelta && delta > 15 {                    // Magic: 15 degrees
    let now = Date()
    if now.timeIntervalSince(lastHaptic) >= 0.5 {       // Magic: 0.5 seconds
        lastHaptic = now
        let intensity = min(delta / 90.0, 1.0)           // Magic: 90 degrees
```

**SuggestionView.swift (lines 371-372):**
```swift
let shouldGoBack = finalX > 35                           // Magic: 35 pixels
let shouldGoNext = finalX < -35
```

**Recommendation:** Create a `TimingConstants` or `AnimationConstants` struct in the design system:

```swift
// DesignSystem/AppConstants.swift
enum AnimationTiming {
    static let sheetSnapDelay: TimeInterval = 0.12
    static let hapticThrottling: TimeInterval = 0.5
    static let splashFadeDuration: TimeInterval = 1.7
    static let compassAlignmentFadeIn: TimeInterval = 0.8
}

enum GeometryConstants {
    static let compassAlignmentThreshold: Double = 15      // degrees
    static let compassMaxIntensityAngle: Double = 90       // degrees
    static let cardSwipeDismissal: CGFloat = 35            // pixels
    static let headingAlignedPulseThreshold: Double = 8    // degrees
}

// Usage:
if delta > prevDelta && delta > GeometryConstants.compassAlignmentThreshold {
    if now.timeIntervalSince(lastHaptic) >= AnimationTiming.hapticThrottling {
        // ...
    }
}
```

**Severity:** High — These magic numbers make code harder to maintain and tune UI behavior.

---

### 1.3 State Duplication in Views (Medium Severity)

**SuggestionView.swift (lines 50-59):**
```swift
@State private var items: [SuggestionItem] = []
@State private var currentIndex: Int     = 0
@State private var isLoading: Bool       = true
@State private var errorMessage: String? = nil
@State private var hasLoaded:    Bool    = false  // Redundant with errorMessage check
@State private var isReversing:      Bool    = false
@State private var dragOffset:       CGFloat = 0
@State private var showDistanceSheet: Bool   = false
@State private var distanceSnapshotWalking: Double = 0
@State private var distanceSnapshotSearch:  Double = 0
```

**Issue:** `hasLoaded` and `errorMessage` track similar state. When `hasLoaded = true`, we know either an error occurred or the load succeeded. This creates multiple sources of truth.

**Recommendation:** Use a single enum:
```swift
@State private var loadState: LoadState = .loading

enum LoadState {
    case loading
    case loaded
    case error(String)
}

// Usage:
switch loadState {
case .loading:
    ProgressView()
case .loaded:
    currentItemView()
case .error(let msg):
    errorView(msg)
}
```

---

### 1.4 Inconsistent Error Handling (Medium Severity)

**SuggestionView.swift (lines 684-686):**
```swift
} catch {
    errorMessage = "Couldn't load suggestions. Check your connection and try again."
    print("[SuggestionView] fetchNearbyPlaces error: \(error)")
}
```

**SupabaseManager.swift (lines 84-89):**
```swift
} catch let error as DecodingError {
    throw SupabaseManagerError.decodingFailed(
        function: name,
        underlying: error,
        rawResponse: nil
    )
}
```

**PurchaseManager.swift (lines 58-60):**
```swift
} catch {
    print("[PurchaseManager] Failed to load product: \(error)")
}
```

**Issue:**
- Some errors are silently printed and converted to generic messages
- Some errors are wrapped in custom types
- No consistent error logging or telemetry strategy
- User-facing errors don't preserve underlying cause information

**Recommendation:** Create a centralized error handling strategy:

```swift
// Models/AppError.swift
enum AppError: LocalizedError {
    case networkFailure(underlying: Error)
    case decodingFailure(underlying: Error)
    case locationDenied
    case notificationPermissionDenied

    var errorDescription: String? {
        switch self {
        case .networkFailure:
            return "Network connection failed. Please check your internet and try again."
        case .decodingFailure:
            return "Unable to load data. Please try again."
        case .locationDenied:
            return "Location access is required. Please enable it in Settings."
        case .notificationPermissionDenied:
            return "Notification permission is required."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkFailure:
            return "Check your WiFi or cellular connection."
        default:
            return nil
        }
    }
}

// Usage in managers:
func fetchPlaces() async throws {
    do {
        // ...
    } catch let error as DecodingError {
        Logger.log(.error, "Failed to decode places", error: error)
        throw AppError.decodingFailure(underlying: error)
    } catch {
        Logger.log(.error, "Unexpected error", error: error)
        throw AppError.networkFailure(underlying: error)
    }
}
```

---

### 1.5 Force Unwrapping in Mock/Preview Code (Low Severity)

**MapItem.swift (lines 204, 208, 210):**
```swift
return MapItem(
    id:          UUID().uuidString,
    name:        pool.randomElement()!,          // Force unwrap
    coordinate:  coord,
    category:    category,
    vibe:        vibe,
    rating:      ratings.randomElement()!,       // Force unwrap
    isOpen:      Bool.random(),
    closingTime: closingTimes.randomElement()!,  // Force unwrap
    reviewCount: reviewCounts.randomElement()!,  // Force unwrap
    photoURL:    nil,
    weekdayDescriptions: nil
)
```

**Issue:** While force unwrapping in preview/mock code is generally acceptable, it's better to be defensive.

**Recommendation:** Use safe alternatives:
```swift
return MapItem(
    id:          UUID().uuidString,
    name:        pool.randomElement() ?? "Unknown Place",
    coordinate:  coord,
    category:    category,
    vibe:        vibe,
    rating:      ratings.randomElement() ?? 4.0,
    isOpen:      Bool.random(),
    closingTime: closingTimes.randomElement() ?? "12:00 AM",
    reviewCount: reviewCounts.randomElement() ?? 50,
    photoURL:    nil,
    weekdayDescriptions: nil
)
```

---

## 2. Naming Convention Analysis

### 2.1 Consistency Overview

**Overall Assessment:** Naming conventions are **very consistent** across the codebase.

**Strengths:**
- ✅ Consistent `@State`, `@Published`, `@Environment` property naming
- ✅ Clear verb prefixes for functions: `request`, `start`, `fetch`, `toggle`, `load`
- ✅ Boolean properties use `is` prefix: `isLoading`, `isOpen`, `hasLoaded`
- ✅ Manager singletons follow pattern: `XyzManager.shared`
- ✅ Clear underscore prefixes for private properties: `_navigationPath` not used, but private keyword is used

### 2.2 Minor Inconsistencies

**LocationManager.swift:**
- Uses `authorizationStatus` (noun) ✓
- Uses `currentLocation` (noun) ✓
- Uses `heading` (noun) ✓

**NotificationManager.swift:**
- Uses `fridayID`, `saturdayID`, `newCityID` (specific ID naming) ✓
- Uses `lastCityKey`, `lastCityArrivalKey` (key naming) ✓

**Recommendation:** All naming is solid. Consider adding file-level documentation comments to clarify purpose for complex managers.

---

## 3. Code Duplication

### 3.1 Opening Hours Parsing Logic (High Severity)

**Files:**
- `Models/NearbyPlace.swift` (lines 213-229)
- `Models/MapItem.swift` (lines 154-168)

**Code is duplicated:**
```swift
// NearbyPlace.swift
private static func splitHoursRange(_ hours: String) -> (open: String, close: String)? {
    let dashes: [Character] = ["\u{2013}", "\u{2014}", "-"]
    for dash in dashes {
        if let idx = hours.firstIndex(of: dash) {
            let openPart = String(hours[hours.startIndex..<idx])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let closePart = String(hours[hours.index(after: idx)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !openPart.isEmpty, !closePart.isEmpty {
                return (openPart, closePart)
            }
        }
    }
    return nil
}

// MapItem.swift (identical)
private static func splitHoursRange(_ hours: String) -> (open: String, close: String)? {
    // ... exact same implementation
}
```

**Recommendation:** Extract to shared utility:
```swift
// Utilities/HoursParser.swift
struct HoursParser {
    static func splitHoursRange(_ hours: String) -> (open: String, close: String)? {
        let dashes: [Character] = ["\u{2013}", "\u{2014}", "-"]
        for dash in dashes {
            if let idx = hours.firstIndex(of: dash) {
                let openPart = String(hours[hours.startIndex..<idx])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let closePart = String(hours[hours.index(after: idx)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !openPart.isEmpty, !closePart.isEmpty {
                    return (openPart, closePart)
                }
            }
        }
        return nil
    }
}

// In both NearbyPlace and MapItem:
guard let times = HoursParser.splitHoursRange(hoursStr) else { continue }
```

---

### 3.2 Opening Hours Computation (Medium Severity)

**Files:**
- `Models/NearbyPlace.swift` (lines 164-211)
- `Models/MapItem.swift` (lines 109-152)

Both files have nearly identical implementations of:
- `todayHours` property
- `closesAt` property
- `opensAt` property

**Recommendation:** These should be combined into a protocol extension:
```swift
// Models/OpeningHoursProvider.swift
protocol OpeningHoursProvider {
    var weekdayDescriptions: [String]? { get }
}

extension OpeningHoursProvider {
    var todayHours: String? {
        guard let descriptions = weekdayDescriptions, !descriptions.isEmpty else { return nil }
        let weekday = Calendar.current.component(.weekday, from: Date())
        let dayName = Calendar.current.weekdaySymbols[weekday - 1]
        guard let entry = descriptions.first(where: { $0.localizedCaseInsensitiveContains(dayName) }) else { return nil }
        if let range = entry.range(of: ": ") {
            let hours = String(entry[range.upperBound...])
            if hours.localizedCaseInsensitiveContains("closed") { return nil }
            return hours
        }
        return nil
    }

    var closesAt: String? {
        guard let hours = todayHours else { return nil }
        return HoursParser.splitHoursRange(hours)?.close
    }

    var opensAt: String? {
        guard let descriptions = weekdayDescriptions, !descriptions.isEmpty else { return nil }
        // ... rest of implementation
    }
}

// Make both types conform:
extension Place: OpeningHoursProvider {}
extension MapItem: OpeningHoursProvider {}
```

---

## 4. Error Handling Patterns

### 4.1 Type Safety & Async/Await Usage

**Strengths:**
- ✅ `PurchaseManager` correctly uses `async/await` with `@MainActor`
- ✅ `SupabaseManager` properly handles decoding errors with custom error types
- ✅ Proper use of `try/catch` in async contexts
- ✅ Transaction-aware error handling in StoreKit

### 4.2 Network Error Handling

**SupabaseManager.swift** has good error handling:
```swift
enum SupabaseManagerError: LocalizedError {
    case decodingFailed(function: String, underlying: Error, rawResponse: String?)
}
```

**Recommendation:** Extend this pattern to all network-dependent code and use Swift's `Error` protocol consistently.

---

## 5. Force Unwrapping & Optionals

### 5.1 Overview

**Findings:**
- ✅ Generally excellent use of optional handling
- ✅ Proper use of `guard let`, `if let` with 103 occurrences across 20 files
- ✅ Defensive optional chaining in most places
- ⚠️ Limited force unwrapping (only in preview/mock code)

**Files using force unwrap:**
- `MapItem.swift` (lines 204, 208, 210) — Mock code (acceptable)
- `CompassActiveView.swift` — Minimal force unwrapping

**Recommendation:** Current approach is solid. Just extend the safe unwrapping to mock code (as noted in 1.5).

---

## 6. Swift Best Practices

### 6.1 Modern Language Features

**Strengths:**
- ✅ Uses `@Observable` macro (SwiftUI 5.0+) in `LocationManager`, `SavedPlacesManager`
- ✅ Uses `@MainActor` correctly on `PurchaseManager`, `AdsManager`
- ✅ Proper use of `NavigationStack` instead of deprecated NavigationView
- ✅ Uses `async/await` throughout managers
- ✅ Proper use of `withThrowingTaskGroup` in `SuggestionView.swift` (line 659)

### 6.2 SwiftUI Idioms

**Strengths:**
- ✅ Consistent use of `.environment()` for dependency injection
- ✅ Proper `@State`, `@Published`, `@Environment` usage
- ✅ Good use of computed properties vs stored state
- ✅ Proper view composition and extraction

**Issues:**
- `RootContainerView.swift` mixes some old patterns with `.sheet(item:)` and `fullScreenCover`
  - **Line 33:** `@State private var compassPresentation: Place?` — Good pattern
  - **Line 48:** `@State private var activeRoute: AppRoute? = nil` — Could be combined with navigationPath

**Recommendation:**
```swift
// Current:
@State private var navigationPath = NavigationPath()
@State private var activeRoute: AppRoute? = nil

// Better:
@State private var navigationPath = NavigationPath()
// Let navigationPath be the single source of truth for all routes
```

---

## 7. Architecture & Design Patterns

### 7.1 Identified Patterns

**Singleton Pattern (Excellent Implementation):**
- ✅ `LocationManager.shared`
- ✅ `SavedPlacesManager.shared`
- ✅ `PurchaseManager.shared`
- ✅ `SupabaseManager.shared`
- ✅ `NotificationManager.shared`

All singletons use private `init()` and static `let shared` correctly.

**Observer Pattern:**
- ✅ Good use of `@Published` in `PurchaseManager` and `AdsManager`
- ✅ Proper Combine integration with `.sink()` and `dropFirst()`

**Dependency Injection:**
- ✅ Excellent use of `.environment()` for passing `LocationManager`
- ✅ Clean closure callbacks for navigation

---

### 7.2 Potential Issues

**Tight Coupling in CompassActiveView (Line 224-226):**
```swift
private func openUber() {
    let lat  = place.coordinate.latitude
    let lng  = place.coordinate.longitude
    let name = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
```

**Issue:** Hardcoded Uber integration makes it difficult to add other ride-sharing services.

**Recommendation:** Extract to a strategy protocol:
```swift
protocol RideSharingProvider {
    func generateDeepLink(latitude: Double, longitude: Double, placeName: String) -> URL?
}

struct UberProvider: RideSharingProvider {
    func generateDeepLink(latitude: Double, longitude: Double, placeName: String) -> URL? {
        let name = placeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "uber://?action=setPickup&dropoff[latitude]=\(latitude)&dropoff[longitude]=\(longitude)&dropoff[nickname]=\(name)")
    }
}

// In CompassActiveView:
private func openRideService() {
    let provider = UberProvider()
    if let url = provider.generateDeepLink(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude, placeName: place.name) {
        // ...
    }
}
```

---

## 8. Design System & Consistency

### 8.1 Strengths

- ✅ **Excellent design system structure** in `DesignSystem/` folder
  - `AppColors.swift` — Centralized color palette
  - `AppTypography.swift` — Consistent font usage
  - `AppSpacing.swift` — Unified spacing constants
  - `AppComponents.swift` — Reusable button components

- ✅ **No raw colors** in view code — all use `AppColors.*`
- ✅ **No hardcoded fonts** — all use `AppTypography.*`
- ✅ **Consistent padding/spacing** — all use `AppSpacing.*`

### 8.2 Recommendations

**Add to design system:**
```swift
// DesignSystem/AppConstants.swift (NEW)
enum AnimationTiming {
    static let fast = 0.15
    static let normal = 0.3
    static let slow = 0.6
}

enum GeometryConstants {
    static let compassAlignmentDegrees = 15.0
    static let cardSwipeThreshold = 35.0
}

enum NotificationConstants {
    static let newCityDwellSeconds: TimeInterval = 45 * 60
}

// Usage in CompassActiveView:
if headingDelta < GeometryConstants.compassAlignmentDegrees { return .aligned }
```

---

## 9. Memory & Performance

### 9.1 Observations

**Good Practices:**
- ✅ Proper use of `[weak self]` in closures
- ✅ Timers and listeners are properly cancelled in deinit
- ✅ No obvious circular references in managers
- ✅ Good use of `@escaping` closures with clear semantics

**Areas to Watch:**
- `PlacesCache` in `SupabaseManager` uses actor for thread safety (excellent)
- Large view hierarchies in `SuggestionView` and `MapTabView` — consider profiling with Xcode's profiler for rendering performance

---

## 10. Code Style & Readability

### 10.1 Positive Observations

- ✅ Consistent formatting and indentation
- ✅ Good use of MARK comments for section organization
- ✅ Clear file header documentation
- ✅ Proper use of whitespace and line breaks
- ✅ Function parameters logically grouped
- ✅ Computed properties use clear names

### 10.2 Documentation Gaps

**Files lacking inline documentation:**
- `Managers/HomeLocationManager.swift` — Complex home location logic
- `Views/Map/MapTabView.swift` — Complex state management
- `CompassActiveView.swift` — Complex bearing calculations

**Recommendation:** Add documentation blocks to complex methods:

```swift
/// Calculates the true bearing from one coordinate to another using the haversine method.
/// - Parameters:
///   - from: Starting coordinate
///   - to: Destination coordinate
/// - Returns: Bearing in degrees (0-360), where 0 = north, 90 = east, etc.
/// - Note: Results may vary slightly near the poles due to spherical approximation
static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    // ...
}
```

---

## 11. Severity Summary

| Issue | Severity | Count | Priority |
|-------|----------|-------|----------|
| DispatchQueue instead of async/await | Medium | 15 | High |
| Magic numbers (timing & geometry) | High | 20+ | High |
| Code duplication (opening hours) | High | 2 files | Medium |
| State duplication | Medium | 1 view | Medium |
| Inconsistent error handling | Medium | 3+ managers | Medium |
| Force unwrap in preview code | Low | 4 instances | Low |
| Missing constants in design system | Medium | Multiple | Medium |
| Tight coupling (Uber integration) | Low | 1 place | Low |

---

## 12. Recommendations Priority List

### Immediate (Next Sprint)
1. **Extract magic numbers to constants** — Create `AppConstants.swift` in design system
2. **Consolidate opening hours logic** — Create `HoursParser.swift` utility and protocol extension
3. **Migrate DispatchQueue to async/await** — Replace all timing-based delays

### Short Term (Next 2 Sprints)
4. **Improve error handling** — Create centralized `AppError` enum and `Logger` utility
5. **Reduce state duplication** — Use LoadState enum in `SuggestionView`
6. **Add inline documentation** — Document complex algorithms and state management

### Medium Term (Next 4-6 Sprints)
7. **Refactor Uber integration** — Extract ride-sharing logic to strategy pattern
8. **Add comprehensive error logging** — Implement telemetry for error tracking
9. **Performance profiling** — Profile large views for rendering efficiency

---

## 13. Final Assessment

**Strengths:**
- Clean, well-organized architecture
- Excellent use of modern Swift/SwiftUI features
- Strong design system implementation
- Good separation of concerns with managers/models/views
- Safe optional handling throughout

**Areas for Improvement:**
- Remove timing-based DispatchQueue calls
- Extract magic numbers to named constants
- Eliminate code duplication in opening hours logic
- Standardize error handling across the app

**Code Quality Grade: B+**

The codebase is production-ready with solid fundamentals. The recommended improvements would elevate it to an A-grade with better maintainability and consistency.

---

## Appendix: Quick Reference Commands

**To find all DispatchQueue usage:**
```bash
grep -n "DispatchQueue" PourDirection/**/*.swift
```

**To find force unwraps:**
```bash
grep -n "!" PourDirection/**/*.swift | grep -v "! " | grep -v "//"
```

**To find magic numbers:**
```bash
grep -nE "[0-9]{2,}" PourDirection/**/*.swift | head -50
```

**To find TODO/FIXME comments:**
```bash
grep -n "TODO\|FIXME\|HACK" PourDirection/**/*.swift
```
(Result: None found — excellent!)
