module Lachisis
  class Event
    def initialize(location, characters)
      @location = location
      @characters = characters.to_set
    end

    attr_reader :location, :characters

    # TODO: would be nice if we were immutable
    def location= location
      @location = location
    end

    def characters= chars
      @characters = chars.to_set
    end

    def inspect
      "<Event#{__id__}: #{to_s}>"
    end

    def to_s
      "At %15s : %s" % [location, characters.sort.join(', ')]
    end
  end

  class TimedEvent
    class Timestamp < Struct.new(:major, :minor)
      include Comparable

      def <=>(other)
        [major, minor]
          .zip([other.major, other.minor])
          .map { |ours, theirs| ours <=> theirs }
          .reject(&:zero?)
          .first || 0
      end
    end

    def initialize(major_or_timestamp, minor_or_event, event=nil)
      if event
        @timestamp = Timestamp.new(major_or_timestamp, minor_or_event)
        @event = event
      else
        @timestamp = major_or_timestamp
        @event = minor_or_event
      end
    end

    attr_reader :timestamp, :event

    def major
      timestamp.major
    end

    def minor
      timestamp.minor
    end
  end
end
