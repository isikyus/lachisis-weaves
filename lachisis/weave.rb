# frozen_string_literal: true

module Lachisis
  # The full history of a story, including all events and
  # character threads.
  class Weave
    # All the events happening at a specific point in time.
    class Frame < Struct.new(:timestamp, :events)
    end

    attr_accessor :location_sorting, :character_sorting

    def initialize
      @events_by_time = {}
      self.location_sorting = []
      self.character_sorting = []
    end

    # View the weave as a sequence of "frames": time slices where one or more
    # events occur simultaneously (but in different places -- sorry Einstein!)
    #
    # @return [Array<Frame>]
    def frames
      @events_by_time.sort.map do |timestamp, events|
        Frame.new(timestamp, events)
      end
    end

    # View the weave as a set of "threads": sequences of events following
    # particular characters.
    #
    # @return [Hash{String, Array<Event>}]
    def threads
      {}.tap do |threads|
        @events_by_time.sort.each do |timestamp, events|
          events.each do |event|
            event.characters.each do |character|
              threads[character] ||= []
              threads[character] << TimedEvent.new(timestamp, event)
            end
          end
        end
      end
    end

    # @return [Array<String>] Names of all locations in the weave
    def locations
      events.map(&:location).uniq
    end

    # @return [Array<String>] Names of all characters in the weave
    def characters
      events
        .map(&:characters)
        .inject(&:union)
        .to_a
    end

    # Add an event to the weave at a given time, creating a new frame
    # if necessary for that time. If an event exists already at this
    # time and location, the new characters will be merged into it.
    #
    # @param major_time [Numeric]
    # @param minor_time [Numeric]
    # @param event [Lachisis::Event]
    def add(major, minor, event)
      timestamp = Lachisis::TimedEvent::Timestamp.new(major, minor)
      add_with_timestamp(timestamp, event)
    end

    # As above, but use a timestamp object instead of separate
    # major and minor times.
    #
    # @param timestamp [Lachisis::TimedEvent::Timestamp]
    # @param event [Lachisis::Event]
    def add_with_timestamp(timestamp, event)
      @events_by_time[timestamp] ||= Set[]
      events_at_time = @events_by_time[timestamp]

      existing_event = events_at_time.detect { |e| e.location == event.location }

      if existing_event
        events_at_time.delete(existing_event)

        merged = Event.new(event.location,
                           existing_event.actions.merge(event.actions))
        events_at_time << merged
      else
        events_at_time << event
      end
    end

    # Fill in history based on the events we know about, by assuming
    # people didn't go anywhere except when events indicate it.
    #
    # TODO: we can do better than this but it requires recording more
    # information about where people are when.
    def propagate!
      # Infer intermediate locations based on what we're given
      # by the story
      inferences = frames.flat_map do |frame|
        threads.map do |character, thread|
          location = infer_location(thread, character, frame)
          location && {
            who: character,
            where: location,
            when: frame.timestamp
          }
        end.compact
      end

      inferences.each do |infer|
        add_with_timestamp(
          infer[:when],
          Lachisis::Event.new(infer[:where], infer[:who] => :present)
        )
      end
    end

    private

    # Work out where the character covered by a given thread
    # is in a particular frame, from surrounding location info.
    #
    # @return [Location,nil] nil if there is no location data to infer from,
    #         or if inference is unnecessary (location already known for
    #         this frame).
    def infer_location(thread, character, frame)
      # TODO: could do this more efficiently if the type expressed that these were in order
      next_appearance = thread.detect { |e| e.timestamp >= frame.timestamp }
      last_appearance = thread.reverse.detect { |e| e.timestamp <= frame.timestamp }

      if next_appearance == last_appearance
        # If these are both non-nil they're this location;
        # we already know where we are.
        # If they're both nil, there are no locations to infer from
        nil

      elsif next_appearance&.present?(character)
        next_appearance.event.location
      elsif last_appearance&.remain?(character)
        last_appearance.event.location
      end
    end

    def events
      @events_by_time
        .values
        .flat_map(&:to_a)
    end
  end
end
