// MarkdownContentRenderer.swift
// Handles parsing Markdown and rendering it to NSAttributedString with configurable styles.

import Markdown // From swift-markdown package
import SwiftUI

// MARK: - Platform-Agnostic Type Aliases
// These are primary definitions for the module.
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

// Note: Helper extensions (MColor.fromHex, MFont.apply, NSAttributedString styling, etc.)
// and utility protocols/structs (ListItemContainingMarkup)
// have been moved to MarkdownStylingUtilities.swift

// MARK: - Main Renderer Struct
public struct MarkdownContentRenderer: MarkupVisitor {

    public struct StyleConfiguration: Equatable {
        public var baseFontSize: CGFloat
        public var baseFontName: String?
        public var codeFontScale: CGFloat
        public var headingScales: [CGFloat]
        public var listIndentPerLevel: CGFloat
        public var blockquoteIndentPerLevel: CGFloat
        public var blockquoteItalic: Bool
        public var layoutDirection: LayoutDirection

        // Platform-dependent default colors are defined here as they are part of the StyleConfiguration.
        #if canImport(UIKit)
        public var textColor: MColor = .label
        public var linkColor: MColor = .systemBlue
        public var codeForegroundColor: MColor = .secondaryLabel
        public var codeBlockBackgroundColor: MColor = .secondarySystemGroupedBackground
        public var blockquoteColor: MColor = .secondaryLabel
        #elseif canImport(AppKit)
        public var textColor: MColor = .labelColor
        public var linkColor: MColor = .systemBlue
        public var codeForegroundColor: MColor = .secondaryLabelColor
        public var codeBlockBackgroundColor: MColor = .unemphasizedSelectedContentBackgroundColor
        public var blockquoteColor: MColor = .secondaryLabelColor
        #endif
        
        public init(
            baseFontSize: CGFloat = 16.0,
            baseFontName: String? = nil,
            codeFontScale: CGFloat = 0.9,
            headingScales: [CGFloat] = [1.8, 1.6, 1.4, 1.2, 1.1, 1.0],
            listIndentPerLevel: CGFloat = 25.0,
            blockquoteIndentPerLevel: CGFloat = 20.0,
            blockquoteItalic: Bool = true,
            layoutDirection: LayoutDirection = .leftToRight
        ) {
            self.baseFontSize = baseFontSize
            self.baseFontName = baseFontName
            self.codeFontScale = codeFontScale
            self.headingScales = headingScales
            self.listIndentPerLevel = listIndentPerLevel
            self.blockquoteIndentPerLevel = blockquoteIndentPerLevel
            self.blockquoteItalic = blockquoteItalic
            self.layoutDirection = layoutDirection
        }
    }

    private let configuration: StyleConfiguration

    public init(configuration: StyleConfiguration = StyleConfiguration()) {
        self.configuration = configuration
    }
    
    public mutating func attributedString(from document: Document) -> NSAttributedString {
        return visit(document)
    }
    
    // Internal font helper methods remain here as they directly use `configuration`.
    private func getBaseFont(ofSize size: CGFloat, weight: MFont.Weight = .regular) -> MFont {
        let targetFont: MFont
        if let fontName = configuration.baseFontName, !fontName.isEmpty,
           let customFont = MFont(name: fontName, size: size) {
            targetFont = customFont
        } else {
            targetFont = MFont.systemFont(ofSize: size)
        }

        if weight != .regular {
            return targetFont.apply(newTraits: weight == .bold ? getBoldTrait() : []) // getBoldTrait() is in MarkdownStylingUtilities
        }
        return targetFont
    }
    
    private func getMonospacedFont(ofSize size: CGFloat, weight: MFont.Weight = .regular) -> MFont {
        return MFont.platformMonospacedSystemFont(ofSize: size, weight: weight) // Static func on MFont from MarkdownStylingUtilities
    }
    
    private func getMonospacedDigitFont(ofSize size: CGFloat, weight: MFont.Weight = .regular) -> MFont {
        return MFont.platformMonospacedDigitSystemFont(ofSize: size, weight: weight) // Static func on MFont from MarkdownStylingUtilities
    }

    private func baseParagraphStyle() -> NSMutableParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.baseWritingDirection = (configuration.layoutDirection == .rightToLeft) ? .rightToLeft : .leftToRight
        
        #if canImport(AppKit)
        if configuration.layoutDirection == .rightToLeft {
             paragraphStyle.alignment = .right
        } else {
             paragraphStyle.alignment = .natural
        }
        #endif
        paragraphStyle.paragraphSpacingBefore = configuration.baseFontSize * 0.25
        paragraphStyle.paragraphSpacing = configuration.baseFontSize * 0.5
        return paragraphStyle
    }

    // MARK: - Visitor Methods
    // These methods form the core rendering logic.

    mutating public func defaultVisit(_ markup: Markup) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in markup.children {
            result.append(visit(child))
        }
        return result
    }
    
    mutating public func visitText(_ text: Markdown.Text) -> NSAttributedString {
        return NSAttributedString(string: text.plainText, attributes: [
            .font: getBaseFont(ofSize: configuration.baseFontSize),
            .foregroundColor: configuration.textColor
        ])
    }
    
    mutating public func visitEmphasis(_ emphasis: Emphasis) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in emphasis.children {
            result.append(visit(child))
        }
        // Uses applyEmphasis from MarkdownStylingUtilities.swift
        result.applyEmphasis(baseFontSize: configuration.baseFontSize, baseFontName: configuration.baseFontName, defaultFontColor: configuration.textColor)
        return result
    }
    
    mutating public func visitStrong(_ strong: Strong) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in strong.children {
            result.append(visit(child))
        }
        // Uses applyStrong from MarkdownStylingUtilities.swift
        result.applyStrong(baseFontSize: configuration.baseFontSize, baseFontName: configuration.baseFontName, defaultFontColor: configuration.textColor)
        return result
    }
    
    mutating public func visitParagraph(_ paragraph: Paragraph) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let paragraphStyle = baseParagraphStyle()

        for child in paragraph.children {
            result.append(visit(child))
        }
        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))
        
        if paragraph.hasSuccessor {
            var newlinesRequired = true
            if let parentListItem = paragraph.parent as? ListItem {
                // isIdentical(to:) requires Markup to be AnyObject, which it is not.
                // Compare based on range or a unique ID if available and necessary.
                // For simplicity, checking if it's the last child by index.
                if parentListItem.childCount > 0 && parentListItem.child(at: parentListItem.childCount - 1)?.range == paragraph.range {
                     newlinesRequired = false
                }
            }
            if newlinesRequired {
                let newlines = paragraph.isContainedInList ? // isContainedInList from MarkdownStylingUtilities
                    NSAttributedString.singleNewline(withFontSize: configuration.baseFontSize, fontName: configuration.baseFontName, color: configuration.textColor) :
                    NSAttributedString.doubleNewline(withFontSize: configuration.baseFontSize, fontName: configuration.baseFontName, color: configuration.textColor)
                result.append(newlines)
            }
        }
        return result
    }
    
    mutating public func visitHeading(_ heading: Heading) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let paragraphStyle = baseParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = 0
        paragraphStyle.paragraphSpacing = configuration.baseFontSize * 0.25

        for child in heading.children {
            result.append(visit(child))
        }
        
        let level = min(max(1, heading.level), configuration.headingScales.count)
        let scale = configuration.headingScales[level - 1]
        // Uses applyHeading from MarkdownStylingUtilities.swift
        result.applyHeading(level: heading.level,
                              fontScale: scale,
                              baseFontSize: configuration.baseFontSize,
                              baseFontName: configuration.baseFontName,
                              defaultFontColor: configuration.textColor)
        
        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))

        if heading.hasSuccessor {
            result.append(NSAttributedString.doubleNewline(withFontSize: configuration.baseFontSize, fontName: configuration.baseFontName, color: configuration.textColor))
        }
        return result
    }
    
    mutating public func visitLink(_ link: Markdown.Link) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in link.children {
            result.append(visit(child))
        }
        let url = link.destination.flatMap { URL(string: $0) }
        // Uses applyLink from MarkdownStylingUtilities.swift
        result.applyLink(withURL: url, color: configuration.linkColor)
        return result
    }
    
    public func visitInlineCode(_ inlineCode: InlineCode) -> NSAttributedString {
        return NSAttributedString(string: inlineCode.code, attributes: [
            .font: getMonospacedFont(ofSize: configuration.baseFontSize * configuration.codeFontScale),
            .foregroundColor: configuration.codeForegroundColor
        ])
    }
    
    public func visitCodeBlock(_ codeBlock: CodeBlock) -> NSAttributedString {
        let codeText = codeBlock.code.hasSuffix("\n") ? String(codeBlock.code.dropLast()) : codeBlock.code
        let paragraphStyle = baseParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = configuration.baseFontSize * 0.25
        paragraphStyle.paragraphSpacing = configuration.baseFontSize * 0.25

        let result = NSMutableAttributedString(string: codeText, attributes: [
            .font: getMonospacedFont(ofSize: configuration.baseFontSize * configuration.codeFontScale),
            .foregroundColor: configuration.codeForegroundColor,
            .backgroundColor: configuration.codeBlockBackgroundColor,
            .paragraphStyle: paragraphStyle
        ])
        
        if codeBlock.hasSuccessor {
            result.append(NSAttributedString.singleNewline(withFontSize: configuration.baseFontSize, fontName: configuration.baseFontName, color: configuration.textColor))
        }
        return result
    }
    
    mutating public func visitStrikethrough(_ strikethrough: Strikethrough) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in strikethrough.children {
            result.append(visit(child))
        }
        // Uses applyStrikethrough from MarkdownStylingUtilities.swift
        result.applyStrikethrough()
        return result
    }
    
    mutating public func visitUnorderedList(_ unorderedList: UnorderedList) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let listFont = getBaseFont(ofSize: configuration.baseFontSize)
                
        for listItem in unorderedList.listItems {
            let itemParagraphStyle = baseParagraphStyle()
            itemParagraphStyle.paragraphSpacingBefore = 0
            itemParagraphStyle.paragraphSpacing = 0
            let listDepthValue: Int = unorderedList.listDepth // listDepth from MarkdownStylingUtilities
            let baseListIndent: CGFloat = configuration.listIndentPerLevel
            let additionalIndentPerLevel: CGFloat = configuration.listIndentPerLevel
            let currentListDepthCGFloat = CGFloat(listDepthValue)
            let effectiveIndentForPrefix = baseListIndent + (additionalIndentPerLevel * currentListDepthCGFloat)
            let spacingFromBullet: CGFloat = 8.0
            let bulletString = "•"
            let bulletWidth = ceil(NSAttributedString(string: bulletString, attributes: [.font: listFont]).size().width)
            let contentHeadIndent = effectiveIndentForPrefix + bulletWidth + spacingFromBullet
            itemParagraphStyle.headIndent = contentHeadIndent
            itemParagraphStyle.tabStops = [
                NSTextTab(textAlignment: .left, location: effectiveIndentForPrefix),
                NSTextTab(textAlignment: .left, location: contentHeadIndent)
            ]
            let prefixAttributes: [NSAttributedString.Key: Any] = [
                .font: listFont,
                .foregroundColor: configuration.textColor,
                .paragraphStyle: itemParagraphStyle
            ]
            let prefix = NSAttributedString(string: "\t\(bulletString)\t", attributes: prefixAttributes)
            let content = visit(listItem)
            let fullItem = NSMutableAttributedString(attributedString: prefix)
            fullItem.append(content)
            fullItem.addAttribute(.paragraphStyle, value: itemParagraphStyle, range: NSRange(location: 0, length: fullItem.length))
            result.append(fullItem)
        }
        
        if unorderedList.hasSuccessor && !(unorderedList.parent is ListItem) {
            result.append(NSAttributedString.doubleNewline(withFontSize: configuration.baseFontSize, fontName: configuration.baseFontName, color: configuration.textColor))
        }
        return result
    }
    
    mutating public func visitListItem(_ listItem: ListItem) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (_, child) in listItem.children.enumerated() {
            let childAttributedString = visit(child)
            result.append(childAttributedString)
        }
        if listItem.hasSuccessor {
             result.append(NSAttributedString.singleNewline(withFontSize: configuration.baseFontSize, fontName: configuration.baseFontName, color: configuration.textColor))
        }
        return result
    }

    mutating public func visitOrderedList(_ orderedList: OrderedList) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let numeralFont: MFont = getMonospacedDigitFont(ofSize: configuration.baseFontSize)
        
        for (index, listItem) in orderedList.listItems.enumerated() {
            let itemParagraphStyle = baseParagraphStyle()
            itemParagraphStyle.paragraphSpacingBefore = 0
            itemParagraphStyle.paragraphSpacing = 0
            let listDepthValue: Int = orderedList.listDepth // listDepth from MarkdownStylingUtilities
            let baseListIndent: CGFloat = configuration.listIndentPerLevel
            let additionalIndentPerLevel: CGFloat = configuration.listIndentPerLevel
            let currentListDepthCGFloat = CGFloat(listDepthValue)
            let effectiveIndentForPrefix = baseListIndent + (additionalIndentPerLevel * currentListDepthCGFloat)
            let itemCount = Array(orderedList.listItems).count
            let numeralStringForWidth = "\(itemCount)."
            let numeralColumnWidth = ceil(NSAttributedString(string: numeralStringForWidth, attributes: [.font: numeralFont]).size().width)
            let spacingFromIndex: CGFloat = 8.0
            let numeralEndPosition = effectiveIndentForPrefix + numeralColumnWidth
            let contentHeadIndent = numeralEndPosition + spacingFromIndex
            itemParagraphStyle.headIndent = contentHeadIndent
            itemParagraphStyle.tabStops = [
                NSTextTab(textAlignment: .right, location: numeralEndPosition),
                NSTextTab(textAlignment: .left, location: contentHeadIndent)
            ]
            let prefixAttributes: [NSAttributedString.Key: Any] = [
                .font: numeralFont,
                .foregroundColor: configuration.textColor,
                .paragraphStyle: itemParagraphStyle
            ]
            let prefix = NSAttributedString(string: "\t\(index + 1).\t", attributes: prefixAttributes)
            let content = visit(listItem)
            let fullItem = NSMutableAttributedString(attributedString: prefix)
            fullItem.append(content)
            fullItem.addAttribute(.paragraphStyle, value: itemParagraphStyle, range: NSRange(location: 0, length: fullItem.length))
            result.append(fullItem)
        }
        
        if orderedList.hasSuccessor && !(orderedList.parent is ListItem) {
            result.append(NSAttributedString.doubleNewline(withFontSize: configuration.baseFontSize, fontName: configuration.baseFontName, color: configuration.textColor))
        }
        return result
    }
    
    mutating public func visitBlockQuote(_ blockQuote: BlockQuote) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        for child in blockQuote.children {
            let childContent = visit(child)
            let quoteAttributedString = NSMutableAttributedString(attributedString: childContent)
            var effectiveRange = NSRange(location: 0, length: 0)
            let existingParagraphStyle = quoteAttributedString.attribute(.paragraphStyle,
                                                                      at: 0,
                                                                      effectiveRange: &effectiveRange) as? NSParagraphStyle
            let paragraphStyle = (existingParagraphStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? baseParagraphStyle()
            paragraphStyle.paragraphSpacingBefore = configuration.baseFontSize * 0.1
            paragraphStyle.paragraphSpacing = configuration.baseFontSize * 0.1
            let quoteDepthValue = blockQuote.quoteDepth // quoteDepth from MarkdownStylingUtilities
            let indentAmount = configuration.blockquoteIndentPerLevel * CGFloat(quoteDepthValue + 1)
            paragraphStyle.firstLineHeadIndent += indentAmount
            paragraphStyle.headIndent += indentAmount
            let attributesToApply: [NSAttributedString.Key: Any] = [
                .paragraphStyle: paragraphStyle,
                .foregroundColor: configuration.blockquoteColor
            ]
            quoteAttributedString.addAttributes(attributesToApply, range: NSRange(location: 0, length: quoteAttributedString.length))
            if configuration.blockquoteItalic {
                quoteAttributedString.enumerateAttribute(.font, in: NSRange(location: 0, length: quoteAttributedString.length), options: []) { value, range, _ in
                    let currentFont = value as? MFont ?? getBaseFont(ofSize: configuration.baseFontSize)
                    let italicFont = currentFont.apply(newTraits: getItalicTrait()) // getItalicTrait from MarkdownStylingUtilities
                    quoteAttributedString.addAttribute(.font, value: italicFont, range: range)
                }
            }
            result.append(quoteAttributedString)
            if child.hasSuccessor {
                 result.append(NSAttributedString.singleNewline(withFontSize: configuration.baseFontSize, fontName: configuration.baseFontName, color: configuration.blockquoteColor))
            }
        }
        if blockQuote.hasSuccessor {
            result.append(NSAttributedString.doubleNewline(withFontSize: configuration.baseFontSize, fontName: configuration.baseFontName, color: configuration.textColor))
        }
        return result
    }
    
    // MARK: - Placeholder Visitor Methods

    public func visitThematicBreak(_ thematicBreak: ThematicBreak) -> NSAttributedString {
        let hrString = "\n" + String(repeating: "⎯", count: 20) + "\n\n"
        let paragraphStyle = baseParagraphStyle()
        paragraphStyle.alignment = .center
        return NSAttributedString(string: hrString, attributes: [
            .font: getBaseFont(ofSize: configuration.baseFontSize),
            .foregroundColor: configuration.textColor.withAlphaComponent(0.3),
            .paragraphStyle: paragraphStyle,
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .strikethroughColor: configuration.textColor.withAlphaComponent(0.3)
        ])
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
        let headRowCount = table.head.childCount
        let bodyRowCount = table.body.childCount
        let columnCount = table.columnAlignments.count
        let desc = "\n[Table: \(columnCount) columns, \(headRowCount) header row(s), \(bodyRowCount) body row(s)]\n\n"
        return NSAttributedString(string: desc, attributes: [
            .font: getBaseFont(ofSize: configuration.baseFontSize * 0.9, weight: .regular),
            .foregroundColor: configuration.textColor.withAlphaComponent(0.7)
        ])
    }
    public func visitTableHead(_ tableHead: Markdown.Table.Head) -> NSAttributedString { return NSAttributedString() }
    public func visitTableBody(_ tableBody: Markdown.Table.Body) -> NSAttributedString { return NSAttributedString() }
    public func visitTableRow(_ tableRow: Markdown.Table.Row) -> NSAttributedString { return NSAttributedString() }
    public func visitTableCell(_ tableCell: Markdown.Table.Cell) -> NSAttributedString { return NSAttributedString() }

    public func visitImage(_ image: Markdown.Image) -> NSAttributedString {
        var textElements: [String] = []
        if let title = image.title, !title.isEmpty {
            textElements.append("\"\(title)\"")
        } else if !image.plainText.isEmpty {
             textElements.append(image.plainText)
        }

        let textPrefix = "Image: "
        var linkText = textElements.joined(separator: " ")
        if linkText.isEmpty {
            linkText = image.source ?? "untitled image"
        }

        let fullText = "\(textPrefix)\(linkText)"
        
        let result = NSMutableAttributedString(string: fullText, attributes: [
            .font: getBaseFont(ofSize: configuration.baseFontSize * 0.9, weight: .regular),
            .foregroundColor: configuration.linkColor
        ])
        
        if let urlSource = image.source, let url = URL(string: urlSource) {
            if let rangeOfLinkText = fullText.range(of: linkText) {
                let nsRange = NSRange(rangeOfLinkText, in: fullText)
                result.addAttribute(.link, value: url, range: nsRange)
            } else if let rangeOfSource = fullText.range(of: urlSource) { // Fallback
                let nsRange = NSRange(rangeOfSource, in: fullText)
                result.addAttribute(.link, value: url, range: nsRange)
            }
        }
        
        if image.hasSuccessor && !(image.parent is Paragraph && (image.parent as? Paragraph)?.childCount == 1) {
             result.append(NSAttributedString.singleNewline(withFontSize: configuration.baseFontSize, fontName: configuration.baseFontName, color: configuration.textColor))
        }
        return result
    }
}

