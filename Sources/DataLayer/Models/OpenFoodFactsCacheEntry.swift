//  OpenFoodFactsCacheEntry.swift
//  DataLayer — local cache for Open Food Facts responses (barcode lookups
//  and search results). Lives in the LOCAL (non-synced) store configuration:
//  caches are device-local by design and never go to CloudKit.
//
//  Open Food Facts data is © Open Food Facts contributors, licensed ODbL.
//  Attribution is shown in More → About (AppShell owns that screen).

import Foundation
import SwiftData

@Model
public final class OpenFoodFactsCacheEntry {
    #Index<OpenFoodFactsCacheEntry>([\.queryKey])
    #Index<OpenFoodFactsCacheEntry>([\.fetchedAt])

    @Attribute(.unique) public var id: UUID
    /// Lookup key: "barcode:<code>" or "search:<normalized query>".
    public var queryKey: String
    public var barcode: String?
    public var productName: String?
    /// Raw OFF API JSON payload (v2 product/search response).
    public var rawJSON: Data
    public var fetchedAt: Date

    public init(
        id: UUID = UUID(),
        queryKey: String,
        barcode: String? = nil,
        productName: String? = nil,
        rawJSON: Data,
        fetchedAt: Date = Date()
    ) {
        self.id = id
        self.queryKey = queryKey
        self.barcode = barcode
        self.productName = productName
        self.rawJSON = rawJSON
        self.fetchedAt = fetchedAt
    }

    /// Cache entries older than this are refreshed on next use.
    public static let timeToLive: TimeInterval = 30 * 24 * 3600 // 30 days

    public var isExpired: Bool {
        Date().timeIntervalSince(fetchedAt) > Self.timeToLive
    }
}
