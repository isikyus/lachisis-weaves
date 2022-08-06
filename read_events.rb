require 'nokogiri'

require_relative 'lachisis/event'

module Lachisis
  NAMESPACE = 'lachisis'

  class Parser < Nokogiri::XML::SAX::Document
    def initialize(&callback)
      @major_time = 0
      @minor_time = 0
      @sequence = { :initial => {0 => []} }
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

        times.sort.each do |t|
          @sequence[t] ||= {}
          @sequence[t][0] ||= []

          event = @sequence[t][0].detect { |e| e.location == location }
          unless event
            event = Event.new(location, [])
            @sequence[t][0] << event
          end

          event.characters |= entering_chars

          @major_time = t
          @current = event
        end

        @minor_time = 0
      else
        @minor_time += 1
        location ||= @current.location
        @current = Event.new(location,
                             existing_chars | entering_chars)

        @sequence[@major_time] ||= {}
        @sequence[@major_time][@minor_time] ||= []
        @sequence[@major_time][@minor_time] << @current
      end

      present_chars.each do |char|
        @was_always_there << {
          character: char,
          location: location,
          since: [@major_time, @minor_time]
        }

        initial_location_event = @sequence[:initial][0].detect { |e| e.location == location }
        unless initial_location_event
          initial_location_event = Event.new(location, [])
          @sequence[:initial][0] << initial_location_event
        end
        initial_location_event.characters << char
      end
    end

    def end_document
      event_stream = []
      sorted_keys = [:initial, *(@sequence.keys - [:initial]).sort]
      sorted_keys.each do |major|
        @sequence[major].keys.sort.each do |minor|
          @sequence[major][minor].each do |event|
            unless major == :initial
              always_there_chars = @was_always_there.select do |entry|
                entry[:location] == event.location &&
                  ((entry[:since] <=> [major, minor]) < 0)
              end.map { |e| e[:character] }
              event.characters += always_there_chars
            end

            event_stream << TimedEvent.new(major, minor, event)
          end
        end
      end

      @callback.call(event_stream)
    end
  end
end

output_callback = ->(sequence) {
  sequence.each do |te|
    printf("%5s %5s : %10s\n", te.major, te.minor, te.event)
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

while ARGV[0].start_with?('-')
  option = ARGV.shift

  case option
  when '--'
    break # End of options

  when '-s' # SVG
    output_callback = ->(sequence) {
      threads = {}
      locations = []
      characters = []

      sequence.each_with_index do |timed_event, index|
        locations |= [timed_event.event.location]
        characters |= timed_event.event.characters

        timed_event.event.characters.each do |c|
          threads[c] ||= []
          threads[c] << { index: index, event: timed_event.event }
        end
      end

      # TODO: could use Nokogiri here
      max_x = sequence.length * SVG_EVENT_SPACE

      location_spacing = (characters.length + SVG_LOCATION_GAP) * SVG_THREAD_SPACING
      max_y = locations.length * location_spacing
      xml_data = ['<?xml version="1.0"?>', '<svg>']

      character_row = nil
      last_location = nil
      threads.each do |character, events|
        path_points = events.flat_map do |index_and_event|
          index_and_event => {index:, event:}
          x = index * SVG_EVENT_SPACE

          # Reset where we put this char's thread if we're in a new location, or if another char is using this one.
          character_row = nil if event.location != last_location || ![nil, character].include?(event.characters[character_row])
          character_row ||= event.characters.index(character)

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
