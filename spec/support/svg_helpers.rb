# frozen_string_literal: true

module SvgHelpers
  NUM = /-?[[:digit:]]+(?:\.[[:digit:]]+)?/

  # @return [<Range,Range>] X and Y dimensions of the given SVG path.
  #         Assumes no curves - i.e. all extreme  points are explicit path
  #         points.
  def bounding_box(symbol)
    points = symbol['d']
             .scan(/M ((#{NUM} #{NUM}\s*)+)/)
             .map do |path|
               path[0].scan(/(#{NUM}) (#{NUM})/).map { |x, y| [x, y] }
             end
             .flatten(1)

    min_x, max_x = points.map(&:first).map(&:to_f).minmax
    x_range = min_x..max_x

    min_y, max_y = points.map(&:last).map(&:to_f).minmax
    y_range = min_y..max_y

    stroke = symbol['stroke_width'].to_f

    [
      expand_by(x_range, stroke),
      expand_by(y_range, stroke)
    ]
  end

  private

  def range_of(array)
    array
  end

  def expand_by(range, padding)
    half_pad = padding / 2
    (range.min - half_pad)..(range.max + half_pad)
  end
end
