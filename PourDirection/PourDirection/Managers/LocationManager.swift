//
//  LocationManager.swift
//  PourDirection
//
//  CLLocationManager singleton. Injected via .environment() from PourDirectionApp.
//  Provides current location, heading, and authorization status.
//

import Foundation
import CoreLocation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {

    // MARK: - Published State

    var currentLocation: CLLocation?
    var heading: CLHeading?
    var authorizationStatus: CLAuthorizationStatus

    // MARK: - Private

    private let manager = CLLocationManager()

    // MARK: - Init

    override init() {
        self.authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.headingFilter = 5
        manager.headingOrientation = .portrait
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    // MARK: - Public API

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Upgrades to Always authorization so significant-location-change monitoring
    /// can wake the app in the background when the user arrives in a new city.
    func requestAlwaysPermission() {
        manager.requestAlwaysAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    /// Start monitoring for significant location changes (≥500 m).
    /// Works even when app is terminated — iOS relaunches the app to deliver the event.
    func startSignificantLocationMonitoring() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else { return }
        manager.startMonitoringSignificantLocationChanges()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}
