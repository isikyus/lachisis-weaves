module Lachisis
  class Event
    # Indicate the character was already at a place when the story reached them.
    PRESENT = [:present]

    # Indicate the character arrived with the story (wasn't previously at the place we see them)
    ARRIVE = [:arrive, :enter]

    # Indicate this is a character's last appearence in a location
    DEPART = [:depart, :exit, :die]

    ACTION_TYPES = PRESENT + ARRIVE + DEPART

    def initialize(location, actions)
      invalid_types = actions.values.uniq - ACTION_TYPES
      raise "Invalid actions: #{invalid_types.inspect}" if invalid_types.any?

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

    # Was a character present for the _start_ of this event?
    def present?(character)
      PRESENT.include?(@actions[character])
    end

    # Was a character present at the end of this event?
    def remain?(character)
      !DEPART.include?(@actions[character])
    end

    def inspect
      "<Event#{__id__}: #{to_s}>"
    end

    def characters
      actions.keys.to_set
    end

    def to_s
      actions_string = actions
          .sort_by(&:first)
          .map { |c, a| "#{c}:#{a}" }
          .join(', ')

      "At %15s : %s" % [location, actions_string]
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

    def present?(char)
      event.present?(char)
    end

    def remain?(char)
      event.remain?(char)
    end
  end
end
