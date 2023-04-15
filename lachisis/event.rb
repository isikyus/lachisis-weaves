module Lachisis
  class Event
    def initialize(location, actions)
      @location = location
      @actions = actions
    end

    attr_reader :location, :actions

    # TODO: would be nice if we were immutable
    def location= location
      @location = location
    end

    def actions= actions
      @actions = actions
    end

    def inspect
      "<Event#{__id__}: #{to_s}>"
    end

    def characters
      actions.keys.to_set
    end

    def to_s
      "At %15s : %s" % [
        location,
        actions
          .sort_by(&:first)
          .map { |c, a| "#{c}:#{a}" }
          .join(', ')
      ]
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

      def to_s
        '%5s %5s' % [major, minor]
      end

      def inspect
        "<#Timestamp #{to_s}>"
      end
    end

    def initialize(timestamp, event)
      @timestamp = timestamp
      @event = event
    end

    attr_reader :timestamp, :event
  end
end
