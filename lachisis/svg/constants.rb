# frozen_string_literal: true

module Lachisis
  class SVG
    module Constants
      THREAD_WIDTH = 3
      THREAD_SPACING = THREAD_WIDTH * 2 # Space between character threads

      LOCATION_GAP = 2 # In thread widths
      EDGE_OFFSET = LOCATION_GAP * THREAD_SPACING

      TIME_GAP = 5 # Space between events horizontally
      BASE_DURATION = 10 # Space events take up
      EVENT_SPACE = TIME_GAP + BASE_DURATION

      LABEL_OFFSET = THREAD_WIDTH
      FONT_SIZE = THREAD_SPACING

      # Number of pixels between re-labellings of the same thread
      RELABEL_INTERVAL = 200

      # Golden ratio - used to separate re-labelling horizontally.
      PHI = (1 + 5.0**0.5) / 2
    end
  end
end
