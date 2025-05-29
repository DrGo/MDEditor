// MarkdownContentRenderer.swift
// Handles parsing Markdown and rendering it to NSAttributedString using MDEditorTheme.

import Markdown
import SwiftUI // For LayoutDirection, and CGFloat

// MARK: - Platform-Agnostic Type Aliases (Primary Definitions)
#if canImport(UIKit)
import UIKit
public typealias MFont = UIFont
public typealias MColor = UIColor
public typealias MFontDescriptor = UIFontDescriptor
#elseif canImport(AppKit)
import AppKit
public typealias MFont = NSFont
public typealias MColor = NSColor
public typealias MFontDescriptor = NSFontDescriptor
#else
#error("Unsupported platform: UIKit or AppKit must be available for MFont, MColor, MFontDescriptor.")
#endif

public struct MarkdownContentRenderer: MarkupVisitor {
    private let theme: MDEditorTheme
    
    private let resolvedBaseFontSize: CGFloat
    private let resolvedBaseFontName: String?
    private let resolvedBaseTextColor: MColor
    private let resolvedGlobalLayoutDirection: LayoutDirection

    // Tracks the current list nesting depth to adjust indentation for list item contents.
    // This is the depth of the list itself (0 for top-level, 1 for first nest, etc.)
    private var currentListNestingDepth: Int = -1 // -1 means not currently inside a list environment
    
    // Added: Stores the paragraph style for the current list item's content
    private var currentListItemParagraphStyle: NSMutableParagraphStyle?


    public init(theme: MDEditorTheme = .internalDefault) {
        self.theme = theme
        
        self.resolvedBaseFontSize = theme.globalBaseFontSize
            ?? MDEditorTheme.internalDefault.globalBaseFontSize
            ?? 16.0

        self.resolvedBaseFontName = theme.globalFontName
            ?? MDEditorTheme.internalDefault.globalFontName
            
        self.resolvedBaseTextColor = theme.globalTextColor?.mColor
            ?? MDEditorTheme.internalDefault.globalTextColor?.mColor
            ?? MColor.platformDefaultTextColor


        if theme.layoutDirection == .rightToLeft {
            self.resolvedGlobalLayoutDirection = .rightToLeft
        } else {
            self.resolvedGlobalLayoutDirection = .leftToRight
        }
    }

    public mutating func attributedString(from document: Document) -> NSAttributedString {
        let finalResult = visit(document)
        return finalResult
    }

    // MARK: - Style Resolution Logic
    private func resolveStyle(for elementKey: MarkdownElementKey) -> MarkdownElementStyle {
        var currentResolvedStyle = MDEditorTheme.internalDefault.defaultElementStyle ?? MarkdownElementStyle()

        if let internalSpecific = MDEditorTheme.internalDefault.elementStyles?[elementKey.rawValue] {
            currentResolvedStyle = internalSpecific.merging(over: currentResolvedStyle)
        }
        
        if let themeDefault = theme.defaultElementStyle {
            currentResolvedStyle = themeDefault.merging(over: currentResolvedStyle)
        }
        
        if let themeSpecific = theme.elementStyles?[elementKey.rawValue] {
            currentResolvedStyle = themeSpecific.merging(over: currentResolvedStyle)
        }
        return currentResolvedStyle
    }

    // MARK: - Attribute Construction Helpers
    private func attributes(
        for elementKey: MarkdownElementKey,
        isNestedInList: Bool = false,
        // listIndentLevel: the number of indentation units to apply (e.g., 1 for first level item content)
        listIndentLevel: Int = 0
    ) -> [NSAttributedString.Key: Any] {
        let style = resolveStyle(for: elementKey)
        var attributes: [NSAttributedString.Key: Any] = [:]

        let fontSize = style.fontSize ?? self.resolvedBaseFontSize
        let fontName = style.fontName ?? self.resolvedBaseFontName
        
        var font = MFont.create(name: fontName, size: fontSize)
        
        var traits: MFontDescriptor.SymbolicTraits = []
        if style.isBold == true { traits.insert(getBoldTrait()) }
        if style.isItalic == true { traits.insert(getItalicTrait()) }
        if !traits.isEmpty {
            font = font.apply(newTraits: traits)
        }
        attributes[.font] = font

        let foregroundColor = style.foregroundColor?.mColor ?? self.resolvedBaseTextColor
        attributes[.foregroundColor] = foregroundColor
        
        if let bgColor = style.backgroundColor?.mColor {
            attributes[.backgroundColor] = bgColor
        }

        if style.strikethrough == true { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if style.underline == true { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        
        if let kerning = style.kerning { attributes[.kern] = kerning }

        let paraStyle = createParagraphStyle(for: style, elementKey: elementKey, isNestedInList: isNestedInList, listIndentLevel: listIndentLevel)
        attributes[.paragraphStyle] = paraStyle
        
        return attributes
    }
    
    private func createParagraphStyle(for style: MarkdownElementStyle, elementKey: MarkdownElementKey, isNestedInList: Bool, listIndentLevel: Int) -> NSMutableParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.baseWritingDirection = (self.resolvedGlobalLayoutDirection == .rightToLeft) ? .rightToLeft : .leftToRight
        
        #if canImport(AppKit)
        if self.resolvedGlobalLayoutDirection == .rightToLeft { paragraphStyle.alignment = .right }
        else { paragraphStyle.alignment = .natural }
        #endif

        switch style.alignment?.lowercased() {
            case "left": paragraphStyle.alignment = .left
            case "center": paragraphStyle.alignment = .center
            case "right": paragraphStyle.alignment = .right
            case "justified": paragraphStyle.alignment = .justified
            case "natural": paragraphStyle.alignment = .natural
            default: break
        }

        paragraphStyle.paragraphSpacingBefore = style.paragraphSpacingBefore ?? (isNestedInList && elementKey == .listItem ? 2 : 5)
        paragraphStyle.paragraphSpacing = style.paragraphSpacingAfter ?? (isNestedInList && elementKey == .listItem ? 2 : 10)
        
        if let lineHeightMult = style.lineHeightMultiplier { paragraphStyle.lineHeightMultiple = lineHeightMult }
        
        var finalFirstLineHeadIndent = style.firstLineHeadIndent ?? 0
        var finalHeadIndent = style.headIndent ?? 0
        
        if listIndentLevel > 0 {
            let listThemeStyle = resolveStyle(for: .list)
            let indentSizePerLevel: CGFloat = listThemeStyle.headIndent ?? 25.0
            
            let totalCalculatedIndent = CGFloat(listIndentLevel) * indentSizePerLevel
            finalHeadIndent += totalCalculatedIndent
            // For list items, the first line (marker) and subsequent lines share the same head indent.
            // The marker itself is placed within this indent using tab stops.
            finalFirstLineHeadIndent += totalCalculatedIndent
        }

        paragraphStyle.firstLineHeadIndent = finalFirstLineHeadIndent
        paragraphStyle.headIndent = finalHeadIndent
        paragraphStyle.tailIndent = style.tailIndent ?? 0
        
        return paragraphStyle
    }

    // MARK: - Visitor Methods
    mutating public func visitDocument(_ document: Document) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let childrenArray = Array(document.children)
        let childrenCount = childrenArray.count

        for (index, child) in childrenArray.enumerated() {
            let childAttributedString = visit(child)
            result.append(childAttributedString)

            if index < childrenCount - 1 {
                if !(child is UnorderedList || child is OrderedList || child is BlockQuote || child is CodeBlock || child is ThematicBreak) || childAttributedString.string.last != "\n" {
                     result.append(NSAttributedString.singleNewline(
                        withFontSize: resolvedBaseFontSize,
                        fontName: resolvedBaseFontName,
                        color: resolvedBaseTextColor
                    ))
                }
            }
        }
        return result
    }
    
    mutating public func defaultVisit(_ markup: Markup) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in markup.children {
            result.append(visit(child))
        }
        return result
    }
    
    mutating public func visitText(_ text: Markdown.Text) -> NSAttributedString {
        return NSAttributedString(string: text.plainText)
    }
    
    mutating private func visitBlockElementAndSetFullStyle(markup: Markup, key: MarkdownElementKey, isNestedInList: Bool = false, listIndentLevel: Int = 0) -> NSAttributedString {
        let finalAttributedString = NSMutableAttributedString()
        let childrenArray = Array(markup.children)
        for (index, child) in childrenArray.enumerated() {
            finalAttributedString.append(visit(child))
            // Add double newline between paragraphs within a list item or blockquote
            if (key == .listItem || key == .blockquote) && child is Paragraph && index < childrenArray.count - 1 && childrenArray[index+1] is Paragraph {
                 finalAttributedString.append(NSAttributedString.doubleNewline(withFontSize: resolvedBaseFontSize, fontName: resolvedBaseFontName, color: resolvedBaseTextColor))
            }
        }

        if finalAttributedString.length > 0 {
            // If currentListItemParagraphStyle is set, it means we are inside a list item's direct content (e.g. a Paragraph)
            // and should use that pre-calculated style for consistent indentation.
            let blockStylingAttributes: [NSAttributedString.Key: Any]
            if let listItemParaStyle = currentListItemParagraphStyle, key == .paragraph && isNestedInList {
                // For a paragraph directly inside a list item, use the list item's pre-calculated style
                // but merge with paragraph-specific font/color if different.
                var tempAttrs = attributes(for: key, isNestedInList: isNestedInList, listIndentLevel: listIndentLevel)
                tempAttrs[.paragraphStyle] = listItemParaStyle // Override with the item's indent style
                blockStylingAttributes = tempAttrs
            } else {
                 blockStylingAttributes = attributes(for: key, isNestedInList: isNestedInList, listIndentLevel: listIndentLevel)
            }


            // Apply the paragraph style for the block to the entire range.
            // This is generally correct for simple blocks like Paragraph or Heading.
            // For complex blocks (like ListItem), this method shouldn't be called directly on the ListItem itself.
            if let paragraphStyle = blockStylingAttributes[.paragraphStyle] {
                finalAttributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: finalAttributedString.length))
            }

            let blockBaseFont = blockStylingAttributes[.font] ?? MFont.create(name: resolvedBaseFontName, size: resolvedBaseFontSize)
            let blockBaseColor = blockStylingAttributes[.foregroundColor] ?? resolvedBaseTextColor

            finalAttributedString.enumerateAttributes(in: NSRange(location: 0, length: finalAttributedString.length), options: []) { existingAttributes, range, _ in
                var attributesToAdd: [NSAttributedString.Key: Any] = [:]
                if existingAttributes[.font] == nil {
                    attributesToAdd[.font] = blockBaseFont
                }
                if existingAttributes[.foregroundColor] == nil {
                    attributesToAdd[.foregroundColor] = blockBaseColor
                }
                if !attributesToAdd.isEmpty {
                    finalAttributedString.addAttributes(attributesToAdd, range: range)
                }
            }
        }
        return finalAttributedString
    }
    
    mutating private func visitInlineElementAndAddSpecificStyles(markup: Markup, key: MarkdownElementKey) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let specificElementStyle = resolveStyle(for: key)

        for child in markup.children {
            let childAttributedString = visit(child)
            let mutableChild = NSMutableAttributedString(attributedString: childAttributedString)

            if mutableChild.length > 0 {
                var attributesToLayer: [NSAttributedString.Key: Any] = [:]
                
                var currentFont = MFont.create(name: resolvedBaseFontName, size: resolvedBaseFontSize)

                if let elFontName = specificElementStyle.fontName {
                    currentFont = MFont.create(name: elFontName, size: specificElementStyle.fontSize ?? currentFont.pointSize)
                } else if let elFontSize = specificElementStyle.fontSize {
                    currentFont = MFont.create(name: currentFont.fontName, size: elFontSize)
                }
                
                var traits: MFontDescriptor.SymbolicTraits = []
                if specificElementStyle.isBold == true { traits.insert(getBoldTrait()) }
                if specificElementStyle.isItalic == true { traits.insert(getItalicTrait()) }
                if !traits.isEmpty {
                    currentFont = currentFont.apply(newTraits: traits)
                }
                attributesToLayer[.font] = currentFont
                
                attributesToLayer[.foregroundColor] = specificElementStyle.foregroundColor?.mColor ?? resolvedBaseTextColor
                
                if let bgColor = specificElementStyle.backgroundColor?.mColor {
                    attributesToLayer[.backgroundColor] = bgColor
                }
                if specificElementStyle.strikethrough == true { attributesToLayer[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
                if specificElementStyle.underline == true { attributesToLayer[.underlineStyle] = NSUnderlineStyle.single.rawValue }
                
                mutableChild.addAttributes(attributesToLayer, range: NSRange(location: 0, length: mutableChild.length))
            }
            result.append(mutableChild)
        }
        return result
    }

    mutating public func visitParagraph(_ paragraph: Paragraph) -> NSAttributedString {
        let indentLevel = paragraph.effectiveIndentLevelInList
        return visitBlockElementAndSetFullStyle(markup: paragraph, key: .paragraph, isNestedInList: indentLevel > 0, listIndentLevel: indentLevel)
    }

    mutating public func visitHeading(_ heading: Heading) -> NSAttributedString {
        let key: MarkdownElementKey
        switch heading.level {
            case 1: key = .heading1; case 2: key = .heading2; case 3: key = .heading3
            case 4: key = .heading4; case 5: key = .heading5; default: key = .heading6
        }
        return visitBlockElementAndSetFullStyle(markup: heading, key: key)
    }

    mutating public func visitEmphasis(_ emphasis: Emphasis) -> NSAttributedString {
        return visitInlineElementAndAddSpecificStyles(markup: emphasis, key: .emphasis)
    }
    
    mutating public func visitStrong(_ strong: Strong) -> NSAttributedString {
        return visitInlineElementAndAddSpecificStyles(markup: strong, key: .strong)
    }
    
    mutating public func visitStrikethrough(_ strikethrough: Strikethrough) -> NSAttributedString {
        return visitInlineElementAndAddSpecificStyles(markup: strikethrough, key: .strikethrough)
    }
        
    mutating public func visitLink(_ link: Markdown.Link) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let linkSpecificStyle = resolveStyle(for: .link)

        for child in link.children {
            let childAttributedString = visit(child)
            let mutableChild = NSMutableAttributedString(attributedString: childAttributedString)
            
            if mutableChild.length > 0 {
                var linkAttrsToApply: [NSAttributedString.Key: Any] = [:]
                
                let linkColor = linkSpecificStyle.foregroundColor?.mColor
                                ?? theme.globalAccentColor?.mColor
                                ?? resolvedBaseTextColor
                linkAttrsToApply[.foregroundColor] = linkColor
                
                var currentFont = MFont.create(name: resolvedBaseFontName, size: resolvedBaseFontSize)
                if let linkFontName = linkSpecificStyle.fontName {
                     currentFont = MFont.create(name: linkFontName, size: linkSpecificStyle.fontSize ?? currentFont.pointSize)
                } else if let linkFontSize = linkSpecificStyle.fontSize {
                     currentFont = MFont.create(name: currentFont.fontName, size: linkFontSize)
                }

                var traits: MFontDescriptor.SymbolicTraits = []
                if linkSpecificStyle.isBold == true { traits.insert(getBoldTrait()) }
                if linkSpecificStyle.isItalic == true { traits.insert(getItalicTrait()) }
                if !traits.isEmpty {
                    currentFont = currentFont.apply(newTraits: traits)
                }
                linkAttrsToApply[.font] = currentFont

                if linkSpecificStyle.underline != false {
                    linkAttrsToApply[.underlineStyle] = NSUnderlineStyle.single.rawValue
                }
                
                mutableChild.addAttributes(linkAttrsToApply, range: NSRange(location: 0, length: mutableChild.length))
            }
            result.append(mutableChild)
        }
        
        if result.length > 0, let urlDestination = link.destination, let url = URL(string: urlDestination) {
            result.addAttribute(.link, value: url, range: NSRange(location: 0, length: result.length))
        }
        return result
    }
    
    public func visitInlineCode(_ inlineCode: InlineCode) -> NSAttributedString {
        let tempSelf = self
        let codeAttributes = tempSelf.attributes(for: .inlineCode)
        return NSAttributedString(string: inlineCode.code, attributes: codeAttributes)
    }
    
    public func visitCodeBlock(_ codeBlock: CodeBlock) -> NSAttributedString {
        let tempSelf = self
        let codeBlockAttributes = tempSelf.attributes(for: .codeBlock)
        let codeText = codeBlock.code.hasSuffix("\n") ? String(codeBlock.code.dropLast()) : codeBlock.code
        return NSAttributedString(string: codeText, attributes: codeBlockAttributes)
    }
    
    mutating public func visitBlockQuote(_ blockQuote: BlockQuote) -> NSAttributedString {
        // A blockquote's own depth contributes to its indent, plus any list nesting it's within.
        let listNestingForQuote = blockQuote.effectiveIndentLevelInList
        let totalIndentLevel = listNestingForQuote + blockQuote.quoteDepth
        return visitBlockElementAndSetFullStyle(markup: blockQuote, key: .blockquote, isNestedInList: listNestingForQuote > 0, listIndentLevel: totalIndentLevel)
    }

    mutating public func visitUnorderedList(_ unorderedList: UnorderedList) -> NSAttributedString {
        let previousListNestingDepth = currentListNestingDepth
        currentListNestingDepth = unorderedList.listDepth
        let result = visitList(listContent: unorderedList, markerFormat: "\t•\t", listNestingDepth: currentListNestingDepth, isOrdered: false)
        currentListNestingDepth = previousListNestingDepth // Restore previous depth
        return result
    }

    mutating public func visitOrderedList(_ orderedList: OrderedList) -> NSAttributedString {
        let previousListNestingDepth = currentListNestingDepth
        currentListNestingDepth = orderedList.listDepth
        let result = visitList(listContent: orderedList, markerFormat: "\t%d.\t", listNestingDepth: currentListNestingDepth, isOrdered: true)
        currentListNestingDepth = previousListNestingDepth // Restore previous depth
        return result
    }
    
    mutating private func visitList(listContent: Markup, markerFormat: String, listNestingDepth: Int, isOrdered: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let childrenAsArray = Array(listContent.children)

        // Content of items in *this* list will be at listNestingDepth + 1
        let itemContentEffectiveIndentLevel = listNestingDepth + 1

        for (index, item) in childrenAsArray.enumerated() {
            guard let listItem = item as? ListItem else { continue }
            
            let listItemStyle = resolveStyle(for: .listItem)
            let markerParagraphStyle = createParagraphStyle(
                for: listItemStyle,
                elementKey: .listItem,
                isNestedInList: true,
                listIndentLevel: itemContentEffectiveIndentLevel // Marker and first line of item content share this indent
            )
            
            let markerFont = MFont.create(name: listItemStyle.fontName ?? resolvedBaseFontName,
                                          size: listItemStyle.fontSize ?? resolvedBaseFontSize)
            let markerColor = listItemStyle.foregroundColor?.mColor ?? resolvedBaseTextColor
            
            let effectiveMarkerText = isOrdered ? String(format: markerFormat.trimmingCharacters(in: .whitespacesAndNewlines), index + 1)
                                                : markerFormat.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let markerAttributedString = NSAttributedString(string: effectiveMarkerText + "\t", attributes: [
                .font: markerFont,
                .foregroundColor: markerColor,
                .paragraphStyle: markerParagraphStyle
            ])
            result.append(markerAttributedString)
            
            // Store this style so that direct Paragraph children of ListItem can use it.
            let previousListItemStyleState = self.currentListItemParagraphStyle // Corrected: Accessing self.
            self.currentListItemParagraphStyle = markerParagraphStyle      // Corrected: Accessing self.
            
            let itemContentResult = visit(listItem)
            result.append(itemContentResult)
            
            self.currentListItemParagraphStyle = previousListItemStyleState // Restore // Corrected: Accessing self.

            if index < childrenAsArray.count - 1 {
                 result.append(NSAttributedString.singleNewline(withFontSize: resolvedBaseFontSize, fontName: resolvedBaseFontName, color: resolvedBaseTextColor))
            }
        }
        return result
    }

    mutating public func visitListItem(_ listItem: ListItem) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let childrenArray = Array(listItem.children)
        let childrenCount = childrenArray.count
        
        for (index, child) in childrenArray.enumerated() {
            let childAttributedString = visit(child) // This will call visitParagraph, visitUnorderedList etc.
            result.append(childAttributedString)
            
            if childrenCount > 1 && index < childrenCount - 1 {
                 // If a list item has multiple blocks (e.g. two paragraphs), add a newline between them.
                 // The paragraph spacing attributes should handle the visual separation.
                 if childAttributedString.length > 0 && childAttributedString.string.last != "\n" {
                    result.append(NSAttributedString.singleNewline(withFontSize: resolvedBaseFontSize, fontName: resolvedBaseFontName, color: resolvedBaseTextColor))
                 }
            }
        }
        return result
    }
    
    public func visitThematicBreak(_ thematicBreak: ThematicBreak) -> NSAttributedString {
        let tempSelf = self
        let hrString = String(repeating: "⎯", count: 30)
        let breakAttributes = tempSelf.attributes(for: .thematicBreak)
        
        let finalBreak = NSMutableAttributedString(string: "\n", attributes: [
            .font: MFont.create(name: resolvedBaseFontName, size: resolvedBaseFontSize / 2),
            .paragraphStyle: breakAttributes[.paragraphStyle] ?? NSParagraphStyle.default])
        finalBreak.append(NSAttributedString(string: hrString, attributes: breakAttributes))
        finalBreak.append(NSAttributedString(string: "\n\n", attributes: [
            .font: MFont.create(name: resolvedBaseFontName, size: resolvedBaseFontSize / 2),
            .paragraphStyle: breakAttributes[.paragraphStyle] ?? NSParagraphStyle.default]))
        return finalBreak
    }

    public func visitHTMLBlock(_ htmlBlock: HTMLBlock) -> NSAttributedString {
        let pseudoCodeBlock = CodeBlock(language: "html", htmlBlock.rawHTML)
        return visitCodeBlock(pseudoCodeBlock)
    }

    public func visitInlineHTML(_ inlineHTML: InlineHTML) -> NSAttributedString {
        let pseudoInlineCode = InlineCode(inlineHTML.rawHTML)
        return visitInlineCode(pseudoInlineCode)
    }
    
    public func visitTable(_ table: Markdown.Table) -> NSAttributedString {
        let tempSelf = self
        let attrs = tempSelf.attributes(for: .paragraph)
        var tableRepresentation = "\n[Table Representation]\n"
        
        let head = table.head
        let headCellsArray = Array(head.cells)
        for cell in headCellsArray {
            tableRepresentation += "| \(cell.plainText) "
        }
        tableRepresentation += "|\n"
        tableRepresentation += String(repeating: "----", count: headCellsArray.count) + "\n"
        
        for rowMarkup in table.body.children {
            if let row = rowMarkup as? Markdown.Table.Row {
                for cell in row.cells {
                    tableRepresentation += "| \(cell.plainText) "
                }
                tableRepresentation += "|\n"
            }
        }
        tableRepresentation += "\n"
        return NSAttributedString(string: tableRepresentation, attributes: attrs)
    }

    public func visitTableHead(_ tableHead: Markdown.Table.Head) -> NSAttributedString { return NSAttributedString() }
    public func visitTableBody(_ tableBody: Markdown.Table.Body) -> NSAttributedString { return NSAttributedString() }
    public func visitTableRow(_ tableRow: Markdown.Table.Row) -> NSAttributedString { return NSAttributedString() }
    public func visitTableCell(_ tableCell: Markdown.Table.Cell) -> NSAttributedString { return NSAttributedString() }

    public func visitImage(_ image: Markdown.Image) -> NSAttributedString {
        let tempSelf = self
        var imageAttributes = tempSelf.attributes(for: .image)
        if imageAttributes[.foregroundColor] == nil {
            let linkStyleColor = resolveStyle(for: .link).foregroundColor?.mColor
            let globalAccent = theme.globalAccentColor?.mColor
            imageAttributes[.foregroundColor] = linkStyleColor ?? globalAccent ?? resolvedBaseTextColor
        }
        
        var textElements: [String] = []
        if !image.plainText.isEmpty {
            textElements.append(image.plainText)
        } else if let title = image.title, !title.isEmpty {
            textElements.append("\"\(title)\"")
        }

        let textPrefix = "Image: "
        var linkText = textElements.joined(separator: " ")
        if linkText.isEmpty { linkText = image.source ?? "untitled image" }
        
        let fullText = "\(textPrefix)[\(linkText)]"
        
        let result = NSMutableAttributedString(string: fullText, attributes: imageAttributes)
        if let urlSource = image.source, let url = URL(string: urlSource) {
            result.addAttribute(.link, value: url, range: NSRange(location: 0, length: result.length))
            if imageAttributes[.underlineStyle] == nil && resolveStyle(for: .image).underline != false {
                 result.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: result.length))
            }
        }
        return result
    }
}

// Internal helper extensions
internal extension MFont {
    static func create(name: String?, size: CGFloat) -> MFont {
        if let fontName = name, !fontName.isEmpty, let customFont = MFont(name: fontName, size: size) {
            return customFont
        }
        return MFont.systemFont(ofSize: size)
    }
}

internal extension MColor {
    static var platformDefaultTextColor: MColor {
        #if canImport(UIKit)
        return .label
        #elseif canImport(AppKit)
        return .labelColor
        #else
        return MColor(red: 0, green: 0, blue: 0, alpha: 1)
        #endif
    }

    var rgbaDescription: String {
        var r: CGFloat = -1, g: CGFloat = -1, b: CGFloat = -1, a: CGFloat = -1
        #if canImport(UIKit)
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        if let calibratedColor = self.usingColorSpace(.sRGB) {
            calibratedColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        } else {
            self.getRed(&r, green: &g, blue: &b, alpha: &a)
        }
        #endif
        return String(format: "R:%.2f G:%.2f B:%.2f A:%.2f", r, g, b, a)
    }
}

// Add effectiveIndentLevelInList to MarkdownStylingUtilities.swift or here if not present
extension Markup {
    public var effectiveIndentLevelInList: Int {
        var level = 0
        var current: Markup? = self
        while let parent = current?.parent {
            if parent is ListItem {
                level += 1
            }
            // Stop if we hit a List element itself, as its depth is handled by listDepth
            if parent is UnorderedList || parent is OrderedList {
                break
            }
            current = parent
        }
        return level
    }
}

