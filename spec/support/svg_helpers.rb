# frozen_string_literal: true

module SvgHelpers

  # @return [<Range,Range>] X and Y dimensions of the given SVG path.
  #         Assumes no curves - i.e. all extreme  points are explicit path
  #         points.
  def bounding_box(symbol)
    points = symbol['d']
               .scan(/M (([\d.]+ [\d.]+\s*)+)/)
               .map do |path|
      path[0].scan(/([\d.]+) ([\d.]+)/).map { |x, y| [x, y] }
    end
               .flatten(1)
    minX, maxX = points.map(&:first).map(&:to_f).minmax
    minY, maxY = points.map(&:last).map(&:to_f).minmax

    half_stroke = symbol['stroke_width'].to_f / 2
    minX -= half_stroke
    minY -= half_stroke
    maxX += half_stroke
    maxY += half_stroke

    x_range = minX...maxX
    y_range = minY...maxY
    return x_range, y_range
  end
end
