# frozen_string_literal: true

require_relative 'constants'

module Lachisis
  class SVG
    # Calculates measurements information common to the whole SVG
    class Metrics
      def initialize(diagram_width:, max_name_size:)
        @width = diagram_width
        @max_name_size = max_name_size
        @last_location_end = 0
      end

      attr_accessor :last_location_end

      def max_x
        @width + @max_name_size * 2
      end

      def max_y
        last_location_end + Constants::EDGE_OFFSET
      end

      def location_name_offset(index)
        @max_name_size + (index * Constants::EVENT_SPACE)
      end
    end
  end
end
