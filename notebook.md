# The Idea

To convert from markdown to html we need:

    markdown -> tree -> html

1. Convert markdown text to data structure (Parse)
2. Convert data structure to html (Generate)

Something like this:

    markdown -> (markdown-to-hash) -> hash -> (hash-to-html) -> html

a markdown doc is represented with a tree (hash)

a tree is a list of nodes

a node is a hash with:

    {
      tag: string
      content: string | hash | array
      props: hash (key, value pairs)
    }

a node can contain either content (string), or a list of nodes (hash)

The flow is something like this:

### Markdown

    # Heading
    ### Another deeper heading
    
    Paragraphs are separated
    by a blank line.
    
    Two spaces at the end of a line leave a
    line break.
    
    _italic_, **bold**, `monospace`
    
    ---
    
    - apples
    - oranges
    - pears
    
    A [link](http://example.com).

# 👇
### ParseTree (Hash)

    [
      { tag: "h1", content: "Heading" },
      { tag: "h3", content: "Another deeper heading" },
      { tag: "p",  content: "Paragraphs are separated by a blank line." },
      { tag: "p", content: [
        "Two spaces at the end of a line leave a",
        { tag: "br", content: "line break." }
      ]},
      { tag: "p", content: [
        { tag: "i", content: "italic" },
        ", ",
        { tag: "strong", content: "bold" },
        ", ",
        { tag: "pre", content: "monospace" }
      ]},
      { tag: "hr" },
      { tag: "ul", content: [
        { tag: "li", content: "apples"  },
        { tag: "li", content: "oranges" },
        { tag: "li", content: "pears"   }
      ]},
      { tag: "p", content: [
        "A ",
        { tag: "a", href: "http://example.com", content: "link" },
        "."
      ]},
    ]

# 👇
### HTML

    <h1>Heading</h1>
    
    <h3>Another deeper heading</h3>
    
    <p>Paragraphs are separated
    by a blank line.</p>
    
    <p>Two spaces at the end of a line leave a <br>
    line break.</p>
    
    <p><em>italic</em>, <strong>bold</strong>, <code>monospace</code></p>
    
    <hr>
    
    <ul>
    <li>apples</li>
    <li>oranges</li>
    <li>pears</li>
    </ul>
    
    <p>A <a href="http://example.com">link</a>.</p>

# Resourses

read: https://daringfireball.net/projects/markdown/basics

# Test with

    cat example.md | markdown --html4tags

# History

# 2017-05-04

- Add the blockquote element
- Use html4 tags
- Refactor