import Foundation

enum FingerprintFormatter {
    /// `47a231d1b6b2…` → `47A2 31D1 B6B2 …`
    static func format(_ fingerprint: String) -> String {
        stride(from: 0, to: fingerprint.count, by: 4)
            .map { offset in
                let start = fingerprint.index(fingerprint.startIndex, offsetBy: offset)
                let end = fingerprint.index(start, offsetBy: 4, limitedBy: fingerprint.endIndex) ?? fingerprint.endIndex
                return fingerprint[start..<end].uppercased()
            }
            .joined(separator: " ")
    }
}
