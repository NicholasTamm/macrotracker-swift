//  MeasurementRepository.swift
//  DataLayer — body measurements + progress photos (metadata + files).

import Foundation
import SwiftData

@MainActor
public protocol MeasurementRepository {
    // MARK: Body measurements
    @discardableResult
    func saveMeasurement(_ measurement: BodyMeasurement) throws -> BodyMeasurement
    func measurements(from: Date, to: Date) throws -> [BodyMeasurement]
    func deleteMeasurement(_ measurement: BodyMeasurement) throws

    // MARK: Progress photos
    @discardableResult
    func savePhoto(
        jpegData: Data,
        thumbnailJPEGData: Data?,
        takenAt: Date,
        viewTag: PhotoViewTag,
        weightKgAtCapture: Double?,
        note: String?
    ) throws -> ProgressPhoto
    func photos(from: Date, to: Date) throws -> [ProgressPhoto]
    func deletePhoto(_ photo: ProgressPhoto) throws
    func fileURL(for photo: ProgressPhoto) -> URL
}

// MARK: - Defaulted convenience overloads
// Protocol requirements can't carry default arguments, so the defaults live
// here and forward to the requirement.

@MainActor
extension MeasurementRepository {
    @discardableResult
    func savePhoto(
        jpegData: Data,
        thumbnailJPEGData: Data? = nil,
        takenAt: Date = Date(),
        viewTag: PhotoViewTag = .other,
        weightKgAtCapture: Double? = nil,
        note: String? = nil
    ) throws -> ProgressPhoto {
        try savePhoto(
            jpegData: jpegData,
            thumbnailJPEGData: thumbnailJPEGData,
            takenAt: takenAt,
            viewTag: viewTag,
            weightKgAtCapture: weightKgAtCapture,
            note: note
        )
    }
}

@MainActor
public final class SwiftDataMeasurementRepository: MeasurementRepository {
    private let context: ModelContext
    private let photoStore: PhotoFileStore

    public init(context: ModelContext, photoStore: PhotoFileStore) {
        self.context = context
        self.photoStore = photoStore
    }

    // MARK: Body measurements

    @discardableResult
    public func saveMeasurement(_ measurement: BodyMeasurement) throws -> BodyMeasurement {
        guard measurement.hasAnyMeasurement else {
            throw MFDataError.invalidInput("Add at least one measurement.")
        }
        context.insert(measurement)
        try context.save()
        return measurement
    }

    public func measurements(from: Date, to: Date) throws -> [BodyMeasurement] {
        let descriptor = FetchDescriptor<BodyMeasurement>(
            predicate: #Predicate { $0.date >= from && $0.date <= to },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor)
    }

    public func deleteMeasurement(_ measurement: BodyMeasurement) throws {
        context.delete(measurement)
        try context.save()
    }

    // MARK: Progress photos

    @discardableResult
    public func savePhoto(
        jpegData: Data,
        thumbnailJPEGData: Data? = nil,
        takenAt: Date = Date(),
        viewTag: PhotoViewTag = .other,
        weightKgAtCapture: Double? = nil,
        note: String? = nil
    ) throws -> ProgressPhoto {
        let relativePath = try photoStore.saveJPEG(jpegData)
        var thumbnailPath: String?
        if let thumbnailJPEGData {
            thumbnailPath = try photoStore.saveJPEG(thumbnailJPEGData)
        }
        let photo = ProgressPhoto(
            takenAt: takenAt,
            relativePath: relativePath,
            thumbnailRelativePath: thumbnailPath,
            viewTag: viewTag,
            weightKgAtCapture: weightKgAtCapture,
            note: note
        )
        context.insert(photo)
        try context.save()
        return photo
    }

    public func photos(from: Date, to: Date) throws -> [ProgressPhoto] {
        let descriptor = FetchDescriptor<ProgressPhoto>(
            predicate: #Predicate { $0.takenAt >= from && $0.takenAt <= to },
            sortBy: [SortDescriptor(\.takenAt)]
        )
        return try context.fetch(descriptor)
    }

    public func deletePhoto(_ photo: ProgressPhoto) throws {
        try photoStore.delete(relativePath: photo.relativePath)
        if let thumbnail = photo.thumbnailRelativePath {
            try photoStore.delete(relativePath: thumbnail)
        }
        context.delete(photo)
        try context.save()
    }

    public func fileURL(for photo: ProgressPhoto) -> URL {
        photoStore.fileURL(for: photo.relativePath)
    }
}
