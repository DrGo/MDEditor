// ThemeParserTests.swift

import Testing
@testable import MDEditor
import SwiftUI
import Foundation

fileprivate extension HexColor {
    static func fromHexWithAlphaForTest(_ hexString: String) -> (rgbHexColor: HexColor, alpha: UInt8)? {
        var hex = hexString.trimmingCharacters(in: .alphanumerics.inverted); if hex.hasPrefix("#") { hex.remove(at: hex.startIndex) }
        guard hex.count == 8 else { return nil }; var rgbaValue: UInt64 = 0; guard Scanner(string: hex).scanHexInt64(&rgbaValue) else { return nil }
        let r = UInt8((rgbaValue & 0xFF000000) >> 24); let g = UInt8((rgbaValue & 0x00FF0000) >> 16); let b = UInt8((rgbaValue & 0x0000FF00) >> 8); let a = UInt8(rgbaValue & 0x000000FF)
        return (HexColor(red: r, green: g, blue: b), a)
    }
}

@Suite("ThemeParser - Theme Structure & Legacy Tests")
struct ThemeParserStructureTests {

    struct TestError: Error, LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }

    @Test("parser: Successfully parses valid theme (legacy structure)")
    func testParseValidLegacyStructure() throws {
        let yamlContent = """
        name: "Test Legacy Theme"
        author: "Legacy Author"
        description: "A legacy theme."
        layoutDirection: "rtl"
        globalFontName: "Helvetica"
        globalBaseFontSize: 16.0
        defaultElementStyle:
          fontSize: 15.0
          foregroundColor: "#111111"
        elementStyles:
          heading1:
            fontSize: 28.0
            isBold: true
          paragraph:
            alignment: "justify"
            lineHeightMultiplier: 1.8
            animationHintDuration: "0.5s"
        """
        let theme = try ThemeParser.parse(themeFileContents: yamlContent)
        #expect(theme.frontMatter.title == "Test Legacy Theme")
        #expect(theme.frontMatter.author == "Legacy Author")
        #expect(theme.frontMatter.description == "A legacy theme.")
        #expect(theme.layoutDirection == TextDirection.rightToLeft)
        #expect(theme.globalFontName == "Helvetica")
        #expect(theme.globalBaseFontSize == 16.0)
        let defaultStyle = try #require(theme.defaultElementStyle)
        #expect(defaultStyle.fontSize == 15.0)
        #expect(defaultStyle.foregroundColor == HexColor("111111"))
        let elementStyles = try #require(theme.elementStyles)
        let h1Style = try #require(elementStyles["heading1"])
        #expect(h1Style.fontSize == 28.0)
        #expect(h1Style.isBold == true)
        let paraStyle = try #require(elementStyles["paragraph"])
        #expect(paraStyle.alignment == "justify")
        #expect(paraStyle.lineHeightMultiplier == 1.8)
        #expect(paraStyle.animationHintDuration == 0.5)
    }

    @Test("parser: Throws on missing required 'name' key (legacy structure)")
    func testMissingRequiredNameKeyLegacy() throws {
        let yamlContent = """
        author: "Legacy Author Only"
        globalBaseFontSize: 16.0
        """
        var thrownError: Error?
        do { _ = try ThemeParser.parse(themeFileContents: yamlContent) } catch { thrownError = error }
        let yamlError = try #require(thrownError as? YamlParsingError)
        guard case .missingKey(let key, _, _) = yamlError else { Issue.record("Expected .missingKey, got \(yamlError)"); return }
        #expect(key == "title (in front matter) or name (legacy top-level)")
    }

    @Test("parser: Duplicate top-level key throws error (legacy)")
    func testDuplicateTopLevelKeyLegacy() throws {
        let yamlContent = """
        name: "Theme One"
        author: "Author A"
        name: "Theme Two" 
        """
        var thrownError: Error?
        do { _ = try ThemeParser.parse(themeFileContents: yamlContent) } catch { thrownError = error }
        let yamlError = try #require(thrownError as? YamlParsingError)
        guard case .syntaxError(let line, let message) = yamlError else { Issue.record("Expected .syntaxError for duplicate key, got \(yamlError)"); return }
        #expect(line == 3)
        #expect(message == "Duplicate top-level key in theme body: 'name'")
    }

    // MARK: - AnimationHintDuration Tests (Theme-specific style property)
    @Test("animationHintDuration: Parses valid time intervals in defaultElementStyle")
    func testValidAnimationHintDurationInDefault() throws {
        let yamlContent = """
        name: "Animation Theme" 
        defaultElementStyle:
          animationHintDuration: "1.5s"
        """
        let theme = try ThemeParser.parse(themeFileContents: yamlContent)
        let defaultStyle = try #require(theme.defaultElementStyle)
        #expect(defaultStyle.animationHintDuration == 1.5)
    }

    @Test("animationHintDuration: Parses various valid time intervals in elementStyles")
    func testValidAnimationHintDurationInElement() throws {
        let simplerYamlContent = """
        name: "Animation Theme Elements"
        elementStyles:
          paragraph:
            animationHintDuration: "0.25s"
          heading1:
            animationHintDuration: "2m30s" 
          heading2:
            animationHintDuration: "1h"
          heading3:
            animationHintDuration: "10m"
          heading4:
            animationHintDuration: "0s"
          heading5:
            animationHintDuration: "1h 30m 15s"
        """
        let theme = try ThemeParser.parse(themeFileContents: simplerYamlContent)
        let elementStyles = try #require(theme.elementStyles)
        
        let paraStyle = try #require(elementStyles["paragraph"])
        #expect(paraStyle.animationHintDuration == 0.25)

        let h1Style = try #require(elementStyles["heading1"])
        #expect(h1Style.animationHintDuration == TimeInterval(150))

        let h2Style = try #require(elementStyles["heading2"])
        #expect(h2Style.animationHintDuration == TimeInterval(3600))

        let h3Style = try #require(elementStyles["heading3"])
        #expect(h3Style.animationHintDuration == TimeInterval(600))

        let h4Style = try #require(elementStyles["heading4"])
        #expect(h4Style.animationHintDuration == 0.0)

        let h5Style = try #require(elementStyles["heading5"])
        let expectedH5Duration: TimeInterval = TimeInterval(1 * 3600 + 30 * 60 + 15)
        #expect(h5Style.animationHintDuration == expectedH5Duration)
    }

    @Test("animationHintDuration: Invalid time interval string throws error")
    func testInvalidAnimationHintDuration() throws {
        let yamlContent = """
        name: "Bad Animation Theme"
        defaultElementStyle:
          animationHintDuration: "10seconds" 
        """
        var thrownError: Error?
        do { _ = try ThemeParser.parse(themeFileContents: yamlContent) } catch { thrownError = error }
        let yamlError = try #require(thrownError as? YamlParsingError)
        guard case .typeMismatch(let key, let expectedType, let actual, let line, _) = yamlError else {
            Issue.record("Expected .typeMismatch for invalid duration, got \(yamlError)"); return
        }
        #expect(key == "defaultElementStyle.animationHintDuration")
        #expect(actual == "e") 
        // Corrected: Match the exact expectedType string from the parser for this failure.
        #expect(expectedType == "valid time string component (number, unit, or separator)")
        #expect(line == 3)
    }
    
    @Test("animationHintDuration: Handles explicit null")
    func testAnimationHintDurationExplicitNull() throws {
        let yamlContent = """
        name: "Null Animation Theme"
        defaultElementStyle:
          animationHintDuration: null
        """
        let theme = try ThemeParser.parse(themeFileContents: yamlContent)
        let defaultStyle = try #require(theme.defaultElementStyle)
        #expect(defaultStyle.animationHintDuration == nil)
    }

    @Test("animationHintDuration: Number without unit at end of string is an error")
    func testAnimationHintDurationNumberWithoutUnitAtEnd() throws {
        let yamlContent = """
        name: "Bad Animation"
        defaultElementStyle:
          animationHintDuration: "10s 5" 
        """
        var thrownError: Error?
        do { _ = try ThemeParser.parse(themeFileContents: yamlContent) } catch { thrownError = error }
        let yamlError = try #require(thrownError as? YamlParsingError)
        guard case .typeMismatch(let key, let expectedType, let actualValue, let line, _) = yamlError else {
            Issue.record("Expected .typeMismatch for trailing number without unit, got \(yamlError)"); return
        }
        #expect(key == "defaultElementStyle.animationHintDuration")
        #expect(expectedType.contains("time unit for trailing number"))
        #expect(actualValue == "5")
        #expect(line == 3)
    }

    @Test("animationHintDuration: Number without unit before separator is an error")
    func testAnimationHintDurationNumberWithoutUnitBeforeSeparator() throws {
        let yamlContent = """
        name: "Bad Animation 2"
        defaultElementStyle:
          animationHintDuration: "10 5s" 
        """
        var thrownError: Error?
        do { _ = try ThemeParser.parse(themeFileContents: yamlContent) } catch { thrownError = error }
        let yamlError = try #require(thrownError as? YamlParsingError)
        guard case .typeMismatch(let key, let expectedType, _, let line, _) = yamlError else {
            Issue.record("Expected .typeMismatch for number without unit before separator, got \(yamlError)"); return
        }
        #expect(key == "defaultElementStyle.animationHintDuration")
        #expect(expectedType.contains("time unit after number"))
        #expect(line == 3)
    }
}

