require 'nokogiri'
require 'optparse'

require_relative 'svg'
require_relative 'parser'
require_relative 'parser/line_number_aware'

module Lachisis
  class CLI
    class Options < Struct.new(:svg, :xml_file)
    end

    def run
      options = parse_options
      weave = weave_from_xml(options[:xml_file])
      puts render(weave, options)
    rescue Lachisis::Parser::LineNumberAware::LocatedError => e
      die(e.message)
    end

    private

    def parse_options
      options = Options.new
      parser = OptionParser.new do |opts|
        opts.banner =
          "Usage: bundle exec ruby read_events.rb [-s] [--] <file.xml>"

        opts.on('-s', '--svg',
                'Generate SVG output rather than text diagnostics') do
          options.svg = true
        end
      end

      parser.parse!

      # Filename is a non-option argument
      if ARGV.length == 1
        options[:xml_file] = ARGV[0]
      else
        die("#{parser.help} \n\n" \
            "Expected 1 non-option arg; got #{ARGV.length}: #{ARGV.inspect}")
      end

      options
    end

    def weave_from_xml(filename)
      weave = nil

      # TODO: could move these two lines into Lachisis::Parser
      sax_processor = Lachisis::Parser.new { |w| weave = w }
      sax_parser = Lachisis::Parser::LineNumberAware.new(sax_processor)
      sax_parser.parse(filename)

      raise 'Expected callback to set weave' unless weave

      weave
    end

    # @return [#to_proc]
    def render(weave, options)
      if options.svg
        @layout ||= Lachisis::Layout::SimulatedAnnealing.new
        renderer = Lachisis::SVG.new(@layout)
        renderer.call(weave)

      else
        @render_result = ''
        weave.frames.each do |frame|
          frame.events.each do |event|
            @render_result << sprintf("%11s : %10s\n", frame.timestamp, event)
          end
        end
      end
    end

    def die(message, status: 1)
      warn message
      exit status
    end
  end
end
