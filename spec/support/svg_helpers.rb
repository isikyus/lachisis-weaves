# frozen_string_literal: true

module SvgHelpers
  NUM = /-?[[:digit:]]+(?:\.[[:digit:]]+)?/

  # @return [<Range,Range>] X and Y dimensions of the given SVG path.
  #         Assumes no curves - i.e. all extreme  points are explicit path
  #         points.
  def bounding_box(symbol)
    points = symbol['d'].tap { pp _1 }
             .scan(/M ((#{NUM} #{NUM}\s*)+)/)
             .map do |path|
               path[0].scan(/(#{NUM}) (#{NUM})/).map { |x, y| [x, y] }
             end
             .flatten(1)

    min_x, max_x = points.map(&:first).map(&:to_f).minmax
    min_y, max_y = points.map(&:last).map(&:to_f).minmax

    half_stroke = symbol['stroke_width'].to_f / 2
    min_x -= half_stroke
    min_y -= half_stroke
    max_x += half_stroke
    max_y += half_stroke

    x_range = min_x..max_x
    y_range = min_y..max_y

    [x_range, y_range]
  end
end
