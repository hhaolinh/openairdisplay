import Foundation
import Network

/// Numeric addresses bypass mDNS, which may be blocked on managed Wi-Fi.
/// Reject peer-to-peer scopes so this entry point tests the LAN path only.
struct DirectAddress {
    let host: String
    let port: UInt16

    init?(host: String, port: String) {
        var host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.hasPrefix("["), host.hasSuffix("]") {
            host = String(host.dropFirst().dropLast())
        }
        let parts = host.split(separator: "%", omittingEmptySubsequences: false)
        guard parts.count <= 2, let address = parts.first,
              IPv4Address(String(address)) != nil || IPv6Address(String(address)) != nil,
              parts.count == 1 || (!parts[1].isEmpty
                  && !isPeerToPeerWiFiInterface(String(parts[1]))),
              let port = UInt16(port.trimmingCharacters(in: .whitespacesAndNewlines)),
              port > 0 else { return nil }
        self.host = host
        self.port = port
    }
}
