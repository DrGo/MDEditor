// MDEditorListRenderingTests.swift

import Testing
@testable import MDEditor
import Markdown
import SwiftUI // For MColor, MFont if needed indirectly

// Platform-specific typealiases for TestMColor and TestFont are assumed
// to be defined in another file within this test target (e.g., MDEditorTests.swift)

// Define custom tags by extending Testing.Tag if not already globally available
// This is added here to ensure the file compiles independently if needed.
// If this extension is already in MDEditorTests.swift and visible, this can be removed.
extension Testing.Tag {
    @Tag static var renderer: Self // Custom tag for renderer tests
    // Add other tags like .parsing, .themeStructure if they are used by suites in this file
    // and not defined globally for the test target.
}


@Suite("renderer: List Rendering Tests", .tags(.renderer))
struct MDEditorListRenderingTests {

    // Local helper function for rendering within this test suite
    func render(_ markdown: String, theme: MDEditorTheme = .internalDefault) -> NSAttributedString {
        var renderer = MarkdownContentRenderer(theme: theme)
        let document = Document(parsing: markdown)
        return renderer.attributedString(from: document)
    }

    // Local helper to extract paragraph styles for examination
    func getParagraphStyles(from attributedString: NSAttributedString) -> [NSParagraphStyle] {
        var styles: [NSParagraphStyle] = []
        attributedString.enumerateAttribute(.paragraphStyle,
                                           in: NSRange(location: 0, length: attributedString.length),
                                           options: []) { value, range, _ in
            if let style = value as? NSParagraphStyle {
                styles.append(style)
            }
        }
        return styles
    }
    
    // Local helper to check for list markers
    func countListMarkers(in string: String, marker: String) -> Int {
        return string.components(separatedBy: marker).count - 1
    }

    @Test("renderer: Simple Unordered List - Basic Structure and Markers")
    func testSimpleUnorderedList() {
        let markdown = """
        - Item 1
        - Item 2
        - Item 3
        """
        let attributedString = render(markdown)
        let string = attributedString.string

        #expect(string.contains("Item 1"))
        #expect(string.contains("Item 2"))
        #expect(string.contains("Item 3"))
        #expect(countListMarkers(in: string, marker: "•") >= 3, "Should find at least 3 bullet markers. Found: \(countListMarkers(in: string, marker: "•")) in '\(string.replacingOccurrences(of: "\n", with: "\\n"))'")
        
        let paragraphStyles = getParagraphStyles(from: attributedString)
        #expect(!paragraphStyles.isEmpty, "Should have paragraph styles for list items.")
    }

    @Test("renderer: Simple Ordered List - Basic Structure and Numbering")
    func testSimpleOrderedList() {
        let markdown = """
        1. First
        2. Second
        3. Third
        """
        let attributedString = render(markdown)
        let string = attributedString.string

        #expect(string.contains("1.\tFirst"))
        #expect(string.contains("2.\tSecond"))
        #expect(string.contains("3.\tThird"))
        
        let paragraphStyles = getParagraphStyles(from: attributedString)
        #expect(!paragraphStyles.isEmpty, "Should have paragraph styles for list items.")
    }

    @Test("renderer: Nested Unordered List - 2 Levels")
    func testNestedUnorderedListTwoLevels() {
        let markdown = """
        - Level 1 Item A
            - Level 2 Item A1
            - Level 2 Item A2
        - Level 1 Item B
        """
        let attributedString = render(markdown)
        let string = attributedString.string
        
        #expect(string.contains("Level 1 Item A"))
        #expect(string.contains("Level 2 Item A1"))
        #expect(string.contains("Level 2 Item A2"))
        #expect(string.contains("Level 1 Item B"))

        let newlines = string.components(separatedBy: "\n").count - 1
        #expect(newlines >= 3, "Expected at least 3 newlines for 4 items. Found: \(newlines)")
    }

    @Test("renderer: Nested Ordered List - 2 Levels")
    func testNestedOrderedListTwoLevels() {
        let markdown = """
        1. Level 1 Item X
            1. Level 2 Item X1
            2. Level 2 Item X2
        2. Level 1 Item Y
        """
        let attributedString = render(markdown)
        let string = attributedString.string

        #expect(string.contains("1.\tLevel 1 Item X"))
        #expect(string.contains("1.\tLevel 2 Item X1"))
        #expect(string.contains("2.\tLevel 2 Item X2"))
        #expect(string.contains("2.\tLevel 1 Item Y"))
    }

    @Test("renderer: Mixed Nested List - Unordered in Ordered - 2 Levels")
    func testMixedNestedListUnorderedInOrdered() {
        let markdown = """
        1. Ordered L1
            - Unordered L2 A
            - Unordered L2 B
        2. Ordered L1 Next
        """
        let attributedString = render(markdown)
        let string = attributedString.string
        
        #expect(string.contains("1.\tOrdered L1"))
        #expect(countListMarkers(in: string, marker: "•") >= 2)
        #expect(string.contains("Unordered L2 A"))
        #expect(string.contains("Unordered L2 B"))
        #expect(string.contains("2.\tOrdered L1 Next"))
    }
    
    @Test("renderer: Mixed Nested List - Ordered in Unordered - 2 Levels")
    func testMixedNestedListOrderedInUnordered() {
        let markdown = """
        - Unordered L1
            1. Ordered L2 X
            2. Ordered L2 Y
        - Unordered L1 Next
        """
        let attributedString = render(markdown)
        let string = attributedString.string
        
        #expect(string.contains("•\tUnordered L1"))
        #expect(string.contains("1.\tOrdered L2 X"))
        #expect(string.contains("2.\tOrdered L2 Y"))
        #expect(string.contains("•\tUnordered L1 Next"))
    }

    @Test("renderer: Deeply Nested List - 3 Levels Mixed")
    func testDeeplyNestedListThreeLevels() {
        let markdown = """
        1. Level 1 (Ordered)
            - Level 2 (Unordered)
                1. Level 3 (Ordered) - A
                2. Level 3 (Ordered) - B
            - Level 2 (Unordered) - Next
        2. Level 1 (Ordered) - Sibling
        """
        let attributedString = render(markdown)
        let string = attributedString.string

        #expect(string.contains("1.\tLevel 1 (Ordered)"))
        #expect(string.contains("•\tLevel 2 (Unordered)"))
        #expect(string.contains("1.\tLevel 3 (Ordered) - A"))
        #expect(string.contains("2.\tLevel 3 (Ordered) - B"))
        #expect(string.contains("•\tLevel 2 (Unordered) - Next"))
        #expect(string.contains("2.\tLevel 1 (Ordered) - Sibling"))

        let paragraphStyles = getParagraphStyles(from: attributedString)
        #expect(paragraphStyles.count >= 6, "Should have at least 6 paragraph styles for the items")
    }
    
    @Test("renderer: List Item with Multiple Paragraphs")
    func testListItemWithMultipleParagraphs() {
        let markdown = """
        - Item 1 Para 1
        
          Item 1 Para 2
        - Item 2
        """
        let attributedString = render(markdown)
        let string = attributedString.string
        
        #expect(string.contains("Item 1 Para 1"))
        #expect(string.contains("Item 1 Para 2"))
        #expect(string.contains("Item 2"))
        
        let newlines = string.components(separatedBy: "\n").count - 1
        // The expectation here depends on how MarkdownContentRenderer handles paragraph breaks within list items
        // If it adds double newlines effectively, this should be >=3. If single, then >=2.
        // The previous error showed 2 newlines, so the expectation was likely for more spacing.
        // Let's assume the fix in MarkdownContentRenderer aims for more separation.
        #expect(newlines >= 3, "Expected at least 3 newlines for distinct paragraphs in list. Found: \(newlines) in '\(string.replacingOccurrences(of: "\n", with: "\\n"))'")
    }
}
