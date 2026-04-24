//
//  Place+Codable.swift
//  PourDirection
//
//  Codable conformance for Place — stores coordinate as separate lat/lng
//  so the struct round-trips to disk (used by the 24h places cache).
//

import Foundation
import CoreLocation

extension Place: Codable {

    private enum CodingKeys: String, CodingKey {
        case id, name, formattedAddress, latitude, longitude, rating,
             photoURL, types, userRatingCount, isOpenNow, weekdayDescriptions
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let lat = try c.decode(Double.self, forKey: .latitude)
        let lng = try c.decode(Double.self, forKey: .longitude)
        self.init(
            id:                  try c.decode(String.self, forKey: .id),
            name:                try c.decode(String.self, forKey: .name),
            formattedAddress:    try c.decodeIfPresent(String.self, forKey: .formattedAddress),
            coordinate:          CLLocationCoordinate2D(latitude: lat, longitude: lng),
            rating:              try c.decodeIfPresent(Double.self, forKey: .rating),
            photoURL:            try c.decodeIfPresent(URL.self, forKey: .photoURL),
            types:               try c.decodeIfPresent([String].self, forKey: .types) ?? [],
            userRatingCount:     try c.decodeIfPresent(Int.self, forKey: .userRatingCount),
            isOpenNow:           try c.decodeIfPresent(Bool.self, forKey: .isOpenNow),
            weekdayDescriptions: try c.decodeIfPresent([String].self, forKey: .weekdayDescriptions)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(formattedAddress, forKey: .formattedAddress)
        try c.encode(coordinate.latitude,  forKey: .latitude)
        try c.encode(coordinate.longitude, forKey: .longitude)
        try c.encodeIfPresent(rating, forKey: .rating)
        try c.encodeIfPresent(photoURL, forKey: .photoURL)
        try c.encode(types, forKey: .types)
        try c.encodeIfPresent(userRatingCount, forKey: .userRatingCount)
        try c.encodeIfPresent(isOpenNow, forKey: .isOpenNow)
        try c.encodeIfPresent(weekdayDescriptions, forKey: .weekdayDescriptions)
    }
}
