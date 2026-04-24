//
//  NotificationRoutingManager.swift
//  PourDirection
//
//  Central in-app routing hub for notification taps.
//  NotificationManager writes pending actions here;
//  RootContainerView consumes and executes them.
//

import Foundation
import Observation

enum NotificationRouteAction: Equatable {
    case openSavedForHomeSetup
    case openHomeCompass
}

@Observable
final class NotificationRoutingManager {

    static let shared = NotificationRoutingManager()

    private(set) var pendingAction: NotificationRouteAction?

    private init() {}

    func setPending(_ action: NotificationRouteAction) {
        pendingAction = action
    }

    func clearPending() {
        pendingAction = nil
    }
}
