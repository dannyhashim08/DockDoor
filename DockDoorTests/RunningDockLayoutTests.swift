import AppKit
@testable import DockDoor
import XCTest

final class RunningDockLayoutTests: XCTestCase {
    func testCentersOnOffsetDisplay() {
        let screen = CGRect(x: -1440, y: 90, width: 1440, height: 810)
        let frame = RunningDockLayout.frame(in: screen, appCount: 4)
        XCTAssertEqual(frame.midX, screen.midX)
        XCTAssertEqual(frame.minY, screen.minY + 8)
        XCTAssertEqual(frame.width, 216)
    }

    func testOverflowStaysInsideRotatedDisplay() {
        let screen = CGRect(x: 1920, y: -500, width: 720, height: 1280)
        let frame = RunningDockLayout.frame(in: screen, appCount: 100)
        XCTAssertTrue(screen.contains(frame))
        XCTAssertEqual(frame.width, screen.width - 16)
    }
}
