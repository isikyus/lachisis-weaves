# frozen_string_literal: true

require 'nokogiri'
require 'optparse'

require_relative 'svg'
require_relative 'parser'
require_relative 'parser/line_number_aware'

module Lachisis
  # Recognises command-line options and args and
  # runs the appropriate bits of Lachisis code
  class CLI
    class Options < Struct.new(:svg)
    end

    def run
      options = parse_options

      # TODO: get usage message from option parser
      die("Usage: #{$0} [-s] [--] file.xml\n\nExpected 1 non-option arg; got #{ARGV.length}: #{ARGV.inspect}") unless ARGV.length == 1
      xml_file = ARGV[0]

      # TODO: could move these three lines into Lachisis::Parser
      sax_processor = Lachisis::Parser.new(&render_callback(options))
      sax_parser = Lachisis::Parser::LineNumberAware.new(sax_processor)
      svg = sax_parser.parse(xml_file)

      raise "No result from SVG render" unless render_result

      puts render_result

    rescue Lachisis::Parser::LineNumberAware::LocatedError => e
      die(e.message)
    end

    private

    def parse_options
      options = Options.new
      OptionParser.new do |opts|
        opts.banner = "Usage: bundle exec ruby read_events.rb -s <file>.xml > <file.svg>"

        opts.on('-s', '--svg', 'Generate SVG output rather than text diagnostics') do
          options.svg = true
        end
      end.parse!

      options
    end

    # @return [#to_proc]
    def render_callback(options)
      if options.svg
        @render_result = nil
        @layout ||= Lachisis::Layout::Sorted.new
        renderer = Lachisis::SVG.new(@layout)
        ->(weave) {
          @render_result = renderer.call(weave)
        }

      else
        @render_result = ''
        ->(weave) {
          @render_result << "Location order: #{weave.location_sorting.inspect}\n"
          @render_result << "Character order: #{weave.character_sorting.inspect}\n"
          weave.frames.each do |frame|
            frame.events.each do |event|
              @render_result << sprintf("%11s : %10s\n", frame.timestamp, event)
            end
          end
        }
      end
    end

    def render_result
      @render_result
    end

    def die(message, status: 1)
      warn message
      exit status
    end
  end
end
