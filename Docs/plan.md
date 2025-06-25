
# MDEditor Swift Package

## Progress So Far:

1. Core Architecture & Setup:
* The Swift package targets macOS 15+ and iOS 18+.
* It utilizes swift-markdown (GitHub Flavored Markdown by default) for core parsing.
* A single-module structure (MDEditor) is in place.
* Platform-specific code has been largely isolated into separate files (e.g., MacOSEditorComponents.swift, IOSEditorComponents.swift).
* Platform-agnostic typealiases (MFont, MColor, MFontDescriptor) are used for cross-platform compatibility in rendering.

2. SwiftUI Editor View (MDEditorView.swift):
* MDEditorView is the primary SwiftUI component, taking a @Binding to the raw Markdown text.
* Manages .view and .edit modes.
* Edit Mode:
* Uses MacOSTextEditorView (an NSViewRepresentable wrapping NSTextView) on macOS for robust text editing and Undo/Redo.
* Uses IOSEditorTextView (a UIViewRepresentable wrapping UITextView) on iOS for enhanced control over text editing.
* The appearance of the editor in Edit Mode is configurable via an MDEditorConfiguration object, which is passed as a @Binding from the host application. This allows the host to control font, colors, line spacing, and layout direction.
* View Mode:
* Displays rendered Markdown.
* The rendering is driven by MarkdownContentRenderer.
* Toolbar:
* Provides mode switching (View/Edit).
* Includes a consolidated LTR/RTL toggle button that affects the active mode (View or Edit).
* Basic actions like "Clear Editor" and "Copy All" (raw Markdown).
* Undo/Redo buttons for Edit mode.

3. Markdown Rendering Engine (MarkdownContentRenderer.swift):
* Parses raw Markdown into an Abstract Syntax Tree (AST) using swift-markdown.
* Implements MarkupVisitor to traverse the AST.
* Advanced Theming System (View Mode):
* MDEditorTheme.swift: Defines a comprehensive theme structure, including global settings (font, colors, layout direction) and element-specific styles.
* MarkdownElementStyle.swift: Defines granular style properties (font, color, traits, paragraph settings) for individual Markdown elements.
* HexColor.swift: A robust, Codable struct for parsing HEX color strings (including shorthand) from theme files.
* TextDirection.swift: A Codable enum (ltr, rtl) for type-safe layout direction in themes and configurations.
* MarkdownContentRenderer is now initialized with an MDEditorTheme object.
* It features a style resolution mechanism that applies styles with a fallback order: theme's element-specific style -> theme's default element style -> internal default theme's specific style -> internal default theme's default style.
* All visit... methods are being refactored to use this new theme-driven style resolution.
* Caching: A basic NSCache is used for NSAttributedString (keyed by Markdown text only, with cache clearing on theme/style change).

4. Theme Loading:
* MDEditorView accepts an optional themeURL from the host application.
* If a themeURL is provided, MDEditorView attempts to load and parse the YAML theme file from that URL.
* If no themeURL is provided or loading fails, it falls back to an initialTheme (which defaults to MDEditorTheme.internalDefault).
* The host application is responsible for discovering theme files and providing the URL of the selected theme.

5. Platform Abstraction:
* MDEditorPlatformActions protocol and platform-specific structs (MacOSPlatformActions, IOSPlatformActions) abstract Undo/Redo and Copy operations.

## What Is Left To Do:
While the core theming structure is in place, significant work remains to fully leverage it in the renderer and to complete other features.

1. Finalize Theme-Driven Rendering in MarkdownContentRenderer:
* Complete visit... Methods: Ensure all visit... methods in MarkdownContentRenderer correctly and comprehensively use the resolved MarkdownElementStyle from the active MDEditorTheme to apply all defined attributes (fonts, colors, paragraph styles, decorations, etc.) to the NSAttributedString.
* Pay special attention to complex elements like lists (indentation, marker styling), blockquotes (recursive styling), and tables.
* Refine style inheritance for nested elements (e.g., a link within a heading).
* Test MColor.fromHex and Font Utilities: Confirm these are robust and all themed colors/fonts are applied as expected.

2. macOS Font Panel Integration (for editorConfiguration):
* Fully wire up the NSFontPanel on macOS (when invoked for Edit Mode) to update the bound editorConfiguration's editorFontName and editorFontSize. This involves ensuring MacOSTextEditorView.Coordinator.changeFont(_:) correctly modifies the binding.

3. macOS Font Panel for View Mode Theming (Advanced):
* Investigate and implement a mechanism for the macOS Font Panel to update the activeTheme in MDEditorView when in View Mode. This could involve:
* Modifying global font properties of a copy of the activeTheme.
* Making MDEditorView (or a helper object) a responder to changeFont(_:) actions.

4. Enhance Markdown Feature Support in MarkdownContentRenderer:
* GFM Tables: Implement visitTable, visitTableRow, and visitTableCell to correctly render tables using themed styles.
* Images: Enhance visitImage. Currently a placeholder link. Consider rendering actual images using NSTextAttachment (for NSAttributedString) or exploring SwiftUI Image embedding if feasible within the attributed string context. The theme could specify image alignment, max size, etc.
* Task Lists: Add rendering support for GitHub-style task lists (- [ ], - [x]). Consider interactivity (allowing clicks to toggle state, which would modify the raw Markdown).
* HTML Handling: Define and implement a clear strategy for rendering or stripping raw HTML blocks and inline HTML. The theme could specify how these are handled (e.g., display as a styled code block, strip, or attempt basic pass-through).

5. RTL and Internationalization Polish:
* Thorough RTL Testing: Conduct extensive testing with mixed Arabic/Latin text in both View and Edit modes, focusing on list numbering/bullet alignment, blockquote rendering, code block alignment, and overall text flow.
* Localization: Localize any user-facing strings within the editor's UI (e.g., tooltips, menu items if not using system symbols/defaults).

6. API, Performance, and Usability Polish:
* API Review: Finalize the public APIs of MDEditorView, MDEditorConfiguration, MDEditorTheme, MarkdownElementStyle, HexColor, and TextDirection for clarity, ease of use, and sensible defaults.
* Error Handling:
* Enhance error reporting for theme loading in MDEditorView (currently prints to console, could use the themeLoadingError state more visibly or offer a callback).
* Implement an error callback mechanism in MDEditorView for parsing or NSAttributedString conversion failures.
* Performance Optimization: Stress-test with very large Markdown documents and complex themes. Optimize parsing, style resolution, rendering, and caching logic if bottlenecks are identified.
* Accessibility: Review and ensure good accessibility for all editor components.

7. Documentation and Examples:
* README.md: (Generated in a separate step).
* Developer Documentation: Write comprehensive inline documentation (DocC) for all public types and methods.
* Demo App: Enhance the demo application to showcase all features, including theme selection from various sources, dynamic editor configuration changes, and all supported Markdown elements.

8. Testing:
* Unit Tests: (Generated a starting set in a separate step).
* Expand tests for MarkdownContentRenderer with various themes to verify correct NSAttributedString output for all Markdown inputs and element styles.
* Test MDEditorTheme and MarkdownElementStyle decoding with more complex and edge-case YAML.
* Test HexColor and TextDirection parsing more extensively.
* UI Tests: Consider UI tests for MDEditorView interactions if a suitable testing framework/approach is identified for package UI.

9. (Postponed) Front Matter:
* Implement YAML front matter parsing.
* Integrate storage and access to front matter data.
* Design and implement UI for viewing/editing front matter.


