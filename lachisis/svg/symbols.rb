# frozen_string_literal: true

require_relative 'constants'

module Lachisis
  class SVG
    # Knows how to render various event types symbolically in SVG
    class Symbols
      ASTERISK_SPOKES = 7
      ASTERISK_VOID_FRACTION = 0.5
      SCALE = Constants::THREAD_SPACING * 0.5

      # TODO: consider storing these pre-rendered?
      # @return [String] SVG tag.
      def death(x, y, character)
        path = []
        ASTERISK_SPOKES.times do |spoke|
          # Offset 180 degrees so the first spoke
          # lands on top of the incoming line.
          angle =
            (2 * Math::PI * spoke + ASTERISK_SPOKES / 2.0) / ASTERISK_SPOKES
          x_extent = Math.cos(angle) * SCALE
          y_extent = Math.sin(angle) * SCALE

          path += [
            'M',
            x + (x_extent * ASTERISK_VOID_FRACTION),
            y + (y_extent * ASTERISK_VOID_FRACTION),
            x + x_extent,
            y + y_extent
          ]
        end

        %(<path
          id="symbol_death_#{character}_#{x}_#{y}"
          class="symbol symbol_#{character} symbol-death"
          fill="none"
          stroke="black"
          stroke_width="2"
          d="#{path.join(' ')}"
        />)
      end

      DASH_RATIO = [5, 1, 3, 1, 2, 5].freeze
      DASH_LENGTHS = DASH_RATIO.map do |relative|
        relative * (Constants::BASE_DURATION.to_f / DASH_RATIO.sum)
      end

      def disappear(start_x, y, character)
        start_of_dash = true
        x = start_x

        path = [*DASH_LENGTHS, 0].flat_map do |length|
          action = start_of_dash ? ['M'] : []
          segment = [*action, x, y]
          x += length
          start_of_dash = !start_of_dash

          segment
        end
        %(<path
          id="symbol_disappear_#{character}_#{x}_#{y}"
          class="symbol symbol_#{character} symbol-disappear"
          fill="none"
          stroke="black"
          stroke_width="#{Constants::THREAD_WIDTH}"
          d="#{path.join(' ')}"
        />)
      end

      def arrive(end_x, y, character)
        end_of_dash = true
        x = end_x

        path = [*DASH_LENGTHS, 0].flat_map do |length|
          action = end_of_dash ? ['M'] : []
          segment = [*action, x, y]
          x -= length
          end_of_dash = !end_of_dash

          segment
        end
        %(<path id="symbol_appear_#{character}_#{x}_#{y}"
          class="symbol symbol_#{character} symbol-appear"
          fill="none"
          stroke="black"
          stroke_width="#{Constants::THREAD_WIDTH}"
          d="#{path.join(' ')}"
        />)
      end

      # TODO: extract subclasses that can calculate this
      def spacing(symbol)
        case symbol
        when :arrive, :disappear
          DASH_LENGTHS.sum + (2 * Constants::THREAD_WIDTH)
        when :death
          (2 * SCALE) + (2 * Constants::THREAD_WIDTH)
        else
          raise "Unknown symbol #{symbol}"
        end
      end
    end
  end
end
