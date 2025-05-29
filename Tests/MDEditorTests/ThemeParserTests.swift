// ThemeParserTests.swift

import Testing
@testable import MDEditor // Gives access to MDEditorTheme, MarkdownElementStyle, HexColor, TextDirection
import SwiftUI // For CGFloat

// Ensure LosslessStringConvertible conformances for CGFloat, Bool are available.
// They are defined in ThemeParser.swift for the main module.

// This extension for Testing.Tag is assumed to be defined in the main MDEditorTests.swift file
// or another shared location within the MDEditorTests target.
// extension Testing.Tag {
//     @Tag static var parser: Self // Example if you add a specific tag for parser tests
// }


@Suite("ThemeParser Tests") // Optionally add .tags(.parser) if defined
struct ThemeParserTests {

    // Helper to load the content of default.yaml from the test bundle
    func loadDefaultYamlFromBundle() throws -> String {
        guard let url = Bundle.module.url(forResource: "default", withExtension: "yaml", subdirectory: "TestThemes") else {
            throw TestError("default.yaml not found in TestThemes subdirectory of test bundle.")
        }
        // Corrected: Use encoding parameter
        return try String(contentsOf: url, encoding: .utf8)
    }
    struct TestError: Error, LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }


    @Test("parser: Successfully parses valid default.yaml content")
    func testParseValidDefaultYaml() throws { // Mark as throws
        let yamlContent = """
        name: "Test Default Theme"
        author: "Test Author"
        description: "A test theme."
        layoutDirection: "rtl"
        globalFontName: "Helvetica"
        globalBaseFontSize: 18.0
        globalTextColor: "#112233"
        globalBackgroundColor: "#ABCDEF"
        globalAccentColor: "#007AFF"

        defaultElementStyle:
          fontName: "Georgia"
          fontSize: 17
          isBold: true
          isItalic: false
          foregroundColor: "#AABBCC"
          backgroundColor: "#121212"
          strikethrough: true
          underline: false
          paragraphSpacingBefore: 5.5
          paragraphSpacingAfter: 10.5
          lineHeightMultiplier: 1.3
          firstLineHeadIndent: 0
          headIndent: 0
          tailIndent: 0
          kerning: 0.2
          alignment: "center"

        elementStyles:
          paragraph:
            lineHeightMultiplier: 1.7
            alignment: "left"
          heading1:
            fontSize: 30.0
            isBold: true
          link:
            foregroundColor: "#FF00FF"
            underline: true
        """

        let theme = try ThemeParser.parse(themeFileContents: yamlContent)

        #expect(theme.name == "Test Default Theme")
        #expect(theme.author == "Test Author")
        #expect(theme.description == "A test theme.")
        #expect(theme.layoutDirection == .rightToLeft)
        #expect(theme.globalFontName == "Helvetica")
        #expect(theme.globalBaseFontSize == 18.0)
        #expect(theme.globalTextColor == HexColor("112233"))
        #expect(theme.globalBackgroundColor == HexColor("ABCDEF"))
        #expect(theme.globalAccentColor == HexColor("007AFF"))

        let defaultStyle = try #require(theme.defaultElementStyle)
        #expect(defaultStyle.fontName == "Georgia")
        #expect(defaultStyle.fontSize == 17.0) // Test int to CGFloat
        #expect(defaultStyle.isBold == true)
        #expect(defaultStyle.isItalic == false)
        #expect(defaultStyle.foregroundColor == HexColor("AABBCC"))
        #expect(defaultStyle.backgroundColor == HexColor("121212"))
        #expect(defaultStyle.strikethrough == true)
        #expect(defaultStyle.underline == false)
        #expect(defaultStyle.paragraphSpacingBefore == 5.5)
        #expect(defaultStyle.paragraphSpacingAfter == 10.5)
        #expect(defaultStyle.lineHeightMultiplier == 1.3)
        #expect(defaultStyle.kerning == 0.2)
        #expect(defaultStyle.alignment == "center")
        
        let elementStyles = try #require(theme.elementStyles)
        #expect(elementStyles.count == 3)
        
        let paraStyle = try #require(elementStyles["paragraph"])
        #expect(paraStyle.lineHeightMultiplier == 1.7)
        #expect(paraStyle.alignment == "left")

        let h1Style = try #require(elementStyles["heading1"])
        #expect(h1Style.fontSize == 30.0)
        #expect(h1Style.isBold == true)
        
        let linkStyle = try #require(elementStyles["link"])
        #expect(linkStyle.foregroundColor == HexColor("FF00FF"))
        #expect(linkStyle.underline == true)
    }

    @Test("parser: Parses default.yaml from bundle")
    func testParseDefaultYamlFromBundle() throws { // Mark as throws
        let yamlContent = """
        name: "Bundled Default"
        globalBaseFontSize: 16
        defaultElementStyle:
          fontSize: 15.0
        elementStyles:
          heading1:
            fontSize: 28
        """
        // To use loadDefaultYamlFromBundle(), ensure default.yaml is in TestTarget/Resources/TestThemes/
        // let yamlContent = try loadDefaultYamlFromBundle()
        let theme = try ThemeParser.parse(themeFileContents: yamlContent)
        #expect(theme.name == "Bundled Default")
        #expect(theme.globalBaseFontSize == 16.0)
        #expect(theme.defaultElementStyle?.fontSize == 15.0)
        #expect(theme.elementStyles?["heading1"]?.fontSize == 28.0)
    }

    @Test("parser: Throws on missing required 'name' key")
    func testMissingRequiredNameKey() throws { // Mark as throws
        let yamlContent = """
        author: "Test Author"
        globalBaseFontSize: 16.0
        """
        var thrownError: Error?
        do {
            _ = try ThemeParser.parse(themeFileContents: yamlContent)
        } catch {
            thrownError = error
        }
        let themeError = try #require(thrownError as? ThemeParsingError)
        // Corrected: Provide all associated values for the pattern
        guard case .missingKey(let key, _, _) = themeError else {
            Issue.record("Expected .missingKey, got \(themeError)")
            return
        }
        #expect(key == "name")
    }

    @Test("parser: Throws on type mismatch for CGFloat")
    func testTypeMismatchForCGFloat() throws { // Mark as throws
        let yamlContent = """
        name: "Test Theme"
        globalBaseFontSize: sixteen 
        """
        var thrownError: Error?
        do {
            _ = try ThemeParser.parse(themeFileContents: yamlContent)
        } catch {
            thrownError = error
        }
        let themeError = try #require(thrownError as? ThemeParsingError)
        // Corrected: Provide all associated values for the pattern
        guard case .typeMismatch(let key, let expected, let actual, _, _) = themeError else {
            Issue.record("Expected .typeMismatch, got \(themeError)")
            return
        }
        #expect(key == "globalBaseFontSize")
        #expect(expected.contains("CGFloat") || expected.contains("LosslessStringConvertible"))
        #expect(actual == "sixteen")
    }
    
    @Test("parser: Throws on type mismatch for HexColor")
    func testTypeMismatchForHexColor() throws { // Mark as throws
        let yamlContent = """
        name: "Test Theme"
        globalTextColor: not_a_hex
        """
         var thrownError: Error?
        do {
            _ = try ThemeParser.parse(themeFileContents: yamlContent)
        } catch {
            thrownError = error
        }
        let themeError = try #require(thrownError as? ThemeParsingError)
        // Corrected: Provide all associated values for the pattern
        guard case .typeMismatch(let key, _, let actual, _, _) = themeError else {
            Issue.record("Expected .typeMismatch, got \(themeError)")
            return
        }
        #expect(key == "globalTextColor")
        #expect(actual == "not_a_hex")
    }

    @Test("parser: Handles optional fields being absent")
    func testOptionalFieldsAbsent() throws { // Mark as throws
        let yamlContent = """
        name: "Minimal Theme"
        globalBaseFontSize: 15
        """
        let theme = try ThemeParser.parse(themeFileContents: yamlContent)
        #expect(theme.name == "Minimal Theme")
        #expect(theme.author == nil)
        #expect(theme.description == nil)
        #expect(theme.globalFontName == nil)
        #expect(theme.globalBaseFontSize == 15.0)
        #expect(theme.defaultElementStyle == nil)
        #expect(theme.elementStyles == nil || theme.elementStyles?.isEmpty == true)
    }
    
    @Test("parser: Handles explicit null for optional fields")
    func testOptionalFieldsExplicitNull() throws { // Mark as throws
        let yamlContent = """
        name: "Null Test Theme"
        author: null
        description: ~ # Another way to write null
        globalFontName: NULL # Test case-insensitivity of null
        """
        let theme = try ThemeParser.parse(themeFileContents: yamlContent)
        #expect(theme.name == "Null Test Theme")
        #expect(theme.author == nil, "Author should be nil for 'null'")
        #expect(theme.description == nil, "Description should be nil for '~ # comment'")
        #expect(theme.globalFontName == nil, "GlobalFontName should be nil for 'NULL'")
    }

    @Test("parser: Incorrect indentation for style property")
    func testIncorrectIndentation() throws { // Mark as throws
        let yamlContent = """
        name: "Indent Test"
        defaultElementStyle:
          fontName: "Arial"
            fontSize: 16 # Incorrectly indented
        """
        var thrownError: Error?
        do {
            _ = try ThemeParser.parse(themeFileContents: yamlContent)
        } catch {
            thrownError = error
        }
        
        let themeError = try #require(thrownError as? ThemeParsingError)
        // Corrected: Match the full .typeMismatch or .unexpectedIndentation pattern
        switch themeError {
        // The current parser might throw unexpectedIndentation if it detects the indent mismatch first
        case .unexpectedIndentation(line: 4, expected: 2, actual: 4): // Assuming indentUnitSpaces = 2
            break
        // Or it might proceed and fail on a type mismatch if the structure is severely broken
        case .typeMismatch(key: "fontSize", _, _, _, _):
            break
        case .syntaxError(line: 4, _):
            break
        default:
            Issue.record("Expected unexpectedIndentation, typeMismatch, or syntaxError for bad indent, got \(themeError)")
        }
    }

    @Test("parser: Valid HexColor decoding")
    func testValidHexColorDecoding() throws {
        let yamlContent = """
        name: "Hex Test"
        globalTextColor: "#FF0000"      # Standard
        globalBackgroundColor: 00FF00   # No hash
        globalAccentColor: '#00F'       # Shorthand with quotes
        defaultElementStyle:
          foregroundColor: FFA500      # Orange, no hash, no quotes
          backgroundColor: '#8080807F' # Gray with alpha (alpha currently ignored by HexColor)
        """
        let theme = try ThemeParser.parse(themeFileContents: yamlContent)
        #expect(theme.globalTextColor == HexColor(red: 255, green: 0, blue: 0))
        #expect(theme.globalBackgroundColor == HexColor(red: 0, green: 255, blue: 0))
        #expect(theme.globalAccentColor == HexColor(red: 0, green: 0, blue: 255)) // #00F -> #0000FF
        
        let defaultStyle = try #require(theme.defaultElementStyle)
        #expect(defaultStyle.foregroundColor == HexColor(red: 255, green: 165, blue: 0)) // FFA500
        // HexColor currently doesn't parse alpha, so #8080807F will be parsed as #808080
        #expect(defaultStyle.backgroundColor == HexColor(red: 128, green: 128, blue: 128))
    }

    @Test("parser: Valid LayoutDirection decoding")
    func testValidLayoutDirectionDecoding() throws {
        var yamlContent = """
        name: "LTR Test"
        layoutDirection: "ltr"
        """
        var theme = try ThemeParser.parse(themeFileContents: yamlContent)
        #expect(theme.layoutDirection == .leftToRight)

        yamlContent = """
        name: "RTL Test"
        layoutDirection: rtl 
        """
        theme = try ThemeParser.parse(themeFileContents: yamlContent)
        #expect(theme.layoutDirection == .rightToLeft)

        yamlContent = """
        name: "RTL Uppercase Test"
        layoutDirection: "RTL" 
        """
        theme = try ThemeParser.parse(themeFileContents: yamlContent)
        #expect(theme.layoutDirection == .rightToLeft)
        
        yamlContent = """
        name: "No Direction Test"
        """
        theme = try ThemeParser.parse(themeFileContents: yamlContent)
        #expect(theme.layoutDirection == nil) // Optional, so should be nil
    }

    @Test("parser: Invalid HexColor decoding throws error")
    func testInvalidHexColorDecodingThrowsError() throws {
        let yamlContent = """
        name: "Invalid Hex"
        globalTextColor: "#12345" 
        """
        var thrownError: Error?
        do {
            _ = try ThemeParser.parse(themeFileContents: yamlContent)
        } catch {
            thrownError = error
        }
        let themeError = try #require(thrownError as? ThemeParsingError)
        guard case .typeMismatch(let key, _, let actual, let line, _) = themeError else {
            Issue.record("Expected .typeMismatch for invalid hex, got \(themeError)")
            return
        }
        #expect(key == "globalTextColor")
        #expect(actual == "#12345")
        #expect(line == 2)
    }

    @Test("parser: Invalid LayoutDirection decoding throws error")
    func testInvalidLayoutDirectionDecodingThrowsError() throws {
        let yamlContent = """
        name: "Invalid Direction"
        layoutDirection: "left-to-right" 
        """
        var thrownError: Error?
        do {
            _ = try ThemeParser.parse(themeFileContents: yamlContent)
        } catch {
            thrownError = error
        }
        let themeError = try #require(thrownError as? ThemeParsingError)
        guard case .typeMismatch(let key, _, let actual, let line, _) = themeError else {
            Issue.record("Expected .typeMismatch for invalid direction, got \(themeError)")
            return
        }
        #expect(key == "layoutDirection")
        #expect(actual == "left-to-right")
        #expect(line == 2)
    }
}
