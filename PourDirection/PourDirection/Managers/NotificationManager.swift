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

    private let fridayID   = "com.pourdirection.notify.friday"
    private let saturdayID = "com.pourdirection.notify.saturday"
    private let newCityID  = "com.pourdirection.notify.newcity"

    // MARK: - UserDefaults Keys (new-city detection)

    private let lastCityKey        = "com.pourdirection.lastKnownCity"
    private let lastCityArrivalKey = "com.pourdirection.lastCityArrivalDate"

    /// Minimum time (seconds) the user must be in the new city before we notify.
    /// 45 minutes filters out quick drive-throughs.
    private let newCityDwellSeconds: TimeInterval = 45 * 60

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
                    DispatchQueue.main.async { self.scheduleWeeklyNotifications() }
                }
            case .authorized, .provisional:
                DispatchQueue.main.async { self.scheduleWeeklyNotifications() }
            default:
                break
            }
        }
    }

    /// Remove and re-add both weekly notifications.
    /// Replacing by identifier guarantees no duplicates even if called multiple times.
    func scheduleWeeklyNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [fridayID, saturdayID])

        center.add(makeRequest(
            id:      fridayID,
            weekday: 6,         // Friday (1 = Sunday)
            hour:    18,        // 6:00 PM
            body:    "It's Friday. Find something near you."
        ))

        center.add(makeRequest(
            id:      saturdayID,
            weekday: 7,         // Saturday
            hour:    19,        // 7:00 PM
            body:    "Going out tonight?"
        ))
    }

    /// Cancel all pending PourDirection notifications.
    /// Call this if the user disables notifications inside the app.
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Call this from the significant-location-change delegate (including background launches).
    /// Reverse-geocodes the location, checks if the city changed, and fires a notification
    /// after the user has been in the new city for at least `newCityDwellSeconds`.
    func handleSignificantLocationChange(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
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
}
