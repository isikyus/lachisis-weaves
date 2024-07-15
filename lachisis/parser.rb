# frozen_string_literal: true

require 'nokogiri'

require_relative 'event'
require_relative 'weave'

module Lachisis
  module Tokens
    Time = Struct.new(:time) do
      def <=>(other)
        self.time <=> other.time
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

    # Time that should be before all other events
    INITIAL = -1000

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

      location = nil
      new_actions = {}

      updates = content.strip.split(/\s+/)

      if %w[sort-locations sort-characters].include?(updates[0])
        sorting_hint(*updates)
        return
      end

      add_events_for_updates(
        **classify_updates(updates)
      )

    rescue Error => e
      raise Error.new(
        "Invalid processing instruction #{content}: #{e.message}"
      )
    end

    def end_document
      @weave.propagate!
      @callback.call(@weave)
    end

    private

    def classify_updates(updates)
      action_tokens = updates.map(&method(:tokenise_update))
      locations, action_tokens =
        action_tokens.partition { |at| at.is_a?(Tokens::Location) }
      times, new_actions =
        action_tokens.partition { |at| at.is_a?(Tokens::Time) }

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
        raise Error, 'Need location' unless location

        @minor_time = 0
        times.sort.each do |t|
          @major_time = t.time
          add_event(new_actions, location)
        end
      else
        @minor_time += 1
        add_event(new_actions, location || @current.location)
      end
    end

    def add_event(actions_data, location=@current.location)
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
      action_strings = Event::ACTION_TYPES.map(&:to_s)
      case update.split(':')
      in ['time', value]
        Tokens::Time.new(value.to_f)

      in ['location', value]
        Tokens::Location.new(value)

      in [action, value]
        raise 'BANG' unless action_strings.include?(action)
        Tokens::Action.new(value.to_sym, action.to_sym)

      else
        raise "Unknown update type #{update}. Expected 'time:<value>'," \
                "'location:<name>', or <event>:<char> " \
                "where <event> is one of these: #{action_strings.join(', ')}"
      end
    end

    # @param type ["sort-locations","sort-characters"] What to sort
    # @param order [Array<String>] What order to sort those things in.
    #               May include asterisks as wild cards.
    def sorting_hint(type, *order)
      regexes = order.map do |pattern|
        escaped = Regexp.escape(pattern)
        escaped.gsub!('\*', '.*') if pattern.include?('*')
        Regexp.new("^#{escaped}$")
      end

      case type
      when 'sort-locations'
        @weave.location_sorting = regexes
      when 'sort-characters'
        @weave.character_sorting = regexes
      else
        raise "Unknown sorting hint type #{type}"
      end
    end
  end
end
