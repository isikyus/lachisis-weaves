require 'nokogiri'

require_relative 'event'
require_relative 'weave'

module Lachisis
  NAMESPACE = 'lachisis'

  class Parser < Nokogiri::XML::SAX::Document
    # Time that should be before all other events
    INITIAL = -1000

    def initialize(&callback)
      @major_time = 0
      @minor_time = 0
      @weave = Weave.new
      @was_always_there = []
      @current = nil

      @callback = callback
    end

    def processing_instruction(name, content)
      return unless name.downcase == NAMESPACE

      location = nil
      existing_chars = @current&.characters || []
      entering_chars = []
      present_chars = []
      times = []

      updates = content.strip.split(/\s+/)
      updates.each do |update|
        event, value, *extra = update.split(':')

        if event.nil? || value.nil? || (extra || []).any?
          raise "Invalid update: expected x:y, got \"#{update}\""
        end

        case event
        when 'time'
          times << value.to_f
          existing_chars = []

        when 'location'
          location = value
          existing_chars = []

        when 'enter'
          entering_chars << value

        when 'present'
          present_chars << value

        else
          raise "Unknown update type #{update}"
        end
      end

      entering_chars += present_chars

      if times.any?
        raise "Invalid processing instruction #{content}: need location" unless location
        @minor_time = 0

        times.sort.each do |t|
          event ||= Event.new(location, [])
          event.characters |= entering_chars

          @major_time = t
          @weave.add(@major_time, @minor_time, event)

          @current = event
        end
      else
        @minor_time += 1
        location ||= @current.location
        @current = Event.new(location,
                             existing_chars | entering_chars)

        @weave.add(@major_time, @minor_time, @current)
      end

      @weave.add(INITIAL, 0, Event.new(location, present_chars)) if present_chars.any?

      present_chars.each do |char|
        @was_always_there << {
          character: char,
          location: location,
          since: [@major_time, @minor_time]
        }
      end
    end

    def end_document
      @weave.propagate!
      @callback.call(@weave)
    end
  end
end
