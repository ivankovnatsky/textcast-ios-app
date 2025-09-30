@testable import TextCastApp
import XCTest

final class TextCastAppTests: XCTestCase {
    func testQueueItemProgressText() {
        let item = QueueItem(
            id: "test",
            title: "Test Book",
            author: "Test Author",
            coverURL: nil,
            progress: 0.5,
            currentTime: 1800, // 30 minutes
            totalDuration: 3600 // 60 minutes
        )

        XCTAssertTrue(item.progressText.contains("30m"))
        XCTAssertTrue(item.progressText.contains("60m"))
        XCTAssertTrue(item.progressText.contains("50%"))
    }

    func testQueueItemProgressWithHours() {
        let item = QueueItem(
            id: "test",
            title: "Test Book",
            author: "Test Author",
            coverURL: nil,
            progress: 0.25,
            currentTime: 3600, // 1 hour
            totalDuration: 14400 // 4 hours
        )

        XCTAssertTrue(item.progressText.contains("1h"))
        XCTAssertTrue(item.progressText.contains("4h"))
        XCTAssertTrue(item.progressText.contains("25%"))
    }
}
