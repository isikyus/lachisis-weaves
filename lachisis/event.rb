# frozen_string_literal: true

module Lachisis
  # An event, without the context of a specific time.
  # Records only which characters were present/arriving/leaving
  class Event
    # Indicate the character was already at a place when the story reached them.
    PRESENT = [:present].freeze

    # Indicate the character arrived with the story; i.e. they weren't
    # at this location prior to this event.
    ARRIVE = %i[arrive enter].freeze

    # Indicate this is a character's last appearence in a location
    DEPART = %i[depart exit die].freeze

    ACTION_TYPES = PRESENT + ARRIVE + DEPART

    def initialize(location, actions)
      invalid_types = actions.values.uniq - ACTION_TYPES
      raise "Invalid actions: #{invalid_types.inspect}" if invalid_types.any?

      @location = location
      @actions = actions
    end

    # TODO: would be nice if we were immutable
    attr_accessor :location, :actions

    # Was a character present for the _start_ of this event?
    def present?(character)
      PRESENT.include?(@actions[character])
    end

    # Was a character present at the end of this event?
    def remain?(character)
      !DEPART.include?(@actions[character])
    end

    def inspect
      "<Event#{__id__}: #{self}>"
    end

    def characters
      actions.keys.to_set
    end

    def to_s
      actions_string = actions
                       .sort_by(&:first)
                       .map { |c, a| "#{c}:#{a}" }
                       .join(', ')

      'At %<loc>15s : %<acts>s' % { loc: location, acts: actions_string }
    end
  end

  # Wraps an event and adds time inforation:
  # when all this happened
  class TimedEvent
    # Represent the time an event happened.
    # This has two parts: the major timestamp
    # is the time explicitly set in the input
    # (for time jumps etc.), while the minor
    # timestamp measures the ordinary, linear
    # passage of time from sentenece to sentence
    # or (comic) frame to frame.
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
        '%<maj>5s %<min>5s' % { maj: major, min: minor }
      end

      def inspect
        "<#Timestamp #{self}>"
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
