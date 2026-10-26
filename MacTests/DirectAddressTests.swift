import XCTest

final class DirectAddressTests: XCTestCase {
    func testNumericAddresses() {
        XCTAssertEqual(DirectAddress(host: " 10.2.3.4 ", port: "9000")?.host, "10.2.3.4")
        XCTAssertEqual(DirectAddress(host: "[2001:db8::1]", port: "9000")?.host, "2001:db8::1")
        XCTAssertNotNil(DirectAddress(host: "fe80::1%en0", port: "65535"))
    }

    func testRejectsBonjourPeerToPeerAndInvalidPorts() {
        for host in ["", "ipad.local", "10.2.3.4:9000", "fe80::1%awdl0", "fe80::1%llw0", "fe80::1%"] {
            XCTAssertNil(DirectAddress(host: host, port: "9000"), host)
        }
        for port in ["0", "-1", "65536", "abc", ""] {
            XCTAssertNil(DirectAddress(host: "10.2.3.4", port: port), port)
        }
    }
}
