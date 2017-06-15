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
      props: hash (key-value pairs)
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

  paragraphs:  p
  headings:    h1 h2 h3 h4 h5 h6
  lists:       ul, ol, li
  inline:      a, strong, em, img
  line_breaks: br
  rules:       hr
  code:        code
  blockquote:  blockquote

How do we know what's what?

and empty line has no characters or only spaces

- paragraphs      : one of more consecutive lines that end with an empty line or the end of the string and are not headings, rule, lists
- headings        : are single lines that start with 1..6 hash (#) symbols then have anything
- lists           : are one or more consecutive lines that start with a single dash
- lines breaks    : are single lines INSIDE PARAGRAPHS that end with 2 or more spaces
- horizontal rule : are single lines that have 3 or more consecutive dashes (---) and maybe space


This is more difficult than I thought :(

However we're making progress...

# 2017-05-07

Actually let's do simple integration test...start with the simplest case and keep going.

Let's split this into features, starting at the top and working our way down:

1. Paragraphs
2. Headings
3. Lists
4. Inline
5. Line Breaks
6. Rules
7. Code
8. Blockquote
9. Embedded HTML?

At each point we should have a working program. Even with minimal features.

Done with Paragraphs. We have now very rudimentary converter that only handles Paragraphs.

# 2017-05-14

Todays plan is to expand our rudimentary markdown converter to handle:

  - headings
  - lists

Let's start with h1

We're currently splitting the input into chunks that are separated by empty lines. And de idea was that because we're just know about paragraphs we identify every chunk as a paragraph.

But now that we need to identify parts of the chunks as headings we need a way to split the chunks into other elements. The idea is that we split the input into chunks then chunks into block elements then block elements into inline elements so the overall structure would be something like this:

chunks are composed of block elements
blocks are composed of content (text) or inline elements
inline elements are composed of content or inline elements

    chunk -> blocks -> inline elements
                    -> content

inline elements are always inside block elements
content elements are always inside block elements

Ok, but let's not get ahead, let's focus on headings.

What's a heading?

    # heading 1

That's a heading (h1)

And how do we know that that's a headings?

Because the line begins with a hash.

Are there other types of headings?

Yes. There is h2, h3, h4, h5 and h6. But let's not get ahead.

H1's are pieces of text that:
    
    - start on a new line
    - the first character is a `#`
    - end at the end of the line

or expressed in regexp:

    ^#(.*)$

ok let's try that.

    # heading 1

should produce:

    [{ tag: 'h1' , content: 'Heading 1' }]

that worked, except that we should markdown strips spaces before words. But should we do this at the parse level, or should be process the content in the generator?

It's seems easy to do it here, so let's go ahead.

That works.

However we're ran into a problem:

Our current process goes like this

    take the input
    split it into chunks
    identify each chunk as either a paragraph of h1

the problem with this is that, a chunk can have multiple lines, so it can have paragraphs and headings, so we need to have a process for splitting chunks into blocks.

Processing the chunk line by line works well with headings but not with paragraphs.

Because paragraphs can span multiple lines.

Take this chunk for example:

      # Heading
      Paragraphs are separated
      by a blank line.

or

    # Heading\nParagraphs are separated\nby a blank line.

if we proces line by line we get:

    h1: Heading
    p:  Paragraphs are separated
    p:  by a blank line.

but we want:

    h1: Heading
    p:  Paragraphs are separated•by a blank line.

So we need a function that takes a chunk and tells us where headings are and where paragraphs are.

The first thing that comes to mind is:

take a chunk and identify where the headings are and assume every other part is a p

    chunk -> (split_into_blocks) -> [{h1: Heading}, {p: "Paragraphs are separated•by a blank line."}]

So the function takes a string and returns a list of hashes representing headings or paragraphs

or

    chunk -> (split_into_blocks) -> [Hash]

so first we could just take the string and split by the h1 regexp then replace the h1 string by h1 hashes then the remaning parts of the list that are string and turning then into p hashes. Lets try that.

That worked

Done with headings

Done with unordered list

# 2017-05-21

here

    .flat_map { |chunk| chunk_to_nodes(chunk, 'ul', /^\s*(\-[^-]+.*)(?!=\-\])/m) } # TODO Review, looks wrong.

try replacing the regexp with

    /^\s*(\-[^-]+.*)(?!=^\s*\-[^-]+)/m

Maybe the structure is:

beginning of match, content , end of match

in this case we could transform the regexp to

    /
    ^\s*\-(?!=\-) start:   starts at beginning of line then maybe spaces, followed by a dash, not followed by a dash
    (.*)          content: anything
    ^\s*\-(?!=\-) end:     same as start
    /

# TODO Can we generalize this and say:

> A regular expresion to parse a chunk of text has three parts: start, content and end

or

> A regular expresion to parse a chunk of text has three capture groups: (start)(content)(end)


but before we do that, let's be done with lists.

Next: Ordered list

Another thing that needs to be done is to simplify the ParseTree structure. Previously the definition was like this:

    {
      tag: string
      content: string | hash | array
      props: hash (key-value pairs)
    }

But as we progress, it seems like the `content` is always a list like so:

    {
      tag: string
      content: [string | hash | array]
      props: hash (key-value pairs)
    }

The initial idea was that we could that some content would only have strings, but if we are already handling the case of arrays of string, the that becomes an optimisation which we don't want to do right now, so a node in a parse tree that previously would like this:

    { tag: "h1", content: "Heading" }

Will become:

    { tag: "h1", content: ["Heading"] }

What is the gain?

None yet. Tried that and it only seems to complicate things. Let's keep going we what we have.

Done with ordered lists.

Next is inline elements. these are:

- [x] li
- [x] strong
- [x] em
- [x] code
- [x] links

`li` is done

Next is `strong`

Should be as simple as adding an inline matcher, let's try.

Done with `strong`

Next is `em`. Done.

# 2017-05-22

Done with code. That was super simple to add.
Next links

# 2017-05-23

Links are done.

Next: let's try something simple like Horizontal Rules

Done, that was easy.

Next is images. Let's be done with inline elements.

Done with images. Sleepy sleepy time 😴

# 2017-05-24

Let's do Code Blocks, what are this things?

code blocks are consecutive lines that start with 4 or more spaces

    \n\n\n\narray.reverse -> <pre><code>array.reverse</code></pre>

Done. Things are getting a bit hacky. Might need to refactor a bit on the next session.


# IDEA

    fn -> MDString -> Node
    fn -> Node -> HTMLString

Have a function for each entity? each function knows how to transform one entity only


# 2017-05-26

Do we have a markdown parser yet? I mean can we use it as a tool from the command line?

No.

Ok then do that next. It doesn't matter if it is not complete, remember that the idea is to always have a working program. No matter how simple it might be.

# 2017-05-31

next: program that takes an input from STDIN or File

Done

Next is Blockquotes

What are these?

    > block quotes
    > look like this
    
    > but can also
    look like this

beginning is `>` end is empty an line or end of string

Done

Next is more complex scenarios, maybe examples from https://daringfireball.net/projects/markdown/syntax

# 2017-06-15

Where are we at?

I've decided to leave out embedded html and reference links. I've never use those features and have never seen it use anywhere.

So we're done with:

- Supporting all tags
- Integration testing with a very simple input

There are several places in the code with questions and todos.

So let's fix that.