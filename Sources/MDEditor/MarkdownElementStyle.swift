// MarkdownElementStyle.swift
// Defines the style properties for a single Markdown element within a theme.

import SwiftUI // For CGFloat

/// Represents the style for a specific Markdown element.
/// All properties are optional, allowing for sparse definitions in themes, 
/// where unspecified properties can inherit from a default element style or global settings.
public struct MarkdownElementStyle: Codable, Equatable, Sendable {
    // Font properties
    public var fontName: String?
    public var fontSize: CGFloat? // Absolute font size
    public var isBold: Bool?
    public var isItalic: Bool?

    // Color properties (Hex strings from YAML)
    public var foregroundColor: HexColor?
    public var backgroundColor: HexColor? // E.g., for code blocks

    // Text decorations
    public var strikethrough: Bool?
    public var underline: Bool?

    // Paragraph properties
    public var paragraphSpacingBefore: CGFloat?
    public var paragraphSpacingAfter: CGFloat?
    public var lineHeightMultiplier: CGFloat?
    public var firstLineHeadIndent: CGFloat?
    public var headIndent: CGFloat?
    public var tailIndent: CGFloat?
    
    public var kerning: CGFloat?
    public var alignment: String? // "left", "center", "right", "justified", "natural"

    public init(
        fontName: String? = nil,
        fontSize: CGFloat? = nil,
        isBold: Bool? = nil,
        isItalic: Bool? = nil,
        foregroundColor: HexColor? = nil,
        backgroundColor: HexColor? = nil,
        strikethrough: Bool? = nil,
        underline: Bool? = nil,
        paragraphSpacingBefore: CGFloat? = nil,
        paragraphSpacingAfter: CGFloat? = nil,
        lineHeightMultiplier: CGFloat? = nil,
        firstLineHeadIndent: CGFloat? = nil,
        headIndent: CGFloat? = nil,
        tailIndent: CGFloat? = nil,
        kerning: CGFloat? = nil,
        alignment: String? = nil
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.isBold = isBold
        self.isItalic = isItalic
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.strikethrough = strikethrough
        self.underline = underline
        self.paragraphSpacingBefore = paragraphSpacingBefore
        self.paragraphSpacingAfter = paragraphSpacingAfter
        self.lineHeightMultiplier = lineHeightMultiplier
        self.firstLineHeadIndent = firstLineHeadIndent
        self.headIndent = headIndent
        self.tailIndent = tailIndent
        self.kerning = kerning
        self.alignment = alignment
    }

    public func merging(over other: MarkdownElementStyle) -> MarkdownElementStyle {
        return MarkdownElementStyle(
            fontName: self.fontName ?? other.fontName,
            fontSize: self.fontSize ?? other.fontSize,
            isBold: self.isBold ?? other.isBold,
            isItalic: self.isItalic ?? other.isItalic,
            foregroundColor: self.foregroundColor ?? other.foregroundColor,
            backgroundColor: self.backgroundColor ?? other.backgroundColor,
            strikethrough: self.strikethrough ?? other.strikethrough,
            underline: self.underline ?? other.underline,
            paragraphSpacingBefore: self.paragraphSpacingBefore ?? other.paragraphSpacingBefore,
            paragraphSpacingAfter: self.paragraphSpacingAfter ?? other.paragraphSpacingAfter,
            lineHeightMultiplier: self.lineHeightMultiplier ?? other.lineHeightMultiplier,
            firstLineHeadIndent: self.firstLineHeadIndent ?? other.firstLineHeadIndent,
            headIndent: self.headIndent ?? other.headIndent,
            tailIndent: self.tailIndent ?? other.tailIndent,
            kerning: self.kerning ?? other.kerning,
            alignment: self.alignment ?? other.alignment
        )
    }
}

