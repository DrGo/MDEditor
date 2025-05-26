
import SwiftUI

public struct MDEditorConfiguration: Equatable {
    public var editorFontName: String?
    public var editorFontSize: CGFloat
    public var editorTextColor: MColor // Relies on MColor being defined above
    public var editorBackgroundColor: MColor // Relies on MColor being defined above
    public var editorLineSpacing: CGFloat
    public var editorDefaultIndentWidth: CGFloat
    public var editorLayoutDirection: LayoutDirection

    public init(
        editorFontName: String? = nil,
        editorFontSize: CGFloat? = nil,
        editorTextColor: MColor? = nil,
        editorBackgroundColor: MColor? = nil,
        editorLineSpacing: CGFloat = 2.0,
        editorDefaultIndentWidth: CGFloat = 20.0,
        editorLayoutDirection: LayoutDirection = .leftToRight
    ) {
        self.editorFontName = editorFontName
        self.editorLineSpacing = editorLineSpacing
        self.editorDefaultIndentWidth = editorDefaultIndentWidth
        self.editorLayoutDirection = editorLayoutDirection

        #if canImport(UIKit)
        self.editorFontSize = editorFontSize ?? 15.0
        self.editorTextColor = editorTextColor ?? .label
        self.editorBackgroundColor = editorBackgroundColor ?? .systemBackground
        #elseif canImport(AppKit)
        self.editorFontSize = editorFontSize ?? NSFont.systemFontSize
        self.editorTextColor = editorTextColor ?? .textColor
        self.editorBackgroundColor = editorBackgroundColor ?? .textBackgroundColor
        #endif
    }
}
