// Defines the structure for a theme and its conversion to StyleConfiguration.

import SwiftUI
import Yams // For Codable support with YAML


// MARK: - Theme Structure (Codable for YAML parsing)

public struct MDEditorTheme: Codable, Identifiable, Equatable {
    public var id: String { name } // Use theme name as a unique identifier
    public var name: String
    public var author: String?
    public var description: String?

    // Base font settings
    public var baseFontSize: CGFloat?
    public var baseFontName: String?

    // Text colors (as Hex strings in YAML, converted to MColor)
    // We'll need a helper to convert hex strings to MColor.
    public var textColorHex: String?
    public var linkColorHex: String?
    public var codeForegroundColorHex: String?
    public var codeBlockBackgroundColorHex: String?
    public var blockquoteColorHex: String?

    // Font scaling and style properties
    public var codeFontScale: CGFloat?
    public var headingScales: [CGFloat]? // H1 to H6 relative to baseFontSize
    public var blockquoteItalic: Bool?

    // Layout properties (optional in theme, can be overridden by MDEditorView)
    public var listIndentPerLevel: CGFloat?
    public var blockquoteIndentPerLevel: CGFloat?
    // Note: layoutDirection is typically controlled by MDEditorView's UI,
    // but a theme could provide a default if desired.

    enum CodingKeys: String, CodingKey {
        case name, author, description
        case baseFontSize, baseFontName
        case textColorHex = "textColor" // Map YAML key "textColor" to textColorHex
        case linkColorHex = "linkColor"
        case codeForegroundColorHex = "codeForegroundColor"
        case codeBlockBackgroundColorHex = "codeBlockBackgroundColor"
        case blockquoteColorHex = "blockquoteColor"
        case codeFontScale, headingScales, blockquoteItalic
        case listIndentPerLevel, blockquoteIndentPerLevel
    }

    // Default initializer
    public init(name: String, author: String? = nil, description: String? = nil, baseFontSize: CGFloat? = nil, baseFontName: String? = nil, textColorHex: String? = nil, linkColorHex: String? = nil, codeForegroundColorHex: String? = nil, codeBlockBackgroundColorHex: String? = nil, blockquoteColorHex: String? = nil, codeFontScale: CGFloat? = nil, headingScales: [CGFloat]? = nil, blockquoteItalic: Bool? = nil, listIndentPerLevel: CGFloat? = nil, blockquoteIndentPerLevel: CGFloat? = nil) {
        self.name = name
        self.author = author
        self.description = description
        self.baseFontSize = baseFontSize
        self.baseFontName = baseFontName
        self.textColorHex = textColorHex
        self.linkColorHex = linkColorHex
        self.codeForegroundColorHex = codeForegroundColorHex
        self.codeBlockBackgroundColorHex = codeBlockBackgroundColorHex
        self.blockquoteColorHex = blockquoteColorHex
        self.codeFontScale = codeFontScale
        self.headingScales = headingScales
        self.blockquoteItalic = blockquoteItalic
        self.listIndentPerLevel = listIndentPerLevel
        self.blockquoteIndentPerLevel = blockquoteIndentPerLevel
    }


    // MARK: - Conversion to StyleConfiguration
    
    /// Converts this theme into a `MarkdownContentRenderer.StyleConfiguration`.
    /// - Parameter existingConfiguration: An optional existing configuration to use as a base for defaults.
    /// - Returns: A `StyleConfiguration` instance based on the theme.
    public func toStyleConfiguration(
        baseDefaults: MarkdownContentRenderer.StyleConfiguration = .init()
    ) -> MarkdownContentRenderer.StyleConfiguration {
        
        var newConfig = baseDefaults

        // Apply theme values, falling back to baseDefaults if theme property is nil.
        newConfig.baseFontSize = self.baseFontSize ?? baseDefaults.baseFontSize
        newConfig.baseFontName = self.baseFontName // Can be nil to use system font
        
        newConfig.codeFontScale = self.codeFontScale ?? baseDefaults.codeFontScale
        newConfig.headingScales = self.headingScales ?? baseDefaults.headingScales
        newConfig.blockquoteItalic = self.blockquoteItalic ?? baseDefaults.blockquoteItalic
        
        newConfig.listIndentPerLevel = self.listIndentPerLevel ?? baseDefaults.listIndentPerLevel
        newConfig.blockquoteIndentPerLevel = self.blockquoteIndentPerLevel ?? baseDefaults.blockquoteIndentPerLevel

        // Color conversion (requires MColor.fromHex helper)
        if let hex = textColorHex, let color = MColor.fromHex(hex) { newConfig.textColor = color }
        if let hex = linkColorHex, let color = MColor.fromHex(hex) { newConfig.linkColor = color }
        if let hex = codeForegroundColorHex, let color = MColor.fromHex(hex) { newConfig.codeForegroundColor = color }
        if let hex = codeBlockBackgroundColorHex, let color = MColor.fromHex(hex) { newConfig.codeBlockBackgroundColor = color }
        if let hex = blockquoteColorHex, let color = MColor.fromHex(hex) { newConfig.blockquoteColor = color }
        
        // layoutDirection is typically controlled by MDEditorView's UI,
        // so it's not directly set from the theme here to avoid conflicts.
        // If a theme were to provide a default, MDEditorView would need to decide how to use it.

        return newConfig
    }
}

