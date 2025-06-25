// YamlParserTests.swift

import Testing
@testable import MDEditor
import Foundation
import SwiftUI 

@Suite("YamlParser - Front Matter & Core Functionality Tests")
struct YamlParserTests {

    struct TestError: Error, LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }

    // MARK: - Front Matter Specific Tests
    @Test("frontMatter: Parses full valid front matter block")
    func testFullValidFrontMatter() throws {
        let yamlContent = """
        ---
        title: "My Awesome Theme"
        author: "Dr. Go"
        description: "A truly remarkable theme for testing."
        createdOn: "2024-01-15"
        updatedOn: "2024-05-28T10:30:00Z"
        publishedOn: "2024-06-01"
        tags: "swift, parser, test"
        categories: "development, tools"
        ---
        layoutDirection: ltr 
        globalBaseFontSize: 16.0
        """
        let theme = try ThemeParser.parse(themeFileContents: yamlContent)
        let fm = theme.frontMatter
        #expect(fm.title == "My Awesome Theme")
        #expect(fm.author == "Dr. Go")
        #expect(fm.description == "A truly remarkable theme for testing.")
        let dateFormatter = ISO8601DateFormatter(); dateFormatter.formatOptions = [.withFullDate]
        let created = try #require(fm.createdOn)
        #expect(Calendar.current.isDate(created, equalTo: try #require(dateFormatter.date(from: "2024-01-15")), toGranularity: .day))
        let updated = try #require(fm.updatedOn)
        #expect(abs(updated.timeIntervalSince(try #require(ISO8601DateFormatter().date(from: "2024-05-28T10:30:00Z")))) < 1)
        let published = try #require(fm.publishedOn)
        #expect(Calendar.current.isDate(published, equalTo: try #require(dateFormatter.date(from: "2024-06-01")), toGranularity: .day))
        #expect(fm.tags == ["swift", "parser", "test"])
        #expect(fm.categories == ["development", "tools"])
        #expect(theme.layoutDirection == TextDirection.leftToRight) 
    }

    @Test("frontMatter: Unknown key in front matter throws error")
    func testUnknownKeyInFrontMatter() throws {
        let yamlContent = """
        ---
        title: "Test Theme"
        unknownKey: "some value"
        ---
        """
        var thrownError: Error?
        do { _ = try ThemeParser.parse(themeFileContents: yamlContent) } catch { thrownError = error }
        let yamlError = try #require(thrownError as? YamlParsingError)
        guard case .frontMatterSyntaxError(let line, let message) = yamlError else {
            Issue.record("Expected .frontMatterSyntaxError, got \(yamlError)"); return
        }
        #expect(line == 3)
        // Corrected: Match the exact message from YamlParser.parseFrontMatterBlock
        #expect(message == "Unknown key in front matter: 'unknownKey'")
    }

    // MARK: - Core YamlParser Functionality Tests
    @Test("yamlParser: Empty file throws error")
    func testEmptyFile() throws {
        let yamlContent = ""
        var thrownError: Error?
        do { _ = try ThemeParser.parse(themeFileContents: yamlContent) } catch { thrownError = error }
        let yamlError = try #require(thrownError as? YamlParsingError)
        #expect(yamlError == .contentEmptyOrInvalid)
    }

    @Test("yamlParser: Whitespace-only file throws error")
    func testWhitespaceOnlyFile() throws {
        let yamlContent = "   \n   \t   \n  "
        var thrownError: Error?
        do { _ = try ThemeParser.parse(themeFileContents: yamlContent) } catch { thrownError = error }
        let yamlError = try #require(thrownError as? YamlParsingError)
        #expect(yamlError == .contentEmptyOrInvalid)
    }

    @Test("yamlParser: File with only comments is treated like empty for body parsing")
    func testCommentOnlyFile() throws {
        let yamlContent = """
        # This is a comment only file
        # another comment
        """
        var thrownError: Error?
        do { _ = try ThemeParser.parse(themeFileContents: yamlContent) } catch { thrownError = error }
        let yamlError = try #require(thrownError as? YamlParsingError)
        // Corrected: The line number reported for missing key in an all-comment file.
        // ThemeParser.parse's errorLine calculation: `tempParserState.lines.isEmpty ? 1 : tempParserState.lines.count`
        // For the given yamlContent, lines.count is 2.
        #expect(yamlError == .missingKey(key: "title (in front matter) or name (legacy top-level)", line: 2, context: "Theme identifier is mandatory."))
    }
    // ... (other YamlParser specific tests like testMinimalFrontMatterOptionalTitlePresent, testFrontMatterNoTitle, testEmptyFrontMatterBlock, testMissingEndDelimiter, testInvalidDateFormat from previous version should be here)
    @Test("frontMatter: Parses minimal front matter (title optional, present here)")
    func testMinimalFrontMatterOptionalTitlePresent() throws {
        let yamlContent = """
        ---
        title: "Minimalistic"
        ---
        globalBaseFontSize: 12
        """
        let theme = try ThemeParser.parse(themeFileContents: yamlContent)
        #expect(theme.frontMatter.title == "Minimalistic")
        #expect(theme.frontMatter.author == nil)
        #expect(theme.globalBaseFontSize == 12) 
    }

    @Test("frontMatter: Parses front matter with no title")
    func testFrontMatterNoTitle() throws {
        let yamlContent = """
        ---
        author: "Anonymous"
        description: "A theme without a title in front matter."
        ---
        layoutDirection: rtl
        """
        let theme = try ThemeParser.parse(themeFileContents: yamlContent)
        #expect(theme.frontMatter.title == nil)
        #expect(theme.frontMatter.author == "Anonymous")
        #expect(theme.frontMatter.description == "A theme without a title in front matter.")
        #expect(theme.layoutDirection == TextDirection.rightToLeft)
    }

    @Test("frontMatter: Parses empty front matter block")
    func testEmptyFrontMatterBlock() throws {
        let yamlContent = """
        ---
        ---
        globalFontName: "Arial"
        """
        let theme = try ThemeParser.parse(themeFileContents: yamlContent)
        #expect(theme.frontMatter.title == nil)
        #expect(theme.frontMatter.author == nil)
        #expect(theme.globalFontName == "Arial") 
    }

    @Test("frontMatter: Missing end delimiter throws error")
    func testMissingEndDelimiter() throws {
        let yamlContent = """
        ---
        title: "No End"
        author: "Forgot"
        """ 
        var thrownError: Error?
        do { _ = try ThemeParser.parse(themeFileContents: yamlContent) } catch { thrownError = error }
        let yamlError = try #require(thrownError as? YamlParsingError)
        guard case .missingFrontMatterDelimiter(let position) = yamlError else {
            Issue.record("Expected .missingFrontMatterDelimiter, got \(yamlError)"); return
        }
        #expect(position == "end")
    }

    @Test("frontMatter: Invalid date format throws error")
    func testInvalidDateFormat() throws {
        let yamlContent = """
        ---
        title: "Bad Date Theme"
        createdOn: "15 January 2024" 
        ---
        """
        var thrownError: Error?
        do { _ = try ThemeParser.parse(themeFileContents: yamlContent) } catch { thrownError = error }
        let yamlError = try #require(thrownError as? YamlParsingError)
        guard case .typeMismatch(let key, _, let actual, let line, _) = yamlError else {
            Issue.record("Expected .typeMismatch for invalid date, got \(yamlError)"); return
        }
        #expect(key.hasSuffix("createdOn"))
        #expect(actual == "15 January 2024")
        #expect(line == 3)
    }
}

