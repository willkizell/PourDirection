//
//  ImageCacheManager.swift
//  PourDirection
//
//  Thread-safe image caching using NSCache for in-memory cache.
//  Prevents redundant downloads of the same card images during swiping.
//

import SwiftUI

actor ImageCacheManager {

    static let shared = ImageCacheManager()

    private let memoryCache = NSCache<NSString, UIImage>()

    private init() {
        // Limit cache to ~50MB of images (NSCache manages this automatically)
        memoryCache.totalCostLimit = 50 * 1024 * 1024
    }

    /// Retrieve cached image or return nil if not in cache.
    func cachedImage(for url: URL) -> UIImage? {
        let key = url.absoluteString as NSString
        return memoryCache.object(forKey: key)
    }

    /// Store image in memory cache with URL as key.
    func cache(image: UIImage, for url: URL) {
        let key = url.absoluteString as NSString
        // Estimate image cost as width × height (in bytes, roughly)
        let cost = Int(image.size.width * image.size.height)
        memoryCache.setObject(image, forKey: key, cost: cost)
    }

    /// Clear all cached images.
    func clearCache() {
        memoryCache.removeAllObjects()
    }
}
