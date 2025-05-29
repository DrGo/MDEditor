# GFM Feature Showcase

This document demonstrates various GitHub Flavored Markdown features, including nesting and edge cases.

## Basic Formatting

This is a paragraph with **bold text**, *italic text*, and ***bold italic text***.
We can also use underscores: _italic_ and __bold__.
Let's test ~~strikethrough text~~.

An edge case: can we have **bold with _italic nested_ inside**? Or *italic with __bold nested__ inside*?
How about **bold with a \*literal asterisk\*** or *italic with a \_literal underscore\_*?

## Headings

### H3: Sub-section
#### H4: Deeper Sub-section
##### H5: Even Deeper
###### H6: The Deepest Standard Heading

## Blockquotes

> This is a simple blockquote.
> It can span multiple lines.

> Nested blockquotes:
>> Level 2 blockquote.
>>> Level 3 blockquote.
>>> More on level 3.
>> Back to level 2.
> Back to level 1.

> Blockquote with other elements:
> - A list item inside a blockquote.
>   - A nested list item.
> > ```swift
> > // A code block inside a nested blockquote
> > print("Hello, GFM!")
> > ```
> > #### An H4 heading in a blockquote

## Lists

### Unordered Lists

- Item 1
- Item 2
  - Nested Item 2.1
    - Deeper Nested Item 2.1.1
      - Even Deeper 2.1.1.1
  - Nested Item 2.2
- Item 3
  * Mixed marker (asterisk)
  + Mixed marker (plus)

Edge case: List item with multiple paragraphs.

- This is the first paragraph of a list item.
  A line that might seem like a new item but is part of the first paragraph due to indentation.

  This is the second paragraph of the same list item, separated by a blank line and indented.

- Next top-level item.

### Ordered Lists

1. First item
2. Second item
   1. Nested ordered item 2.1
      1. Deeper nested ordered item 2.1.1
   2. Nested ordered item 2.2
3. Third item
   i. Roman numeral (GFM might not style this differently from Arabic numerals, but it's valid Markdown)
   ii. Another Roman numeral

Edge case: Ordered list starting with a number other than 1.
3. This item is number 3.
4. This item is number 4.
1. This item is number 1 (restarts numbering).

### Task Lists (GFM Specific)

- [x] Completed task
- [ ] Incomplete task
- [ ] Another incomplete task
  - [x] Nested completed task
  - [ ] Nested incomplete task
    - [ ] Deeper nested task

## Code Blocks

### Fenced Code Blocks

```swift
// Swift code block
import SwiftUI

struct MyView: View {
    var body: some View {
        Text("Hello, Swift!")
    }
}
```javascript
// JavaScript code block
function greet(name) {
  console.log(`Hello, ${name}!`);
}
greet('GFM');

// No language specified
This is a generic code block.
It preserves whitespace.


### Indented Code Blocks (Less common with GFM, but part of core Markdown)

    // This is an indented code block
    let x = 10;
    if (x > 5) {
        print("x is greater than 5");
    }

## Inline Code

Use `inlineCode()` for short snippets like `variableName` or `functionCall()`.
What about `*asterisks*` or `_underscores_` inside inline code? They should be literal.
Or backticks themselves: `` ` `` or `` `code with backticks` ``.

## Horizontal Rules

---
***
___

Rules can be separated by text.

---

More text.

## Links

[GitHub](https://github.com)
[GitHub with a title](https://github.com "Visit GitHub!")
<https://www.example.com> (Autolink)
[Relative link](./another-file.md)

Edge case: Link with [nested **bold** and *italic* text](https://example.com).

## Images

![Alt text for an image](https://placehold.co/100x50/aabbcc/ffffff?text=Image)
![Alt text with a title](https://placehold.co/100x50/ddeeff/000000?text=Title! "Image Title")

Image as a link:
[![Linked Image Alt](https://placehold.co/80x40/aabbcc/ffffff?text=LinkImg)](https://example.com)

## Tables (GFM Specific)

| Header 1 | Header 2 | Header 3 |
| :------- | :------: | -------: |
| Align L  | Align C  | Align R  |
| Cell 1.1 | Cell 1.2 | Cell 1.3 |
| Cell 2.1 with more text | `code` | **bold** *italic* |
| Cell 3   |          |          |

Edge case: Table with pipes in content (must be escaped):
| Command | Description |
| ------- | ----------- |
| `ls \| grep .md` | List Markdown files (escaped pipe) |

## HTML (Behavior can vary based on renderer settings)

This is <strong>strong HTML</strong> and <em>emphasized HTML</em>.
<div>A div block with <a href="#">a link</a>.</div>

<details>
  <summary>Click to expand HTML details</summary>
  This content is hidden by default.
</details>

## Escaping Characters

\*literal asterisks\*
\\literal backslash\\
\`literal backtick\`
\{literal curly brace\}
\[literal square bracket\]
\(literal parenthesis\)
\#literal hash mark\#
\+literal plus sign\+
\-literal minus sign (hyphen)\-
\.literal dot\.
\!literal exclamation mark\!
\|literal pipe (for tables usually)\|

This concludes the GFM feature showcase.


