//  PhotoFileStore.swift
//  DataLayer — progress-photo file storage. JPEGs live in
//  Application Support/ProgressPhotos (never in the database); the
//  ProgressPhoto model stores paths relative to this directory.

import Foundation

public final class PhotoFileStore: Sendable {
    public static let directoryName = "ProgressPhotos"

    private let directory: URL

    public init() throws {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        directory = base.appendingPathComponent(Self.directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// For tests: use a custom directory.
    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Saves JPEG data, returns the relative path to store on ProgressPhoto.
    @discardableResult
    public func saveJPEG(_ data: Data) throws -> String {
        let filename = "\(UUID().uuidString).jpg"
        try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    public func delete(relativePath: String) throws {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(relativePath))
    }

    public func fileURL(for relativePath: String) -> URL {
        directory.appendingPathComponent(relativePath)
    }

    public func exists(relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: relativePath).path)
    }
}
