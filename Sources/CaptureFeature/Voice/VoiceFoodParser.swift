import Foundation

// MARK: - VoiceFoodCandidate

/// One food item heard in a voice transcript, before the user edits it.
public struct VoiceFoodCandidate: Identifiable, Equatable, Sendable {
    public var id: UUID
    /// Food name with the quantity stripped ("chicken breast").
    public var name: String
    /// Grams guessed from the spoken quantity (100 g default).
    public var estimatedGrams: Double
    /// The raw transcript chunk, for reference.
    public var rawText: String

    public init(id: UUID = UUID(), name: String, estimatedGrams: Double, rawText: String) {
        self.id = id
        self.name = name
        self.estimatedGrams = estimatedGrams
        self.rawText = rawText
    }
}

// MARK: - VoiceFoodParser

/// Turns a speech transcript into editable food candidates.
///
/// Splits the transcript into items on commas and "and"/"plus", then pulls
/// a leading quantity ("two" is NOT handled — digits only; users can edit)
/// off each chunk via `QuantityParser`.
///
/// Examples:
/// - "2 eggs and toast" → [eggs ×200 g, toast ×100 g]
/// - "150g chicken breast, 1 cup rice" → [chicken breast ×150 g, rice ×240 g]
public enum VoiceFoodParser {

    public static func parse(_ transcript: String) -> [VoiceFoodCandidate] {
        let chunks = splitItems(transcript)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return chunks.map { chunk in
            let (grams, name) = QuantityParser.splitQuantityAndName(chunk)
            return VoiceFoodCandidate(
                name: name.isEmpty ? chunk : name,
                estimatedGrams: grams ?? 100,
                rawText: chunk
            )
        }
    }

    private static func splitItems(_ transcript: String) -> [String] {
        var text = transcript
        for separator in [",", ";", " and ", " plus ", " & "] {
            text = text.replacingOccurrences(of: separator, with: "\n")
        }
        return text
            .components(separatedBy: "\n")
            .flatMap { $0.components(separatedBy: ". ") }
    }
}
