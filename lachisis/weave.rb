module Lachisis

  # The full history of a story, including all events and
  # character threads.
  class Weave

    # All the events happening at a specific point in time.
    class Frame < Struct.new(:timestamp, :events)
    end

    attr_accessor :location_sorting
    attr_accessor :character_sorting

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
      # Cache a copy of thread data since we're about to modify the records it's based on
      threads_before = threads
      frames.each do |frame|
        events_before = frame.events.dup
        threads_before.each do |character, thread|
          # TODO: could do this more efficiently if the type expressed that these were in order
          next_appearence = thread.detect { |e| e.timestamp > frame.timestamp }
          last_appearence = thread.reverse.detect { |e| e.timestamp <= frame.timestamp }

          if last_appearence && events_before.include?(last_appearence.event)
            # Nothing to do - we already know where this person is
          elsif next_appearence && next_appearence.present?(character)
            # Assume they go immediately to where we see them next
            add_with_timestamp(frame.timestamp, Lachisis::Event.new(next_appearence.event.location, character => :present))
          elsif last_appearence && last_appearence.remain?(character)
            # Still in the same place they were before
            add_with_timestamp(frame.timestamp, Lachisis::Event.new(last_appearence.event.location, character => :present))
          else
            # No idea where they were; we can't propogate anything.
          end
        end
      end
    end

    private

    def events
      @events_by_time
        .values
        .flat_map(&:to_a)
    end
  end
end
