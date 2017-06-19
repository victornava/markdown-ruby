# require 'pry'

class Markdown
  class << self
    def to_html(md)
      Generator.generate(Parser.parse(md))
    end
  end
end

class Parser
  class << self
    def parse(markdown)
      {
        tag: 'html',
        content: split_into_blocks(split_into_chunks(markdown))
      }
    end

    # Order important here. Chunks get converted to paragraphs if they don't match anything else
    BLOCK_MATCHERS = [
      { tag: 'h1'        , regexp: /^#[^#](.*)(?=$)/            , handler: '_generic'    },
      { tag: 'h2'        , regexp: /^##[^#](.*)(?=$)/           , handler: '_generic'    },
      { tag: 'h3'        , regexp: /^###[^#](.*)(?=$)/          , handler: '_generic'    },
      { tag: 'h4'        , regexp: /^####[^#](.*)(?=$)/         , handler: '_generic'    },
      { tag: 'h5'        , regexp: /^#####[^#](.*)(?=$)/        , handler: '_generic'    },
      { tag: 'h6'        , regexp: /^######\s*(.*)(?=$)/        , handler: '_generic'    },
      { tag: 'ul'        , regexp: /^\s*(\-[^-]+.*)(?!=\-\])/m  , handler: '_generic'    }, # 🤔 looks wrong
      { tag: 'ol'        , regexp: /^\s*(\d+\..*)(?!=\d+\.\])/m , handler: '_generic'    }, # 🤔 looks wrong
      { tag: 'hr'        , regexp: /^\-\-\-+$/                  , handler: '_generic'    },
      { tag: 'code_block', regexp: /(^\ {4,}.*)+/m              , handler: '_code_block' }, # 🤔 produces pre and code tags
      { tag: 'blockquote', regexp: /^\s?\>\s?.*$/m              , handler: '_blockquote' }, # 🤔 produces blockquote and p tags
      { tag: 'p'         , regexp: /(.*)/m                      , handler: '_generic'    }, # 🤔 too open?
    ]

    INLINE_MATCHERS = [
      { tag: 'code'      , regexp: /`+(.*)`+/                   , handler: '_generic'    },
      { tag: 'li'        , regexp: /^\s*\-\s+(.*)\n?$/          , handler: '_generic'    },
      { tag: 'li'        , regexp: /^\s*\d+\.\s?(.*)\n?$/       , handler: '_generic'    },
      { tag: 'strong'    , regexp: /\*\*(.*)\*\*/               , handler: '_generic'    },
      { tag: 'em'        , regexp: /_(.*)_/                     , handler: '_generic'    },
      { tag: 'a'         , regexp: /(?<!\!)\[(.*)\]\((.*)\)/    , handler: '_link'       },
      { tag: 'img'       , regexp: /\!\[(.*)\]\((.*)\)/         , handler: '_image'      },
    ]

    # 🤔 this step shouldn't be required
    def split_into_chunks(markdown)
      markdown
        .split(/^\s*$/)                      # split by empty lines
        .map { |x| x.gsub(/^\n+|\n+$/, '') } # remove new lines from start or end
    end

    def split_into_blocks(chunks)
      chunks_to_nodes(chunks, BLOCK_MATCHERS)
    end

    def split_into_inlines(chunk)
      chunks_to_nodes([chunk], INLINE_MATCHERS).compact
    end

    def chunks_to_nodes(chunks, matchers)
      matchers.reduce(chunks) do |chunks, matcher|
        chunks.flat_map do |chunk|
          chunk_to_nodes(chunk, matcher[:tag], matcher[:regexp], matcher[:handler])
        end
      end
    end

    def chunk_to_nodes(chunk, tag, regexp, handler)
      return chunk unless chunk.is_a?(String)
      return [] if chunk.empty?

      before, match, rest =  chunk.partition(regexp)

      if match.empty?
        [chunk]
      else
        node = self.send(handler, tag, chunk, regexp)
        node_list = before.chomp.empty? ? [node] : [before, node]
        node_list.concat(chunk_to_nodes(rest, tag, regexp, handler))
      end
    end

    def _generic(tag, chunk, regexp)
      { tag: tag, content: split_into_inlines(chunk[regexp, 1]) }
    end

    def _link(tag, chunk, regexp)
      { tag: tag, content: split_into_inlines(chunk[regexp, 1]), props: { href: chunk[regexp, 2] }}
    end

    def _image(tag, chunk, regexp)
      { tag: tag, props: { src: chunk[regexp, 2], alt: chunk[regexp, 1], title: "" }}
    end

    def _code_block(tag, chunk, regexp)
      content = chunk[regexp].gsub(/^ {4}/,'') # 🤔 hack?
      { tag: 'pre', content: [{ tag: 'code', content: [content]}]}
    end

    def _blockquote(tag, chunk, regexp)
      content = chunk[regexp].gsub(/^\s?\>\s?/, '') # 🤔 hack?
      { tag: 'blockquote', content: [{ tag: 'p', content: [content]}]} # 🤔 why content needs to be array?
    end
  end
end

class Generator
  BLOCK_TAGS  = %w[h1 h2 h3 h4 h5 h6 p blockquote ul ol]
  INLINE_TAGS = %w[li a strong em code pre]
  SINGLE_TAGS = %w[br hr img]
  NORMAL_TAGS = BLOCK_TAGS + INLINE_TAGS

  class << self
    def generate(tree)
      process_node(tree)
    end

    def tag_type(tag)
      return :single if SINGLE_TAGS.include?(tag)
      return :normal if NORMAL_TAGS.include?(tag)
      :unknown
    end

    def convert_props(props)
      props.map {|k, v| "#{k.to_s}=\"#{v}\"" }.join(" ")
    end

    def process_node(node)
      [
       open_tag(node),
       after_open_tag(node),
       process_content(node[:content]),
       close_tag(node),
       after_close_tag(node),
      ].compact.join
    end

    def process_content(content)
      case content
      when String
        content
      when Hash
        process_node(content)
      when Array
        if content.size == 1
          process_content(content.first)
        elsif content.size > 1
          head, *tail = content
          [process_content(head)] + [process_content(tail)]
        end
      end
    end

    def open_tag(node)
      return if tag_type(node[:tag]) == :unknown
      props = Array(node[:props])
      if props.any?
        "<#{node[:tag]} #{convert_props(props)}>"
      else
        "<#{node[:tag]}>"
      end
    end

    def close_tag(node)
      if tag_type(node[:tag]) == :normal
        "</#{node[:tag]}>"
      end
    end

    def after_open_tag(node)
      "\n" if %w[ul ol blockquote].include?(node[:tag])
    end

    def after_close_tag(node)
      return "\n" if (BLOCK_TAGS + %w[li br hr]).include?(node[:tag])
    end
  end
end

def log(message)
  # puts message
end

def main
  input = ARGV.any? ? File.read(ARGV.first) : STDIN.read
  puts Markdown.to_html(input)
  exit
end

if ARGV.include?('--test')
  ARGV.shift
else
  main
end

########################################################################
# TEST
########################################################################

require 'minitest/spec'
require 'minitest/autorun'

SIMPLE_PARSE_TREE = {
  tag: "html",
  content: [
    { tag: "h1", content: "Heading" },
    { tag: "h2", content: "Sub-heading" },
    { tag: "h3", content: "Another deeper heading" },
    { tag: "p",  content: "Paragraphs are separated\nby a blank line." },
    { tag: "p", content: [
      "Two spaces at the end of a line leave a ",
      { tag: "br" },
      "line break."
    ]},
    { tag: "p", content: [
      "Text attributes ",
      { tag: "em", content: "italic" },
      ", ",
      { tag: "strong", content: "bold" },
      ", ",
      { tag: "code", content: "monospace" },
      "."
    ]},
    { tag: "blockquote", content: [{ tag: 'p', content: 'This is a blockquote' }] },
    { tag: "p", content: "Horizontal rule:"},
    { tag: "hr" },
    { tag: "p", content: "Bullet list:"},
    { tag: "ul", content: [
      { tag: "li", content: "apples"  },
      { tag: "li", content: "oranges" },
      { tag: "li", content: "pears"   }
    ]},
    { tag: "p", content: "Numbered list:"},
    { tag: "ol", content: [
      { tag: "li", content: "apples"  },
      { tag: "li", content: "oranges" },
      { tag: "li", content: "pears"   }
    ]},
    { tag: "p", content: [
      "A ",
      { tag: "a", content: "link", props: { href: "http://example.com" } },
      "."
    ]}
  ]
}

class MardownTest < Minitest::Spec
  describe Generator do
    it "generates html from a simple parse_tree" do
      target = File.read('./example-simple.html')
      assert_equal target, Generator.generate(SIMPLE_PARSE_TREE)
    end

    it 'simple tag test' do
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

    it 'generate simple unordered lists' do
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
    describe 'simple markdown' do
      it 'handles paragraphs and h1' do
        input  = File.read('example.md')
        target = File.read('example.html')
        output = Markdown.to_html(input)
        # File.write('out.html', output)
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
