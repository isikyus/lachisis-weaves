# frozen_string_literal: true

require 'nokogiri'

require_relative 'event'
require_relative 'weave'

module Lachisis
  module Tokens
    Time = Struct.new(:time) do
      def <=>(other)
        time <=> other.time
      end
    end
    Location = Struct.new(:location)
    Action = Struct.new(:character, :action)
  end

  # Used to distinguish ours from other processing instructions.
  NAMESPACE = 'lachisis'

  # Parses Lachisis processing instructions from XML
  class Parser < Nokogiri::XML::SAX::Document

    # Wrapper for XML parsing errors
    class Error < StandardError
      def initialize(message)
        super("XML parse error: #{message}")
      end
    end

    # Raised when the XML contains events we don't recognise.
    class UnknownUpdateType < Error
      def initialize(update)
        super(
          "Unknown update type #{update}. Expected 'time:<value>'," \
            "'location:<name>', or <event>:<char> " \
            "where <event> is one of these: #{Event::ACTION_TYPES.join(', ')}"
        )
      end
    end

    # Time that should be before all other events
    INITIAL = -1000

    SORTING_HINT_TYPES = {
      'sort-locations' => :locations,
      'sort-characters' => :characters
    }

    def initialize(&callback)
      super

      @major_time = 0
      @minor_time = 0
      @weave = Weave.new
      @current = nil

      @callback = callback
    end

    def warning(message)
      warn "XML parse warning: #{message}"
    end

    def error(message)
      raise Error, message
    end

    def processing_instruction(name, content)
      return unless name.downcase == NAMESPACE

      updates = content.strip.split(/\s+/)

      sorting_hint(*updates) and return if sorting_hint?(updates)

      add_events_for_updates(
        **classify_updates(updates)
      )
    rescue Error => e
      raise Error, "Invalid processing instruction #{content}: #{e.message}"
    end

    def end_document
      @weave.propagate!
      @callback.call(@weave)
    end

    private

    def sorting_hint?(updates)
      SORTING_HINT_TYPES.keys.include?(updates.first)
    end

    def classify_updates(updates)
      tokens = updates.map(&method(:tokenise_update))
      locations, tokens = tokens.partition { |at| at.is_a?(Tokens::Location) }
      times, new_actions = tokens.partition { |at| at.is_a?(Tokens::Time) }

      raise Error, 'Maximum one location' unless locations.length <= 1

      location = locations.any? && locations.first.location

      {
        location: location,
        times: times,
        new_actions: new_actions
      }
    end

    def add_events_for_updates(location:, times:, new_actions:)
      if times.any?
        raise Error, 'Need location after time jump' unless location

        times.sort.each do |t|
          time_jump_to_event(location: location,
                             new_actions: new_actions,
                             time: t)
        end
      else
        @minor_time += 1
        add_event(new_actions, location || @current.location)
      end
    end

    def time_jump_to_event(location:, time:, new_actions:)
      @minor_time = 0
      @major_time = time.time
      add_event(new_actions, location)
    end

    def add_event(actions_data, location = @current.location)
      @current = Event.new(
        location,
        actions_hash(actions_data)
      )
      @weave.add(@major_time, @minor_time, @current)
    end

    def actions_hash(new_actions)
      Hash[
        new_actions.map { |a| [a.character, a.action] }
      ]
    end

    def tokenise_update(update)
      case update.split(':')
      in ['time', value]
        Tokens::Time.new(value.to_f)

      in ['location', value]
        Tokens::Location.new(value)

      in [action_string, value]
        action_for_string(action_string, value)

      else
        raise UnknownUpdateType, update
      end
    end

    def action_for_string(action_string, value)
      action = action_string.to_sym

      types = Event::ACTION_TYPES
      unless types.include?(action)
        update = "#{action_string}:#{value}"
        raise UnknownUpdateType, update
      end

      Tokens::Action.new(value.to_sym, action)
    end

    # @param type ["sort-locations","sort-characters"] What to sort
    # @param order [Array<String>] What order to sort those things in.
    #               May include asterisks as wild cards.
    def sorting_hint(type, *order)
      case SORTING_HINT_TYPES[type]
      when :locations
        @weave.location_sorting = sort_regexes(order)
      when :characters
        @weave.character_sorting = sort_regexes(order)
      else
        raise Error, "Unknown sorting hint type #{type}"
      end
    end

    # @param order_elements [Array<String>]
    def sort_regexes(order_elements)
      order_elements.map do |pattern|
        escaped = Regexp.escape(pattern)
        escaped.gsub!('\*', '.*') if pattern.include?('*')
        Regexp.new("^#{escaped}$")
      end
    end
  end
end
