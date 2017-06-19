#!/usr/bin/env ruby

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
      content = chunk[regexp].gsub(/^\s?\>\s?/, '') # 🤔 hack? yes. Shuold handle with look-behind in the regexp
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

def main
  input = ARGV.any? ? File.read(ARGV.first) : STDIN.read
  puts Markdown.to_html(input)
end

main if $0 == __FILE__