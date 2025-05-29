// Defines a Codable enum for text layout direction.

import Foundation

/// Represents the text layout direction, supporting common values for LTR and RTL.
/// This enum is Codable to allow easy parsing from theme files (e.g., YAML).
public enum TextDirection: String, Codable, Equatable, Hashable, Sendable, LosslessStringConvertible, CustomStringConvertible {
    case rightToLeft = "rtl"
    case leftToRight = "ltr"

    // MARK: - LosslessStringConvertible Conformance
    public init?(_ description: String) {
        switch description.lowercased() {
        case "rtl":
            self = .rightToLeft
        case "ltr":
            self = .leftToRight
        default:
            return nil
        }
    }
    
    // MARK: - CustomStringConvertible Conformance
    public var description: String {
        return self.rawValue
    }
    
    // MARK: - Custom Codable Conformance (Maintained for robustness if direct decoding is used)
//    /// Custom error for decoding issues.
//    enum CodingError: Error { // This specific error is for the Codable path.
//        case invalidValue(String)
//    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValueString = try container.decode(String.self)

        guard let direction = TextDirection(rawValueString) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid TextDirection value: '\(rawValueString)'. Expected 'ltr' or 'rtl'.")
        }
        self = direction
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

