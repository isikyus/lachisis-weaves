require 'nokogiri'

require_relative 'lachisis/event'
require_relative 'lachisis/weave'

module Lachisis
  NAMESPACE = 'lachisis'

  class Parser < Nokogiri::XML::SAX::Document
    # Time that should be before all other events
    INITIAL = -1000

    def initialize(&callback)
      @major_time = 0
      @minor_time = 0
      @weave = Weave.new
      @was_always_there = []
      @current = nil

      @callback = callback
    end

    def processing_instruction(name, content)
      return unless name.downcase == NAMESPACE

      location = nil
      existing_chars = @current&.characters || []
      entering_chars = []
      present_chars = []
      times = []

      updates = content.strip.split(/\s+/)
      updates.each do |update|
        event, value, *extra = update.split(':')

        if event.nil? || value.nil? || (extra || []).any?
          raise "Invalid update: expected x=y, got \"#{update}\""
        end

        case event
        when 'time'
          times << value.to_f
          existing_chars = []

        when 'location'
          location = value
          existing_chars = []

        when 'enter'
          entering_chars << value

        when 'present'
          present_chars << value

        else
          raise "Unknown update type #{update}"
        end
      end

      entering_chars += present_chars

      if times.any?
        raise "Invalid processing instruction #{content}: need location" unless location
        @minor_time = 0

        times.sort.each do |t|
          event ||= Event.new(location, [])
          event.characters |= entering_chars

          @major_time = t
          @weave.add(@major_time, @minor_time, event)

          @current = event
        end
      else
        @minor_time += 1
        location ||= @current.location
        @current = Event.new(location,
                             existing_chars | entering_chars)

        @weave.add(@major_time, @minor_time, @current)
      end

      @weave.add(INITIAL, 0, Event.new(location, present_chars)) if present_chars.any?

      present_chars.each do |char|
        @was_always_there << {
          character: char,
          location: location,
          since: [@major_time, @minor_time]
        }
      end
    end

    def end_document
      @weave.propagate!
      @callback.call(@weave)
    end
  end
end

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
      locations = []
      characters = []

      weave.frames.each_with_index do |frame, index|
        frame.events.each do |event|
          locations |= [event.location]

          # Convert to array since we care about order of characters
          characters |= event.characters.to_a

          event.characters.each do |c|
            threads[c] ||= []
            threads[c] << { index: index, event: event }
          end
        end
      end

      characters.sort

      # TODO: could use Nokogiri here

      diagram_width = weave.frames.length * SVG_EVENT_SPACE

      # HACK: should really use font metrics or similar
      max_name_size = SVG_FONT_SIZE * characters.map(&:length).max
      max_x = diagram_width + max_name_size * 2

      location_spacing = (characters.length + SVG_LOCATION_GAP) * SVG_THREAD_SPACING
      max_y = locations.length * location_spacing
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

          y = locations.index(event.location) * location_spacing
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

parser = Nokogiri::XML::SAX::Parser.new(
  Lachisis::Parser.new(&output_callback)
)
parser.parse(File.open(ARGV[0]))
