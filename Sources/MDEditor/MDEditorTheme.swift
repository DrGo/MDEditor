// MDEditorTheme.swift
// Defines the structure for a theme, including global settings and specific element styles.

import SwiftUI // For CGFloat, LayoutDirection
import Foundation // For UUID

// Note: FrontMatterData is now defined in YamlParser.swift
// HexColor, TextDirection, MarkdownElementStyle are defined in their respective files.

/// Keys for identifying different Markdown elements to apply specific styles.
public enum MarkdownElementKey: String, CaseIterable, Codable {
    case paragraph
    case heading1, heading2, heading3, heading4, heading5, heading6
    case list // Represents the overall list style (e.g., indent size)
    case listItem // Represents individual list items, including their markers
    case blockquote
    case codeBlock
    case inlineCode
    case link
    case emphasis // Typically italic
    case strong   // Typically bold
    case strikethrough
    case image
    case thematicBreak // Horizontal Rule
}

/// Represents a complete theme for rendering Markdown.
public struct MDEditorTheme: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var frontMatter: FrontMatterData // This type is from YamlParser.swift

    // MARK: - Global Theme Settings
    public var layoutDirection: TextDirection?
    public var globalFontName: String?
    public var globalBaseFontSize: CGFloat?
    public var globalTextColor: HexColor?
    public var globalBackgroundColor: HexColor?
    public var globalAccentColor: HexColor?

    // MARK: - Element Styles
    public var defaultElementStyle: MarkdownElementStyle?
    public var elementStyles: [String: MarkdownElementStyle]? // Keys are MarkdownElementKey.rawValue

    // MARK: - Initializer
    public init(
        id: String = UUID().uuidString,
        frontMatter: FrontMatterData,
        layoutDirection: TextDirection? = .leftToRight,
        globalFontName: String? = nil,
        globalBaseFontSize: CGFloat? = nil,
        globalTextColor: HexColor? = nil,
        globalBackgroundColor: HexColor? = nil,
        globalAccentColor: HexColor? = nil,
        defaultElementStyle: MarkdownElementStyle? = nil,
        elementStyles: [String: MarkdownElementStyle]? = nil
    ) {
        self.id = id
        self.frontMatter = frontMatter
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
        let defaultFrontMatter = FrontMatterData(
            title: "Internal Default",
            author: "MDEditor Package",
            description: "A basic, hardcoded theme for fallback."
        )
     
        let fallbackElementStyle = MarkdownElementStyle(
            fontName: nil, fontSize: nil, isBold: false, isItalic: false, foregroundColor: nil,
            paragraphSpacingBefore: 5, paragraphSpacingAfter: 10, lineHeightMultiplier: 1.2,
            alignment: "natural"
        )

        var elementSpecificStyles: [String: MarkdownElementStyle] = [:]
        let headingBaseSize: CGFloat = 16.0 
        elementSpecificStyles[MarkdownElementKey.paragraph.rawValue] = MarkdownElementStyle()
        elementSpecificStyles[MarkdownElementKey.heading1.rawValue] = MarkdownElementStyle(fontSize: headingBaseSize * 2.0, isBold: true)
        elementSpecificStyles[MarkdownElementKey.heading2.rawValue] = MarkdownElementStyle(fontSize: headingBaseSize * 1.8, isBold: true)
        elementSpecificStyles[MarkdownElementKey.heading3.rawValue] = MarkdownElementStyle(fontSize: headingBaseSize * 1.6, isBold: true)
        elementSpecificStyles[MarkdownElementKey.heading4.rawValue] = MarkdownElementStyle(fontSize: headingBaseSize * 1.4, isBold: true)
        elementSpecificStyles[MarkdownElementKey.heading5.rawValue] = MarkdownElementStyle(fontSize: headingBaseSize * 1.2, isBold: true)
        elementSpecificStyles[MarkdownElementKey.heading6.rawValue] = MarkdownElementStyle(fontSize: headingBaseSize * 1.1, isBold: true)
        elementSpecificStyles[MarkdownElementKey.link.rawValue] = MarkdownElementStyle(foregroundColor: HexColor("007AFF"))
        elementSpecificStyles[MarkdownElementKey.emphasis.rawValue] = MarkdownElementStyle(isItalic: true)
        elementSpecificStyles[MarkdownElementKey.strong.rawValue] = MarkdownElementStyle(isBold: true)
        elementSpecificStyles[MarkdownElementKey.strikethrough.rawValue] = MarkdownElementStyle(strikethrough: true)
        elementSpecificStyles[MarkdownElementKey.inlineCode.rawValue] = MarkdownElementStyle(fontName: "Menlo", fontSize: headingBaseSize * 0.9, foregroundColor: HexColor("D12F1B"), backgroundColor: HexColor("F6F8FA"))
        elementSpecificStyles[MarkdownElementKey.codeBlock.rawValue] = MarkdownElementStyle(fontName: "Menlo", fontSize: headingBaseSize * 0.9, foregroundColor: HexColor("333333"), backgroundColor: HexColor("F6F8FA"), paragraphSpacingBefore: 8, paragraphSpacingAfter: 8)
        elementSpecificStyles[MarkdownElementKey.blockquote.rawValue] = MarkdownElementStyle(isItalic: true, foregroundColor: HexColor("586069"), firstLineHeadIndent: 20, headIndent: 20)
        elementSpecificStyles[MarkdownElementKey.listItem.rawValue] = MarkdownElementStyle(paragraphSpacingBefore: 2, paragraphSpacingAfter: 2)
        elementSpecificStyles[MarkdownElementKey.thematicBreak.rawValue] = MarkdownElementStyle(foregroundColor: HexColor("CCCCCC"), paragraphSpacingBefore:10, paragraphSpacingAfter:10) // Example for thematic break
        elementSpecificStyles[MarkdownElementKey.image.rawValue] = MarkdownElementStyle(alignment: "center") // Example for image


        return MDEditorTheme(
            frontMatter: defaultFrontMatter,
            layoutDirection: .leftToRight,
            globalFontName: nil, 
            globalBaseFontSize: 16.0,
            globalTextColor: HexColor("333333"), 
            globalBackgroundColor: nil, 
            globalAccentColor: HexColor("007AFF"),
            defaultElementStyle: fallbackElementStyle, 
            elementStyles: elementSpecificStyles
        )
    }()
}

// Other dependent type definitions (HexColor, TextDirection, MarkdownElementStyle)
// are assumed to be in their respective files and accessible.
