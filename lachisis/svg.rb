require_relative 'layout'
require_relative 'layout/crossings'

module Lachisis

  # Knows how to render a weave to SVG
  class SVG

    # Measurement information common to the whole SVG
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
        last_location_end + Lachisis::SVG::EDGE_OFFSET
      end

      # TODO: what actually is this?
      def event_name_offset(index)
        @max_name_size + (index * EVENT_SPACE)
      end
    end

    THREAD_WIDTH = 3
    THREAD_SPACING = THREAD_WIDTH * 2 # Space between character threads

    LOCATION_GAP = 2 # In thread widths
    EDGE_OFFSET = LOCATION_GAP * THREAD_SPACING

    TIME_GAP = 5 # Space between events horizontally
    BASE_DURATION = 10 # Space events take up
    EVENT_SPACE = TIME_GAP + BASE_DURATION

    # Knows how to render various event types symbolically in SVG
    class Symbols
      ASTERISK_SPOKES = 7
      ASTERISK_VOID_FRACTION = 0.5
      SCALE = Lachisis::SVG::THREAD_SPACING * 0.5

      # TODO: consider storing these pre-rendered?
      # @return [String] SVG tag.
      def death(x, y, character)
        path = []
        ASTERISK_SPOKES.times do |spoke|
          # Offset 180 degrees so the first spoke lands on top of the incoming line.
          angle = (2 * Math::PI * spoke + ASTERISK_SPOKES / 2.0) / ASTERISK_SPOKES
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

        %{<path id="symbol_death_#{character}_#{x}_#{y}" class="symbol symbol_#{character} symbol-death" fill="none" stroke="black" stroke_width="2" d="#{path.join(' ')}"/>}
      end

      DASH_RATIO = [5, 1, 3, 1, 2, 5]
      DASH_LENGTHS = DASH_RATIO.map do |relative|
        relative * (Lachisis::SVG::BASE_DURATION.to_f / DASH_RATIO.sum)
      end

      def disappear(startX, y, character)
        start_of_dash = true
        x = startX

        path = [*DASH_LENGTHS, 0].flat_map do |length|
          action = start_of_dash ? ['M'] : []
          segment = [*action, x,  y]
          x += length
          start_of_dash = !start_of_dash

          segment
        end
        %{<path id="symbol_disappear_#{character}_#{x}_#{y}" class="symbol symbol_#{character} symbol-disappear" fill="none" stroke="black" stroke_width="#{Lachisis::SVG::THREAD_WIDTH}" d="#{path.join(' ')}"/>}
      end

      def arrive(endX, y, character)
        end_of_dash = true
        x = endX

        path = [*DASH_LENGTHS, 0].flat_map do |length|
          action = end_of_dash ? ['M'] : []
          segment = [*action, x,  y]
          x -= length
          end_of_dash = !end_of_dash

          segment
        end
        %{<path id="symbol_appear_#{character}_#{x}_#{y}" class="symbol symbol_#{character} symbol-appear" fill="none" stroke="black" stroke_width="#{Lachisis::SVG::THREAD_WIDTH}" d="#{path.join(' ')}"/>}
      end

      # TODO: extract subclasses that can calculate this
      def spacing(symbol)
        case symbol
        when :arrive, :disappear
          DASH_LENGTHS.sum + (2 * THREAD_WIDTH)
        when :death
          (2 * SCALE) + (2 * THREAD_WIDTH)
        else
          raise "Unknown symbol #{symbol}"
        end
      end
    end

    LABEL_OFFSET = THREAD_WIDTH
    FONT_SIZE = THREAD_SPACING

    # Number of pixels between re-labellings of the same thread
    RELABEL_INTERVAL = 200

    # Golden ratio - used to separate re-labelling horizontally.
    PHI = (1 + 5.0**0.5) / 2

    # @param layout [#layout] something matching the API of
    #               Layout::SortLayout#layout
    def initialize(layout)
      @layout = layout
    end

    # Make callable as a proc
    def to_proc
      Proc.new do |weave|
        self.call(weave)
      end
    end

    def call(weave)
      threads, location_sizes = build_threads(weave)
      location_order, characters = @layout.layout(weave)

      # TODO: turned off for now as crossing calculation makes assumptions about propogation that don't hold.
      #$stderr.puts "Crossing number: #{Layout::Crossings.count(weave, location_order, characters).total}"
      $stderr.puts "Location order: #{location_order.inspect}"

      # The same, but for vertical space between events. This needs to be big
      # enough to fit any symbols or angled transition lines
      cumulative_offset  = 0
      carried_over = 0
      event_spacing = weave.frames.map do |frame|
        actions = frame.events.map(&:actions).flat_map(&:values)
        before_spacings = actions
                            .select { [:enter].include?(_1) }
                            .uniq
                            .map { Symbols.new.spacing(:arrive) }
        offset = BASE_DURATION + carried_over + [0, *before_spacings].max

        # Spacing for "leave" events apply to the _next_ event space.
        carried_over = actions
                         .select { [:die, :exit].include?(_1) }
                         .uniq
                         .map do |action|
                           case action
                           when :die,
                             Symbols.new.spacing(:death)
                           when :exit
                             Symbols.new.spacing(:disappear)
                           else
                             raise 'Unknown leave event type'
                           end
                         end.max || 0

        cumulative_offset += offset
        cumulative_offset
      end

      # TODO: could use Nokogiri here

      metrics = Metrics.new(
        diagram_width: cumulative_offset,
        # HACK: should really use font metrics or similar
        max_name_size: characters.map(&:length).max * FONT_SIZE
      )

      # Calculate where (horizontal row) to each location fits. Assume order stays the same.
      # Start with a bit of space so the first line is readable-ish

      location_spacing = {}
      location_sizes.sort_by { |l, _sz| location_order.index(l) }.each do |location, char_count|
        start_y = metrics.last_location_end + EDGE_OFFSET
        metrics.last_location_end = start_y + char_count * THREAD_SPACING

        location_spacing[location] = start_y
      end

      $stderr.puts(location_spacing.map { |location, space| "%5d (%2d) %s" % [space, location_order.index(location) || -1, location.inspect] })

      xml_data = [
        '<?xml version="1.0"?>',
        "<svg width='#{metrics.max_x}' height='#{metrics.max_y}' xmlns='http://www.w3.org/2000/svg'>"
      ]

      # Draw location labels
      location_spacing.each do |loc, y_position|
        _frame, first_frame_index = weave
          .frames
          .each_with_index
          .detect { |f, _i| f.events.map(&:location).include?(loc) }

        label_y = y_position + (location_sizes[loc] * THREAD_SPACING / 2.0)
        label_x = metrics.event_name_offset(first_frame_index)
        xml_data << %{<text x="#{label_x - LABEL_OFFSET}" y="#{label_y}" text-anchor="end" dominant-baseline="middle" font-size="#{FONT_SIZE * 2}" opacity="0.5">#{loc}</text> }
      end

      # Draw character threads
      relabel_phase = 0
      relabel_offset = 0
      threads.each do |character, events|

        path = events_to_points(character, events, metrics, characters, location_spacing, event_spacing)
        path_points = simplify(path)

        # Insert labels at intervals in straight lines
        relabel_offset = (relabel_offset * PHI) % RELABEL_INTERVAL
        distance_until_relabel = RELABEL_INTERVAL - relabel_offset
        # HACK: again, should be using font metrics
        label_length = FONT_SIZE * character.length

        start, *_rest = *path_points
        paths = [[start[0..1]]]
        symbols = []
        drawing = true
        path_points.each_cons(2).map do |segment|
          p0, p1 = *segment
          x0, y0, _ = *p0
          x1, y1, event = *p1

          # Only consider 'enter' events worth a symbol if we were previously blanked.
          event = :appear if drawing && event == :enter
          symbols << [x1, y1, event] unless [:present, :appear].include?(event)

          if event == :exit
            drawing = false
            distance_until_relabel = RELABEL_INTERVAL - relabel_offset
            next
          elsif drawing == false
            drawing = true
            paths.last << [x0, y0]
            paths.last << 'M'
          end

          distance = ((x0 - x1)**2 + (y0 - y1)**2)**0.5
          distance_until_relabel -= distance

          if distance_until_relabel <= 0 && distance > label_length
            # Create a gap to put the label in
            label_portion = label_length / distance
            non_label_portion = (1 - label_portion)
            portion_each_side = non_label_portion / 2

            # End path before the label.
            paths.last << [
              (x0 * (1 - portion_each_side)) + (x1 * portion_each_side),
              (y0 * (1 - portion_each_side)) + (y1 * portion_each_side)
            ]

            # Insert label in the gap.
            label_x = (x0 + x1) / 2.0
            label_y = (y0 + y1) / 2.0

            line_angle = Math.atan((y1 - y0) / (x1 - x0).to_f)

            # Rotate 90 degrees to ???
            label_angle = line_angle
            label_angle_degrees = 360 * label_angle / (2 * Math::PI)
            xml_data << %{<text x="#{label_x}" y="#{label_y}" transform="rotate(#{label_angle_degrees} #{label_x} #{label_y})" text-anchor="middle" dominant-baseline="middle" font-size="#{FONT_SIZE}">#{character}</text>}

            # Start new path after the label
            paths << []
            paths.last << [
              (x0 * portion_each_side) + (x1 * (1 - portion_each_side)),
              (y0 * portion_each_side) + (y1 * (1 - portion_each_side))
            ]

            distance_until_relabel = RELABEL_INTERVAL
          end

          paths.last << [x1, y1]
        end

        # Actually generate SVG

        # Create multiple tags for each path.
        # TODO: consider having one path with gaps instead?
        paths.each_with_index do |path, index|
          xml_data << %{<path id="thread_#{character}_#{index}" fill="none" stroke="black" stroke_width="3" d="M #{path.flatten.join(' ')}"/>}
        end

        symbols.each_with_index do |point_event, index|
          x, y, event = *point_event
          text_positioning =
            if Event::ARRIVE.include?(event)
              [-LABEL_OFFSET, 'end']
            elsif Event::DEPART.include?(event)
              [+LABEL_OFFSET, 'start']
            else
              [0, 'middle']
            end
          x_offset, anchor = *text_positioning

          case event
          when :die
            xml_data << Symbols.new.death(x, y, character)
          when :enter
            xml_data << Symbols.new.arrive(x, y, character)
          when :exit
            xml_data << Symbols.new.disappear(x, y, character)
          else
            $stderr.puts("No symbol available for event type #{event.inspect}")
          end
          #xml_data << %{<text id="event_#{event}_#{index}" x="#{x + x_offset}" y="#{y}" text-anchor="#{anchor}" dominant-baseline="middle" font-size="#{FONT_SIZE}" color="red">#{event}</text>}
        end

        start_x, start_y, *, end_x, end_y, _ = *path_points.flatten
        xml_data << %{<text x="#{start_x - LABEL_OFFSET}" y="#{start_y}" text-anchor="end" dominant-baseline="middle" font-size="#{FONT_SIZE}">#{character}</text>}
        xml_data << %{<text x="#{end_x + LABEL_OFFSET}" y="#{end_y}" text-anchor="start" dominant-baseline="middle" font-size="#{FONT_SIZE}">#{character}</text>}
      end

      xml_data << '</svg>'

      xml_data.join("\n")
    end

    private

    def events_to_points(character, events, metrics, characters, location_spacing, event_spacing)
      events.flat_map do |index_and_event|
        index_and_event => {index:, event:}
        x = event_spacing[index]

        # Allocate character rows based on the global sorted list, so they
        # don't cross over within events
        character_row = (characters & event.characters.to_a).index(character)

        y = location_spacing[event.location]
        y += character_row * THREAD_SPACING

        last_location = event.location
        [
          [x, y, event.initial_action(character)],
          [x + BASE_DURATION, y, event.final_action(character)]
        ]
      end
    end

    def simplify(path_points)
      # Simplify path to make relabelling easier
      before = path_points.length
      relevant_points = path_points.each_cons(3).map do |p0, p1, p2|
        # Ignore points which are (a) collinear, and
        # (b) don't have any interesting events
        if horizontally_collinear(p0, p1, p2) && p1[2] == :present
          nil
        else
          p1
        end
      end
      path_points = [
        path_points.first,
        *relevant_points.compact,
        path_points.last
      ]

      path_points
    end

    # @param p1, p1, p3 [Array<Integer, Object>] Possibly-annotated points,
    #                   represented as arrays [x, y, ...]
    def horizontally_collinear(p0, p1, p2)
      p0[1] == p1[1] && p1[1] == p2[1]
    end

    def build_threads(weave)
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

      [threads, location_sizes]
    end
  end
end
