require 'nokogiri'

require_relative 'lachisis/parser'

output_callback = ->(weave) {
  weave.frames.each do |frame|
    frame.events.each do |event|
      printf("%11s : %10s\n", frame.timestamp, event)
    end
  end
}

SVG_THREAD_WIDTH = 3
SVG_THREAD_SPACING = SVG_THREAD_WIDTH * 2 # Space between character threads
SVG_LOCATION_GAP = 2 # In thread widths

SVG_TIME_GAP = 5 # Space between events horizontally
SVG_BASE_DURATION = 10 # Space events take up
SVG_EVENT_SPACE = SVG_TIME_GAP + SVG_BASE_DURATION

SVG_LABEL_OFFSET = SVG_THREAD_WIDTH
SVG_FONT_SIZE = SVG_THREAD_SPACING

if ARGV.empty?
  warn "Usage: #{$0} [-s] [--] file.xml"
  exit 1
end

while ARGV[0].start_with?('-')
  option = ARGV.shift

  case option
  when '--'
    break # End of options

  when '-s' # SVG
    output_callback = ->(weave) {
      threads = {}
      location_sizes = {}
      characters = []

      weave.frames.each_with_index do |frame, index|
        frame.events.each do |event|

          # Convert to array since we care about order of characters
          characters |= event.characters.to_a

          event.characters.each do |c|
            threads[c] ||= []
            threads[c] << { index: index, event: event }
          end

          location_size = [location_sizes[event.location], event.characters.length]
              .compact
              .max
          location_sizes[event.location] = location_size
        end
      end

      characters.sort

      # TODO: could use Nokogiri here

      diagram_width = weave.frames.length * SVG_EVENT_SPACE

      # HACK: should really use font metrics or similar
      max_name_size = SVG_FONT_SIZE * characters.map(&:length).max
      max_x = diagram_width + max_name_size * 2

      # Calculate where (horizontal row) to each location fits. Assume order stays the same.
      # Start with a bit of space so the first line is readable-ish
      edge_offset = SVG_LOCATION_GAP * SVG_THREAD_SPACING
      last_location_end = 0

      location_spacing = {}
      location_sizes.sort.each do |location, char_count|
        start_y = last_location_end + edge_offset
        last_location_end = start_y + char_count * SVG_THREAD_SPACING

        location_spacing[location] = start_y
      end

      max_y = last_location_end + edge_offset
      xml_data = [
        '<?xml version="1.0"?>',
        "<svg width='#{max_x}' height='#{max_y}'>"
      ]

      threads.each do |character, events|
        path_points = events.flat_map do |index_and_event|
          index_and_event => {index:, event:}
          x = max_name_size + (index * SVG_EVENT_SPACE)

          # Allocate character rows based on the global sorted list, so they
          # don't cross over within events
          character_row = (characters & event.characters.to_a).index(character)

          y = location_spacing[event.location]
          y += character_row * SVG_THREAD_SPACING

          last_location = event.location
          [x, y, x + SVG_BASE_DURATION, y]
        end

        xml_data << %{<path id="thread_#{character}" fill="none" stroke="black" stroke_width="3" d="M #{path_points.join(' ')}"/>}

        start_x, start_y, *, end_x, end_y = *path_points
        xml_data << %{<text x="#{start_x - SVG_LABEL_OFFSET}" y="#{start_y}" text-anchor="end" dominant-baseline="middle" font-size="#{SVG_FONT_SIZE}">#{character}</text>}
        xml_data << %{<text x="#{end_x + SVG_LABEL_OFFSET}" y="#{end_y}" text-anchor="start" dominant-baseline="middle" font-size="#{SVG_FONT_SIZE}">#{character}</text>}
      end

      xml_data << '</svg>'

      puts xml_data
    }
  end
end


parser = Lachisis::Parser.new(&output_callback)

class LineNumberTrackingParser
  class LocatedError < Lachisis::Parser::Error
    def initialize(filename, line, position, cause)
      super("#{filename}:#{line} (near byte #{position}): ERROR #{cause.message}")
      set_backtrace(cause.backtrace)
    end

    attr_reader :cause
  end

  def initialize(sax_document)
    @sax_document = sax_document
  end

  # @param filename_or_io [String,IO]
  def parse(filename_or_io)
    if filename_or_io.is_a?(IO)
      filename = '<input>'
      io = filename_or_io
    else
      filename = filename_or_io
      io = File.open(filename)
    end

    sax_parser = Nokogiri::XML::SAX::PushParser.new(@sax_document, filename)

    io.each_line.each_with_index do |line, line_number|
      begin
        sax_parser << line
      rescue Lachisis::Parser::Error => e
        # each_with_index uses 0-based indexing, but we want 1-based for the human-readable line number
        raise LocatedError.new(filename, line_number + 1, io.pos, e)
      end
    end

    sax_parser.finish
  end
end

begin
  parser_with_line_info = LineNumberTrackingParser.new(parser)
  parser_with_line_info.parse(ARGV[0])
rescue LineNumberTrackingParser::LocatedError => e
  warn e.message

  exit 1
end
