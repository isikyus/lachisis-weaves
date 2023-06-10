# frozen_string_literal: true

module Lachisis
  class Parser
    # Wrapper around Nokogiri::XML::SAX parser that tracks the line
    # numbers of errors, since Nokogiri apparently doesn't.
    class LineNumberAware
      # Extend parser errors with the location in the file
      # the error occured.
      # Since Nokogiri SAX parsing doesn't give us this by default
      class LocatedError < Lachisis::Parser::Error
        def initialize(filename, line, position, cause)
          super("#{filename}:#{line} (near byte #{position}): " \
                "ERROR #{cause.message}")

          set_backtrace(cause.backtrace)
        end

        attr_reader :cause
      end

      def initialize(sax_document)
        @sax_document = sax_document
      end

      # @param filename_or_io [String,IO]
      def parse(filename_or_io)
        filename, io = name_and_io_from(filename_or_io)

        sax_parser = Nokogiri::XML::SAX::PushParser.new(@sax_document, filename)

        io.each_line.each_with_index do |line, line_number|
          add_line_to_errors(filename, line_number, io.pos) do
            sax_parser << line
          end
        end

        sax_parser.finish
      end

      private

      # @param [String, IO] IO object or string
      # @return [Array<String, IO>] Name of the input,
      #         and IO stream to actually read from.
      def name_and_io_from(filename_or_io)
        if filename_or_io.is_a?(IO)
          ['<input>', filename_or_io]
        else
          filename = filename_or_io
          [filename, File.open(filename)]
        end
      end

      def add_line_to_errors(filename, line_index, position)
        yield
      rescue Lachisis::Parser::Error => e
        # each_with_index uses 0-based indexing,
        # but we want 1-based for the human-readable line number
        line_number = line_index + 1
        raise LocatedError.new(filename, line_number, position, e)
      end
    end
  end
end
