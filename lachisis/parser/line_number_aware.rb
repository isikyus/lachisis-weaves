# frozen_string_literal: true

module Lachisis
  class Parser

    # Wrapper around Nokogiri::XML::SAX parser that tracks the line
    # numbers of errors, since Nokogiri apparently doesn't.
    class LineNumberAware

      # Decorates a parse error with the line it happened on,
      # since Nokogiri SAX parsing doesn't give us this by default
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
  end
end
