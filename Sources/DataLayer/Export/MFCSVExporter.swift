import Foundation

// MARK: - MFCSVExporter

/// Spreadsheet export of log + weight data (issue #12).
///
/// Pure functions over repository results — no I/O, no SwiftUI. AppShell
/// fetches the rows through the repository protocols, calls these
/// builders, and shares the resulting files. All copy here is original;
/// the column layout is a straightforward data dump (dates ISO-8601 so
/// spreadsheets sort correctly).
public enum MFCSVExporter {
    // MARK: Builders

    /// One row per log entry, newest last. Nutrient columns are absolute
    /// amounts for the logged serving (the snapshot stored at log time, so
    /// later food edits never rewrite exported history).
    public static func foodLogCSV(_ entries: [LogEntry]) -> String {
        let header = [
            "Date", "Time", "Meal", "Food", "Grams",
            "Calories (kcal)", "Protein (g)", "Fat (g)", "Carbs (g)",
            "Fiber (g)", "Sugar (g)", "Sodium (mg)",
            "Source", "Note",
        ]
        var lines = [header.map(escape).joined(separator: ",")]
        for entry in entries.sorted(by: { $0.timestamp < $1.timestamp }) {
            let row = [
                isoDate(entry.timestamp),
                isoTime(entry.timestamp),
                entry.mealSlot.displayName,
                entry.foodName,
                number(entry.grams),
                number(entry.snapshot(.calories)),
                number(entry.snapshot(.protein)),
                number(entry.snapshot(.fat)),
                number(entry.snapshot(.carbs)),
                number(entry.snapshot(.fiber)),
                number(entry.snapshot(.sugar)),
                number(entry.snapshot(.sodium)),
                entry.entrySource.rawValue,
                entry.note ?? "",
            ]
            lines.append(row.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// One row per weigh-in, oldest first. Weights export in kilograms (the
    /// canonical stored unit); spreadsheets can convert to pounds.
    public static func weightsCSV(_ weights: [WeightEntry]) -> String {
        let header = ["Date", "Time", "Weight (kg)", "Source", "Note"]
        var lines = [header.map(escape).joined(separator: ",")]
        for weight in weights.sorted(by: { $0.timestamp < $1.timestamp }) {
            let row = [
                isoDate(weight.timestamp),
                isoTime(weight.timestamp),
                number(weight.weightKg),
                weight.source.rawValue,
                weight.note ?? "",
            ]
            lines.append(row.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: File writing

    /// Writes the export tables to the temporary directory and returns the
    /// file URLs for sharing. Filenames carry the export date.
    public static func writeFiles(
        foodLogCSV: String,
        weightsCSV: String
    ) throws -> [URL] {
        let stamp = isoDate(Date())
        let directory = FileManager.default.temporaryDirectory
        let foodURL = directory.appendingPathComponent("food-log-\(stamp).csv")
        let weightURL = directory.appendingPathComponent("weight-history-\(stamp).csv")
        try foodLogCSV.write(to: foodURL, atomically: true, encoding: .utf8)
        try weightsCSV.write(to: weightURL, atomically: true, encoding: .utf8)
        return [foodURL, weightURL]
    }

    // MARK: Formatting

    /// RFC 4180 escaping: quote fields containing commas, quotes, or
    /// newlines; double embedded quotes.
    public static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    private static func number(_ value: Double) -> String {
        // Round to 2 decimals; drop the fraction when it's whole.
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(rounded)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static func isoDate(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private static func isoTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}
