//
//  NotificationManager.swift
//  PourDirection
//
//  Local push notifications only — no remote push, no APNs token.
//  Schedules two recurring weekly notifications:
//    • Friday  6PM — "It's Friday. Find something near you."
//    • Saturday 7PM — "Going out tonight?"
//
//  Permission is never requested on first launch.
//  Call requestPermissionAndSchedule() on second launch and beyond.
//  Fixed notification identifiers prevent duplicates — existing requests
//  are replaced before new ones are added.
//

import Foundation
import UserNotifications
import CoreLocation

final class NotificationManager: NSObject {

    static let shared = NotificationManager()

    private override init() {
        super.init()
        // Set delegate so notifications can show while app is in foreground
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Identifiers

    private let fridayID          = "com.pourdirection.notify.friday"
    private let saturdayID        = "com.pourdirection.notify.saturday"
    private let fridayLateID      = "com.pourdirection.notify.friday.late"
    private let saturdayLateID    = "com.pourdirection.notify.saturday.late"
    private let fridayMidnightID  = "com.pourdirection.notify.friday.midnight"
    private let saturdayMidnightID = "com.pourdirection.notify.saturday.midnight"
    private let newCityID         = "com.pourdirection.notify.newcity"
    private let goHomeID          = "com.pourdirection.notify.saturday.gohome"
    private let firstDayHomeID    = "com.pourdirection.notify.firstday.sethome"

    // MARK: - UserDefaults Keys (new-city detection)

    private let lastCityKey        = "com.pourdirection.lastKnownCity"
    private let lastCityArrivalKey = "com.pourdirection.lastCityArrivalDate"
    private let firstLaunchDateKey = "com.pourdirection.firstLaunchDate"

    // MARK: - Notification Route Metadata

    private let routeKey            = "com.pourdirection.notification.route"
    private let routeOpenSavedSetup = "open_saved_setup"
    private let routeOpenHome       = "open_home_compass"

    // MARK: - Home-Context Rules

    /// User is considered "away from home" when farther than this distance.
    private let awayFromHomeThresholdMeters: CLLocationDistance = 500
    private let firstDayWindowSeconds: TimeInterval = 24 * 60 * 60
    private let firstDayReminderOffsetSeconds: TimeInterval = 20 * 60 * 60

    /// Minimum time (seconds) the user must be in the new city before we notify.
    /// 45 minutes filters out quick drive-throughs.
    private let newCityDwellSeconds: TimeInterval = 45 * 60

    // MARK: - Reverse Geocoding Throttling

    private var geocoder: CLGeocoder?
    private var lastGeocodeTime: Date = .distantPast
    private let geocodeThrottleInterval: TimeInterval = 60  // Min 60 seconds between requests

    // MARK: - Public API

    /// Check current authorization status.
    /// • .notDetermined  → request permission, then schedule on grant
    /// • .authorized     → schedule immediately (no dialog shown)
    /// • .denied / other → do nothing
    /// Safe to call on every launch after the first.
    func requestPermissionAndSchedule() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    guard granted else { return }
                    DispatchQueue.main.async {
                        self.scheduleWeeklyNotifications()
                        self.scheduleFirstDayHomeReminderIfNeeded()
                    }
                }
            case .authorized, .provisional:
                DispatchQueue.main.async {
                    self.scheduleWeeklyNotifications()
                    self.scheduleFirstDayHomeReminderIfNeeded()
                }
            default:
                break
            }
        }
    }

    /// Remove and re-add both weekly notifications.
    /// Replacing by identifier guarantees no duplicates even if called multiple times.
    func scheduleWeeklyNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            fridayID, saturdayID,
            fridayLateID, saturdayLateID,
            fridayMidnightID, saturdayMidnightID
        ])

        // Friday 7 PM
        center.add(makeRequest(
            id:      fridayID,
            weekday: 6,
            hour:    19,
            body:    "🚨 It's FRIDAY!! Find something near you."
        ))

        // Saturday 7 PM
        center.add(makeRequest(
            id:      saturdayID,
            weekday: 7,
            hour:    19,
            body:    "👀 It's Saturday!! You know what to do."
        ))

        // Friday 11 PM
        center.add(makeRequest(
            id:      fridayLateID,
            weekday: 6,
            hour:    23,
            body:    "🍕 Hungry? Find somewhere to eat near you."
        ))

        // Saturday 11 PM
        center.add(makeRequest(
            id:      saturdayLateID,
            weekday: 7,
            hour:    23,
            body:    "🍔 Getting hungry? See what's still open."
        ))

        // Friday midnight (Saturday 12 AM)
        center.add(makeRequest(
            id:      fridayMidnightID,
            weekday: 7,
            hour:    0,
            body:    "Still out? Find what's open near you 🍺🍕!!"
        ))

        // Saturday midnight (Sunday 12 AM)
        center.add(makeRequest(
            id:      saturdayMidnightID,
            weekday: 1,
            hour:    0,
            body:    "🚨 NIGHT'S NOT OVER!! See what's around you."
        ))
    }

    /// Cancel all pending PourDirection notifications.
    /// Call this if the user disables notifications inside the app.
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Persist the app's first launch date once, then reuse for first-day reminders.
    func recordFirstLaunchIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: firstLaunchDateKey) == nil else { return }
        defaults.set(Date(), forKey: firstLaunchDateKey)
    }

    /// Refresh home-context notifications (first-day setup + go-home reminder).
    /// Safe to call repeatedly from location updates and app foregrounding.
    func refreshHomeContextNotifications(currentLocation: CLLocation?) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self,
                  settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else { return }
            DispatchQueue.main.async {
                self.scheduleFirstDayHomeReminderIfNeeded()
                self.syncSaturdayGoHomeNotification(currentLocation: currentLocation)
            }
        }
    }

    /// Call this from the significant-location-change delegate (including background launches).
    /// Reverse-geocodes the location, checks if the city changed, and fires a notification
    /// after the user has been in the new city for at least `newCityDwellSeconds`.
    /// Throttled to prevent main-thread blocking from concurrent reverse-geocode requests.
    func handleSignificantLocationChange(_ location: CLLocation) {
        // Keep home-context reminders in sync when location changes in background.
        refreshHomeContextNotifications(currentLocation: location)

        // Throttle: only reverse-geocode if 60+ seconds have passed since last request
        guard Date().timeIntervalSince(lastGeocodeTime) >= geocodeThrottleInterval else { return }

        // Cancel any pending geocode request before starting a new one
        geocoder?.cancelGeocode()

        geocoder = CLGeocoder()
        lastGeocodeTime = Date()

        geocoder?.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self,
                  let city = placemarks?.first?.locality,
                  !city.isEmpty else { return }

            let defaults    = UserDefaults.standard
            let lastCity    = defaults.string(forKey: self.lastCityKey)
            let arrivalDate = defaults.object(forKey: self.lastCityArrivalKey) as? Date

            if city != lastCity {
                // Entered a new city — record it and start the dwell timer
                defaults.set(city, forKey: self.lastCityKey)
                defaults.set(Date(), forKey: self.lastCityArrivalKey)
            } else if let arrival = arrivalDate,
                      Date().timeIntervalSince(arrival) >= self.newCityDwellSeconds {
                // Still in the same new city after dwell period — fire once, then clear arrival
                // so we don't re-fire on subsequent location updates in the same city.
                defaults.removeObject(forKey: self.lastCityArrivalKey)
                self.fireNewCityNotification()
            }
        }
    }

    // MARK: - Private

    private func fireNewCityNotification() {
        let center  = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self,
                  settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else { return }

            // Remove any previous new-city notification that hasn't been tapped yet
            center.removePendingNotificationRequests(withIdentifiers: [self.newCityID])

            let content       = UNMutableNotificationContent()
            content.title     = "New in town?"
            content.body      = "Pour's got you — see what's open tonight!"
            content.sound     = .default

            // Immediate one-shot trigger (non-repeating)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: self.newCityID, content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func scheduleFirstDayHomeReminderIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [firstDayHomeID])

        guard !HomeLocationManager.shared.isSet else { return }
        guard let firstLaunch = UserDefaults.standard.object(forKey: firstLaunchDateKey) as? Date else { return }

        let now = Date()
        let elapsed = now.timeIntervalSince(firstLaunch)
        guard elapsed >= 0, elapsed < firstDayWindowSeconds else { return }

        let reminderDate = firstLaunch.addingTimeInterval(firstDayReminderOffsetSeconds)
        guard reminderDate > now else { return }
        let fireDate = reminderDate

        let content = UNMutableNotificationContent()
        content.title = "PourDirection"
        content.body = "Set your home location so Pour can help you get back safely."
        content.sound = .default
        content.userInfo = [routeKey: routeOpenSavedSetup]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: firstDayHomeID, content: content, trigger: trigger)
        center.add(request)
    }

    private func syncSaturdayGoHomeNotification(currentLocation: CLLocation?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [goHomeID])

        guard HomeLocationManager.shared.isSet,
              let currentLocation,
              let distance = HomeLocationManager.shared.distance(from: currentLocation),
              distance > awayFromHomeThresholdMeters else { return }

        let content = UNMutableNotificationContent()
        content.title = "PourDirection"
        content.body = "Time to go home?"
        content.sound = .default
        content.userInfo = [routeKey: routeOpenHome]

        var components = DateComponents()
        components.weekday = 7 // Saturday
        components.hour = 12
        components.minute = 45

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: goHomeID, content: content, trigger: trigger)
        center.add(request)
    }

    private func makeRequest(
        id:      String,
        weekday: Int,
        hour:    Int,
        body:    String
    ) -> UNNotificationRequest {
        let content       = UNMutableNotificationContent()
        content.title     = "PourDirection"
        content.body      = body
        content.sound     = .default

        var components    = DateComponents()
        components.weekday = weekday
        components.hour    = hour
        components.minute  = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Show banner + play sound even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let route = response.notification.request.content.userInfo[routeKey] as? String {
            switch route {
            case routeOpenSavedSetup:
                NotificationRoutingManager.shared.setPending(.openSavedForHomeSetup)
            case routeOpenHome:
                NotificationRoutingManager.shared.setPending(.openHomeCompass)
            default:
                break
            }
        }
        completionHandler()
    }
}
