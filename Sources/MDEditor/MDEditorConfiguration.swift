// MDEditorConfiguration.swift
// Defines the configuration options for the editor in Edit mode.

import SwiftUI

// TextDirection enum is expected to be defined in TextDirection.swift
// MColor typealias is expected to be defined elsewhere (e.g., MarkdownContentRenderer.swift)

public struct MDEditorConfiguration: Equatable, Hashable, Sendable { // Added Hashable and Sendable
    public var editorFontName: String?
    public var editorFontSize: CGFloat
    public var editorTextColor: MColor
    public var editorBackgroundColor: MColor
    public var editorLineSpacing: CGFloat
    public var editorDefaultIndentWidth: CGFloat
    public var editorLayoutDirection: TextDirection // Changed to use custom TextDirection

    public init(
        editorFontName: String? = nil,
        editorFontSize: CGFloat? = nil,
        editorTextColor: MColor? = nil,
        editorBackgroundColor: MColor? = nil,
        editorLineSpacing: CGFloat = 2.0,
        editorDefaultIndentWidth: CGFloat = 20.0,
        editorLayoutDirection: TextDirection = .leftToRight // Default to LTR TextDirection
    ) {
        self.editorFontName = editorFontName
        self.editorLineSpacing = editorLineSpacing
        self.editorDefaultIndentWidth = editorDefaultIndentWidth
        self.editorLayoutDirection = editorLayoutDirection

        #if canImport(UIKit)
        self.editorFontSize = editorFontSize ?? 16.0
        self.editorTextColor = editorTextColor ?? .label
        self.editorBackgroundColor = editorBackgroundColor ?? .systemBackground
        #elseif canImport(AppKit)
        self.editorFontSize = editorFontSize ?? NSFont.systemFontSize
        self.editorTextColor = editorTextColor ?? .textColor
        self.editorBackgroundColor = editorBackgroundColor ?? .textBackgroundColor
        #else
        self.editorFontSize = editorFontSize ?? 14.0
        self.editorTextColor = editorTextColor ?? MColor.black
        self.editorBackgroundColor = editorBackgroundColor ?? MColor.white
        #endif
    }

    /// Helper computed property to convert the custom `TextDirection`
    /// to `SwiftUI.LayoutDirection` for use with SwiftUI environment modifiers.
    public var swiftUILayoutDirection: SwiftUI.LayoutDirection {
        switch editorLayoutDirection {
        case .leftToRight:
            return .leftToRight
        case .rightToLeft:
            return .rightToLeft
        }
    }
    
    // Hashable conformance (ensure MColor is Hashable)
    public func hash(into hasher: inout Hasher) {
        hasher.combine(editorFontName)
        hasher.combine(editorFontSize)
        hasher.combine(editorTextColor)
        hasher.combine(editorBackgroundColor)
        hasher.combine(editorLineSpacing)
        hasher.combine(editorDefaultIndentWidth)
        hasher.combine(editorLayoutDirection) // Now TextDirection, which is Hashable
    }

    // Equatable conformance is automatically synthesized if all members are Equatable.
    // (MColor needs to be Equatable)
}
