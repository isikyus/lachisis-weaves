require 'nokogiri'

require_relative 'lachisis/parser'
require_relative 'lachisis/svg'

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
    renderer = Lachisis::SVG.new
    output_callback = ->(weave) {
      puts renderer.call(weave)
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
