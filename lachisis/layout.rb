# frozen_string_literal: true

module Lachisis
  # Layout strategies, responsible for deciding what order to put locations
  # and# characters in.
  # Other layout is mostly forced by the structure of the diagram (frames in
  # order, events at their time and location, and threads running through their
  # events.)
  module Layout
    # Superclass of layout strategies, responsible for deciding what order
    # to put locations and characters in.
    # Other layout is mostly forced by the structure of the diagram
    # (frames in order, events at their time and location,
    # and threads running through their events.)
    class AbstractLayout
      # @param weave [Lachisis::Weave]
      def layout(_weave)
        raise 'To be implemented by subclass'
      end
    end

    # Minimal algorithm that sort of works: sort by location name,
    # and sort characters by their names
    class SortLayout < AbstractLayout
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

    # Doesn't try to do any auto-layout; instead relies on sorting infomration
    # added by the file author.
    class Sorted
      def layout(weave)
        [
          apply_sorting(weave.locations, weave.location_sorting),
          apply_sorting(weave.characters, weave.character_sorting)
        ]
      end

      private

      def apply_sorting(list, sort_rules)
        list.sort_by do |item|
          [
            sort_rules.index { |rule| rule.match?(item) } || -1,
            item
          ]
        end
      end
    end
  end
end
