module Lachisis
  # Layout strategies, responsible for deciding what order to put locations
  # and# characters in.
  # Other layout is mostly forced by the structure of the diagram (frames in
  # order, events at their time and location, and threads running through their
  # events.)
  module Layout

    # Layout strategies, responsible for deciding what order to put locations
    # and# characters in.
    # Other layout is mostly forced by the structure of the diagram (frames in
    # order, events at their time and location, and threads running through their
    # events.)

    class AbstractLayout
      def layout(weave)
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

  end
end
