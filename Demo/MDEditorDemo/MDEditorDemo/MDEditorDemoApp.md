
**I. Instructions to Add an iOS App Target to Your Swift Package:**

1.  **Open your `MDEditor` Swift Package in Xcode.**
2.  In the **Project Navigator** (left sidebar), select the **project icon** (the top-level item with the package name `MDEditor`).
3.  In the main editor area, you should see your project settings. Make sure the **PROJECT** (not TARGETS) is selected in the narrow sidebar within the editor.
4.  Look for the **"Targets"** section. You should see your `MDEditor` library target and `MDEditorTests` target.
5.  At the bottom of the "Targets" list, click the **"+" button** to add a new target.
6.  A sheet will appear. Select the **"iOS" tab** at the top.
7.  Choose the **"App"** template under "Application". Click **Next**.
8.  **Product Name:** Enter a name like `MDEditorDemo`.
9.  **Team:** Select your team if applicable.
10. **Bundle Identifier:** Xcode will suggest one (e.g., `com.yourdomain.MDEditorDemo`). You can customize it.
11. **Interface:** Choose **"SwiftUI"**.
12. **Life Cycle:** Choose **"SwiftUI App"**.
13. **Language:** Choose **"Swift"**.
14. **Include Tests:** You can uncheck this for the demo app unless you plan to write specific UI tests for it.
15. Click **Finish**.

Xcode will create a new group/folder in your Project Navigator for `MDEditorDemo` (or whatever name you chose), containing files like `MDEditorDemoApp.swift`, `ContentView.swift`, and an `Assets.xcassets` file.

**II. Link the Demo App to the `MDEditor` Library:**

The new demo app target needs to know about your `MDEditor` library.

1.  Select the `MDEditorDemo` **target** in the project settings (Targets list).
2.  Go to the **"General"** tab.
3.  Scroll down to the **"Frameworks, Libraries, and Embedded Content"** section.
4.  Click the **"+" button** under this section.
5.  A sheet will appear. You should see your `MDEditor` library product listed (it might be under "Workspace" or the project itself). Select **`MDEditor.framework`** (or just `MDEditor` if it appears as a library product).
6.  Click **Add**.

Now your `MDEditorDemo` app can import and use the `MDEditor` module.

**III. Code for the Demo App:**

**1. `MDEditorDemoApp.swift` (Main App File):**
   Replace the content of `MDEditorDemo/MDEditorDemoApp.swift` with:

   ```swift
   // MDEditorDemo/MDEditorDemoApp.swift
   import SwiftUI

   @main
   struct MDEditorDemoApp: App {
       var body: some Scene {
           WindowGroup {
               ContentView()
           }
       }
   }
   ```

**2. `ContentView.swift` (Main View for the Demo):**
   Replace the content of `MDEditorDemo/ContentView.swift` with:

   ```swift
   // MDEditorDemo/ContentView.swift
   import SwiftUI
   import MDEditor // Import your package library

   struct ContentView: View {
       // Sample Markdown text for the editor
       @State private var markdownText: String = """
       # Welcome to MDEditor!

       This is a demo of the `MDEditorView` component.

       ## Features Showcased:
       * **Bold text** and *italic text*.
       * ~~Strikethrough~~.
       * `Inline code`.
       * [A link to Swift.org](https://swift.org)

       ### Lists:
       1.  First ordered item.
           * Nested unordered item.
       2.  Second ordered item.
           1.  Further nested ordered item.

       ### Blockquote:
       > This is a blockquote.
       > It can span multiple lines.
       >> And can be nested!

       ### Code Block:
       ```swift
       import SwiftUI

       struct MyView: View {
           var body: some View {
               Text("Hello, MDEditor Demo!")
           }
       }
       ```
       ---
       A thematic break.
       """

       // Example of a custom style configuration
       private var customStyle: MarkdownContentRenderer.StyleConfiguration {
           var style = MarkdownContentRenderer.StyleConfiguration(baseFontSize: 16.0)
           // Customize further if needed, e.g.:
           // #if canImport(UIKit)
           // style.linkColor = .orange
           // #elseif canImport(AppKit)
           // style.linkColor = .orange
           // #endif
           return style
       }

       var body: some View {
           NavigationView {
               MDEditorView(
                   text: $markdownText,
                   initialMode: .view, // Start in view mode
                   styleConfiguration: customStyle // Pass the custom style
               )
               .navigationTitle("MDEditor Demo")
               .navigationBarTitleDisplayMode(.inline)
               // For macOS, you might want to manage the title differently or remove .inline
           }
           // On macOS, NavigationView might behave differently; consider a simpler VSplitView
           // or just the MDEditorView directly if not needing navigation.
       }
   }

   struct ContentView_Previews: PreviewProvider {
       static var previews: some View {
           ContentView()
       }
   }
   ```

**IV. Adding a macOS Demo App Target (Optional):**

If you also want a macOS demo:
1.  Follow the same steps as for iOS to add a new target (I.1 - I.5).
2.  In step I.6, select the **"macOS" tab**.
3.  Choose **"App"** and click Next.
4.  Product Name: e.g., `MDEditorDemoMac`.
5.  Interface: **"SwiftUI"**.
6.  Life Cycle: **"SwiftUI App"**.
7.  Language: **"Swift"**.
8.  Click Finish.
9.  Link it to the `MDEditor` library (Step II).
10. The `MDEditorDemoMacApp.swift` file will be similar.
11. The `ContentView.swift` can be very similar, but you might adjust the `NavigationView` or frame modifiers for a typical macOS window layout. For example, you might not use `NavigationView` at all for a simple macOS demo, or use `HSplitView`/`VSplitView`.

**V. Running the Demo App:**

1.  In Xcode's scheme selector (at the top, next to the Play/Stop buttons), choose the `MDEditorDemo` (iOS) scheme.
2.  Select an iOS Simulator or a connected iOS device.
3.  Click the **Play button (Build and Run)**.

Your demo iOS app should launch, displaying the `MDEditorView` with the sample Markdown content. You can switch between view and edit modes and interact with it.

This setup provides a self-contained way to test and showcase your `MDEditor` packa
