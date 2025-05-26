// MarkdownStylingUtilities.swift
// Contains helper extensions and protocols for Markdown rendering.

import SwiftUI
import Markdown // For Markup protocol


// MARK: - Platform-Agnostic Type Aliases
// These typealiases (MFont, MColor, MFontDescriptor) are defined as public
// in MarkdownContentRenderer.swift and are expected to be accessible here.
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - MColor Hex Extension
extension MColor {
    static func fromHex(_ hexString: String) -> MColor? {
        var hex = hexString.trimmingCharacters(in: .alphanumerics.inverted)
        if hex.hasPrefix("#") {
            hex.remove(at: hex.startIndex)
        }

        var rgbValue: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&rgbValue) else { return nil }

        let red, green, blue, alpha: CGFloat
        switch hex.count {
        case 6: // RGB (24-bit), e.g., "RRGGBB"
            red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(rgbValue & 0x0000FF) / 255.0
            alpha = 1.0
        case 8: // RGBA (32-bit), e.g., "RRGGBBAA"
            red = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
            green = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
            blue = CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0
            alpha = CGFloat(rgbValue & 0x000000FF) / 255.0
        default:
            print("Warning: Invalid HEX string format: \(hexString). Expected 6 or 8 characters after '#'.")
            return nil
        }

        #if canImport(UIKit)
        return MColor(red: red, green: green, blue: blue, alpha: alpha)
        #elseif canImport(AppKit)
        return MColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
        #else
        return nil
        #endif
    }
}

// MARK: - Platform Agnostic Font Traits Helpers
// Made to ensure visibility across files in the module.
func getItalicTrait() -> MFontDescriptor.SymbolicTraits {
    #if canImport(UIKit)
    return .traitItalic
    #elseif canImport(AppKit)
    return .italic
    #else
    return []
    #endif
}

func getBoldTrait() -> MFontDescriptor.SymbolicTraits {
    #if canImport(UIKit)
    return .traitBold
    #elseif canImport(AppKit)
    return .bold
    #else
    return []
    #endif
}

// MARK: - ListItemContainingMarkup Protocol and Extension
protocol ListItemContainingMarkup: Markup {
    var listDepth: Int { get }
}

extension UnorderedList: ListItemContainingMarkup {} // conformance
extension OrderedList: ListItemContainingMarkup {}  // conformance

extension ListItemContainingMarkup { // extension
    var listDepth: Int { // listDepth is already due to protocol requirement
        var depth = 0
        var currentParent = self.parent
        while let parent = currentParent {
            if parent is ListItemContainingMarkup {
                depth += 1
            }
            currentParent = parent.parent
        }
        return depth
    }
}

// MARK: - NSAttributedString Styling Extensions
extension NSMutableAttributedString { // Made extension public
    // Helper to get a base font, ensuring it uses the typealiased MFont
    // Kept private as it's only used within this extension.
    private func getBaseFontForExtension(baseFontSize: CGFloat, baseFontName: String?, weight: MFont.Weight = .regular) -> MFont {
         if let fontName = baseFontName, !fontName.isEmpty, let customFont = MFont(name: fontName, size: baseFontSize) {
            return customFont.apply(newTraits: weight == .bold ? getBoldTrait() : [])
        }
        return MFont.systemFont(ofSize: baseFontSize, weight: weight)
    }

    // Made methods public
    func applyEmphasis(baseFontSize: CGFloat, baseFontName: String?, defaultFontColor: MColor) {
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
            let currentFont = value as? MFont ?? getBaseFontForExtension(baseFontSize: baseFontSize, baseFontName: baseFontName)
            let newFont = currentFont.apply(newTraits: getItalicTrait())
            addAttribute(.font, value: newFont, range: range)
            if attribute(.foregroundColor, at: range.location, effectiveRange: nil) == nil {
                 addAttribute(.foregroundColor, value: defaultFontColor, range: range)
            }
        }
    }
    
    func applyStrong(baseFontSize: CGFloat, baseFontName: String?, defaultFontColor: MColor) {
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
            let currentFont = value as? MFont ?? getBaseFontForExtension(baseFontSize: baseFontSize, baseFontName: baseFontName)
            let newFont = currentFont.apply(newTraits: getBoldTrait())
            addAttribute(.font, value: newFont, range: range)
            if attribute(.foregroundColor, at: range.location, effectiveRange: nil) == nil {
                 addAttribute(.foregroundColor, value: defaultFontColor, range: range)
            }
        }
    }
    
    func applyLink(withURL url: URL?, color: MColor) {
        let range = NSRange(location: 0, length: length)
        addAttribute(.foregroundColor, value: color, range: range)
        if let url = url {
            addAttribute(.link, value: url, range: range)
        }
    }
        
    func applyHeading(level: Int, fontScale: CGFloat, baseFontSize: CGFloat, baseFontName: String?, defaultFontColor: MColor) {
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
            let newPointSize = baseFontSize * fontScale
            var fontToModify = getBaseFontForExtension(baseFontSize: newPointSize, baseFontName: baseFontName)
            fontToModify = fontToModify.apply(newTraits: getBoldTrait())

            addAttribute(.font, value: fontToModify, range: range)
            if attribute(.foregroundColor, at: range.location, effectiveRange: nil) == nil {
                 addAttribute(.foregroundColor, value: defaultFontColor, range: range)
            }
        }
    }
    
    func applyStrikethrough() {
        addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: length))
    }
}

// MARK: - MFont Extension
extension MFont { // Made extension public
    // Made methods public
    func apply(newTraits: MFontDescriptor.SymbolicTraits, newPointSize: CGFloat? = nil) -> MFont {
        let currentDescriptor = self.fontDescriptor
        var combinedTraits = currentDescriptor.symbolicTraits
        combinedTraits.insert(newTraits)

        #if canImport(UIKit)
        guard let newFontDescriptor = currentDescriptor.withSymbolicTraits(combinedTraits) else { return self }
        return MFont(descriptor: newFontDescriptor, size: newPointSize ?? pointSize) ?? self
        #elseif canImport(AppKit)
        let newFontDescriptor: NSFontDescriptor = currentDescriptor.withSymbolicTraits(combinedTraits)
        return MFont(descriptor: newFontDescriptor, size: newPointSize ?? self.pointSize) ?? self
        #else
        return self
        #endif
    }

    static func platformMonospacedSystemFont(ofSize size: CGFloat, weight: MFont.Weight) -> MFont {
        #if os(macOS)
        if #available(macOS 10.15, *) {
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        } else {
            return NSFont.userFixedPitchFont(ofSize: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
        }
        #elseif os(iOS) || os(tvOS)
        return UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        #elseif os(watchOS)
        return UIFont.systemFont(ofSize: size, weight: weight)
        #endif
    }

    static func platformMonospacedDigitSystemFont(ofSize size: CGFloat, weight: MFont.Weight) -> MFont {
        #if os(macOS)
        if #available(macOS 10.15, *) {
            return NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        } else {
            return NSFont.userFixedPitchFont(ofSize: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
        }
        #elseif os(iOS) || os(tvOS)
        return UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        #elseif os(watchOS)
        return UIFont.systemFont(ofSize: size, weight: weight)
        #endif
    }
}

// MARK: - Markup Structure Extensions
extension Markup { // Made extension public
    // Made properties public
    var hasSuccessor: Bool {
        guard let p = self.parent else { return false }
        let idx: Int = self.indexInParent
        return idx < p.childCount - 1
    }

    var isContainedInList: Bool {
        var currentElement = parent
        while currentElement != nil {
            if currentElement is ListItemContainingMarkup { return true }
            currentElement = currentElement?.parent
        }
        return false
    }
}

// MARK: - BlockQuote Extension
extension BlockQuote { // Made extension public
    // Made property public
    var quoteDepth: Int {
        var index = 0
        var currentElement = parent
        while currentElement != nil {
            if currentElement is BlockQuote { index += 1 }
            currentElement = currentElement?.parent
        }
        return index
    }
}

// MARK: - NSAttributedString Newline Statics
extension NSAttributedString { // Made extension public
    // Kept private as it's only used by static methods within this extension.
    private static func getFontForNewline(fontName: String?, fontSize: CGFloat) -> MFont {
        if let name = fontName, !name.isEmpty, let customFont = MFont(name: name, size: fontSize) {
            return customFont
        }
        return MFont.systemFont(ofSize: fontSize)
    }

    // Made static methods public
    static func singleNewline(withFontSize fontSize: CGFloat, fontName: String?, color: MColor) -> NSAttributedString {
        return NSAttributedString(string: "\n", attributes: [
            .font: getFontForNewline(fontName: fontName, fontSize: fontSize),
            .foregroundColor: color
        ])
    }
    
    static func doubleNewline(withFontSize fontSize: CGFloat, fontName: String?, color: MColor) -> NSAttributedString {
        return NSAttributedString(string: "\n\n", attributes: [
            .font: getFontForNewline(fontName: fontName, fontSize: fontSize),
            .foregroundColor: color
        ])
    }
}

