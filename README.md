# Submark

A markdown (subset) to HTML converter.

I have no idea how parsers work. So I'm doing this as programming exercice to learn about them.

The idea is to figure out how to make a rudimentary markdown to html converter, before learning about parsers. Then write another version as a "proper" parser. Once I read about them.

## Usage

    $ ruby submark.rb example.md

## Done

- [x] Paragraphs
- [x] Line Breaks
- [x] Headers
- [x] Blockquotes
- [x] Lists
- [x] Code Blocks
- [x] Horizontal Rules
- [x] Code
- [x] Emphasis
- [x] Links
- [x] Images

## Subset of markdown means...

### Only one way of representing

- Headers: # H1, ## H2...###### H6
- Unordered lists: `-`
- Strong: `**bold**`
- Emphasis: `_italic_`
- Horizontal rules: `---`

### Not Supported

- Reference links
- Embedded HTML
- Automatic links

## Notebook

Here is a [notebook](./notebook.md) with notes about the process and approach taken. 