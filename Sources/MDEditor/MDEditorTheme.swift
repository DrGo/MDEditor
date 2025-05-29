// MDEditorTheme.swift
// Defines the structure for a theme, including global settings and specific element styles.

import SwiftUI // For CGFloat, LayoutDirection

// HexColor struct is defined in HexColor.swift
// MarkdownElementStyle struct is defined in MarkdownElementStyle.swift and be Sendable.
// TextDirection enum is defined in TextDirection.swift

/// Represents a complete theme for rendering Markdown.
public struct MDEditorTheme: Codable, Identifiable, Equatable, Sendable {
    public var id: String { name } // Use theme name as a unique identifier
    public var name: String
    public var author: String?
    public var description: String?

    // MARK: - Global Theme Settings
    public var layoutDirection: TextDirection?
    public var globalFontName: String?
    public var globalBaseFontSize: CGFloat?
    public var globalTextColor: HexColor?
    public var globalBackgroundColor: HexColor?
    public var globalAccentColor: HexColor?

    // MARK: - Element Styles
    public var defaultElementStyle: MarkdownElementStyle?
    public var elementStyles: [String: MarkdownElementStyle]?

    // MARK: - Initializer
    public init(
        name: String,
        author: String? = nil,
        description: String? = nil,
        layoutDirection: TextDirection? = .leftToRight,
        globalFontName: String? = nil,
        globalBaseFontSize: CGFloat? = nil,
        globalTextColor: HexColor? = nil,
        globalBackgroundColor: HexColor? = nil,
        globalAccentColor: HexColor? = nil,
        defaultElementStyle: MarkdownElementStyle? = nil,
        elementStyles: [String: MarkdownElementStyle]? = nil
    ) {
        self.name = name
        self.author = author
        self.description = description
        self.layoutDirection = layoutDirection
        self.globalFontName = globalFontName
        self.globalBaseFontSize = globalBaseFontSize
        self.globalTextColor = globalTextColor
        self.globalBackgroundColor = globalBackgroundColor
        self.globalAccentColor = globalAccentColor
        self.defaultElementStyle = defaultElementStyle
        self.elementStyles = elementStyles
    }
    

    // MARK: - Internal Default Theme
    public static let internalDefault: MDEditorTheme = {
     
        let fallbackElementStyle = MarkdownElementStyle(
            fontName: nil,       // Will inherit from globalFontName (which is also nil, so system font)
            fontSize: nil,       // MODIFIED: Will inherit from globalBaseFontSize (16.0 below)
            isBold: false,
            isItalic: false,
            foregroundColor: nil, // MODIFIED: Will inherit from globalTextColor (#333333 below)
            paragraphSpacingBefore: 5,
            paragraphSpacingAfter: 10,
            lineHeightMultiplier: 1.2,
            alignment: "natural"
        )

        var elementSpecificStyles: [String: MarkdownElementStyle] = [:]
        // For element-specific styles, if fontSize is not set, it will fallback to
        // defaultElementStyle.fontSize (now nil), then to globalBaseFontSize.
        // The headingBaseSize calculation here is a bit redundant if defaultElementStyle.fontSize is nil,
        // as it would effectively use the globalBaseFontSize for scaling.
        // However, keeping it allows for a future scenario where defaultElementStyle.fontSize might be set.
        let headingBaseSize: CGFloat = fallbackElementStyle.fontSize ?? 16.0 // Fallback to 16 if defaultElementStyle.fontSize is nil (which it is now)

        elementSpecificStyles[MarkdownElementKey.paragraph.rawValue] = MarkdownElementStyle() // Empty, will fully use defaultElementStyle then globals

        elementSpecificStyles[MarkdownElementKey.heading1.rawValue] = MarkdownElementStyle(fontSize: headingBaseSize * 2.0, isBold: true)
        elementSpecificStyles[MarkdownElementKey.heading2.rawValue] = MarkdownElementStyle(fontSize: headingBaseSize * 1.8, isBold: true)
        elementSpecificStyles[MarkdownElementKey.heading3.rawValue] = MarkdownElementStyle(fontSize: headingBaseSize * 1.6, isBold: true)
        elementSpecificStyles[MarkdownElementKey.heading4.rawValue] = MarkdownElementStyle(fontSize: headingBaseSize * 1.4, isBold: true)
        elementSpecificStyles[MarkdownElementKey.heading5.rawValue] = MarkdownElementStyle(fontSize: headingBaseSize * 1.2, isBold: true)
        elementSpecificStyles[MarkdownElementKey.heading6.rawValue] = MarkdownElementStyle(fontSize: headingBaseSize * 1.1, isBold: true)

        elementSpecificStyles[MarkdownElementKey.link.rawValue] = MarkdownElementStyle(foregroundColor: HexColor(red: 0x00, green: 0x7A, blue: 0xFF)) // #007AFF Blue
        elementSpecificStyles[MarkdownElementKey.emphasis.rawValue] = MarkdownElementStyle(isItalic: true)
        elementSpecificStyles[MarkdownElementKey.strong.rawValue] = MarkdownElementStyle(isBold: true)
        elementSpecificStyles[MarkdownElementKey.strikethrough.rawValue] = MarkdownElementStyle(strikethrough: true)
        
        elementSpecificStyles[MarkdownElementKey.inlineCode.rawValue] = MarkdownElementStyle(
            fontName: "Menlo", // Specific font for inline code
            fontSize: (fallbackElementStyle.fontSize ?? 16.0) * 0.9, // Scale based on effective base
            isItalic: false,
            foregroundColor: HexColor(red: 0xD1, green: 0x2F, blue: 0x1B), // #D12F1B Reddish
            backgroundColor: HexColor(red: 0xF6, green: 0xF8, blue: 0xFA)  // #F6F8FA Light Gray
        )
        elementSpecificStyles[MarkdownElementKey.codeBlock.rawValue] = MarkdownElementStyle(
            fontName: "Menlo", // Specific font for code blocks
            fontSize: (fallbackElementStyle.fontSize ?? 16.0) * 0.9, // Scale based on effective base
            isItalic: false,
            foregroundColor: HexColor(red: 0x33, green: 0x33, blue: 0x33), // #333333 Dark Gray text on light bg
            backgroundColor: HexColor(red: 0xF6, green: 0xF8, blue: 0xFA),  // #F6F8FA Light Gray background
            paragraphSpacingBefore: 8, paragraphSpacingAfter: 8
        )
        elementSpecificStyles[MarkdownElementKey.blockquote.rawValue] = MarkdownElementStyle(
            isItalic: true, foregroundColor: HexColor(red: 0x58, green: 0x60, blue: 0x69), // #586069 Muted Gray
            firstLineHeadIndent: 20, headIndent: 20
        )
        elementSpecificStyles[MarkdownElementKey.listItem.rawValue] = MarkdownElementStyle(paragraphSpacingBefore: 2, paragraphSpacingAfter: 2)


        return MDEditorTheme(
            name: "Internal Default",
            author: "MDEditor Package",
            description: "A basic, hardcoded theme for fallback.",
            layoutDirection: .leftToRight,
            globalFontName: nil, // System font will be used by default
            globalBaseFontSize: 16.0, // Default base font size
            globalTextColor: HexColor(red: 0x33, green: 0x33, blue: 0x33),     // #333333 Dark Gray
            globalBackgroundColor: nil, // No global background color by default
            globalAccentColor: HexColor(red: 0x00, green: 0x7A, blue: 0xFF),   // #007AFF Blue
            defaultElementStyle: fallbackElementStyle, // This now has nil for fontSize and foregroundColor
            elementStyles: elementSpecificStyles
        )
    }()
}

public enum MarkdownElementKey: String, CaseIterable, Codable {
    case paragraph
    case heading1, heading2, heading3, heading4, heading5, heading6
    case list
    case listItem
    case blockquote
    case codeBlock
    case inlineCode
    case link
    case emphasis
    case strong
    case strikethrough
    case image
    case thematicBreak
}

