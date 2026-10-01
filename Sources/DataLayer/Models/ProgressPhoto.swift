//  ProgressPhoto.swift
//  DataLayer — progress-photo metadata. Image bytes live in the app's
//  Application Support directory (see PhotoFileStore); only relative paths
//  are stored here so the database stays small and CloudKit-safe.

import Foundation
import SwiftData

public enum PhotoViewTag: String, Codable, Sendable, CaseIterable {
    case front
    case side
    case back
    case other

    public var displayName: String {
        switch self {
        case .front: return "Front"
        case .side: return "Side"
        case .back: return "Back"
        case .other: return "Other"
        }
    }
}

@Model
public final class ProgressPhoto {
    #Index<ProgressPhoto>([\.takenAt])

    @Attribute(.unique) public var id: UUID
    public var takenAt: Date
    /// Path relative to the photo store directory (never absolute).
    public var relativePath: String
    /// Optional downscaled thumbnail, same convention.
    public var thumbnailRelativePath: String?
    public var viewTagRaw: String
    public var weightKgAtCapture: Double?
    public var note: String?

    public init(
        id: UUID = UUID(),
        takenAt: Date = Date(),
        relativePath: String,
        thumbnailRelativePath: String? = nil,
        viewTag: PhotoViewTag = .other,
        weightKgAtCapture: Double? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.takenAt = takenAt
        self.relativePath = relativePath
        self.thumbnailRelativePath = thumbnailRelativePath
        self.viewTagRaw = viewTag.rawValue
        self.weightKgAtCapture = weightKgAtCapture
        self.note = note
    }

    public var viewTag: PhotoViewTag {
        get { PhotoViewTag(rawValue: viewTagRaw) ?? .other }
        set { viewTagRaw = newValue.rawValue }
    }
}
