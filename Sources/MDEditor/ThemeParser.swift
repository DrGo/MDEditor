// ThemeParser.swift
// Specific parser for MDEditor theme files, using YamlParser for generic capabilities.

import Foundation
import SwiftUI // For CGFloat, TextDirection, HexColor (MDEditorTheme types)

// YamlParsingError is defined in YamlParser.swift
// FrontMatterData, ProcessedLine, ParserState are defined in YamlParser.swift
// CGFloat LosslessStringConvertible extension is in YamlParser.swift

public struct ThemeParser {

    private struct ParsedThemeBody {
        var legacyName: String?; var legacyAuthor: String?; var legacyDescription: String?
        var layoutDirection: TextDirection?; var globalFontName: String?; var globalBaseFontSize: CGFloat?
        var globalTextColor: HexColor?; var globalBackgroundColor: HexColor?; var globalAccentColor: HexColor?
        var defaultElementStyle: MarkdownElementStyle?; var elementStyles: [String: MarkdownElementStyle] = [:]
    }
    private static func parseTimeInterval(from stringValue: String, forKey key: String, atLine line: Int) throws -> TimeInterval? {
        let lowercasedValue = stringValue.lowercased(); var totalDuration: TimeInterval = 0; var currentNumberString = ""; var foundNumberComponent = false
        if lowercasedValue == "0" { return 0 }
        for char in lowercasedValue {
            if char.isNumber || char == "." { currentNumberString.append(char); foundNumberComponent = true }
            else if char.isLetter, foundNumberComponent {
                guard let number = Double(currentNumberString) else { throw YamlParsingError.typeMismatch(key: key, expectedType: "valid number for time unit", actualValue: currentNumberString, line: line) }
                switch char {
                case "s": totalDuration += number; case "m": totalDuration += number * 60; case "h": totalDuration += number * 3600
                default: throw YamlParsingError.typeMismatch(key: key, expectedType: "valid time unit (s, m, h)", actualValue: String(char), line: line)
                }
                currentNumberString = ""; foundNumberComponent = false
            } else if char.isWhitespace || char == "," {
                if foundNumberComponent, !currentNumberString.isEmpty { throw YamlParsingError.typeMismatch(key: key, expectedType: "time unit after number before separator", actualValue: currentNumberString, line: line) }
                currentNumberString = ""; foundNumberComponent = false
            } else if !char.isWhitespace { throw YamlParsingError.typeMismatch(key: key, expectedType: "valid time string component", actualValue: String(char), line: line) }
        }
        if foundNumberComponent, !currentNumberString.isEmpty { throw YamlParsingError.typeMismatch(key: key, expectedType: "time unit for trailing number", actualValue: currentNumberString, line: line) }
        return totalDuration > 0 || (totalDuration == 0 && lowercasedValue.contains("0")) ? totalDuration : nil
    }
    private static func parseStyleBlock(parserState: inout ParserState, parentIndentCount: Int, contextKey: String) throws -> MarkdownElementStyle {
        var styleProperties: [String: ProcessedLine] = [:]
        while let peekedLine = try parserState.peekNextLine() {
            if peekedLine.indentCount <= parentIndentCount { break }
            if peekedLine.indentCount != parentIndentCount + 1 { throw YamlParsingError.unexpectedIndentation(line: peekedLine.number, expectedIndentCount: parentIndentCount + 1, actualIndentCount: peekedLine.indentCount) }
            guard let consumedLine = try parserState.nextLine() else { break }
            styleProperties[consumedLine.key] = consumedLine
        }
        func getOptional<T: LosslessStringConvertible>(_ key: String, asType: T.Type) throws -> T? {
            if let line = styleProperties[key] { return try YamlParser.parseOptionalValue(from: line, as: asType, contextKey: "\(contextKey).\(key)") }
            return nil
        }
        var parsedAnimationHintDuration: TimeInterval? = nil
        if let animationDurationLine = styleProperties["animationHintDuration"] {
            if let durationStr = animationDurationLine.rawValue { parsedAnimationHintDuration = try parseTimeInterval(from: durationStr, forKey: "\(contextKey).animationHintDuration", atLine: animationDurationLine.number) }
            else if animationDurationLine.isExplicitlyNull { parsedAnimationHintDuration = nil }
        }
        return MarkdownElementStyle( fontName: try getOptional("fontName", asType: String.self), fontSize: try getOptional("fontSize", asType: CGFloat.self), isBold: try getOptional("isBold", asType: Bool.self), isItalic: try getOptional("isItalic", asType: Bool.self), foregroundColor: try getOptional("foregroundColor", asType: HexColor.self), backgroundColor: try getOptional("backgroundColor", asType: HexColor.self), strikethrough: try getOptional("strikethrough", asType: Bool.self), underline: try getOptional("underline", asType: Bool.self), paragraphSpacingBefore: try getOptional("paragraphSpacingBefore", asType: CGFloat.self), paragraphSpacingAfter: try getOptional("paragraphSpacingAfter", asType: CGFloat.self), lineHeightMultiplier: try getOptional("lineHeightMultiplier", asType: CGFloat.self), firstLineHeadIndent: try getOptional("firstLineHeadIndent", asType: CGFloat.self), headIndent: try getOptional("headIndent", asType: CGFloat.self), tailIndent: try getOptional("tailIndent", asType: CGFloat.self), kerning: try getOptional("kerning", asType: CGFloat.self), alignment: try getOptional("alignment", asType: String.self), animationHintDuration: parsedAnimationHintDuration )
    }
    private static func parseStylesDictionary(parserState: inout ParserState, parentIndentCount: Int) throws -> [String: MarkdownElementStyle] {
        var stylesDictionary: [String: MarkdownElementStyle] = [:]
        while let peekedLine = try parserState.peekNextLine() {
            if peekedLine.indentCount <= parentIndentCount { break }
            guard peekedLine.indentCount == parentIndentCount + 1 else { throw YamlParsingError.unexpectedIndentation(line: peekedLine.number, expectedIndentCount: parentIndentCount + 1, actualIndentCount: peekedLine.indentCount) }
            guard let keyLine = try parserState.nextLine() else { break }
            if keyLine.rawValue != nil || keyLine.isExplicitlyNull { throw YamlParsingError.syntaxError(line: keyLine.number, message: "Expected block for style key '\(keyLine.key)'.") }
            let elementName = keyLine.key
            let style = try parseStyleBlock(parserState: &parserState, parentIndentCount: keyLine.indentCount, contextKey: elementName)
            stylesDictionary[elementName] = style
        }
        return stylesDictionary
    }
    private static func parseThemeContentPart(parserState: inout ParserState, frontMatterData: FrontMatterData?) throws -> ParsedThemeBody {
        var body = ParsedThemeBody(); var parsedBodyKeys: Set<String> = []; let frontMatterWasPresent = frontMatterData != nil
        while let line = try parserState.nextLine() {
            guard line.indentCount == 0 else { throw YamlParsingError.unexpectedIndentation(line: line.number, expectedIndentCount: 0, actualIndentCount: line.indentCount) }
            if parsedBodyKeys.contains(line.key) { throw YamlParsingError.syntaxError(line: line.number, message: "Duplicate top-level key in theme body: '\(line.key)'") } // Corrected message
            parsedBodyKeys.insert(line.key)
            switch line.key {
            case "name": if !frontMatterWasPresent { body.legacyName = try YamlParser.parseValue(from: line, as: String.self) } else { throw YamlParsingError.syntaxError(line: line.number, message: "'name' key not allowed with front matter.")}
            case "author": if !frontMatterWasPresent { body.legacyAuthor = try YamlParser.parseOptionalValue(from: line, as: String.self) } else { throw YamlParsingError.syntaxError(line: line.number, message: "'author' key not allowed with front matter.")}
            case "description": if !frontMatterWasPresent { body.legacyDescription = try YamlParser.parseOptionalValue(from: line, as: String.self) } else { throw YamlParsingError.syntaxError(line: line.number, message: "'description' key not allowed with front matter.")}
            case "layoutDirection": body.layoutDirection = try YamlParser.parseOptionalValue(from: line, as: TextDirection.self)
            case "globalFontName": body.globalFontName = try YamlParser.parseOptionalValue(from: line, as: String.self)
            case "globalBaseFontSize": body.globalBaseFontSize = try YamlParser.parseOptionalValue(from: line, as: CGFloat.self)
            case "globalTextColor": body.globalTextColor = try YamlParser.parseOptionalValue(from: line, as: HexColor.self)
            case "globalBackgroundColor": body.globalBackgroundColor = try YamlParser.parseOptionalValue(from: line, as: HexColor.self)
            case "globalAccentColor": body.globalAccentColor = try YamlParser.parseOptionalValue(from: line, as: HexColor.self)
            case "defaultElementStyle": if line.rawValue != nil || line.isExplicitlyNull { throw YamlParsingError.syntaxError(line: line.number, message: "'defaultElementStyle' must be block.")} ; body.defaultElementStyle = try parseStyleBlock(parserState: &parserState, parentIndentCount: line.indentCount, contextKey: "defaultElementStyle")
            case "elementStyles": if line.rawValue != nil || line.isExplicitlyNull { throw YamlParsingError.syntaxError(line: line.number, message: "'elementStyles' must be block.")}; body.elementStyles = try parseStylesDictionary(parserState: &parserState, parentIndentCount: line.indentCount)
            default: throw YamlParsingError.syntaxError(line: line.number, message: "Unknown top-level key in theme body: '\(line.key)'") // Corrected message
            }
        }
        return body
    }
    public static func parse(themeFileContents: String) throws -> MDEditorTheme {
        let (parsedFmOpt, parsedBody) = try YamlParser.parseYamlFile( fileContents: themeFileContents, bodyParser: self.parseThemeContentPart )
        let finalFrontMatter: FrontMatterData
        if let fm = parsedFmOpt { finalFrontMatter = fm } 
        else {
            guard let name = parsedBody.legacyName else {
                // Corrected error line calculation
                let tempParserState = ParserState(fileContents: themeFileContents)
                let errorLine = tempParserState.lines.isEmpty ? 1 : tempParserState.lines.count
                throw YamlParsingError.missingKey(key: "title (in front matter) or name (legacy top-level)", line: errorLine, context: "Theme identifier is mandatory.")
            }
            finalFrontMatter = FrontMatterData(title: name, author: parsedBody.legacyAuthor, description: parsedBody.legacyDescription)
        }
        return MDEditorTheme( frontMatter: finalFrontMatter, layoutDirection: parsedBody.layoutDirection, globalFontName: parsedBody.globalFontName, globalBaseFontSize: parsedBody.globalBaseFontSize, globalTextColor: parsedBody.globalTextColor, globalBackgroundColor: parsedBody.globalBackgroundColor, globalAccentColor: parsedBody.globalAccentColor, defaultElementStyle: parsedBody.defaultElementStyle, elementStyles: parsedBody.elementStyles )
    }
}

