// YamlParser.swift
// Contains generic parsing infrastructure for YAML-like file structures.

import Foundation
import CoreGraphics // For CGFloat

// Data structure for theme metadata, typically parsed from front matter.
// This is now part of YamlParser as it's a generic concept for YAML-like files.
public struct FrontMatterData: Codable, Equatable, Sendable, Hashable {
    public var title: String? // Optional as per new requirements
    public var author: String?
    public var description: String?
    public var createdOn: Date?
    public var updatedOn: Date?
    public var publishedOn: Date?
    public var tags: [String]?
    public var categories: [String]?

    public init(
        title: String? = nil,
        author: String? = nil,
        description: String? = nil,
        createdOn: Date? = nil,
        updatedOn: Date? = nil,
        publishedOn: Date? = nil,
        tags: [String]? = nil,
        categories: [String]? = nil
    ) {
        self.title = title
        self.author = author
        self.description = description
        self.createdOn = createdOn
        self.updatedOn = updatedOn
        self.publishedOn = publishedOn
        self.tags = tags
        self.categories = categories
    }
}

// LosslessStringConvertible conformances
extension CGFloat: @retroactive LosslessStringConvertible {
    public init?(_ description: String) {
        if let doubleValue = Double(description) {
            self = CGFloat(doubleValue)
        } else {
            if let intValue = Int(description) {
                self = CGFloat(intValue)
            } else {
                return nil
            }
        }
    }
}
// Standard Bool.init?(String) will be used.

// Generic Parsing Error enum
public enum YamlParsingError: Error, LocalizedError, CustomStringConvertible, Equatable {
    case fileNotFound(URL)
    case fileReadError(URL, Error) 
    case syntaxError(line: Int, message: String)
    case missingKey(key: String, line: Int, context: String? = nil)
    case typeMismatch(key: String, expectedType: String, actualValue: String, line: Int, context: String? = nil)
    case unexpectedIndentation(line: Int, expectedIndentCount: Int, actualIndentCount: Int)
    case contentEmptyOrInvalid
    case frontMatterSyntaxError(line: Int, message: String)
    case missingFrontMatterDelimiter(position: String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url): return "File not found at \(url.path)."
        case .fileReadError(let url, let error): return "Could not read file \(url.path): \(error.localizedDescription)"
        case .syntaxError(let line, let message): return "Syntax error at line \(line): \(message)."
        case .missingKey(let key, let line, let context):
            var msg = "Missing required key '\(key)' near line \(line)."
            if let ctx = context { msg += " (Context: \(ctx))" }
            return msg
        case .typeMismatch(let key, let expected, let actual, let line, let context):
            var msg = "Type mismatch for key '\(key)' at line \(line). Expected \(expected), found value: '\(actual)'."
            if let ctx = context { msg += " (Context: \(ctx))" }
            return msg
        case .unexpectedIndentation(let line, let expected, let actual): return "Unexpected indentation at line \(line). Expected indent level \(expected), found \(actual)."
        case .contentEmptyOrInvalid: return "Content is empty or invalid."
        case .frontMatterSyntaxError(let line, let message): return "Front matter syntax error at line \(line): \(message)."
        case .missingFrontMatterDelimiter(let position): return "Missing front matter delimiter '---' at the \(position) of the block."
        }
    }
    public var description: String { return errorDescription ?? "An unknown YAML parsing error occurred." }
    public static func == (lhs: YamlParsingError, rhs: YamlParsingError) -> Bool {
        switch (lhs, rhs) {
        case (.fileNotFound(let l), .fileNotFound(let r)): return l == r
        case (.fileReadError(let lu, let le), .fileReadError(let ru, let re)): return lu == ru && le.localizedDescription == re.localizedDescription
        case (.syntaxError(let ll, let lm), .syntaxError(let rl, let rm)): return ll == rl && lm == rm
        case (.missingKey(let lk, let ll, let lc), .missingKey(let rk, let rl, let rc)): return lk == rk && ll == rl && lc == rc
        case (.typeMismatch(let lk, let le, let la, let ll, let lc), .typeMismatch(let rk, let re, let ra, let rl, let rc)): return lk == rk && le == re && la == ra && ll == rl && lc == rc
        case (.unexpectedIndentation(let ll, let le, let la), .unexpectedIndentation(let rl, let re, let ra)): return ll == rl && le == re && la == ra
        case (.contentEmptyOrInvalid, .contentEmptyOrInvalid): return true
        case (.frontMatterSyntaxError(let ll, let lm), .frontMatterSyntaxError(let rl, let rm)): return ll == rl && lm == rm
        case (.missingFrontMatterDelimiter(let lp), .missingFrontMatterDelimiter(let rp)): return lp == rp
        default: return false
        }
    }
}

public struct ProcessedLine {
    let number: Int
    let indentCount: Int
    let key: String
    let rawValue: String?
    let isExplicitlyNull: Bool
}

public struct ParserState {
    var lines: [String]
    var currentIndex: Int = 0
    public let indentUnitSpaces: Int
    static let frontMatterDelimiterString = "---"

    public init(fileContents: String, indentUnitSpaces: Int = 2) {
        self.lines = fileContents.components(separatedBy: .newlines)
        self.indentUnitSpaces = indentUnitSpaces
    }

    mutating func lexLine(rawLineContent: String, number: Int, withinFrontMatter: Bool = false) throws -> ProcessedLine? {
        var effectiveContent = rawLineContent
        var inSingleQuotes = false; var inDoubleQuotes = false; var commentStartIndex: String.Index? = nil
        for index in effectiveContent.indices {
            let char = effectiveContent[index]
            if char == "'" && (index == effectiveContent.startIndex || effectiveContent[effectiveContent.index(before: index)] != "\\") { inSingleQuotes.toggle() }
            else if char == "\"" && (index == effectiveContent.startIndex || effectiveContent[effectiveContent.index(before: index)] != "\\") { inDoubleQuotes.toggle() }
            else if char == "#" && !inSingleQuotes && !inDoubleQuotes && (index == effectiveContent.startIndex || effectiveContent[effectiveContent.index(before: index)].isWhitespace) { commentStartIndex = index; break }
        }
        if let cs = commentStartIndex { effectiveContent = String(effectiveContent[..<cs]) }
        let trimmedLine = effectiveContent.trimmingCharacters(in: .whitespaces); if trimmedLine.isEmpty { return nil }
        let leadingSpaces = rawLineContent.prefix(while: { $0.isWhitespace }).count
        if !withinFrontMatter && trimmedLine != Self.frontMatterDelimiterString && (leadingSpaces % indentUnitSpaces != 0) { throw YamlParsingError.unexpectedIndentation(line: number, expectedIndentCount: leadingSpaces / indentUnitSpaces, actualIndentCount: -1) }
        let indentCount = withinFrontMatter ? 0 : leadingSpaces / indentUnitSpaces
        var keyString: String; var valuePart: String? = ""
        if let colonIndex = trimmedLine.firstIndex(of: ":") {
            keyString = String(trimmedLine[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            valuePart = String(trimmedLine[trimmedLine.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
        } else { keyString = trimmedLine }
        if keyString.isEmpty { return nil }
        var finalRawValue: String? = nil; var isExplicitlyNull = false
        if let valStr = valuePart, !valStr.isEmpty {
            if valStr.lowercased() == "null" || valStr == "~" { isExplicitlyNull = true }
            else if (valStr.starts(with: "'") && valStr.hasSuffix("'")) || (valStr.starts(with: "\"") && valStr.hasSuffix("\"")) { finalRawValue = String(valStr.dropFirst().dropLast()) }
            else { var tempVal = valStr
                if !withinFrontMatter && !keyString.lowercased().contains("color") && !tempVal.starts(with: "#") {
                     if let hi = tempVal.firstIndex(of: "#"), (hi == tempVal.startIndex || tempVal[tempVal.index(before: hi)].isWhitespace) { tempVal = String(tempVal[..<hi]).trimmingCharacters(in: .whitespaces) }
                }
                finalRawValue = tempVal.isEmpty ? nil : tempVal
            }
        }
        return ProcessedLine(number: number, indentCount: indentCount, key: keyString, rawValue: finalRawValue, isExplicitlyNull: isExplicitlyNull)
    }
    
    public mutating func nextLine(withinFrontMatterContext: Bool = false) throws -> ProcessedLine? {
        while currentIndex < lines.count {
            let currentLineNumber = currentIndex + 1; let rawLine = lines[currentIndex]; currentIndex += 1
            let trimmedRawLine = rawLine.trimmingCharacters(in: .whitespaces)
            if withinFrontMatterContext && trimmedRawLine == Self.frontMatterDelimiterString { return ProcessedLine(number: currentLineNumber, indentCount: 0, key: Self.frontMatterDelimiterString, rawValue: nil, isExplicitlyNull: false) }
            if let processed = try lexLine(rawLineContent: rawLine, number: currentLineNumber, withinFrontMatter: withinFrontMatterContext) { return processed }
        }
        return nil
    }
    public mutating func peekNextLine(withinFrontMatterContext: Bool = false) throws -> ProcessedLine? { var ts = self; return try ts.nextLine(withinFrontMatterContext: withinFrontMatterContext) }
}

public struct YamlParser {

    public static func parseValue<T: LosslessStringConvertible>(from line: ProcessedLine, as type: T.Type, contextKey: String? = nil) throws -> T {
        let k = contextKey ?? line.key; if line.isExplicitlyNull { throw YamlParsingError.typeMismatch(key: k, expectedType: "\(T.self)", actualValue: "null", line: line.number) }
        guard let vS = line.rawValue else { throw YamlParsingError.missingKey(key: k, line: line.number, context: "Value expected empty/null.") }; guard let v = T(vS) else { throw YamlParsingError.typeMismatch(key: k, expectedType: "\(T.self)", actualValue: vS, line: line.number) }; return v
    }
    public static func parseOptionalValue<T: LosslessStringConvertible>(from line: ProcessedLine, as type: T.Type, contextKey: String? = nil) throws -> T? {
        let k = contextKey ?? line.key; if line.isExplicitlyNull || line.rawValue == nil { return nil }; guard let v = T(line.rawValue!) else { throw YamlParsingError.typeMismatch(key: k, expectedType: "convertible to \(T.self) or null", actualValue: line.rawValue!, line: line.number) }; return v
    }
    public static func parseDate(from stringValue: String, forKey key: String, atLine line: Int) throws -> Date {
        let f1 = ISO8601DateFormatter(); if let d = f1.date(from: stringValue) { return d }
        let f2 = ISO8601DateFormatter(); f2.formatOptions = [.withFullDate]; if let d = f2.date(from: stringValue) { return d }
        let f3 = DateFormatter(); f3.dateFormat = "yyyy-MM-dd HH:mm:ss"; f3.locale = Locale(identifier: "en_US_POSIX"); if let d = f3.date(from: stringValue) { return d }
        let f4 = DateFormatter(); f4.dateFormat = "yyyy-MM-dd"; f4.locale = Locale(identifier: "en_US_POSIX"); if let d = f4.date(from: stringValue) { return d }
        throw YamlParsingError.typeMismatch(key: key, expectedType: "valid date string", actualValue: stringValue, line: line)
    }
    public static func parseStringArray(from stringValue: String) -> [String] {
        return stringValue.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private static func parseFrontMatterBlock(parserState: inout ParserState) throws -> FrontMatterData {
        var title: String? = nil; var author: String? = nil; var descriptionText: String? = nil; var createdOn: Date? = nil; var updatedOn: Date? = nil; var publishedOn: Date? = nil; var tags: [String]? = nil; var categories: [String]? = nil; var parsedFrontMatterKeys: Set<String> = []
        while let line = try parserState.nextLine(withinFrontMatterContext: true) {
            if line.key == ParserState.frontMatterDelimiterString { return FrontMatterData(title: title, author: author, description: descriptionText, createdOn: createdOn, updatedOn: updatedOn, publishedOn: publishedOn, tags: tags, categories: categories) }
            if parsedFrontMatterKeys.contains(line.key) { throw YamlParsingError.frontMatterSyntaxError(line: line.number, message: "Duplicate key: '\(line.key)'") }
            parsedFrontMatterKeys.insert(line.key)
            switch line.key {
            case "title": title = try self.parseOptionalValue(from: line, as: String.self)
            case "author": author = try self.parseOptionalValue(from: line, as: String.self)
            case "description": descriptionText = try self.parseOptionalValue(from: line, as: String.self)
            case "createdOn": if let v = line.rawValue { createdOn = try parseDate(from: v, forKey: line.key, atLine: line.number) } else if line.isExplicitlyNull { createdOn = nil }
            case "updatedOn": if let v = line.rawValue { updatedOn = try parseDate(from: v, forKey: line.key, atLine: line.number) } else if line.isExplicitlyNull { updatedOn = nil }
            case "publishedOn": if let v = line.rawValue { publishedOn = try parseDate(from: v, forKey: line.key, atLine: line.number) } else if line.isExplicitlyNull { publishedOn = nil }
            case "tags": if let v = line.rawValue { tags = parseStringArray(from: v) } else if line.isExplicitlyNull { tags = nil }
            case "categories": if let v = line.rawValue { categories = parseStringArray(from: v) } else if line.isExplicitlyNull { categories = nil }
            default: throw YamlParsingError.frontMatterSyntaxError(line: line.number, message: "Unknown key in front matter: '\(line.key)'")
            }
        }
        throw YamlParsingError.missingFrontMatterDelimiter(position: "end")
    }

    public static func parseYamlFile<BodyResult>(
        fileContents: String,
        indentUnitSpaces: Int = 2,
        bodyParser: (_ parserState: inout ParserState, _ frontMatterData: FrontMatterData?) throws -> BodyResult 
    ) throws -> (frontMatter: FrontMatterData?, body: BodyResult) {
        if fileContents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw YamlParsingError.contentEmptyOrInvalid }
        var parserState = ParserState(fileContents: fileContents, indentUnitSpaces: indentUnitSpaces)
        var frontMatterData: FrontMatterData? = nil
        var firstSignificantLineIndex = -1; var firstSignificantRawLineContent: String? = nil
        for i in 0..<parserState.lines.count {
            let rawLine = parserState.lines[i]; let trimmedLine = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty || trimmedLine.starts(with: "#") { continue }
            firstSignificantRawLineContent = trimmedLine; firstSignificantLineIndex = i; break
        }
        if let firstContent = firstSignificantRawLineContent, firstContent == ParserState.frontMatterDelimiterString {
            parserState.currentIndex = firstSignificantLineIndex
            _ = try parserState.nextLine(withinFrontMatterContext: true) 
            frontMatterData = try self.parseFrontMatterBlock(parserState: &parserState)
        }
        let bodyResult = try bodyParser(&parserState, frontMatterData)
        return (frontMatterData, bodyResult)
    }
}

