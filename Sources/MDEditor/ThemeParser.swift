// ThemeParser.swift
// Custom parser for MDEditor theme files (YAML-like structure).

import Foundation
import SwiftUI // For CGFloat, MDEditorTheme, TextDirection, HexColor

// MARK: - LosslessStringConvertible Conformances for Primitive Types
// These are needed for the custom parser.
extension CGFloat: LosslessStringConvertible {
    public init?(_ description: String) {
        if let doubleValue = Double(description) {
            self = CGFloat(doubleValue)
        } else {
            // Attempt to initialize from Int if Double fails, to support "16" as 16.0
            if let intValue = Int(description) {
                self = CGFloat(intValue)
            } else {
                return nil
            }
        }
    }
}

extension Bool: LosslessStringConvertible {
    public init?(_ description: String) {
        switch description.lowercased() {
        case "true", "yes", "1":
            self = true
        case "false", "no", "0":
            self = false
        default:
            return nil
        }
    }
}

// Custom error type for theme parsing
public enum ThemeParsingError: Error, LocalizedError, CustomStringConvertible {
    case fileNotFound(URL)
    case fileReadError(URL, Error)
    case syntaxError(line: Int, message: String)
    case missingKey(key: String, line: Int, context: String? = nil)
    case typeMismatch(key: String, expectedType: String, actualValue: String, line: Int, context: String? = nil)
    case unexpectedIndentation(line: Int, expected: Int, actual: Int)
    case yamlContentEmptyOrInvalid

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Theme file not found at \(url.lastPathComponent)."
        case .fileReadError(let url, let error):
            return "Could not read theme file \(url.lastPathComponent): \(error.localizedDescription)"
        case .syntaxError(let line, let message):
            return "Syntax error at line \(line): \(message)."
        case .missingKey(let key, let line, let context):
            var msg = "Missing required key '\(key)' near line \(line)."
            if let ctx = context { msg += " (Context: \(ctx))" }
            return msg
        case .typeMismatch(let key, let expected, let actual, let line, let context):
            var msg = "Type mismatch for key '\(key)' at line \(line). Expected \(expected), found value: '\(actual)'."
            if let ctx = context { msg += " (Context: \(ctx))" }
            return msg
        case .unexpectedIndentation(let line, let expected, let actual):
            return "Unexpected indentation at line \(line). Expected \(expected) spaces, found \(actual) spaces (or multiple of)."
        case .yamlContentEmptyOrInvalid:
            return "YAML content is empty or invalid."
        }
    }
    
    public var description: String {
        return errorDescription ?? "An unknown theme parsing error occurred."
    }
}

fileprivate struct ParsedLine {
    let number: Int
    let indentSpaces: Int // Actual number of leading spaces
    let key: String
    let value: String?
}

public struct ThemeParser {

    private var lines: [String]
    private var currentIndex: Int = 0
    private let indentUnitSpaces: Int = 2 // Define how many spaces constitute one indent level

    private init(themeFileContents: String) {
        self.lines = themeFileContents.components(separatedBy: .newlines)
    }

    private mutating func nextMeaningfulLine() -> ParsedLine? {
        while currentIndex < lines.count {
            let currentLineNumber = currentIndex + 1
            let lineContent = lines[currentIndex]
            currentIndex += 1

            // Strip full-line comments first
            var effectiveLineContent = lineContent
            if let commentStartIndex = effectiveLineContent.firstIndex(of: "#") {
                // Check if '#' is part of a quoted string or a hex color
                // This is a simplified check; a robust comment stripper is complex.
                // For now, if '#' is not inside quotes, assume it's a comment.
                // A more robust solution would involve checking quote balancing.
                var inSingleQuotes = false
                var inDoubleQuotes = false
                var charBeforeComment: String.Index? = nil

                for index in effectiveLineContent.indices {
                    if effectiveLineContent[index] == "'" { inSingleQuotes.toggle() }
                    if effectiveLineContent[index] == "\"" { inDoubleQuotes.toggle() }
                    if effectiveLineContent[index] == "#" && !inSingleQuotes && !inDoubleQuotes {
                        charBeforeComment = index
                        break
                    }
                }
                if let actualCommentStart = charBeforeComment {
                     effectiveLineContent = String(effectiveLineContent[..<actualCommentStart])
                }
            }
            
            let trimmedLine = effectiveLineContent.trimmingCharacters(in: .whitespaces)

            if trimmedLine.isEmpty {
                continue
            }

            let leadingSpaces = effectiveLineContent.prefix(while: { $0.isWhitespace }).count
            
            var key: String
            var value: String?

            if let colonIndex = trimmedLine.firstIndex(of: ":") {
                key = String(trimmedLine[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let valueStartIndex = trimmedLine.index(after: colonIndex)
                var rawValue = String(trimmedLine[valueStartIndex...]).trimmingCharacters(in: .whitespaces)
                
                // Value part might still have an inline comment if not handled above,
                // or if the '#' was part of a value (e.g. hex color).
                // The previous comment stripping should handle most cases.
                // Let's ensure one more pass for value-only comments if '#' is not part of a hex color.
                if !key.lowercased().contains("color") { // Don't strip # from hex colors
                    if let commentInValueIndex = rawValue.firstIndex(of: "#") {
                        // Simple check: if # is not inside quotes, strip it and after
                        // This is still a simplification.
                        var inSingleQuotesVal = false
                        var inDoubleQuotesVal = false
                        var actualCommentStartVal: String.Index? = nil
                        for index in rawValue.indices {
                             if rawValue[index] == "'" { inSingleQuotesVal.toggle() }
                             if rawValue[index] == "\"" { inDoubleQuotesVal.toggle() }
                             if rawValue[index] == "#" && !inSingleQuotesVal && !inDoubleQuotesVal {
                                 actualCommentStartVal = index
                                 break
                             }
                        }
                        if let acs = actualCommentStartVal {
                             rawValue = String(rawValue[..<acs]).trimmingCharacters(in: .whitespaces)
                        }
                    }
                }


                if rawValue.isEmpty || rawValue.lowercased() == "null" || rawValue == "~" {
                    value = nil
                } else if (rawValue.starts(with: "'") && rawValue.hasSuffix("'")) || (rawValue.starts(with: "\"") && rawValue.hasSuffix("\"")) {
                    value = String(rawValue.dropFirst().dropLast())
                } else {
                    value = rawValue
                }
            } else {
                key = trimmedLine
                value = nil
            }
            
            guard !key.isEmpty else { continue }
            return ParsedLine(number: currentLineNumber, indentSpaces: leadingSpaces, key: key, value: value)
        }
        return nil
    }

    private mutating func parseValue<T: LosslessStringConvertible>(from line: ParsedLine, as: T.Type) throws -> T {
        guard let valueString = line.value else {
            throw ThemeParsingError.missingKey(key: line.key, line: line.number, context: "Value expected but not found.")
        }
        guard let value = T(valueString) else {
            throw ThemeParsingError.typeMismatch(key: line.key, expectedType: "\(T.self)", actualValue: valueString, line: line.number)
        }
        return value
    }

    private mutating func parseOptionalValue<T: LosslessStringConvertible>(from line: ParsedLine, as: T.Type) throws -> T? {
        guard let valueString = line.value else {
            return nil
        }
        // "null" or "~" should have been converted to value = nil by nextMeaningfulLine
        // If valueString is still "null" or "~" here, it means it was quoted, e.g. description: "null"
        // In that case, it's a string literal "null", not a YAML null.
        // LosslessStringConvertible init should handle if "null" is a valid T.
        
        guard let value = T(valueString) else {
            // If T is String?, and valueString is "null", T(valueString) will be "null", not nil.
            // This is correct. If T is e.g. Int?, and valueString is "null", T(valueString) will be nil.
            // This typeMismatch is for when valueString is something like "abc" for an Int.
            throw ThemeParsingError.typeMismatch(key: line.key, expectedType: "convertible to \(T.self) or null keyword", actualValue: valueString, line: line.number)
        }
        return value
    }
    
    private mutating func parseStyleBlock(parentIndentSpaces: Int, contextKey: String) throws -> MarkdownElementStyle {
        var styleDict: [String: String] = [:]
        var tempCurrentIndex = currentIndex

        while tempCurrentIndex < lines.count {
            let lineContent = lines[tempCurrentIndex]
            // Comment stripping and basic parsing is now handled by a local call to a simplified nextMeaningfulLine logic
            // This avoids advancing the main currentIndex prematurely.
            
            var effectiveLineContent = lineContent
            if let commentStartIndex = effectiveLineContent.firstIndex(of: "#") {
                var inSingleQuotes = false
                var inDoubleQuotes = false
                var charBeforeComment: String.Index? = nil
                for index in effectiveLineContent.indices {
                    if effectiveLineContent[index] == "'" { inSingleQuotes.toggle() }
                    if effectiveLineContent[index] == "\"" { inDoubleQuotes.toggle() }
                    if effectiveLineContent[index] == "#" && !inSingleQuotes && !inDoubleQuotes {
                        charBeforeComment = index
                        break
                    }
                }
                if let actualCommentStart = charBeforeComment {
                     effectiveLineContent = String(effectiveLineContent[..<actualCommentStart])
                }
            }
            let trimmedLine = effectiveLineContent.trimmingCharacters(in: .whitespaces)

            if trimmedLine.isEmpty {
                tempCurrentIndex += 1
                continue
            }
            
            let leadingSpaces = effectiveLineContent.prefix(while: { $0.isWhitespace }).count
            
            if leadingSpaces < parentIndentSpaces + indentUnitSpaces { break }
            if leadingSpaces > parentIndentSpaces + indentUnitSpaces {
                throw ThemeParsingError.unexpectedIndentation(line: tempCurrentIndex + 1, expected: parentIndentSpaces + indentUnitSpaces, actual: leadingSpaces)
            }

            let currentLineNumber = tempCurrentIndex + 1
            var key: String
            var value: String?
            if let colonIndex = trimmedLine.firstIndex(of: ":") {
                key = String(trimmedLine[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let valueStartIndex = trimmedLine.index(after: colonIndex)
                var rawValue = String(trimmedLine[valueStartIndex...]).trimmingCharacters(in: .whitespaces)
                
                // Value part comment stripping (simplified)
                if !key.lowercased().contains("color") {
                    if let commentInValueIndex = rawValue.firstIndex(of: "#") {
                        var inSingleQuotesVal = false; var inDoubleQuotesVal = false
                        var actualCommentStartVal: String.Index? = nil
                        for index in rawValue.indices {
                             if rawValue[index] == "'" { inSingleQuotesVal.toggle() }
                             if rawValue[index] == "\"" { inDoubleQuotesVal.toggle() }
                             if rawValue[index] == "#" && !inSingleQuotesVal && !inDoubleQuotesVal { actualCommentStartVal = index; break }
                        }
                        if let acs = actualCommentStartVal { rawValue = String(rawValue[..<acs]).trimmingCharacters(in: .whitespaces) }
                    }
                }

                 if rawValue.isEmpty || rawValue.lowercased() == "null" || rawValue == "~" {
                    value = nil
                } else if (rawValue.starts(with: "'") && rawValue.hasSuffix("'")) || (rawValue.starts(with: "\"") && rawValue.hasSuffix("\"")) {
                    value = String(rawValue.dropFirst().dropLast())
                } else {
                    value = rawValue
                }
            } else {
                 throw ThemeParsingError.syntaxError(line: currentLineNumber, message: "Expected key-value pair for style property.")
            }
            
            if let val = value { styleDict[key] = val }
            
            tempCurrentIndex += 1
        }
        currentIndex = tempCurrentIndex

        return MarkdownElementStyle(
            fontName: styleDict["fontName"],
            fontSize: styleDict["fontSize"].flatMap { CGFloat($0) },
            isBold: styleDict["isBold"].flatMap { Bool($0) },
            isItalic: styleDict["isItalic"].flatMap { Bool($0) },
            foregroundColor: styleDict["foregroundColor"].flatMap { HexColor($0) },
            backgroundColor: styleDict["backgroundColor"].flatMap { HexColor($0) },
            strikethrough: styleDict["strikethrough"].flatMap { Bool($0) },
            underline: styleDict["underline"].flatMap { Bool($0) },
            paragraphSpacingBefore: styleDict["paragraphSpacingBefore"].flatMap { CGFloat($0) },
            paragraphSpacingAfter: styleDict["paragraphSpacingAfter"].flatMap { CGFloat($0) },
            lineHeightMultiplier: styleDict["lineHeightMultiplier"].flatMap { CGFloat($0) },
            firstLineHeadIndent: styleDict["firstLineHeadIndent"].flatMap { CGFloat($0) },
            headIndent: styleDict["headIndent"].flatMap { CGFloat($0) },
            tailIndent: styleDict["tailIndent"].flatMap { CGFloat($0) },
            kerning: styleDict["kerning"].flatMap { CGFloat($0) },
            alignment: styleDict["alignment"]
        )
    }

    private mutating func parseStylesDictionary(parentIndentSpaces: Int) throws -> [String: MarkdownElementStyle] {
        var stylesDictionary: [String: MarkdownElementStyle] = [:]
        
        while let peekedLine = peekNextMeaningfulLine(), peekedLine.indentSpaces > parentIndentSpaces {
             // Ensure the line is a direct child for the dictionary key
            guard peekedLine.indentSpaces == parentIndentSpaces + indentUnitSpaces else {
                throw ThemeParsingError.unexpectedIndentation(line: peekedLine.number, expected: parentIndentSpaces + indentUnitSpaces, actual: peekedLine.indentSpaces)
            }
            // Consume the line that is the key for the style block
            guard let keyLine = nextMeaningfulLine() else { break } // Should not happen if peekedLine was valid

            guard keyLine.value == nil else {
                throw ThemeParsingError.syntaxError(line: keyLine.number, message: "Expected new indented block for style key '\(keyLine.key)', not inline value.")
            }
            
            let elementName = keyLine.key
            let style = try parseStyleBlock(parentIndentSpaces: keyLine.indentSpaces, contextKey: elementName)
            stylesDictionary[elementName] = style
        }
        return stylesDictionary
    }
    
    private func peekNextMeaningfulLine() -> ParsedLine? {
        var tempParser = self
        return tempParser.nextMeaningfulLine()
    }

    private mutating func parse() throws -> MDEditorTheme {
        var themeName: String?
        var author: String?
        var descriptionText: String?
        var layoutDirection: TextDirection?
        var globalFontName: String?
        var globalBaseFontSize: CGFloat?
        var globalTextColor: HexColor?
        var globalBackgroundColor: HexColor?
        var globalAccentColor: HexColor?
        var defaultElementStyle: MarkdownElementStyle?
        var elementStyles: [String: MarkdownElementStyle] = [:]

        while let line = nextMeaningfulLine() {
            guard line.indentSpaces == 0 else {
                throw ThemeParsingError.unexpectedIndentation(line: line.number, expected: 0, actual: line.indentSpaces)
            }

            switch line.key {
            case "name": themeName = try parseValue(from: line, as: String.self)
            case "author": author = try parseOptionalValue(from: line, as: String.self)
            case "description": descriptionText = try parseOptionalValue(from: line, as: String.self)
            case "layoutDirection": layoutDirection = try parseOptionalValue(from: line, as: TextDirection.self)
            case "globalFontName": globalFontName = try parseOptionalValue(from: line, as: String.self)
            case "globalBaseFontSize": globalBaseFontSize = try parseOptionalValue(from: line, as: CGFloat.self)
            case "globalTextColor": globalTextColor = try parseOptionalValue(from: line, as: HexColor.self)
            case "globalBackgroundColor": globalBackgroundColor = try parseOptionalValue(from: line, as: HexColor.self)
            case "globalAccentColor": globalAccentColor = try parseOptionalValue(from: line, as: HexColor.self)
            case "defaultElementStyle":
                defaultElementStyle = try parseStyleBlock(parentIndentSpaces: line.indentSpaces, contextKey: "defaultElementStyle")
            case "elementStyles":
                elementStyles = try parseStylesDictionary(parentIndentSpaces: line.indentSpaces)
            default:
                throw ThemeParsingError.syntaxError(line: line.number, message: "Unknown top-level key: \(line.key)")
            }
        }
        
        guard let name = themeName else {
            throw ThemeParsingError.missingKey(key: "name", line: lines.count + 1) // Use last line + 1 if name missing by EOF
        }

        return MDEditorTheme(
            name: name, author: author, description: descriptionText, layoutDirection: layoutDirection,
            globalFontName: globalFontName, globalBaseFontSize: globalBaseFontSize,
            globalTextColor: globalTextColor, globalBackgroundColor: globalBackgroundColor, globalAccentColor: globalAccentColor,
            defaultElementStyle: defaultElementStyle, elementStyles: elementStyles
        )
    }

    public static func parse(themeFileContents: String) throws -> MDEditorTheme {
        var parser = ThemeParser(themeFileContents: themeFileContents)
        return try parser.parse()
    }
}
