require 'nokogiri'

module Lachisis
  NAMESPACE = 'lachisis'

  class Event < Struct.new(:location, :characters)
    def inspect
      "<Event#{__id__}: #{to_s}>"
    end

    def to_s
      "At %15s : %s" % [location, characters.sort.join(', ')]
    end
  end

  class TimedEvent < Struct.new(:major, :minor, :event)
  end

  class Parser < Nokogiri::XML::SAX::Document
    def initialize(&callback)
      @major_time = 0
      @minor_time = 0
      @sequence = {}
      @current = nil

      @callback = callback
    end

    def processing_instruction(name, content)
      return unless name.downcase == NAMESPACE

      location = nil
      existing_chars = @current&.characters || []
      new_chars = []
      times = []

      updates = content.strip.split(/\s+/)
      updates.each do |update|
        name, value, *extra = update.split('=')

        if name.nil? || value.nil? || (extra || []).any?
          raise "Invalid update: expected x=y, got \"#{update}\""
        end

        case name
        when 'time'
          times << value.to_f
          existing_chars = []

        when 'location'
          location = value
          existing_chars = []

        when 'char'
          new_chars << value

        else
          raise "Unknown update type #{update}"
        end
      end

      if times.any?
        times.sort.each do |t|
          @sequence[t] ||= {}
          @sequence[t][0] ||= []

          event = @sequence[t][0].detect { |e| e.location == location }
          unless event
            event = Event.new(location, [])
            @sequence[t][0] << event
          end

          event.characters |= new_chars

          @major_time = t
          @current = event
        end

        @minor_time = 0
      else
        @minor_time += 1
        @current = Event.new(location || @current.location,
                             existing_chars | new_chars)

        @sequence[@major_time] ||= {}
        @sequence[@major_time][@minor_time] ||= []
        @sequence[@major_time][@minor_time] << @current
      end
    end

    def end_document
      event_stream = []
      @sequence.keys.sort.each do |major|
        @sequence[major].keys.sort.each do |minor|
          @sequence[major][minor].each do |event|
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

while ARGV[0].start_with?('-')
  option = shift

  case option
  when '--'
    break # End of options
  end
end

parser = Nokogiri::XML::SAX::Parser.new(
  Lachisis::Parser.new(&output_callback)
)
parser.parse(File.open(ARGV[0]))
