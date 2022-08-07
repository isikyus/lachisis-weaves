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

  class TimedEvent < Struct.new(:major, :minor, :event)
  end
end
