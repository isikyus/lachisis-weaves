module Lachisis

  # The full history of a story, including all events and
  # character threads.
  class Weave

    # All the events happening at a specific point in time.
    class Frame < Struct.new(:major, :minor, :events)
    end

    def initialize
      @frames_events = {}
    end

    # View the weave as a sequence of "frames": time slices where one or more
    # events occur simultaneously (but in different places -- sorry Einstein!)
    #
    # @return [Array<Frame>]
    def frames
      @frames_events.sort_by { |major, _| major }.flat_map do |major, frames|
        frames.sort_by { |minor, _| minor }.map do |minor, events|
          Frame.new(major, minor, events)
        end
      end
    end

    # View the weave as a set of "threads": sequences of events following
    # particular characters.
    #
    # @return [Hash{String, Array<Event>}]
    def threads
      {}.tap do |threads|
        frames.each do |frame|
          frame.events.each do |event|
            event.characters.each do |character|
              threads[character] ||= []
              threads[character] << TimedEvent.new(frame.major, frame.minor, event)
            end
          end
        end
      end
    end

    # Add an event to the weave at a given time, creating a new frame
    # if necessary for that time. If an event exists already at this
    # time and location, the new characters will be merged into it.
    #
    # @param major_time [Numeric]
    # @param minor_time [Numeric]
    # @param event [Lachisis::Event]
    def add(major, minor, event)
      @frames_events[major] ||= {}
      @frames_events[major][minor] ||= Set.new

      frame_set = @frames_events[major][minor]
      existing_event = frame_set.detect { |e| e.location == event.location }

      if existing_event
        frame_set.delete(existing_event)

        merged = Event.new(event.location,
                           existing_event.characters | event.characters)
        frame_set << merged
      else
        frame_set << event
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
        threads_before.each do |character, thread|
          # TODO: could do this more efficiently if the type expressed that these were in order
          last_appearence = thread.reverse.detect { |e| e.major <= frame.major && e.minor <= frame.minor }

          if last_appearence && frame.events.include?(last_appearence.event)
            # Nothing to do - we already now where this person is
          elsif last_appearence
            # Still in the same place they were before
            add(frame.major, frame.minor, Lachisis::Event.new(last_appearence.event.location, [character]))
          elsif thread.any?
            # Before start of thread; assume they're where we first see them
            add(frame.major, frame.minor, Lachisis::Event.new(thread.first.event.location, [character]))
          else
            raise "Thread for #{character} exists but is empty. This should not happen."
          end

        end
      end
    end
  end
end
