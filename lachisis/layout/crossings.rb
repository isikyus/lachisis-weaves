module Lachisis
  module Layout
    class Crossings
      class Crossing
        def initialize(characters, old_locations, new_locations)
          @characters = characters.map(&:to_sym).to_set
          raise "Expected two characters but got #{@characters.inspect}" unless @characters.length == 2

          @old_locations = old_locations.map(&:to_sym).to_set
          @new_locations = new_locations.map(&:to_sym).to_set
        end

        attr_reader :characters, :old_locations, :new_locations

        def all_locations
          old_locations | new_locations
        end

        def both_characters
          characters
        end

        def eql?(other)
          characters == other.characters &&
            old_locations == other.old_locations &&
            new_locations == other.new_locations
        end

        alias == eql?

        def hash
          characters.hash + old_locations.hash + new_locations.hash
        end
      end

      def self.count(weave, locations, characters)
        new(weave, locations, characters)
          .calculate_crossings!
      end

      def initialize(weave, locations, characters)
        @weave = weave
        @locations = locations
        @characters = characters
      end

      def calculate_crossings!
        raise "Should only calculate crossings once, at initialisation" if @crossings
        @crossings = []

        # TODO: better not to do this calculation in #initialize?
        last_frame, *frames = @weave.frames

        last_order = char_order(@locations, @characters, last_frame)

        frames.each do |frame|
          new_order = char_order(@locations, @characters, frame)
          crossed = crossing_characters(last_order, new_order)

          @crossings += crossed.map do |char1, char2|
            old_events = last_frame.events.select { |e| (e.characters & [char1, char2]).any? }
            new_events = frame.events.select { |e| (e.characters & [char1, char2]).any? }

            Crossing.new(
              [char1, char2].map(&:to_sym),
              old_events.map(&:location).map(&:to_sym),
              new_events.map(&:location).map(&:to_sym)
            )
          end

          last_frame = frame
          last_order = new_order
        end

        self
      end

      # Update crossing counts for this location order, but with two locations
      # and two characters both swapped.
      # (either swap can be nil if you're only swapping one kind of thing).
      #
      # @param location_swap [Array<String>, nil] The two locations to swap
      # @param character_swap [Array<String>, nil] The two characters to swap
      def swap(location_swap, character_swap)
        new_locs = @locations
        new_chars = @characters
        new_crossings = @crossings.dup

        if location_swap
          new_locs = @locations.dup
          adjacent_swaps(location_swap, new_locs).each do |first, last|
            first_loc = new_locs[first]
            last_loc = new_locs[last]
            new_locs[first], new_locs[last] = new_locs[last], new_locs[first]
            new_crossings = update_crossings_with_swap(new_crossings, new_locs, new_chars, first_loc, first, last_loc, last)
          end
        end

        if character_swap
          new_chars = @characters.dup
          adjacent_swaps(character_swap, new_chars).each do |first, last|
            first_char = new_chars[first]
            last_char = new_chars[last]
            new_chars[first], new_chars[last] = new_chars[last], new_chars[first]
            new_crossings = update_crossings_with_char_swap(new_crossings, new_locs, new_chars, first_char, last_char)
          end
        end

        result = Crossings.new(@weave, new_locs, new_chars)
        result.crossings = new_crossings
        result
      end

      # Update a list by swapping two given items
      # @param list [Array]
      # @param swap [Array, nil] two entries to swap
      #             if nil will not swap anything.
      #
      # @return [Array] with the two elements swapped
      def apply_swap(list, swap)
        if swap
          result = list.dup

          raise ArgumentError, 'Can only swap 2 things' unless swap.length == 2
          i1, i2 = *swap.map { |loc| result.index(loc) }

          raise ArgumentError, 'entries must exist in array' unless i1 && i2

          result[i1], result[i2] = result[i2], result[i1]

          result
        else
          list
        end
      end

      def total
        # Each crossing involves two lines. Correct for that.
        @crossings.length / 2
      end

      def by_character
        @by_character ||= @crossings
          .group_by(&:both_characters)
          .transform_values(&:length)
      end

      def by_location
        @by_location ||= @crossings
          .group_by(&:all_locations)
          .transform_values(&:length)
      end

      def to_s
        "<#Crossings #{total} across #{by_character.length} characters and #{by_location.length} locations >"
      end

      alias inspect to_s

      protected

      def crossings=new_crossings
        raise "Should only set crossings once, at initialisation" if @crossings
        @crossings = new_crossings
      end


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
          was_below = from[0...was] # Graphics! Y-axis increases going down
          was_above = from[(was+1)..-1]

          now = to.index(char)
          now_below = to[0...now]
          now_above = to[(now+1)..-1]

          others = (was_below & now_above) + (was_above & now_below)
          others.map { |o| [char, o] }
        end

        unless crossing_chars.length.even?
          raise "Double crossings should be even but #{from.inspect} and " \
                "#{to.inspect} seem to cross #{crossing_chars.length} times"
        end

        crossing_chars
      end


      # Given two list entries to swap, find a sequence of swaps
      # of ajacent pairs that together swap the original two entries
      # (and leave everything else back where it was)
      #
      # @param swap [Array<Object>] The two elements to swap
      # @param list [Array<Object>] The list in which to swap them
      #
      # @return [Array<Array<Integer>]] List of pairs of integers;
      #                             each pair is two adjacent elements
      #                             to swap. Order matters.
      def adjacent_swaps(swap, list)
        start = swap
        finish = []
        affected_indices = list.each_with_index.select do |loc, index|
          # Use the flip-flop operator to pick the two affected locations
          # and any between them. Note we need an `if` to do this as flip-flop
          # only works in that context.
          #
          # Also we can't have both ends of the flip-flop match on the same
          # element or we get just that element.
          if start.include?(loc) .. finish.include?(loc)
            finish = swap
            true
          end
        end.map(&:last)

        unless affected_indices.values_at(0, -1).map { |i| list[i] }.to_set == swap.to_set
          raise "Locations at either end of list should be the values we're swapping"
        end

        # Calculated updated crossings as a series of adjacent swaps.
        # First, swap from start to finish to move the first element to
        # the end; then swap from second-last to beginning to move the
        # old last element back to the start.
        [
          affected_indices,
          affected_indices.reverse[1..]
        ]
          .map { |indices| indices.each_cons(2).to_a }
          .flatten(1)
      end

      # Update the list of crossings given that two adjacent locations are
      # swapped.
      #
      # @param crossings [Array<Crossing>]
      # @param locs [Array<String>] Locations
      # @param chars [Array<String>] Characters
      # @param first_location [String]
      # @param first_location_index [Integer]
      # @param second_location [String]
      # @param second_location_index [Integer]
      def update_crossings_with_swap(crossings, locs, chars, first_location, first_location_index, second_location, second_location_index)
        # Ensure the first location is earlier in order (makes some comparisons later simpler)
        if first_location_index > second_location_index
          first_location, second_location = second_location, first_location
          first_location_index, second_location_index = second_location_index, first_location_index
        end

        # Remove crossings that no longer apply
        # These are only crossings where the two starting locations,
        # or the two ending locations (but not both) are the two being swapped.
        #
        # * If the swap doesn't involve both locations, it doesn't affect the relative
        #   position of the ends of the crossing lines, so there's no effect.
        # * If it does involve both locations, but on opposite sides, then either
        #   (a) one character goes from the first to the second swapped location,
        #   and the other starts above & ends below both, or (b) one character
        #   comes in from above to one of the swapped loations, and the other
        #   leaves from a swapped location to above (or below, but that case
        #   is symmetrical); in that case they will cross regardless of the swap.
        # * If it involves one location twice (one character stays in that
        #   location during the crossing), then the only way a swap makes a
        #   difference is if the other character arrives at or leaves from
        #   the other swapped location; otherwise they still cross from above
        #   to below (or vice versa)
        # * If it involves both locations twice, then one character goes from
        #   the first location to the second and the other goes the other way
        #   (they must change locations as we know they cross). A swap makes
        #   no difference here since it would swap both ends of the crossing
        #   and they'd still cross.
        swapped_locations = Set.new([first_location, second_location].map(&:to_sym))
        remaining_crossings = crossings.reject do |cross|
          (cross.old_locations == swapped_locations) ^ (cross.new_locations == swapped_locations)
        end

        # Add crossings created by the swap.
        # I haven't done a full proof, but I think this case is symmetrical to the above,
        # so only pairs of characters who (a) start or (b) end in the swapped locations,
        # but not both, can be affected by the swap.
        #
        # A full analysis shows that a swap replacing locations (A,B) with (B,A)
        # can only create crossings for characters x (leaving from A) and y
        # (leaving from B) if x's destination is above y's destination (either as
        # a location or in character order within a location). The case for characters
        # arriving at B or A from elsewhere is symmetric.
        #
        # For x and y both leaving from A (or B, or both arriving - symmetry!), they
        # can only now cross if x is above y, x goes to A, and y goes to B.
        new_crossings = @weave.frames.each_cons(2).flat_map do |frame1, frame2|
          leaving_first = []
          leaving_second = []
          leaving_all = []
          frame1.events.sort_by { |e| locs.index(e.location) }.each do |event|
            event.characters.sort_by { |c| chars.index(c) }.each do |character|
              leaving_all << [character, event]

              case event.location
              when first_location
                leaving_first << [character, event]
              when second_location
                leaving_second << [character, event]
              end
            end
          end

          arriving_first = []
          arriving_second = []
          arriving_all = []
          frame2.events.sort_by { |e| locs.index(e.location) }.each do |event|
            event.characters.sort_by { |c| chars.index(c) }.each do |character|
              arriving_all << [character, event]

              case event.location
              when first_location
                arriving_first << [character, event]
              when second_location
                arriving_second << [character, event]
              end
            end
          end

          # Characters pairs leaving from (A, B) who now cross
          new_leaving = []
          leaving_pair = leaving_first + leaving_second
          leaving_pair.each_with_index do |departure, initial_index1|
            char1, event1 = *departure
            _char, destination1, index1 = *arriving_all.each_with_index.detect { |a| a[0][0] == char1 }.flatten
            leaving_pair[(initial_index1 + 1)..].each do |char2, event2|
              next if event1 == event2 # Not actually a swap in this case
              _char, destination2, index2 = *arriving_all.each_with_index.detect { |b| b[0][0] == char2 }.flatten

              if index1 < index2 # Character leaving the previously-higher location arrives at a higher destination
                crossing = Crossing.new(
                  [char1, char2],
                  [event1.location, event2.location],
                  [destination1.location, destination2.location]
                )
                new_leaving << crossing
              end
            end
          end

          # Characters pairs arriving at (A, B) who now cross
          new_arriving = []
          arriving_pair = arriving_first + arriving_second
          arriving_pair.each_with_index do |arrival, initial_index1|
            char1, event1 = *arrival
            _char, destination1, index1 = *leaving_all.each_with_index.detect { |a| a[0][0] == char1 }.flatten
            arriving_pair[(initial_index1 + 1)..].each do |char2, event2|
              next if event1 == event2 # Not actually a swap in this case
              _char, destination2, index2 = *leaving_all.each_with_index.detect { |b| b[0][0] == char2 }.flatten

              if index1 < index2 # Character arriving at the previously-higher location left from a higher destination
                crossing = Crossing.new(
                  [char1, char2],
                  [event1.location, event2.location],
                  [destination1.location, destination2.location]
                )
                new_arriving << crossing
              end
            end
          end

          # Crossings in both arrays have both their start _and_ endpoints swapped,
          # which cancels out, so remove them.
          all_new = (new_leaving + new_arriving) - (new_leaving & new_arriving)

          # Double array elements to keep to the existing double-counting API
          all_new * 2
        end

        remaining_crossings + new_crossings
      end

      # Update the list of crossings given that two adjacent characters are
      # swapped.
      #
      # @param crossings [Array<Crossing>]
      # @param locs [Array<String>] Locations
      # @param chars [Array<String>] Characters
      # @param first_character [String]
      # @param first_character_index [Integer]
      # @param second_character [String]
      # @param second_character_index [Integer]
      def update_crossings_with_char_swap(crossings, locs, chars, first_character, second_character)
        swapped = Set[first_character, second_character]

        # Since lines belong to the same character all the way through, swapping two adjacent
        # characters can only affect intersections between those two characters. Everyone else
        # is either always above both, always below both, or crosses one or both of them due
        # to moving across their location (in which case only a location swap could make a
        # difference).
        #
        # In a similar way, a character swap can only cross or uncross two characters
        # between a pair of frames if the characters either _start_ or _finish_ in the
        # same location, but not both. If they both start and finish in different locations,
        # then either (a) one has start and end locations both above the other's (so
        # it remains above all the way through), or (b) one starts above and ends below
        # the other's location(s), so the location order require a crossing and no character
        # swaps will make a difference.
        # If both characters start and end in the same location they can't possibly cross,
        # as the character order is fixed from frame to frame.
        #
        # So, given two characters who start (or by symmetry, finish) in location A, and
        # diverge to locations B and C, a swap must either cross them (if previously not
        # crossed) or uncross them (if crossed). Suppose character 1 goes to B, and 2 to
        # C (and 1 was above 2 before the swap). If B is above C, then 1 and 2 would not
        # have crossed before, and will after the swap. If B's below C, then 1 and 2 did
        # cross originally and will not after the swap.
        # This still holds if either ending location is the same as A.
        #
        # That means we only need to toggle the state of all and only crossings in this
        # A-(to-or-from)-B-and-C onfiguration.

        affected_crossings = @weave.frames.each_cons(2).map do |frame1, frame2|
          {
            from: frame1.events.select { |e| (e.characters & swapped).any? }.map(&:location),
            to: frame2.events.select { |e| (e.characters & swapped).any? }.map(&:location)
          }
        end
          .select { |pair| (pair[:from].length == 1) ^ (pair[:to].length == 1) }
          .map { |pair| Crossing.new(swapped, pair[:from], pair[:to]) }

        removed, added = affected_crossings.partition { |c| crossings.include?(c) }

        (crossings - removed) + (added * 2)
      end
    end
  end
end

