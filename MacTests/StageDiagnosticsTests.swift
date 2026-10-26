import XCTest

final class StageDiagnosticsTests: XCTestCase {
    func testDisabledCollectorProducesNoSamples() {
        let collector = StageDiagnostics(enabled: false)
        collector.record("encodeMs", 123)
        XCTAssertTrue((collector.snapshot(role: "sender")["stages"] as! [String: Any]).isEmpty)
    }

    func testSnapshotRejectsInvalidSamplesAndDrainsWindow() {
        let collector = StageDiagnostics(enabled: true)
        for value in [1.0, 5, 100, -.infinity, .nan, -1] {
            collector.record("encodeMs", value)
        }
        let report = collector.snapshot(role: "sender")
        let stages = report["stages"] as! [String: Any]
        let encode = stages["encodeMs"] as! [String: Any]
        XCTAssertEqual(encode["n"] as? Int, 3)
        XCTAssertEqual(encode["max"] as? Double, 100)
        XCTAssertEqual(encode["over50"] as? Int, 1)
        XCTAssertTrue((collector.snapshot(role: "sender")["stages"] as! [String: Any]).isEmpty)
        XCTAssertTrue(JSONSerialization.isValidJSONObject(report))
    }

    func testWindowMemoryIsBounded() {
        let collector = StageDiagnostics(enabled: true)
        for _ in 0..<5000 { collector.record("cursorReceiveGapMs", 8) }
        let stages = collector.snapshot(role: "receiver")["stages"] as! [String: Any]
        XCTAssertEqual((stages["cursorReceiveGapMs"] as! [String: Any])["n"] as? Int, 4096)
    }
}
