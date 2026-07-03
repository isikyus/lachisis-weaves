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
    def self.run
      new.run
    end

    def initialize(cli_args = ARGV)
      option_parser.parse!(cli_args)

      # Filename is a non-option argument
      @xml_file = filename_from_argv(cli_args)
    end

    def run
      weave = weave_from_xml(@xml_file)
      puts render(weave)
    rescue Lachisis::Parser::LineNumberAware::LocatedError => e
      die(e.message)
    end

    # @api private
    def weave_from_xml(filename)
      weave = nil

      # TODO: could move these two lines into Lachisis::Parser
      sax_processor = Lachisis::Parser.new { |w| weave = w }
      sax_parser = Lachisis::Parser::LineNumberAware.new(sax_processor)
      sax_parser.parse(filename)

      raise 'Expected callback to set weave' unless weave

      weave
    end

    private

    def option_parser
      @option_parser ||= OptionParser.new do |opts|
        opts.banner =
          'Usage: bundle exec ruby read_events.rb [-s] [--] <file.xml>'

        opts.on('-s', '--svg',
                'Generate SVG output rather than text diagnostics') do
          @svg = true
        end
      end
    end

    def filename_from_argv(cli_args)
      if cli_args.length == 1
        cli_args[0]
      else
        die("#{option_parser.help} \n\n" \
            "Expected 1 non-option arg; got #{cli_args.length}: #{cli_args.inspect}")
      end
    end

    # @return [#to_proc]
    def render(weave)
      if @svg
        render_svg(weave)
      else
        list_events(weave)
      end
    end

    def render_svg(weave)
      @layout ||= Lachisis::Layout::Sorted.new
      renderer = Lachisis::SVG.new(@layout)
      renderer.call(weave)
    end

    def list_events(weave)
      [
        "Location order: #{weave.location_sorting.inspect}",
        "Character order: #{weave.character_sorting.inspect}",
        *list_lines(weave)
      ].join("\n")
    end

    def list_lines(weave)
      weave.frames.flat_map do |frame|
        frame.events.map do |event|
          format('%<time>11s : %<event>10s',
                 time: frame.timestamp,
                 event: event)
        end
      end
    end

    def die(message, status: 1)
      warn message
      exit status
    end
  end
end
