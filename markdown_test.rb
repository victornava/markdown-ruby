require 'minitest/spec'
require 'minitest/autorun'
require_relative 'markdown'

SIMPLE_PARSE_TREE = {
 tag: "html", content: 
  [{tag: "h1", content: ["Heading"]},
   {tag: "h2", content: ["Sub-heading"]},
   {tag: "h3", content: ["Another deeper heading"]},
   {tag: "p", content: ["Paragraphs are separated\n" + "by a blank line."]},
   {tag: "p",
    content: ["Two spaces at the end of a line leave a  \n" + "line break."]},
   {tag: "p",
    content: 
     ["Text attributes ",
      {tag: "em", content: ["italic"]},
      ", ",
      {tag: "strong", content: ["bold"]},
      ", ",
      {tag: "code", content: ["monospace"]},
      "."]},
   {tag: "blockquote",
    content: [{tag: "p", content: ["This is a blockquote"]}]},
   {tag: "p", content: ["Horizontal rule:"]},
   {tag: "hr", content: []},
   {tag: "p", content: ["Bullet list:"]},
   {tag: "ul",
    content: 
     [{tag: "li", content: ["apples"]},
      {tag: "li", content: ["oranges"]},
      {tag: "li", content: ["pears"]}]},
   {tag: "p", content: ["Numbered list:"]},
   {tag: "ol",
    content: 
     [{tag: "li", content: ["apples"]},
      {tag: "li", content: ["oranges"]},
      {tag: "li", content: ["pears"]}]},
   {tag: "p",
    content: 
     ["A ",
      {tag: "a", content: ["link"], props: {href: "http://example.com"}},
      "."]},
   {tag: "p",
    content: 
     ["An image ",
      {tag: "img",
       props: 
        {src: "http://daringfireball.net/graphics/logos/",
         alt: "Gruber",
         title: ""}}]},
   {tag: "pre",
    content: 
     [{tag: "code",
       content: 
        ["def a_code_block\n" + "  \"looks like this\"\n" + "end"]}]}]}

class MardownTest < Minitest::Spec
  describe Generator do
    it "generates html from a simple parse_tree" do
      target = File.read('./example.html')
      assert_equal target, Generator.generate(SIMPLE_PARSE_TREE)
    end

    it 'handles simple tags individually' do
      [ # Input                                         # Target
        [{ tag: 'h1'        , content: 'Heading 1'   }, "<h1>Heading 1</h1>\n"             ],
        [{ tag: 'h2'        , content: 'Heading 2'   }, "<h2>Heading 2</h2>\n"             ],
        [{ tag: 'h3'        , content: 'Heading 3'   }, "<h3>Heading 3</h3>\n"             ],
        [{ tag: 'h4'        , content: 'Heading 4'   }, "<h4>Heading 4</h4>\n"             ],
        [{ tag: 'h5'        , content: 'Heading 5'   }, "<h5>Heading 5</h5>\n"             ],
        [{ tag: 'h6'        , content: 'Heading 6'   }, "<h6>Heading 6</h6>\n"             ],
        [{ tag: 'p'         , content: 'Paragraph'   }, "<p>Paragraph</p>\n"               ],
        [{ tag: 'blockquote', content: 'BBQ'         }, "<blockquote>\nBBQ</blockquote>\n" ],
        [{ tag: 'ul'        , content: 'Unordered'   }, "<ul>\nUnordered</ul>\n"           ],
        [{ tag: 'ol'        , content: 'Ordered'     }, "<ol>\nOrdered</ol>\n"             ],
        [{ tag: 'li'        , content: 'List item'   }, "<li>List item</li>\n"             ],
        [{ tag: "code"      , content: "Code"        }, "<code>Code</code>"                ],
        [{ tag: "pre"       , content: "Pre"         }, "<pre>Pre</pre>"                   ],
        [{ tag: "em"        , content: "Italic"      }, "<em>Italic</em>"                  ],
        [{ tag: "strong"    , content: "Strong"      }, "<strong>Strong</strong>"          ],
        [{ tag: "br"                                 }, "<br>\n"                           ],
        [{ tag: "hr"                                 }, "<hr>\n"                           ],
      ].each do |input, target|
        assert_equal target, Generator.generate(input), "#{input} should produce #{target}"
      end
    end

    it 'generates simple unordered lists' do
      input = {
        tag: "ul", content: [
          { tag: "li", content: "apples"  },
          { tag: "li", content: "oranges" },
          { tag: "li", content: "pears"   }
        ]
      }

      target = <<-HTML.strip_heredoc
        <ul>
        <li>apples</li>
        <li>oranges</li>
        <li>pears</li>
        </ul>
      HTML

      assert_equal target, Generator.generate(input)
    end

    it 'generate ordered lists' do
      input = {
        tag: "ol", content: [
          { tag: "li", content: "uno"  },
          { tag: "li", content: "dos"  },
          { tag: "li", content: "tres" }
        ]
      }

      target = <<-HTML.strip_heredoc
        <ol>
        <li>uno</li>
        <li>dos</li>
        <li>tres</li>
        </ol>
      HTML

      assert_equal target, Generator.generate(input)
    end

    it 'generates links' do
      input  = { tag: "a", content: "link", props: { href: "http://example.com" } }
      target = '<a href="http://example.com">link</a>'
      assert_equal target, Generator.generate(input)
    end

    it 'generates images' do
      input = {
        tag: 'img',
        props: { src: 'http://daringfireball.net/graphics/logos/', alt: 'Gruber', title: '' }
      }
      target = '<img src="http://daringfireball.net/graphics/logos/" alt="Gruber" title="">'
      assert_equal target, Generator.generate(input)
    end
  end

  describe Parser do
    it 'parses single lines' do
      [ # Input                        # Target
        ['# Heading 1'               , [{ tag: 'h1', content: ['Heading 1'] }]],
        ['## Heading 2'              , [{ tag: 'h2', content: ['Heading 2'] }]],
        ['### Heading 3'             , [{ tag: 'h3', content: ['Heading 3'] }]],
        ['#### Heading 4'            , [{ tag: 'h4', content: ['Heading 4'] }]],
        ['##### Heading 5'           , [{ tag: 'h5', content: ['Heading 5'] }]],
        ['###### Heading 6'          , [{ tag: 'h6', content: ['Heading 6'] }]],
        ['Paragraph'                 , [{ tag: 'p' , content: ['Paragraph'] }]],
        ['---'                       , [{ tag: 'hr', content: [] }]],
        ['**Strong**'                , [{ tag: 'p' , content: [{ tag: "strong", content: ["Strong"]    }]}]],
        ['_Emphasis_'                , [{ tag: 'p' , content: [{ tag: "em",     content: ["Emphasis"]  }]}]],
        ['`Monospace`'               , [{ tag: 'p' , content: [{ tag: "code",   content: ["Monospace"] }]}]],
        ['[link](http://example.com)', [{ tag: 'p' , content: [{ tag: 'a', content: ['link'], props: { href: 'http://example.com' }}]}]],
        ['![Img](http://x.io/x.jpg)' , [{ tag: 'p' , content: [{ tag: 'img', props: { src: 'http://x.io/x.jpg', alt: 'Img', title: '' }}]}]],
        ['> Blockquote'              , [{ tag: 'blockquote', content: [{ tag: 'p', content: ["Blockquote"] }] }]],
      ].each do |input, target|
        assert_equal target, Parser.parse(input)[:content], "#{input} should produce #{target}"
      end
    end

    it 'parses simple unordered lists' do
      input = <<-MARKDOWN.strip_heredoc
        - apples
        - oranges
        - pears
      MARKDOWN

      target = [{
        tag: "ul", content: [
          { tag: "li", content: ["apples"]  },
          { tag: "li", content: ["oranges"] },
          { tag: "li", content: ["pears"]   }
        ]
      }]

      assert_equal target, Parser.parse(input)[:content]
    end

    it 'parses simple ordered lists' do
      input = <<-MARKDOWN.strip_heredoc
        1. apples
        2. oranges
        3. pears
      MARKDOWN

      target = [{
        tag: "ol", content: [
          { tag: "li", content: ["apples"]  },
          { tag: "li", content: ["oranges"] },
          { tag: "li", content: ["pears"]   }
        ]
      }]

      assert_equal target, Parser.parse(input)[:content]
    end

    it 'parses code blocks' do
      input   = "    def a_code_block\n" + "      print \"looks like this\"\n" + "    end\n"
      content = "def a_code_block\n" + "  print \"looks like this\"\n" + "end"
      target  = [{ tag: 'pre', content: [{ tag: 'code', content: [content]}]}]
      assert_equal target, Parser.parse(input)[:content]
    end

    it 'parses multiline blockquotes' do
      input1  = "> a blockquote\ncontinues here"
      target1 = [{ tag: 'blockquote', content: [{ tag: 'p', content: ["a blockquote\ncontinues here"]}]}]
      assert_equal target1, Parser.parse(input1)[:content]

      input2  = "> a blockquote\n> continues here too"
      target2 = [{ tag: 'blockquote', content: [{ tag: 'p', content: ["a blockquote\ncontinues here too"]}]}]
      assert_equal target2, Parser.parse(input2)[:content]

      input3  = "> a blockquote\n> continues here\n\nbut not here"
      target3 = [{ tag: 'blockquote', content: [{ tag: 'p', content: ["a blockquote\ncontinues here"]}]}, { tag: 'p', content: ['but not here']}]
      assert_equal target3, Parser.parse(input3)[:content]
    end
  end

  describe Markdown do
    describe '.to_html' do
      it 'converts markdown to html' do
        input  = File.read('example.md')
        target = File.read('example.html')
        output = Markdown.to_html(input)
        assert_equal target, output
      end
    end
  end
end

# Helpers
class String
  # http://api.rubyonrails.org/classes/String.html#method-i-strip_heredoc
  def strip_heredoc
    gsub(/^#{scan(/^[ \t]*(?=\S)/).min}/, "".freeze)
  end
end