module Lachisis

  # Knows how to render a weave to SVG
  class SVG
    THREAD_WIDTH = 3
    THREAD_SPACING = THREAD_WIDTH * 2 # Space between character threads
    LOCATION_GAP = 2 # In thread widths

    TIME_GAP = 5 # Space between events horizontally
    BASE_DURATION = 10 # Space events take up
    EVENT_SPACE = TIME_GAP + BASE_DURATION

    LABEL_OFFSET = THREAD_WIDTH
    FONT_SIZE = THREAD_SPACING

    # Finds threads that cross over with a given layout
    class Crossings
      class Crossing < Struct.new(:character, :old_location, :new_location)
      end

      def self.count(weave, locations, characters)
        new(weave, locations, characters)
      end

      def initialize(weave, locations, characters)
        @crossings = []

        # TODO: better not to do this calculation in #initialize?
        last_frame, *frames = weave.frames

        last_order = char_order(locations, characters, last_frame)

        frames.each do |frame|
          new_order = char_order(locations, characters, frame)
          crossed = crossing_characters(last_order, new_order)

          @crossings += crossed.map do |character|
            old_event = last_frame.events.detect { |e| e.characters.include?(character) }
            new_event = frame.events.detect { |e| e.characters.include?(character) }

            Crossing.new(character, old_event.location, new_event.location)
          end

          last_frame = frame
          last_order = new_order
        end
      end

      def total
        # Each crossing involves two lines. Correct for that.
        @crossings.length / 2
      end

      def by_character
        @by_character ||= @crossings
          .group_by(&:character)
          .transform_keys(&:to_sym)
          .transform_values(&:length)
      end

      def by_location
        @by_location ||=
          begin
            totals = Hash.new { |h, k| h[k] = 0 }
            @crossings.each do |crossing|
              totals[crossing.old_location.to_sym] += 1
              totals[crossing.new_location.to_sym] += 1
            end

            totals
          end
      end

      def to_s
        "<#Crossings #{total} across #{by_character.length} characters and #{by_location.length} locations >"
      end

      alias inspect to_s

      private

      # Work out vertical order of characters in a frame, based on layout
      def char_order(locations, characters, frame)
        # TECHNICAL NOTE: this isn't a comparison sort;
        # radix sort may work here since I know the exact place of each
        # location=event in the final array. But I'm not sure how to tell
        # Ruby to use this optimisation.
        events = frame.events.sort_by { |e| locations.index(e.location) }

        events.flat_map do |e|
          e.characters.sort_by { |c| characters.index(c) }
        end
      end

      # Find the threads that cross if you link each element
      # in the input array to the matching one in the output.
      #
      # @return [Array<Crossing>]
      def crossing_characters(from, to)
        # Only care about things that are actually in both sides
        can_cross = from & to

        # Count number of crossings for each character
        crossing_chars = can_cross.flat_map do |char|
          was = from.index(char)
          was_below = from[0..was] # Graphics! Y-axis increases going down
          was_above = from[(was+1)..-1]

          now = to.index(char)
          now_below = to[0..was]
          now_above = to[(was+1)..-1]

          (was_below & now_above) + (was_above & now_below)
        end

        unless crossing_chars.length.even?
          raise "Double crossings should be even but #{from.inspect} and " \
                "#{to.inspect} seem to cross #{crossing_chars.length} times"
        end

        crossing_chars
      end
    end

    # Layout strategies, responsible for deciding what order to put locations
    # and# characters in.
    # Other layout is mostly forced by the structure of the diagram (frames in
    # order, events at their time and location, and threads running through their
    # events.)

    class Layout
      def layout(weave)
        raise 'To be implemented by subclass'
      end

      def crossing_number(weave)
        locations, characters = layout(weave)
        Crossings.count(weave, locations, characters)
      end
    end

    # Minimal algorithm that sort of works: sort by location name,
    # and sort characters by their names
    class SortLayout < Layout
      # @oaram weave [Weave]
      # @return [(Array<String>,Array<String>)]
      #   * Location names in order
      #   * Character names in order
      def layout(weave)
        [
          weave.locations.sort,
          weave.characters.sort
        ]
      end
    end

    class SimulatedAnnealing < Layout
      SAMPLES_PER_ITERATION = 10
      STARTING_TEMPERATURE = 100.0

      def initialize
        # Chosen by fair dice roll ...
        # Actually just constant for now so results are deterministic
        @random = Random.new(4)
      end

      def layout(weave)
        temperature = STARTING_TEMPERATURE
        best_locations = weave.locations
        best_characters = weave.characters
        best_score = Crossings.count(weave, best_locations, best_characters)

        while(temperature > 0.001)
          improvement = 0

          log("Temperature #{temperature}")
          samples = SAMPLES_PER_ITERATION.times.map do
            locs, chars = shuffle(temperature, best_locations, best_characters)
            score = Crossings.count(weave, locs, chars)

            log("- #{score}")

            {
              locs: locs,
              chars: chars,
              score: score
            }
          end

          candidate = samples.min_by { |s| s[:score].total }

          if candidate[:score].total < best_score.total
            improvement = best_score.total - candidate[:score].total
            best_score = candidate[:score]
            best_locations = candidate[:locs]
            best_characters = candidate[:chars]
          end

          log("- improvement this round: #{improvement} (current best #{best_score.total})\n")

          # Decreasing exponentially is good for this, right?
          temperature *= 0.5
        end

        [best_locations, best_characters]
      end

      private

      def shuffle(temperature, locations, characters)
        [
          shuffle_array(temperature, locations),
          shuffle_array(temperature, characters)
        ]
      end

      def shuffle_array(temperature, array)
        a = array.dup
        probability = temperature / STARTING_TEMPERATURE
        (array.length / 2).times do
          i1 = @random.rand(array.length)
          i2 = @random.rand(array.length)
          a[i1], a[i2] = a[i2], a[i1]
        end

        a
      end

      def log msg
        $stderr.puts(msg)
      end
    end

    # @param layout [#layout] something matching the API of
    #               SortLayout#layout
    def initialize(layout)
      @layout = layout
    end

    def call(weave)
      threads = {}
      location_sizes = {}

      weave.frames.each_with_index do |frame, index|
        frame.events.each do |event|

          # TODO: could use Weave#threads here?
          event.characters.each do |c|
            threads[c] ||= []
            threads[c] << { index: index, event: event }
          end

          location_size = [location_sizes[event.location], event.characters.length]
              .compact
              .max
          location_sizes[event.location] = location_size
        end
      end

      location_order, characters = @layout.layout(weave)
      $stderr.puts "Crossing number: #{@layout.crossing_number(weave)}"
      $stderr.puts "Location order: #{location_order.join(', ')}"

      # TODO: could use Nokogiri here

      diagram_width = weave.frames.length * EVENT_SPACE

      # HACK: should really use font metrics or similar
      max_name_size = FONT_SIZE * characters.map(&:length).max
      max_x = diagram_width + max_name_size * 2

      # Calculate where (horizontal row) to each location fits. Assume order stays the same.
      # Start with a bit of space so the first line is readable-ish
      edge_offset = LOCATION_GAP * THREAD_SPACING
      last_location_end = 0

      location_spacing = {}
      location_sizes.sort_by { |l| location_order.index(l) }.each do |location, char_count|
        start_y = last_location_end + edge_offset
        last_location_end = start_y + char_count * THREAD_SPACING

        location_spacing[location] = start_y
      end

      max_y = last_location_end + edge_offset
      xml_data = [
        '<?xml version="1.0"?>',
        "<svg width='#{max_x}' height='#{max_y}'>"
      ]

      threads.each do |character, events|
        path_points = events.flat_map do |index_and_event|
          index_and_event => {index:, event:}
          x = max_name_size + (index * EVENT_SPACE)

          # Allocate character rows based on the global sorted list, so they
          # don't cross over within events
          character_row = (characters & event.characters.to_a).index(character)

          y = location_spacing[event.location]
          y += character_row * THREAD_SPACING

          last_location = event.location
          [x, y, x + BASE_DURATION, y]
        end

        xml_data << %{<path id="thread_#{character}" fill="none" stroke="black" stroke_width="3" d="M #{path_points.join(' ')}"/>}

        start_x, start_y, *, end_x, end_y = *path_points
        xml_data << %{<text x="#{start_x - LABEL_OFFSET}" y="#{start_y}" text-anchor="end" dominant-baseline="middle" font-size="#{FONT_SIZE}">#{character}</text>}
        xml_data << %{<text x="#{end_x + LABEL_OFFSET}" y="#{end_y}" text-anchor="start" dominant-baseline="middle" font-size="#{FONT_SIZE}">#{character}</text>}
      end

      xml_data << '</svg>'

      xml_data.join("\n")
    end
  end
end
