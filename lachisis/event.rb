module Lachisis
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
end
