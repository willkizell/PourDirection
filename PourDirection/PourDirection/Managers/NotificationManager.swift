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

    // MARK: - Private

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
