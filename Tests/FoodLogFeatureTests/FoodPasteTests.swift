import XCTest
import SwiftData
import DataLayer
@testable import FoodLogFeature

@MainActor
final class FoodPasteTests: XCTestCase {
    func testSingleFoodPastesToPastAndFutureWithoutChangingSource() throws {
        let fixture = try Fixture()
        let source = fixture.day
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: source))
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: source))
        let egg = try fixture.food(name: "Egg", calories: 120)
        let original = try fixture.logs.logFood(
            egg, grams: 100, mealSlot: .breakfast,
            timestamp: fixture.time(on: source, hour: 11, minute: 17),
            note: "source", source: .manualSearch
        )
        let sourceTotals = try fixture.logs.dayTotals(source)
        FoodLogClipboard.shared.copyFood(original)

        for destination in [yesterday, tomorrow] {
            let model = fixture.model(selectedDay: destination)
            let result = model.pasteIntoSelectedDay()
            XCTAssertEqual(result.count, 1)
            XCTAssertNil(result.error)
            XCTAssertEqual(model.totals.entryCount, 1)
            XCTAssertEqual(model.totals.calories, 120, accuracy: 0.001)
            let pasted = try XCTUnwrap(model.entries.first)
            XCTAssertNotEqual(pasted.id, original.id)
            XCTAssertEqual(pasted.mealSlot, .breakfast)
            XCTAssertEqual(pasted.note, "source")
            XCTAssertTrue(Calendar.current.isDate(pasted.timestamp, inSameDayAs: destination))
            XCTAssertEqual(Calendar.current.component(.hour, from: pasted.timestamp), 11)
            XCTAssertEqual(Calendar.current.component(.minute, from: pasted.timestamp), 17)
        }

        XCTAssertEqual(try fixture.logs.entries(forDay: source).map(\.id), [original.id])
        XCTAssertEqual(try fixture.logs.dayTotals(source), sourceTotals)

        // A new context models a process relaunch against the same store.
        let reopened = fixture.reopenedModel(selectedDay: yesterday)
        reopened.reload()
        XCTAssertEqual(reopened.totals.entryCount, 1)
        XCTAssertEqual(reopened.totals.calories, 120, accuracy: 0.001)
        XCTAssertEqual(try fixture.logs.dayTotals(source), sourceTotals)
    }

    func testBlockKeepsIndividualMinutesAndRepeatPasteIsIntentional() throws {
        let fixture = try Fixture()
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: fixture.day))
        let egg = try fixture.food(name: "Egg", calories: 120)
        let first = try fixture.logs.logFood(
            egg, grams: 100, mealSlot: .breakfast,
            timestamp: fixture.time(on: fixture.day, hour: 11, minute: 5),
            note: nil, source: .manualSearch
        )
        let second = try fixture.logs.logFood(
            egg, grams: 100, mealSlot: .snack,
            timestamp: fixture.time(on: fixture.day, hour: 11, minute: 42),
            note: nil, source: .manualSearch
        )
        FoodLogClipboard.shared.copyBlock(label: "11 AM", entries: [first, second])
        let model = fixture.model(selectedDay: yesterday)

        XCTAssertEqual(model.pasteIntoSelectedDay().count, 2)
        XCTAssertEqual(model.totals.calories, 240, accuracy: 0.001)
        XCTAssertEqual(model.entries.map { Calendar.current.component(.minute, from: $0.timestamp) }, [5, 42])
        XCTAssertEqual(model.entries.map(\.mealSlot), [.breakfast, .snack])
        XCTAssertEqual(try fixture.logs.dayTotals(fixture.day).entryCount, 2)
        XCTAssertEqual(try fixture.logs.dayTotals(fixture.day).calories, 240, accuracy: 0.001)

        XCTAssertEqual(model.pasteIntoSelectedDay().count, 2)
        XCTAssertEqual(model.totals.entryCount, 4)
        XCTAssertEqual(model.totals.calories, 480, accuracy: 0.001)
        XCTAssertEqual(try fixture.logs.dayTotals(fixture.day).entryCount, 2)
        let reopened = fixture.reopenedModel(selectedDay: yesterday)
        reopened.reload()
        XCTAssertEqual(reopened.totals.entryCount, 4)
        XCTAssertEqual(reopened.totals.calories, 480, accuracy: 0.001)
    }

    func testEmptyClipboardAndFailedWriteNeverReportSuccess() throws {
        let fixture = try Fixture()
        let destination = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: fixture.day))
        let model = fixture.model(selectedDay: destination)
        FoodLogClipboard.shared.clear()
        XCTAssertEqual(model.pasteIntoSelectedDay().count, 0)
        XCTAssertNil(model.clipboard.pasteLabel)

        let egg = try fixture.food(name: "Egg", calories: 120)
        let invalid = LogEntry(
            timestamp: fixture.time(on: fixture.day, hour: 11, minute: 5),
            dayStart: fixture.day, food: egg, foodName: egg.name, grams: -1
        )
        FoodLogClipboard.shared.copyFood(invalid)
        let failed = model.pasteIntoSelectedDay()
        XCTAssertEqual(failed.count, 0)
        XCTAssertNotNil(failed.error)
        XCTAssertEqual(model.totals.entryCount, 0)
        XCTAssertEqual(try fixture.logs.dayTotals(destination).entryCount, 0)
    }

    func testPartialBlockReportsOnlyPersistedEntriesAndError() throws {
        let fixture = try Fixture()
        let destination = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: fixture.day))
        let egg = try fixture.food(name: "Egg", calories: 120)
        let good = try fixture.logs.logFood(
            egg, grams: 100, mealSlot: .breakfast,
            timestamp: fixture.time(on: fixture.day, hour: 11, minute: 5),
            note: nil, source: .manualSearch
        )
        let bad = LogEntry(
            timestamp: fixture.time(on: fixture.day, hour: 11, minute: 42),
            dayStart: fixture.day, food: egg, foodName: egg.name, grams: -1
        )
        FoodLogClipboard.shared.copyBlock(label: "11 AM", entries: [good, bad])
        let model = fixture.model(selectedDay: destination)
        let result = model.pasteIntoSelectedDay()
        XCTAssertEqual(result.count, 1)
        XCTAssertNotNil(result.error)
        XCTAssertEqual(model.totals.entryCount, 1)
        XCTAssertEqual(model.totals.calories, 120, accuracy: 0.001)
        XCTAssertEqual(try fixture.logs.dayTotals(fixture.day).entryCount, 1)
    }

    func testNonexistentDestinationClockTimeFallsBackToDayStart() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let source = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 3, day: 7, hour: 2, minute: 30
        )))
        let destination = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 3, day: 8
        )))
        let snapshot = FoodLogClipboard.EntrySnapshot(
            foodName: "Egg", grams: 100, sourceTimestamp: source
        )

        XCTAssertEqual(
            FoodLogViewModel.destinationTimestamp(for: snapshot, on: destination, calendar: calendar),
            destination
        )
    }
}

@MainActor
private final class Fixture {
    let container: ModelContainer
    let context: ModelContext
    let logs: SwiftDataLogRepository
    let foods: SwiftDataFoodRepository
    let program: SwiftDataProgramRepository
    let day = Calendar.current.startOfDay(for: Date())

    init() throws {
        FoodLogClipboard.shared.clear()
        container = try MFModelContainerFactory.makeContainer(inMemory: true)
        context = ModelContext(container)
        logs = SwiftDataLogRepository(context: context)
        foods = SwiftDataFoodRepository(context: context)
        program = SwiftDataProgramRepository(context: context)
    }

    func food(name: String, calories: Double) throws -> FoodItem {
        try foods.saveFood(name: name, nutrientsPer100g: [.calories: calories], source: .seedDatabase)
    }

    func time(on day: Date, hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    func model(selectedDay: Date) -> FoodLogViewModel {
        FoodLogViewModel(logs: logs, foods: foods, program: program, selectedDay: selectedDay)
    }

    func reopenedModel(selectedDay: Date) -> FoodLogViewModel {
        let reopenedContext = ModelContext(container)
        return FoodLogViewModel(
            logs: SwiftDataLogRepository(context: reopenedContext),
            foods: SwiftDataFoodRepository(context: reopenedContext),
            program: SwiftDataProgramRepository(context: reopenedContext),
            selectedDay: selectedDay
        )
    }
}
