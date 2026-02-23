//
//  RoutePlan.swift
//  PourDirection
//
//  Routing model types for future navigation integration.
//  Pure data — no logic, no protocol gymnastics.
//

import Foundation
import CoreLocation

// MARK: - Route Segment

struct RouteSegment {
    let polyline: [CLLocationCoordinate2D]
    let instruction: String
    let distance: CLLocationDistance
}

// MARK: - Route Plan

struct RoutePlan {
    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    let segments: [RouteSegment]
    let estimatedTime: TimeInterval?
    let estimatedDistance: CLLocationDistance?
}

// MARK: - Navigation State

enum NavigationState {
    case idle
    case navigating(RoutePlan)
    case arrived
}
