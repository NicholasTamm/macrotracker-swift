import Foundation

// ████████████████████████████████████████████████████████████████████████████
//  STUB — PhotoLoggingService
//
//  This file defines the seam where a real AI meal-analysis backend plugs
//  in. NOTHING in the photo-logging UI depends on the stub below: the UI
//  only programs against the `PhotoLoggingService` protocol, so swapping in
//  a real implementation is a one-line change in `CaptureDependencies`
//  (pass your own `PhotoLoggingService` instead of `StubPhotoLoggingService`).
//
//  A real implementation should:
//    1. Upload `imageData` (JPEG) to the backend over HTTPS.
//    2. Decode the backend's JSON into `PhotoMealEstimate`.
//    3. Throw a descriptive error (never fake data) when the backend is
//       unreachable or returns something unparseable.
//
//  See also: README.md ("Photo logging stub").
// ████████████████████████████████████████████████████████████████████████████

// MARK: - Estimate value types

/// One food the (future) backend spotted in a meal photo.
public struct PhotoMealItem: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    /// Estimated grams on the plate.
    public var estimatedGrams: Double
    /// Estimated total calories for `estimatedGrams`.
    public var estimatedCalories: Double
    /// 0...1 confidence reported by the backend.
    public var confidence: Double
    /// True when this item came from the stub (never show stub items as
    /// real analysis).
    public var isStubEstimate: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        estimatedGrams: Double,
        estimatedCalories: Double,
        confidence: Double,
        isStubEstimate: Bool = false
    ) {
        self.id = id
        self.name = name
        self.estimatedGrams = estimatedGrams
        self.estimatedCalories = estimatedCalories
        self.confidence = confidence
        self.isStubEstimate = isStubEstimate
    }

    /// Implied calories per 100 g, for building the review draft.
    public var impliedCaloriesPer100g: Double {
        guard estimatedGrams > 0 else { return 0 }
        return estimatedCalories / estimatedGrams * 100
    }
}

/// The backend's read of one meal photo.
public struct PhotoMealEstimate: Equatable, Sendable {
    public var items: [PhotoMealItem]
    /// Backend note, e.g. "Low lighting — estimates are rough."
    public var note: String?

    public init(items: [PhotoMealItem], note: String? = nil) {
        self.items = items
        self.note = note
    }
}

// MARK: - Protocol

/// Analyzes a meal photo into item estimates.
///
/// Implementations MUST NOT fabricate confident-looking data on failure:
/// throw instead. The UI presents every value as an editable estimate.
public protocol PhotoLoggingService: Sendable {
    /// - Parameter imageData: JPEG data of the meal photo.
    /// - Returns: The meal estimate, ready for draft review.
    func analyzeMeal(_ imageData: Data) async throws -> PhotoMealEstimate
}

// MARK: - STUB implementation

/// STUB — clearly-marked stand-in for the future AI backend.
///
/// Returns a fixed, obviously-demo estimate (flagged `isStubEstimate`) so
/// the full capture → review → save → log UI can be built and exercised
/// before any backend exists. The UI always shows a "Demo estimate" banner
/// when the active service is this stub.
///
/// DO NOT ship this as real analysis. Replace by injecting a real
/// `PhotoLoggingService` into `CaptureDependencies`.
public struct StubPhotoLoggingService: PhotoLoggingService {
    public init() {}

    public func analyzeMeal(_ imageData: Data) async throws -> PhotoMealEstimate {
        // Simulate network latency so the loading UI is exercisable.
        try await Task.sleep(for: .seconds(1))
        return PhotoMealEstimate(
            items: [
                PhotoMealItem(
                    name: "Demo bowl (stub)",
                    estimatedGrams: 350,
                    estimatedCalories: 520,
                    confidence: 0.5,
                    isStubEstimate: true
                ),
                PhotoMealItem(
                    name: "Demo side (stub)",
                    estimatedGrams: 120,
                    estimatedCalories: 180,
                    confidence: 0.5,
                    isStubEstimate: true
                ),
            ],
            note: "STUB backend: these items are hardcoded demo data, not analysis."
        )
    }
}
