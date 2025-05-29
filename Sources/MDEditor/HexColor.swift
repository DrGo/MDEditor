// Defines a Codable struct for robust HEX color parsing and representation.

import Foundation
import SwiftUI // For MColor typealias resolution if used here, or ensure global

// Assuming MColor is accessible (e.g., defined in MarkdownContentRenderer.swift)

public struct HexColor: Codable, Equatable, Hashable, Sendable, CustomStringConvertible, LosslessStringConvertible {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8
    // Alpha is not handled in this version for storage, defaults to 1.0 (opaque) when converting to MColor

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    // MARK: - LosslessStringConvertible Conformance
    public init?(_ description: String) {
        let raw = description.trimmingCharacters(in: .whitespacesAndNewlines)
        var cleaned = raw.hasPrefix("#") ? String(raw.dropFirst()) : raw

        // Handle 8-digit hex (RRGGBBAA) by taking only the RGB part for this struct
        if cleaned.count == 8 {
            cleaned = String(cleaned.prefix(6))
        }

        let hex: String
        var tempRed: UInt8?
        var tempGreen: UInt8?
        var tempBlue: UInt8?

        switch cleaned.count {
        case 3: // Expand shorthand "RGB" => "RRGGBB"
            hex = cleaned.map { "\($0)\($0)" }.joined()
            if hex.count == 6 { // Ensure expansion was successful
                 if let rgb = UInt32(hex, radix: 16) {
                    tempRed = UInt8((rgb >> 16) & 0xFF)
                    tempGreen = UInt8((rgb >> 8) & 0xFF)
                    tempBlue = UInt8(rgb & 0xFF)
                }
            }
        case 6: // Standard "RRGGBB"
            hex = cleaned
            if let rgb = UInt32(hex, radix: 16) {
                tempRed = UInt8((rgb >> 16) & 0xFF)
                tempGreen = UInt8((rgb >> 8) & 0xFF)
                tempBlue = UInt8(rgb & 0xFF)
            }
        // Case 8 is handled by truncating 'cleaned' string above.
        default:
            return nil // Invalid length after potential truncation
        }

        guard let r = tempRed, let g = tempGreen, let b = tempBlue else {
            return nil // Parsing failed
        }
        self.red = r
        self.green = g
        self.blue = b
    }

    // MARK: - Codable Conformance
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawString = try container.decode(String.self)
        
        guard let initializedColor = HexColor(rawString) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid hex color string format: \(rawString)")
        }
        self = initializedColor
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(format: "#%02x%02x%02x", red, green, blue))
    }

    // MARK: - CustomStringConvertible Conformance
    public var description: String {
        return String(format: "#%02x%02x%02x", red, green, blue)
    }

    // MARK: - MColor Conversion
    public var mColor: MColor {
        let r = CGFloat(red) / 255.0
        let g = CGFloat(green) / 255.0
        let b = CGFloat(blue) / 255.0
        #if canImport(UIKit)
        return MColor(red: r, green: g, blue: b, alpha: 1.0)
        #elseif canImport(AppKit)
        return MColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
        #else
        return MColor()
        #endif
    }
}

