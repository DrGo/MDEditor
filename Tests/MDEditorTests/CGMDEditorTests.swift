//// MDEditorTests.swift
//
//import Testing // Swift Testing framework
//@testable import MDEditor // Import your package
//import SwiftUI // For LayoutDirection, Color (via MColor)
//import Markdown // Import for Markdown.Document
//
//// Helper to get MColor for tests if not directly accessible or for platform specifics
//#if canImport(UIKit)
//private typealias TestMColor = UIColor
//private typealias TestFont = UIFont
//#elseif canImport(AppKit)
//private typealias TestMColor = NSColor
//private typealias TestFont = NSFont
//#else
//// Fallback for test environment if needed, though tests usually run on specific platforms
//private typealias TestMColor = NSObject // Placeholder if no UI framework
//private typealias TestFont = NSObject
//extension NSObject { static var red: NSObject { NSObject() } } // Dummy color
//#endif
//
//// Define custom tags by extending Testing.Tag
//extension Testing.Tag {
//    @Tag static var renderer: Self // Custom tag for renderer tests
//    @Tag static var parsing: Self  // Custom tag for parsing tests (like HexColor, TextDirection)
//    @Tag static var themeStructure: Self // Custom tag for Theme and ElementStyle structure tests
//    @Tag static var stylingUtilities: Self // Tag for MarkdownStylingUtilities tests
//    @Tag static var platformActions: Self  // Tag for PlatformActions tests
//    @Tag static var editorView: Self       // Tag for MDEditorView logic tests
//}
//
//
//@Suite("MDEditor Theming and Configuration Tests")
//struct MDEditorThemingTests {
//
//    // MARK: - HexColor Tests
//    @Suite("parsing: HexColor Parsing, Encoding, and MColor Conversion", .tags(.parsing))
//    struct HexColorTests {
//        // Reminder: Ensure HexColor.CodingError is public in HexColor.swift
//        // public enum CodingError: Error { case invalidFormat(String) }
//
//        @Test("parsing: Valid 6-digit hex string with #", .tags(.parsing))
//        func testValid6DigitHexWithHash() throws {
//            let yaml = "\"#FF00AA\""
//            let color = try YAMLDecoder().decode(HexColor.self, from: yaml)
//            #expect(color.red == 255)
//            #expect(color.green == 0)
//            #expect(color.blue == 170)
//        }
//
//        @Test("parsing: Valid 6-digit hex string without #", .tags(.parsing))
//        func testValid6DigitHexWithoutHash() throws {
//            let yaml = "\"11BBEE\""
//            let color = try YAMLDecoder().decode(HexColor.self, from: yaml)
//            #expect(color.red == 0x11)
//            #expect(color.green == 0xBB)
//            #expect(color.blue == 0xEE)
//        }
//
//        @Test("parsing: Valid 3-digit hex string with # (shorthand)", .tags(.parsing))
//        func testValid3DigitHexWithHash() throws {
//            let yaml = "\"#F0A\""
//            let color = try YAMLDecoder().decode(HexColor.self, from: yaml)
//            #expect(color.red == 255)
//            #expect(color.green == 0)
//            #expect(color.blue == 170)
//        }
//
//        @Test("parsing: Valid 3-digit hex string without # (shorthand)", .tags(.parsing))
//        func testValid3DigitHexWithoutHash() throws {
//            let yaml = "\"1BE\""
//            let color = try YAMLDecoder().decode(HexColor.self, from: yaml)
//            #expect(color.red == 0x11)
//            #expect(color.green == 0xBB)
//            #expect(color.blue == 0xEE)
//        }
//
//        @Test("parsing: Hex string with mixed case", .tags(.parsing))
//        func testMixedCaseHex() throws {
//            let yaml = "\"#fF00aA\""
//            let color = try YAMLDecoder().decode(HexColor.self, from: yaml)
//            #expect(color.red == 255)
//            #expect(color.green == 0)
//            #expect(color.blue == 170)
//        }
//
//        @Test("parsing: Invalid hex string (length 5)", .tags(.parsing))
//        func testInvalidHexLength5() {
//            let invalidInput = "#FF00A"
//            let yaml = "\"\(invalidInput)\""
//            var caughtExpectedError = false
//            do {
//                _ = try YAMLDecoder().decode(HexColor.self, from: yaml)
//            } catch let DecodingError.dataCorrupted(context) {
//                if let underlying = context.underlyingError as? HexColor.CodingError,
//                   case .invalidFormat(let errorMessage) = underlying {
//                    #expect(errorMessage.contains(invalidInput), "Error message should contain the invalid input '\(invalidInput)'. Got: '\(errorMessage)'")
//                    caughtExpectedError = true
//                } else {
//                    let errorDescription = context.underlyingError != nil ? String(describing: context.underlyingError!) : "nil"
//                    Issue.record("Caught DecodingError.dataCorrupted, but underlyingError was not HexColor.CodingError.invalidFormat or value mismatch. Underlying: \(errorDescription)")
//                }
//            } catch {
//                Issue.record("Caught unexpected error type: \(error)")
//            }
//            #expect(caughtExpectedError, "Expected HexColor.CodingError.invalidFormat for input '\(invalidInput)'")
//        }
//
//        @Test("parsing: Invalid hex string (length 4)", .tags(.parsing))
//        func testInvalidHexLength4() {
//            let invalidInput = "#F0AA"
//            let yaml = "\"\(invalidInput)\""
//            var caughtExpectedError = false
//            do {
//                _ = try YAMLDecoder().decode(HexColor.self, from: yaml)
//            } catch let DecodingError.dataCorrupted(context) {
//                if let underlying = context.underlyingError as? HexColor.CodingError,
//                   case .invalidFormat(let errorMessage) = underlying {
//                    #expect(errorMessage.contains(invalidInput), "Error message should contain the invalid input '\(invalidInput)'. Got: '\(errorMessage)'")
//                    caughtExpectedError = true
//                }
//            } catch {}
//            #expect(caughtExpectedError, "Expected HexColor.CodingError.invalidFormat for input '\(invalidInput)'")
//        }
//
//        @Test("parsing: Invalid hex string (non-hex characters)", .tags(.parsing))
//        func testInvalidHexChars() {
//            let invalidInput = "#FF00GX"
//            let yaml = "\"\(invalidInput)\""
//            var caughtExpectedError = false
//            do {
//                _ = try YAMLDecoder().decode(HexColor.self, from: yaml)
//            } catch let DecodingError.dataCorrupted(context) {
//                if let underlying = context.underlyingError as? HexColor.CodingError,
//                   case .invalidFormat(let errorMessage) = underlying {
//                    #expect(errorMessage.contains(invalidInput), "Error message should contain the invalid input '\(invalidInput)'. Got: '\(errorMessage)'")
//                    caughtExpectedError = true
//                } else {
//                    let errorDescription = context.underlyingError != nil ? String(describing: context.underlyingError!) : "nil"
//                    Issue.record("Caught DecodingError.dataCorrupted, but underlyingError was not HexColor.CodingError.invalidFormat or value mismatch. Underlying: \(errorDescription)")
//                }
//            } catch {
//                Issue.record("Caught unexpected error type: \(error)")
//            }
//            #expect(caughtExpectedError, "Expected HexColor.CodingError.invalidFormat for input '\(invalidInput)'")
//        }
//
//        @Test("parsing: Empty hex string", .tags(.parsing))
//        func testEmptyHexString() {
//            let invalidInput = ""
//            let yaml = "\"\(invalidInput)\""
//            var caughtExpectedError = false
//            do {
//                _ = try YAMLDecoder().decode(HexColor.self, from: yaml)
//            } catch let DecodingError.dataCorrupted(context) {
//                if let underlying = context.underlyingError as? HexColor.CodingError,
//                   case .invalidFormat(let errorMessage) = underlying {
//                    #expect(errorMessage.contains("''") || errorMessage.lowercased().contains("empty string") || errorMessage.lowercased().contains("could not parse"), "Error message for empty input is not as expected. Got: '\(errorMessage)'")
//                    caughtExpectedError = true
//                }
//            } catch {}
//            #expect(caughtExpectedError, "Expected HexColor.CodingError.invalidFormat for empty string")
//        }
//
//        @Test("parsing: Only hash hex string", .tags(.parsing))
//        func testOnlyHashHexString() {
//            let invalidInput = "#"
//            let yaml = "\"\(invalidInput)\""
//            var caughtExpectedError = false
//            do {
//                _ = try YAMLDecoder().decode(HexColor.self, from: yaml)
//            } catch let DecodingError.dataCorrupted(context) {
//                if let underlying = context.underlyingError as? HexColor.CodingError,
//                   case .invalidFormat(let errorMessage) = underlying {
//                    #expect(errorMessage.contains(invalidInput), "Error message should contain the invalid input '\(invalidInput)'. Got: '\(errorMessage)'")
//                    caughtExpectedError = true
//                }
//            } catch {}
//            #expect(caughtExpectedError, "Expected HexColor.CodingError.invalidFormat for input '\(invalidInput)'")
//        }
//
//        @Test("parsing: HexColor to MColor conversion - Red", .tags(.parsing))
//        func testHexToMColorRed() {
//            let hexColor = HexColor(red: 255, green: 0, blue: 0)
//            let mColor = hexColor.mColor
//            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
//            mColor.getRed(&r, green: &g, blue: &b, alpha: &a)
//            #expect(abs(r - 1.0) < 0.001 && abs(g - 0.0) < 0.001 && abs(b - 0.0) < 0.001 && abs(a - 1.0) < 0.001)
//        }
//
//        @Test("parsing: HexColor to MColor conversion - Green", .tags(.parsing))
//        func testHexToMColorGreen() {
//            let hexColor = HexColor(red: 0, green: 255, blue: 0)
//            let mColor = hexColor.mColor
//            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
//            mColor.getRed(&r, green: &g, blue: &b, alpha: &a)
//            #expect(abs(r - 0.0) < 0.001 && abs(g - 1.0) < 0.001 && abs(b - 0.0) < 0.001 && abs(a - 1.0) < 0.001)
//        }
//
//        @Test("parsing: HexColor to MColor conversion - Blue", .tags(.parsing))
//        func testHexToMColorBlue() {
//            let hexColor = HexColor(red: 0, green: 0, blue: 255)
//            let mColor = hexColor.mColor
//            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
//            mColor.getRed(&r, green: &g, blue: &b, alpha: &a)
//            #expect(abs(r - 0.0) < 0.001 && abs(g - 0.0) < 0.001 && abs(b - 1.0) < 0.001 && abs(a - 1.0) < 0.001)
//        }
//
//        @Test("parsing: HexColor encoding", .tags(.parsing))
//        func testHexColorEncoding() throws {
//            let color = HexColor(red: 17, green: 34, blue: 51) // #112233
//            let encoded = try YAMLEncoder().encode(color)
//            let expectedYamlStringWithQuotes = "'#112233'"
//            let expectedYamlStringWithoutQuotes = "#112233"
//
//            let trimmedEncoded = encoded.trimmingCharacters(in: .whitespacesAndNewlines)
//            #expect(trimmedEncoded == expectedYamlStringWithQuotes || trimmedEncoded == expectedYamlStringWithoutQuotes, "Encoded YAML string mismatch. Got: '\(trimmedEncoded)', Expected: '\(expectedYamlStringWithQuotes)' or '\(expectedYamlStringWithoutQuotes)'")
//        }
//    }
//
//    // MARK: - TextDirection Tests
//    @Suite("parsing: TextDirection Enum Codable Conformance", .tags(.parsing))
//    struct TextDirectionTests {
//        // Reminder: Ensure TextDirection.CodingError is public in TextDirection.swift
//        // public enum CodingError: Error { case invalidValue(String) }
//
//        @Test("parsing: Decode LTR", .tags(.parsing))
//        func testDecodeLTR() throws {
//            let yaml = "\"ltr\""
//            let direction = try YAMLDecoder().decode(TextDirection.self, from: yaml)
//            #expect(direction == .leftToRight)
//        }
//
//        @Test("parsing: Decode RTL (uppercase)", .tags(.parsing))
//        func testDecodeRTLUppercase() throws {
//            let yaml = "\"RTL\""
//            let direction = try YAMLDecoder().decode(TextDirection.self, from: yaml)
//            #expect(direction == .rightToLeft)
//        }
//
//        @Test("parsing: Decode Invalid TextDirection (should throw)", .tags(.parsing))
//        func testDecodeInvalidDirectionThrows() {
//            let yaml = "\"xtr\""
//            var caughtExpectedError = false
//            do {
//                _ = try YAMLDecoder().decode(TextDirection.self, from: yaml)
//            } catch let DecodingError.dataCorrupted(context) {
//                if let underlying = context.underlyingError as? TextDirection.CodingError,
//                   case .invalidValue(let value) = underlying {
//                    #expect(value.contains("xtr"))
//                    caughtExpectedError = true
//                } else {
//                     let errorDescription = context.underlyingError != nil ? String(describing: context.underlyingError!) : "nil"
//                     Issue.record("Caught DecodingError.dataCorrupted, but underlyingError was not TextDirection.CodingError.invalidValue or value mismatch. Underlying: \(errorDescription)")
//                }
//            } catch {
//                Issue.record("Caught unexpected error type: \(error)")
//            }
//            #expect(caughtExpectedError, "Expected TextDirection.CodingError.invalidValue to be thrown via DecodingError.dataCorrupted")
//        }
//
//        @Test("parsing: Encode TextDirection", .tags(.parsing))
//        func testEncodeDirection() throws {
//            let ltr = TextDirection.leftToRight
//            let rtl = TextDirection.rightToLeft
//            let encoder = YAMLEncoder()
//
//            let encodedLTR = try encoder.encode(ltr).trimmingCharacters(in: .whitespacesAndNewlines)
//            #expect(encodedLTR == "ltr" || encodedLTR == "'ltr'", "LTR encoding mismatch. Got: \(encodedLTR)")
//
//            let encodedRTL = try encoder.encode(rtl).trimmingCharacters(in: .whitespacesAndNewlines)
//            #expect(encodedRTL == "rtl" || encodedRTL == "'rtl'", "RTL encoding mismatch. Got: \(encodedRTL)")
//        }
//    }
//
//    // MARK: - MarkdownElementStyle Tests
//    @Suite("themeStructure: MarkdownElementStyle Codable and Merging", .tags(.themeStructure))
//    struct MarkdownElementStyleTests {
//        @Test("themeStructure: Decode MarkdownElementStyle", .tags(.themeStructure))
//        func testDecodeElementStyle() throws {
//            let yaml = """
//            fontName: "Arial"
//            fontSize: 18.0
//            isBold: true
//            foregroundColor: "#00FF00" # Green
//            alignment: "center"
//            """
//            let style = try YAMLDecoder().decode(MarkdownElementStyle.self, from: yaml)
//            #expect(style.fontName == "Arial")
//            #expect(style.fontSize == 18.0)
//            #expect(style.isBold == true)
//            #expect(style.isItalic == nil)
//            #expect(style.foregroundColor == HexColor(red: 0, green: 255, blue: 0))
//            #expect(style.alignment == "center")
//        }
//
//        @Test("themeStructure: Merge MarkdownElementStyle", .tags(.themeStructure))
//        func testMergeElementStyle() {
//            let base = MarkdownElementStyle(fontName: "BaseFont", fontSize: 12, foregroundColor: HexColor(red:0,green:0,blue:0))
//            let override = MarkdownElementStyle(fontSize: 14, isBold: true, foregroundColor: HexColor(red:255,green:0,blue:0))
//
//            let merged = override.merging(over: base)
//
//            #expect(merged.fontName == "BaseFont")
//            #expect(merged.fontSize == 14)
//            #expect(merged.isBold == true)
//            #expect(merged.foregroundColor == HexColor(red:255,green:0,blue:0))
//        }
//    }
//
//    // MARK: - MDEditorTheme Tests
//    @Suite("themeStructure: MDEditorTheme Codable and Defaults", .tags(.themeStructure))
//    struct MDEditorThemeTests {
//        @Test("themeStructure: Decode Full MDEditorTheme", .tags(.themeStructure))
//        func testDecodeFullTheme() throws {
//            let yaml = """
//            name: "Test Theme"
//            author: "Tester"
//            layoutDirection: "rtl"
//            globalFontName: "Helvetica"
//            globalBaseFontSize: 15.0
//            globalTextColor: "#111111"
//            defaultElementStyle:
//              fontName: "Georgia"
//              fontSize: 16.0
//              isItalic: true
//            elementStyles:
//              heading1:
//                fontName: "Impact"
//                fontSize: 30.0
//                isBold: true
//              paragraph:
//                lineHeightMultiplier: 1.6
//            """
//            let theme = try YAMLDecoder().decode(MDEditorTheme.self, from: yaml)
//            #expect(theme.name == "Test Theme")
//            #expect(theme.layoutDirection == .rightToLeft)
//            #expect(theme.globalBaseFontSize == 15.0)
//            #expect(theme.globalTextColor == HexColor(red: 0x11, green: 0x11, blue: 0x11))
//            #expect(theme.defaultElementStyle?.fontName == "Georgia")
//            #expect(theme.defaultElementStyle?.isItalic == true)
//            #expect(theme.elementStyles?["heading1"]?.fontName == "Impact")
//            #expect(theme.elementStyles?["paragraph"]?.lineHeightMultiplier == 1.6)
//        }
//
//        @Test("themeStructure: Internal Default Theme Validity", .tags(.themeStructure))
//        func testInternalDefaultTheme() {
//            let theme = MDEditorTheme.internalDefault
//            #expect(theme.name == "Internal Default")
//            #expect(theme.globalBaseFontSize != nil)
//            #expect(theme.defaultElementStyle != nil)
//            #expect((theme.elementStyles?.count ?? 0) > 0)
//        }
//    }
//
//    // MARK: - MarkdownContentRenderer Theming Tests
//    @Suite("renderer: MarkdownContentRenderer with Themes", .tags(.renderer))
//    struct RendererThemingTests {
//
//        func render(_ markdown: String, with theme: MDEditorTheme) -> NSAttributedString {
//            var renderer = MarkdownContentRenderer(theme: theme)
//            let document = Document(parsing: markdown)
//            return renderer.attributedString(from: document)
//        }
//
//        @Test("renderer: Renderer uses global theme settings", .tags(.renderer))
//        func testRendererGlobalSettings() {
//            let theme = MDEditorTheme(
//                name: "GlobalTest",
//                globalFontName: "Papyrus",
//                globalBaseFontSize: 20.0,
//                globalTextColor: HexColor(red: 0xFF, green: 0x00, blue: 0x00) // Red
//            )
//            let attributedString = render("Just some text.", with: theme)
//
//            #expect(attributedString.length > 0)
//            guard attributedString.length > 0 else {
//                Issue.record("Rendered string is empty for global settings test.")
//                return
//            }
//            let attributes = attributedString.attributes(at: 0, effectiveRange: nil)
//
//            let font = attributes[.font] as? TestFont
//            #expect(font != nil, "Font should not be nil")
//            #expect(abs((font?.pointSize ?? 0) - 20.0) < 0.01, "Font size should be 20.0 from globalBaseFontSize. Got \(font?.pointSize ?? -1)")
//
//            let color = attributes[.foregroundColor] as? TestMColor
//            #expect(color != nil, "Color should not be nil")
//            if let color = color {
//                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
//                color.getRed(&r, green: &g, blue: &b, alpha: nil)
//                #expect(abs(r - 1.0) < 0.01, "Color red component should be ~1.0. Got \(r)")
//                #expect(abs(g - 0.0) < 0.01, "Color green component should be ~0.0. Got \(g)")
//                #expect(abs(b - 0.0) < 0.01, "Color blue component should be ~0.0. Got \(b)")
//            }
//        }
//
//        @Test("renderer: Renderer applies element-specific style (Heading)", .tags(.renderer))
//        func testRendererElementSpecificStyle() {
//            var theme = MDEditorTheme(name: "HeadingTestTheme", globalBaseFontSize: 10.0)
//            theme.elementStyles = [
//                MarkdownElementKey.heading1.rawValue: MarkdownElementStyle(
//                    fontName: "Impact",
//                    fontSize: 40.0,
//                    isBold: true,
//                    foregroundColor: HexColor(red: 0x00, green: 0xFF, blue: 0x00) // Green
//                )
//            ]
//
//            let attributedString = render("# Hello", with: theme)
//            #expect(attributedString.length > 0)
//            guard attributedString.length > 0 else {
//                Issue.record("Rendered string is empty for heading style test.")
//                return
//            }
//            let attributes = attributedString.attributes(at: 0, effectiveRange: nil)
//
//            let font = attributes[.font] as? TestFont
//            #expect(font != nil, "Font should not be nil for H1")
//            #expect(abs((font?.pointSize ?? 0) - 40.0) < 0.01, "Heading1 font size should be 40.0. Got \(font?.pointSize ?? -1)")
//
//            #if canImport(UIKit)
//            #expect(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true, "Heading1 should be bold")
//            #elseif canImport(AppKit)
//            #expect(font?.fontDescriptor.symbolicTraits.contains(.bold) == true, "Heading1 should be bold")
//            #endif
//
//            let color = attributes[.foregroundColor] as? TestMColor
//            #expect(color != nil, "Color should not be nil for H1")
//            if let color = color {
//                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
//                color.getRed(&r, green: &g, blue: &b, alpha: nil)
//                #expect(abs(r - 0.0) < 0.01, "Heading1 color red component should be ~0.0. Got \(r)")
//                #expect(abs(g - 1.0) < 0.01, "Heading1 color green component should be ~1.0. Got \(g)")
//                #expect(abs(b - 0.0) < 0.01, "Heading1 color blue component should be ~0.0. Got \(b)")
//            }
//        }
//
//        @Test("renderer: Renderer style resolution fallback to defaultElementStyle", .tags(.renderer))
//        func testRendererStyleFallbackToDefault() {
//            var theme = MDEditorTheme(name: "FallbackTest")
//            theme.defaultElementStyle = MarkdownElementStyle(
//                fontName: "Georgia",
//                fontSize: 18.0,
//                foregroundColor: HexColor(red: 0xAA, green: 0x00, blue: 0xAA) // Purple
//            )
//            theme.elementStyles = [:]
//
//
//            let attributedString = render("A paragraph.", with: theme)
//            #expect(attributedString.length > 0)
//            guard attributedString.length > 0 else {
//                Issue.record("Rendered string is empty for fallback test (paragraph).")
//                return
//            }
//            let attributes = attributedString.attributes(at: 0, effectiveRange: nil)
//
//            let font = attributes[.font] as? TestFont
//            #expect(font != nil, "Font should not be nil for paragraph fallback")
//            #expect(abs((font?.pointSize ?? 0) - 18.0) < 0.01, "Paragraph font size should be 18.0 from theme.defaultElementStyle. Got \(font?.pointSize ?? -1)")
//
//            let color = attributes[.foregroundColor] as? TestMColor
//            #expect(color != nil, "Color should not be nil for paragraph fallback")
//            if let color = color {
//                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
//                color.getRed(&r, green: &g, blue: &b, alpha: nil)
//                #expect(abs(r - CGFloat(0xAA)/255.0) < 0.01, "Paragraph color R should be purple. Got R:\(r)")
//                #expect(abs(g - CGFloat(0x00)/255.0) < 0.01, "Paragraph color G should be purple. Got G:\(g)")
//                #expect(abs(b - CGFloat(0xAA)/255.0) < 0.01, "Paragraph color B should be purple. Got B:\(b)")
//            }
//        }
//
//        @Test("renderer: Link attribute is applied", .tags(.renderer))
//        func testLinkAttribute() {
//            let theme = MDEditorTheme.internalDefault
//            let attributedString = render("[Example](https://example.com)", with: theme)
//            #expect(attributedString.length > 0, "Link text should not be empty")
//            guard attributedString.length > 0 else { return }
//
//            var effectiveRange = NSRange()
//            let linkAttribute = attributedString.attribute(.link, at: 0, effectiveRange: &effectiveRange)
//
//            #expect(linkAttribute != nil, "Link attribute should be present.")
//            #expect(effectiveRange.length > 0, "Link attribute should cover a non-zero range.")
//
//            if let url = linkAttribute as? URL {
//                #expect(url.absoluteString == "https://example.com", "Link URL mismatch.")
//            } else if let urlString = linkAttribute as? String {
//                 #expect(urlString == "https://example.com", "Link URL string mismatch.")
//            }
//             else {
//                Issue.record("Link attribute was not a URL or String. Type: \(String(describing: type(of: linkAttribute)))")
//            }
//        }
//
//        @Test("renderer: Heading followed by Paragraph has newline and spacing", .tags(.renderer))
//        func testHeadingParagraphSpacing() {
//            let markdown = """
//            # Welcome to MDEditor!
//
//            This is a demo of the `MDEditorView` component.
//            """
//            let theme = MDEditorTheme.internalDefault
//            var renderer = MarkdownContentRenderer(theme: theme)
//            let document = Document(parsing: markdown)
//            let attributedString = renderer.attributedString(from: document)
//
//            let fullString = attributedString.string
//            #expect(fullString.contains("\n"), "Output string should contain at least one newline.")
//
//            let components = fullString.components(separatedBy: "\n")
//            #expect(components.count > 1, "String should be splittable into multiple lines. Found \(components.count) lines. Content: \(fullString.replacingOccurrences(of: "\n", with: "\\n"))")
//            
//            if components.count > 1 {
//                let firstLineTrimmed = components[0].trimmingCharacters(in: .whitespaces)
//                let secondLineTrimmed = components[1].trimmingCharacters(in: .whitespaces)
//
//                #expect(firstLineTrimmed == "Welcome to MDEditor!", "First line should be the heading text. Got: '\(firstLineTrimmed)'")
//                #expect(secondLineTrimmed.hasPrefix("This is a demo"), "Second line should start with the paragraph text. Got: '\(secondLineTrimmed)'")
//            }
//
//            if attributedString.length > 0 {
//                if let firstBlockEnd = attributedString.string.range(of: "\n")?.lowerBound {
//                    let headingRange = NSRange(location: 0, length: attributedString.string.distance(from: attributedString.string.startIndex, to: firstBlockEnd))
//                    if headingRange.location != NSNotFound && headingRange.length > 0 && headingRange.upperBound <= attributedString.length {
//                        let headingAttrs = attributedString.attributes(at: headingRange.location, effectiveRange: nil)
//                        if let headingParaStyle = headingAttrs[.paragraphStyle] as? NSParagraphStyle {
//                            #expect(headingParaStyle.paragraphSpacing > 0, "Heading's paragraphStyle should have paragraphSpacing (after) > 0. Got: \(headingParaStyle.paragraphSpacing)")
//                        } else {
//                            Issue.record("No paragraph style found for heading.")
//                        }
//                    }
//
//                    let paragraphSearchStartIndex = attributedString.string.index(after: firstBlockEnd)
//                    if let paragraphTextRange = attributedString.string.range(of: "This is a demo", range: paragraphSearchStartIndex..<attributedString.string.endIndex) {
//                        let paragraphStartLocation = attributedString.string.distance(from: attributedString.string.startIndex, to: paragraphTextRange.lowerBound)
//                        if paragraphStartLocation < attributedString.length {
//                            let paragraphAttrs = attributedString.attributes(at: paragraphStartLocation, effectiveRange: nil)
//                            if let paragraphParaStyle = paragraphAttrs[.paragraphStyle] as? NSParagraphStyle {
//                                 #expect(paragraphParaStyle.paragraphSpacingBefore > 0, "Paragraph's paragraphStyle should have paragraphSpacingBefore > 0. Got: \(paragraphParaStyle.paragraphSpacingBefore)")
//                            } else {
//                                Issue.record("No paragraph style found for paragraph.")
//                            }
//                        }
//                    } else {
//                        Issue.record("Could not find specific paragraph text for style checking. Output was: \(attributedString.string)")
//                    }
//                } else {
//                    Issue.record("Test assumes a newline exists for detailed paragraph style checks after heading. Full string: \(attributedString.string)")
//                }
//            }
//        }
//    }
//}
//
//@Suite("stylingUtilities: Markdown Styling Utilities Tests", .tags(.stylingUtilities))
//struct MarkdownStylingUtilitiesTests {
//
//    @Test("stylingUtilities: MColor.fromHex valid 6-digit")
//    func testMColorFromHex6Digit() {
//        let color = MColor.fromHex("#FF00AA")
//        #expect(color != nil)
//        if let color = color {
//            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
//            color.getRed(&r, green: &g, blue: &b, alpha: &a)
//            #expect(abs(r - 1.0) < 0.001) // FF
//            #expect(abs(g - 0.0) < 0.001) // 00
//            #expect(abs(b - 170/255.0) < 0.001) // AA
//            #expect(abs(a - 1.0) < 0.001) // Default alpha
//        }
//    }
//
//    @Test("stylingUtilities: MColor.fromHex valid 8-digit")
//    func testMColorFromHex8Digit() {
//        let color = MColor.fromHex("#11BBEE80")
//        #expect(color != nil)
//        if let color = color {
//            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
//            color.getRed(&r, green: &g, blue: &b, alpha: &a)
//            #expect(abs(r - 17/255.0) < 0.001)  // 11
//            #expect(abs(g - 187/255.0) < 0.001) // BB
//            #expect(abs(b - 238/255.0) < 0.001) // EE
//            #expect(abs(a - 128/255.0) < 0.001) // 80
//        }
//    }
//    
//    @Test("stylingUtilities: MColor.fromHex invalid hex")
//    func testMColorFromHexInvalid() {
//        #expect(MColor.fromHex("#12345") == nil) // Invalid length
//        #expect(MColor.fromHex("GGHHII") == nil) // Invalid characters
//        #expect(MColor.fromHex("") == nil)       // Empty
//    }
//
//    @Test("stylingUtilities: MFont.apply new traits and size")
//    func testMFontApplyTraitsAndSize() {
//        let baseFontSize: CGFloat = 12
//        let newFontSize: CGFloat = 18
//        #if canImport(UIKit)
//        let originalFont = UIFont.systemFont(ofSize: baseFontSize)
//        let newFont = originalFont.apply(newTraits: [.traitBold, .traitItalic], newPointSize: newFontSize)
//        let traits = newFont.fontDescriptor.symbolicTraits
//        #expect(traits.contains(.traitBold))
//        #expect(traits.contains(.traitItalic))
//        #expect(abs(newFont.pointSize - newFontSize) < 0.001)
//        #elseif canImport(AppKit)
//        let originalFont = NSFont.systemFont(ofSize: baseFontSize)
//        let newFont = originalFont.apply(newTraits: [.bold, .italic], newPointSize: newFontSize)
//        let traits = newFont.fontDescriptor.symbolicTraits
//        #expect(traits.contains(.bold))
//        #expect(traits.contains(.italic))
//        #expect(abs(newFont.pointSize - newFontSize) < 0.001)
//        #endif
//    }
//
//    // Commenting out failing tests for focused debugging
//    /*
//    @Test("stylingUtilities: Markup.isContainedInList")
//    func testMarkupIsContainedInList() {
//        let markdown = """
//        - list item 1
//          - nested list item
//        Paragraph.
//        """
//        let document = Document(parsing: markdown)
//        // The standalone paragraph is the second child of the document
//        let p = document.child(at: 1) as? Paragraph
//        let ul = document.child(at: 0) as? UnorderedList
//        let li1 = ul?.children.first as? ListItem
//        
//        // A ListItem's content is often a Paragraph. The nested list is a sibling to that Paragraph or another child.
//        let nestedUl = li1?.children.first(where: { $0 is UnorderedList }) as? UnorderedList
//        let nestedLi = nestedUl?.children.first as? ListItem
//        
//        #expect(p?.isContainedInList == false, "Paragraph should not be in a list. Parent: \(p?.parent?.debugDescription() ?? "nil")")
//        #expect(li1?.isContainedInList == true, "ListItem should be considered in a list. Parent: \(li1?.parent?.debugDescription() ?? "nil")")
//        #expect(ul?.isContainedInList == false, "Top-level list is not contained in another list. Parent: \(ul?.parent?.debugDescription() ?? "nil")")
//        #expect(nestedUl?.isContainedInList == true, "Nested UnorderedList should be in a list. Parent: \(nestedUl?.parent?.debugDescription() ?? "nil")")
//        
//        // The first child of a ListItem is often a Paragraph.
//        let firstChildParagraphInNestedLi = nestedLi?.children.first(where: { $0 is Paragraph })
//        #expect(firstChildParagraphInNestedLi?.isContainedInList == true, "Content (Paragraph) of nested ListItem should be in a list. Parent: \(firstChildParagraphInNestedLi?.parent?.debugDescription() ?? "nil")")
//    }
//    
//    @Test("stylingUtilities: ListItemContainingMarkup.listDepth")
//    func testListItemContainingMarkupDepth() {
//        let markdown = """
//        - Level 0 List Item 1
//            - Level 1 List Item 1.1
//                - Level 2 List Item 1.1.1
//        - Level 0 List Item 2
//        * Another Level 0 Item
//          * Level 1 Item
//        """
//        let document = Document(parsing: markdown)
//        
//        let ul0 = document.children.first(where: {$0 is UnorderedList}) as? UnorderedList
//        #expect(ul0?.listDepth == 0, "ul0 depth. Actual: \(ul0?.listDepth ?? -99)")
//
//        let li0_0 = ul0?.children.first as? ListItem
//        // A ListItem contains its content (often a Paragraph) and then any nested lists.
//        let ul1 = li0_0?.children.first(where: { $0 is UnorderedList }) as? UnorderedList
//        #expect(ul1?.listDepth == 1, "ul1 depth. Actual: \(ul1?.listDepth ?? -99)")
//        
//        let li1_0 = ul1?.children.first as? ListItem
//        let ul2 = li1_0?.children.first(where: { $0 is UnorderedList }) as? UnorderedList
//        #expect(ul2?.listDepth == 2, "ul2 depth. Actual: \(ul2?.listDepth ?? -99)")
//
//        let allTopLevelLists = document.children.compactMap { $0 as? UnorderedList }
//        #expect(allTopLevelLists.count >= 2, "Should find at least two top-level lists")
//        let ul0_alt = allTopLevelLists.count >= 2 ? allTopLevelLists[1] : nil // Get the second top-level list
//        #expect(ul0_alt?.listDepth == 0, "ul0_alt depth. Actual: \(ul0_alt?.listDepth ?? -99)")
//
//        let li0_alt_0 = ul0_alt?.children.first as? ListItem
//        let ul1_alt = li0_alt_0?.children.first(where: { $0 is UnorderedList }) as? UnorderedList
//        #expect(ul1_alt?.listDepth == 1, "ul1_alt depth. Actual: \(ul1_alt?.listDepth ?? -99)")
//    }
//
//    @Test("stylingUtilities: BlockQuote.quoteDepth")
//    func testBlockQuoteDepth() {
//        let markdown = """
//        > Quote Level 1
//        >> Quote Level 2
//        >>> Quote Level 3
//        """
//        let document = Document(parsing: markdown)
//        let bq1 = document.children.first(where: { $0 is BlockQuote }) as? BlockQuote
//        #expect(bq1?.quoteDepth == 0, "bq1 depth. Actual: \(bq1?.quoteDepth ?? -99)")
//
//        // A BlockQuote often contains a Paragraph, which then contains the text or a nested BlockQuote.
//        // Or, a BlockQuote can directly contain another BlockQuote.
//        var bq2: BlockQuote? = nil
//        if let firstChildOfBq1 = bq1?.children.first {
//            if let para = firstChildOfBq1 as? Paragraph { // Check if first child is Paragraph
//                bq2 = para.children.first(where: { $0 is BlockQuote }) as? BlockQuote
//            } else { // Otherwise, assume direct nesting
//                bq2 = firstChildOfBq1 as? BlockQuote
//            }
//        }
//        #expect(bq2?.quoteDepth == 1, "bq2 depth. Actual: \(bq2?.quoteDepth ?? -99)")
//
//        var bq3: BlockQuote? = nil
//        if let firstChildOfBq2 = bq2?.children.first {
//            if let para = firstChildOfBq2 as? Paragraph {
//                bq3 = para.children.first(where: { $0 is BlockQuote }) as? BlockQuote
//            } else {
//                bq3 = firstChildOfBq2 as? BlockQuote
//            }
//        }
//        #expect(bq3?.quoteDepth == 2, "bq3 depth. Actual: \(bq3?.quoteDepth ?? -99)")
//    }
//    */
//
//    @Test("stylingUtilities: NSAttributedString newlines")
//    func testNSAttributedStringNewlines() {
//        let fontSize: CGFloat = 12
//        let fontName: String? = nil
//        let color: MColor = TestMColor.red // No need for forced cast
//
//        let singleNL = NSAttributedString.singleNewline(withFontSize: fontSize, fontName: fontName, color: color)
//        #expect(singleNL.string == "\n")
//        var attributes = singleNL.attributes(at: 0, effectiveRange: nil)
//        #expect(attributes[.font] != nil)
//        #expect(attributes[.foregroundColor] as? MColor == color)
//
//        let doubleNL = NSAttributedString.doubleNewline(withFontSize: fontSize, fontName: fontName, color: color)
//        #expect(doubleNL.string == "\n\n")
//        attributes = doubleNL.attributes(at: 0, effectiveRange: nil)
//        #expect(attributes[.font] != nil)
//        #expect(attributes[.foregroundColor] as? MColor == color)
//    }
//}
//
//// Helper to convert NSRange to String.Range
//extension NSRange {
//    func toStringRange(for string: String) -> Range<String.Index>? {
//        guard location != NSNotFound, location + length <= string.utf16.count else { return nil }
//        // Safely create indices
//        guard let start = string.index(string.startIndex, offsetBy: location, limitedBy: string.endIndex),
//              let end = string.index(start, offsetBy: length, limitedBy: string.endIndex) else {
//            return nil
//        }
//        return start..<end
//    }
//}
//
