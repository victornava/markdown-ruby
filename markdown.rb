require 'pry'

class Generator
  NORMAL_TAGS = %w[p h1 h2 h3 h4 h5 h6 ul ol li a strong i pre code]
  SINGLE_TAGS = %w[br hr img]

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
      props = Array(node[:props])
      case tag_type(node[:tag])
      when :single
        props.any? ? "<#{node[:tag]} #{convert_props(props)} />" : "<#{node[:tag]} />"
      when :normal
        props.any? ? "<#{node[:tag]} #{convert_props(props)}>" : "<#{node[:tag]}>"
      else
        nil
      end
    end

    def close_tag(node)
      if tag_type(node[:tag]) == :normal
        "</#{node[:tag]}>"
      end
    end

    def after_open_tag(node)
      "\n" if %w[ul ol].include?(node[:tag])
    end

    def after_close_tag(node)
      "\n" if %w[h1 h2 h3 h4 h5 h6 p ul ol li br hr].include?(node[:tag])
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
    { tag: "h3", content: "Another deeper heading" },
    { tag: "p",  content: "Paragraphs are separated by a blank line." },
    { tag: "p", content: [
      "Two spaces at the end of a line leave a",
      { tag: "br" },
      "line break."
    ]},
    { tag: "p", content: [
      { tag: "i", content: "italic" },
      ", ",
      { tag: "strong", content: "bold" },
      ", ",
      { tag: "code", content: "monospace" }
    ]},
    { tag: "hr" },
    { tag: "ul", content: [
      { tag: "li", content: "apples"  },
      { tag: "li", content: "oranges" },
      { tag: "li", content: "pears"   }
    ]},
    { tag: "p", content: [
      "A ",
      { tag: "a", content: "link", props: { href: "http://example.com" } },
      "."
    ]},
    { tag: "p", content: [
      { tag: 'img',
        props: { src: "http://daringfireball.net/graphics/logos/", alt: "Gruber", title: '' } }
    ]},
  ]
}

# puts Generator.process_node(SIMPLE_PARSE_TREE)

# Test
require 'minitest/spec'

describe Generator do
  it "generates html from a simple parse_tree" do
    target = <<-HTML.strip_heredoc
      <h1>Heading</h1>
      <h3>Another deeper heading</h3>
      <p>Paragraphs are separated by a blank line.</p>
      <p>Two spaces at the end of a line leave a<br />
      line break.</p>
      <p><i>italic</i>, <strong>bold</strong>, <code>monospace</code></p>
      <hr />
      <ul>
      <li>apples</li>
      <li>oranges</li>
      <li>pears</li>
      </ul>
      <p>A <a href="http://example.com">link</a>.</p>
      <p><img src="http://daringfireball.net/graphics/logos/" alt="Gruber" title="" /></p>
    HTML

    Generator.generate(SIMPLE_PARSE_TREE).must_equal(target)
  end

  it 'generates headings' do
    Generator.generate({ tag: "h1", content: "Heading 1" }).must_equal("<h1>Heading 1</h1>\n")
    Generator.generate({ tag: "h2", content: "Heading 2" }).must_equal("<h2>Heading 2</h2>\n")
    Generator.generate({ tag: "h3", content: "Heading 3" }).must_equal("<h3>Heading 3</h3>\n")
    Generator.generate({ tag: "h4", content: "Heading 4" }).must_equal("<h4>Heading 4</h4>\n")
    Generator.generate({ tag: "h5", content: "Heading 5" }).must_equal("<h5>Heading 5</h5>\n")
    Generator.generate({ tag: "h6", content: "Heading 6" }).must_equal("<h6>Heading 6</h6>\n")
  end

  it 'generate paragraphs' do
    Generator.generate({ tag: "p", content: "A paragraph" }).must_equal("<p>A paragraph</p>\n")
  end

  it 'generate unordered lists' do
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

  it 'generates italics' do
    Generator.generate({ tag: "i", content: "italic" }).must_equal("<i>italic</i>")
  end

  it 'generates bolds' do
    Generator.generate({ tag: "strong", content: "bold" }).must_equal("<strong>bold</strong>")
  end

  it 'generates codes' do
    Generator.generate({ tag: "code", content: "monospace" }).must_equal("<code>monospace</code>")
  end

  it 'generates links' do
    Generator.generate({ tag: "a", content: "link", props: { href: "http://example.com" } })
             .must_equal('<a href="http://example.com">link</a>')
  end

  it 'generates line breaks' do
    Generator.generate({ tag: "br" }).must_equal("<br />\n")
  end

  it 'generates horizontal rules' do
    Generator.generate({ tag: "hr" }).must_equal("<hr />\n")
  end

  it 'generates images' do
    input = {
      tag: 'img',
      props: { src: 'http://daringfireball.net/graphics/logos/', alt: 'Gruber', title: '' }
    }
    target = '<img src="http://daringfireball.net/graphics/logos/" alt="Gruber" title="" />'
    Generator.generate(input).must_equal(target)
  end
end

# Test Helpers
class String
  # http://api.rubyonrails.org/classes/String.html#method-i-strip_heredoc
  def strip_heredoc
    gsub(/^#{scan(/^[ \t]*(?=\S)/).min}/, "".freeze)
  end
end

Minitest.run if ARGV.include?('--test')