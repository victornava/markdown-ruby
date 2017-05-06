require 'pry'

class Parser
  class << self
    def parse(markdown)
      chunks = markdown.lines.map(&:chomp)
      chunks
        .map { |chunk| [chunk].concat(identify(chunk)) }
        .map do |chunk, tag, regexp|
          case tag
          when :blockquote
            { tag: tag.to_s, content: [{tag: 'p', content: chunk.scan(regexp)&.first&.first}] }
          when :hr
            { tag: tag.to_s }
          when :ul, :ol
            { tag: tag.to_s, content: [{tag: 'li', content: chunk.scan(regexp)&.first&.first}] }
          when :p
            if chunk =~ /\s\s+$/
              { tag: tag.to_s, content: chunk.split(/\s\s+$/).flat_map { |c| [c, { tag: 'br' } ] } }
            else
              { tag: tag.to_s, content: chunk }
            end
          else
            { tag: tag.to_s, content: (chunk.scan(regexp)&.first&.first) }
          end
        end
    end


    def identify(chunk)
      {
        h1:         /^#[^#](.*)/     ,
        h2:         /^##[^#](.*)/    ,
        h3:         /^###[^#](.*)/   ,
        h4:         /^####[^#](.*)/  ,
        h5:         /^#####[^#](.*)/ ,
        h6:         /^######[^#](.*)/,
        blockquote: /^\>(.*)/        ,
        code:       /^`(.*)`/        ,
        em:         /^_(.*)_/        ,
        strong:     /^\*\*(.*)\*\*/  ,
        hr:         /^\-\-\-[\-\s]*/ ,
        ul:         /^\-\s*(.*)/     ,
        ol:         /^\d+\.\s*(.*)/  ,
        p:          /.*/             ,
      }.detect do |_, regexp|
        chunk =~ regexp
      end
    end
  end
end

class Generator
  BLOCK_TAGS  = %w[h1 h2 h3 h4 h5 h6 p blockquote ul ol]
  INLINE_TAGS = %w[li a strong em code]
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
      return "\n" if BLOCK_TAGS.include?(node[:tag])
      return "\n" if %w[li br hr].include?(node[:tag])
    end
  end
end

########################################################################
# TEST
########################################################################

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

# puts Generator.process_node(SIMPLE_PARSE_TREE)

# Test
require 'minitest/spec'

describe Generator do
  it "generates html from a simple parse_tree" do
    target = File.read('./example-simple.html')
    # File.open('test-out.html', 'w').write(Generator.generate(SIMPLE_PARSE_TREE))
    Generator.generate(SIMPLE_PARSE_TREE).must_equal(target)
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
      [{ tag: "code"      , content: "Code"        },  "<code>Code</code>"               ],
      [{ tag: "em"        , content: "Italic"      }, "<em>Italic</em>"                  ],
      [{ tag: "strong"    , content: "Strong"      }, "<strong>Strong</strong>"          ],
      [{ tag: "br"                                 }, "<br>\n"                           ],
      [{ tag: "hr"                                 }, "<hr>\n"                           ]
    ].each do |input, target|
      Generator.generate(input).must_equal(target)
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

    Generator.generate(input).must_equal(target)
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

    Generator.generate(input).must_equal(target)
  end

  it 'generates links' do
    Generator.generate({ tag: "a", content: "link", props: { href: "http://example.com" } })
             .must_equal('<a href="http://example.com">link</a>')
  end

  it 'generates images' do
    input = {
      tag: 'img',
      props: { src: 'http://daringfireball.net/graphics/logos/', alt: 'Gruber', title: '' }
    }
    target = '<img src="http://daringfireball.net/graphics/logos/" alt="Gruber" title="">'
    Generator.generate(input).must_equal(target)
  end
end

describe Parser do
  it 'parses single lines' do
    [ # Input               # Target
      ['# Heading 1'     , [{ tag: 'h1'    , content: 'Heading 1'   }]],
      ['## Heading 2'    , [{ tag: 'h2'    , content: 'Heading 2'   }]],
      ['### Heading 3'   , [{ tag: 'h3'    , content: 'Heading 3'   }]],
      ['#### Heading 4'  , [{ tag: 'h4'    , content: 'Heading 4'   }]],
      ['##### Heading 5' , [{ tag: 'h5'    , content: 'Heading 5'   }]],
      ['###### Heading 6', [{ tag: 'h6'    , content: 'Heading 6'   }]],
      ['Paragraph'       , [{ tag: 'p'     , content: 'Paragraph'   }]],
      ['`Code`'          , [{ tag: 'code'  , content: 'Code'        }]],
      ['_Italic_'        , [{ tag: 'em'    , content: 'Italic'      }]],
      ['**Strong**'      , [{ tag: 'strong', content: 'Strong'      }]],
      ['---'             , [{ tag: "hr"                             }]],
      ['- uno'           , [{ tag: 'ul'        , content: [{ tag: 'li', content: 'uno' }]}]],
      ['1. uno'          , [{ tag: 'ol'        , content: [{ tag: 'li', content: 'uno' }]}]],
      ['>BBQ'            , [{ tag: 'blockquote', content: [{ tag: 'p',  content: 'BBQ' }]}]],
      ['Break  '         , [{ tag: "p"         , content: ['Break', { tag: 'br'        }]}]],
    ].each do |input, target|
      assert_equal target, Parser.parse(input), "Input: #{input} should produce #{target}"
    end
  end
end
# Test Helpers
class String
  # http://api.rubyonrails.org/classes/String.html#method-i-strip_heredoc
  def strip_heredoc
    gsub(/^#{scan(/^[ \t]*(?=\S)/).min}/, "".freeze)
  end
end

require 'minitest/autorun'
# Minitest.run if ARGV.include?('--test')