Heading
## Sub-heading
### Another deeper heading

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

# 2017-05-05

Try this separate the text into chunks then reduce each chunk.

    md = "
      # Heading
      ## Sub-heading
      ### Another deeper heading
      
      Paragraphs are separated
      by a blank line.
      
      Two spaces at the end of a line leave a  
      line break.
      
      Text attributes _italic_, **bold**, `monospace`.
      
      > This is a blockquote
      
      Horizontal rule:
      
      ---
      
      Bullet list:
      
        * apples
        * oranges
        * pears
        
      Numbered list:
      
        1. apples
        2. oranges
        3. pears
      
      A [link](http://example.com)."
      
      puts md.gsub(/^\s*$/,'•')

# 2017-05-06


The markdown documentation by groover says that:

Block elements are divided by empty lines
Empty lines are lines that have only newline or space characters.

With this regexp `/^\s*$/` we seem to be able to divide the text into chunks

these chunks could be any block element like: headings, lists, blockquote, paragraphs

So I think that the process is going to be like this:

divide the input string into chunks
identify each chunk with a tag
then try to identify inline elements within the blocks elements
until there no element can be identified


We can start assuming that each chunk is a paragraph and gradually add oder elements that have more precedence for example, let's say we have this chunk:

    # Heading
    ## Sub-heading
    ### Another deeper heading

if we didn't have the headings rule this should be translated into a paragraph: 

    <p>
    # Heading
    ## Sub-heading
    ### Another deeper heading
    </p>

but adding the headings rules the iteration would go like this:

idenfity(chunk) -> [paragraph, h1, h2, h3]

in which case we need to ask, what is this chunk?
is it a paragraph?
what is a paragraph?
  A paragraph is a chunk what has no other block elements
  
Asking it is a paragraph? is the wrong question, because inside a chunk there can be more than one paragraph combined with other elements.

So we need to ask: are there any elements other than paragraphs?

Splitting the text into chunks with `/^\s*$/` doesn't seem to work

It seems like we need to take into consideration what's behind a chunk/line before we can identify it.

Instead of splitting by big chunks we could split the whole thing into lines a process each line. But doing it this way we need to know in what context we're currently in because we can't identify block elements just by looking line by line, we need to look at several lines at once.

It looks like we need to traverse the string caracter by caracter and keep a state of where we are and where we've been.

Lets try line by line first...

1. split into lines
2. iterate over lines until something looks like another block element...
  
    1 # h1
    2 p1
    3 p1
    4 ## h2
    5 p2
    6 p2
    7
    8 - uno
    9 - dos

1: inital_line:0, current_line:1, initial_guess: ?, current_guess: h1
  
from line 0 to line 1 is h1. Because headings headings span only one line.
we don't need to know what was behind.

    set initial_line to current_line
  
2: from_line:2, to_line:2, guess:? -> from_line:2, to_line:2, guess:p
  
current guess is P because we can't identify it as anything else
are we done with current chunk? no, because paragraphs can span multiple lines
and we don't know that the next line is yet.

3: from_line:2, to_line:2, guess:p -> from_line:2, to_line:3, guess:p -> 

current guess is P because we can't identify it as anything else
are we done with current chunk? no, because paragraphs can span multiple lines
and we don't know that the next line is yet.

4: from_line:2, to_line:3, guess:p -> 

here we have to mark the current chunk as p and start again from line 4 :S
That seems complicated
What about iterating with previous line, current line, next line?

What are we doing again? we need to turn this: (• = \n)

    # h1•p1•p1•## h2p2•p2- uno•- dos

into
  
    [{h1: h1}, {p: p1•p1}, {h2: h2}, {p: p2•p2}, {ul: [{li: uno}, {li: dos}]}]

or
  
    # h1•      p1•p1•      ## h2•    p2•p2•      - uno•- dos
    [{h1: h1}, {p: p1•p1}, {h2: h2}, {p: p2•p2}, {ul: [{li: uno}, {li: dos}]}]

think we're thinking too much about implementation, what are the general rules?

how do we know that's what?

the elements we have are:

  headings:    h1 h2 h3 h4 h5 h6
  rules:       hr
  lists:       ul, ol, li
  line_breaks: br
  inline:      a, strong, em, img
  code:        code
  blockquote:  blockquote
  paragraphs:  p

How do we know what's what?

and empty line has no characters or only spaces

- headings        : are single lines that start with 1..6 hash (#) symbols then have anything
- horizontal rule : are single lines that have 3 or more consecutive dashes (---) and maybe space
- lists           : are one or more consecutive lines that start with a single dash
- lines breaks    : are single lines INSIDE PARAGRAPHS that end with 2 or more spaces
- paragraphs      : one of more consecutive lines that end with an empty line or the end of the string and are not headings, rule, lists


This is more difficult than I thought :(

However we're making progress...