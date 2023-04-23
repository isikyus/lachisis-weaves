require_relative 'layout'

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
      # TODO: turned off for now as crossing calculation makes assumptions about propogation that don't hold.
      #$stderr.puts "Crossing number: #{Layout::Crossings.count(weave, location_order, characters).total}"
      $stderr.puts "Location order: #{location_order.inspect}"

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
      location_sizes.sort_by { |l, _sz| location_order.index(l) }.each do |location, char_count|
        start_y = last_location_end + edge_offset
        last_location_end = start_y + char_count * THREAD_SPACING

        location_spacing[location] = start_y
      end

      $stderr.puts(location_spacing.map { |location, space| "%5d (%2d) %s" % [space, location_order.index(location) || -1, location.inspect] })

      max_y = last_location_end + edge_offset
      xml_data = [
        '<?xml version="1.0"?>',
        "<svg width='#{max_x}' height='#{max_y}' xmlns='http://www.w3.org/2000/svg'>"
      ]

      # Draw location labels
      location_spacing.each do |loc, y_position|
        _frame, first_frame_index = weave
          .frames
          .each_with_index
          .detect { |f, _i| f.events.map(&:location).include?(loc) }

        label_y = y_position + (location_sizes[loc] * THREAD_SPACING / 2.0)
        label_x = max_name_size + (first_frame_index * EVENT_SPACE)
        xml_data << %{<text x="#{label_x - LABEL_OFFSET}" y="#{label_y}" text-anchor="end" dominant-baseline="middle" font-size="#{FONT_SIZE * 2}" opacity="0.5">#{loc}</text> }
      end

      # Draw character threads
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
          [
            [x, y],
            [x + BASE_DURATION, y]
          ]
        end

        # Simplify path to make relabelling easier
        before = path_points.length
        relevant_points = path_points.each_cons(3).map do |p0, p1, p2|
          # TODO: this would be more correct if I could avoid the singularity for slope=0, but may mess up character locations if they have too much vertical movement
          #dx0 = p0[0] - p1[0]
          #dy0 = p0[1] - p1[1]
          #slope0 = dy0/dx0.to_f

          #dx1 = p1[0] - p2[0]
          #dy1 = p1[1] - p2[1]
          #slope1 = dy1/dx1.to_f

          #ratio = slope0 / slope1

          #$stderr.puts([p0, p1, p2, dx0, dy0, slope0, dx1, dy1, slope1, ratio].inspect)

          #if 0.9 < ratio && ratio < 1.1 # points are roughly collinear
          #  nil
          #else
          #  p1
          #end

          # Only consider collinear if the line is horizontal (all same y)
          if p0[1] == p1[1] && p1[1] == p2[1]
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
        $stderr.puts "Before simplify: #{before}; after : #{path_points.length}; change: #{before - path_points.length}"

        #relabel_offset = (relabel_offset * PHI) % RELABEL_INTERVAL
        #distance_until_relabel = RELABEL_INTERVAL - relabel_offset
        #last_point = nil

        xml_data << %{<path id="thread_#{character}" fill="none" stroke="black" stroke_width="3" d="M #{path_points.flatten.join(' ')}"/>}

        start_x, start_y, *, end_x, end_y = *path_points.flatten
        xml_data << %{<text x="#{start_x - LABEL_OFFSET}" y="#{start_y}" text-anchor="end" dominant-baseline="middle" font-size="#{FONT_SIZE}">#{character}</text>}
        xml_data << %{<text x="#{end_x + LABEL_OFFSET}" y="#{end_y}" text-anchor="start" dominant-baseline="middle" font-size="#{FONT_SIZE}">#{character}</text>}
      end

      xml_data << '</svg>'

      xml_data.join("\n")
    end
  end
end
