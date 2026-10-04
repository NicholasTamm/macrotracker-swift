import XCTest
import Vision

final class FoodTimelineNameTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testLoggedFoodsWithFallbackThumbnailsHaveVisibleNamesAfterRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-mf.hasCompletedOnboarding", "YES",
            "-issue4FoodTileFixture",
        ]
        app.launch()
        openFoodLog(in: app)

        // The DEBUG launch fixture saves both foods and entries through the
        // production repositories. Their fallback thumbnails are identical.
        try assertTimelineNames(in: app, phase: "Immediate")

        app.terminate()
        app.launch()
        openFoodLog(in: app)
        try assertTimelineNames(in: app, phase: "After relaunch")
    }

    private func openFoodLog(in app: XCUIApplication) {
        let tab = app.tabBars.buttons["Food Log"]
        XCTAssertTrue(tab.waitForExistence(timeout: 30), "Food Log tab did not load")
        tab.tap()
    }

    private func assertTimelineNames(in app: XCUIApplication, phase: String) throws {
        for name in ["QA4 Yogurt plain nonfat", "QA4 Yogurt plain whole"] {
            let entry = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", name)
            ).firstMatch
            XCTAssertTrue(entry.waitForExistence(timeout: 10), "Missing timeline entry: \(name)")
            XCTAssertEqual(entry.label.components(separatedBy: name).count - 1, 1,
                           "VoiceOver entry identity should not be repeated")
            XCTAssertTrue(entry.label.contains("calories"), "Entry should announce calories")
        }

        let text = try recognizedText(in: app.screenshot())
        XCTAssertTrue(text.localizedCaseInsensitiveContains("nonfat"),
                      "First food's distinguishing word is not visible: \(text)")
        attachTimelineScreenshot(from: app, named: "\(phase) before horizontal scroll")
        app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@", "QA4 Yogurt plain nonfat"
        )).firstMatch.swipeLeft()
        let scrolledText = try recognizedText(in: app.screenshot())
        XCTAssertTrue(scrolledText.localizedCaseInsensitiveContains("whole"),
                      "Second food's distinguishing word is not visible after scrolling: \(scrolledText)")
        attachTimelineScreenshot(from: app, named: "\(phase) after horizontal scroll")

        let secondEntry = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@", "QA4 Yogurt plain whole"
        )).firstMatch
        XCTAssertTrue(secondEntry.isHittable, "Second entry should be tappable after scrolling")
        XCTAssertGreaterThanOrEqual(secondEntry.frame.width, 44)
        secondEntry.tap()
        XCTAssertTrue(app.navigationBars["Edit entry"].waitForExistence(timeout: 10))
        app.buttons["Cancel"].tap()
    }

    private func recognizedText(in screenshot: XCUIScreenshot) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try VNImageRequestHandler(data: screenshot.pngRepresentation).perform([request])
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")
    }

    private func attachTimelineScreenshot(from app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
