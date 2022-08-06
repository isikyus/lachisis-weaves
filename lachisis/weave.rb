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

    def frames
      @frames_events.sort_by { |major, _| major }.flat_map do |major, frames|
        frames.sort_by { |minor, _| minor }.map do |minor, events|
          Frame.new(major, minor, events)
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
  end
end
