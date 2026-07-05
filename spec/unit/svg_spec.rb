# frozen_string_literal: true

require_relative '../support/svg_helpers'

require 'lachisis/event'
require 'lachisis/weave'
require 'lachisis/svg'

require 'nokogiri'

RSpec.describe Lachisis::SVG do
  include SvgHelpers

  subject(:svg) { described_class.new(layout) }

  let(:layout) do
    spy(:layout)
  end

  let(:svg_xml) do
    Nokogiri::XML.parse(svg.call(weave))
  end

  let(:num) { SvgHelpers::NUM }

  describe '#call' do
    context 'with a basic weave without crossings' do
      let(:weave) do
        weave = Lachisis::Weave.new
        weave.add(100, 10, Lachisis::Event.new('somewhere', alice: :enter))
        weave.add(100, 20, Lachisis::Event.new('somewhere', alice: :present))
        weave
      end

      before do
        allow(layout).to receive(:layout)
          .and_return([['somewhere'], [:alice]])
      end

      # TODO: decorate RSpec failures to do this?
      specify 'exports SVG to a text file for comparison' do
        File.open(
          File.join(
            File.dirname(File.dirname(__FILE__)),
            'output',
            'basic.svg'
          ),
          'w'
        ) do |f|
          f.puts svg_xml
        end
      end

      specify 'generates a horizontal line' do
        thread = svg_xml.css('#thread_alice_0')
        expect(thread.length).to eq 1

        coords = thread[0]['d'].match(/M (#{num}) (#{num}) (#{num}) (#{num})/)
        expect(coords).not_to be_nil

        _, x1, y1, x2, y2 = *coords.to_a.map(&:to_f)

        # Horizontal distance between frames
        expect(x2 - x1).to be > 10

        # Line is horizontal (no vertical component)
        expect(y1).to eq y2
      end

      specify 'labels it with the character name' do
        thread = svg_xml.css('#thread_alice_0')
        coords = thread[0]['d'].match(/M (#{num}) (#{num}) (#{num}) (#{num})/)
        x1, y1, x2, y2 = *coords[1..].map(&:to_f)

        labels = svg_xml.xpath("//xmlns:text[text()='alice']")
        expect(labels.length).to eq 2

        left_label = svg_xml.xpath(
          "//xmlns:text[text()='alice'][@text-anchor='end']"
        )
        expect(left_label.length).to eq 1

        right_label = svg_xml.xpath(
          "//xmlns:text[text()='alice'][@text-anchor='start']"
        )
        expect(right_label.length).to eq 1

        expect(left_label[0]['x'].to_f).to be < x1
        expect(left_label[0]['y'].to_f).to eq y1

        expect(right_label[0]['x'].to_f).to be > x2
        expect(right_label[0]['y'].to_f).to eq y2
      end

      specify 'labels the location' do
        thread = svg_xml.css('#thread_alice_0')
        coords = thread[0]['d'].match(
          /M ([[:digit:].]+) ([[:digit:].]+) ([[:digit:].]+) ([[:digit:].]+)/
        )
        x1, y1, _x2, _y2 = *coords[1..].map(&:to_f)

        location_label = svg_xml.xpath('//xmlns:text[text()="somewhere"]')
        expect(location_label.length).to eq 1

        expect(location_label[0]['x'].to_f).to be < x1
        expect(location_label[0]['y'].to_f).to be > y1
      end
    end

    context 'with a horizontal line long enough for relabelling' do
      let(:weave) do
        weave = Lachisis::Weave.new

        weave.add(100, 1, Lachisis::Event.new('somewhere', alice: :enter))
        (2..20).each do |i|
          weave.add(100, i, Lachisis::Event.new('somewhere', alice: :present))
        end
        weave
      end

      before do
        allow(layout).to receive(:layout)
          .and_return([['somewhere'], [:alice]])
      end

      specify 'adds an extra character label' do
        first_thread = svg_xml.css('#thread_alice_0')
        first_coords = first_thread[0]['d'].match(
          /M ([[:digit:].]+) ([[:digit:].]+) ([[:digit:].]+) ([[:digit:].]+)/
        )
        _, x1, y1, x2, y2 = *first_coords.to_a.map(&:to_f)

        labels = svg_xml.xpath("//xmlns:text[text()='alice']")
                        .sort_by { |l| l['x'].to_f }
        expect(labels.length).to eq 3

        expect(labels.map { |l| l['text-anchor'] })
          .to eq %w[end middle start]
        expect(labels.map { |l| l['y'].to_f }).to eq [y1, y1, y1]
      end

      specify 'lines up both halves of the line' do
        first_thread = svg_xml.css('#thread_alice_0')
        first_coords = first_thread[0]['d'].match(
          /M ([[:digit:].]+) ([[:digit:].]+) ([[:digit:].]+) ([[:digit:].]+)/
        )
        _, x1a, y1a, x2a, y2a = *first_coords.to_a.map(&:to_f)

        second_thread = svg_xml.css('#thread_alice_1')
        expect(second_thread).not_to be_empty
        second_coords = second_thread[0]['d'].match(
          /M ([[:digit:].]+) ([[:digit:].]+) ([[:digit:].]+) ([[:digit:].]+)/
        )
        _, x1b, y1b, x2b, y2b = *second_coords.to_a.map(&:to_f)

        expect(x1a).to be < x2a
        expect(x2a).to be < x1b
        expect(x1b).to be < x2b

        expect([y1b, y2b]).to eq [y1a, y2a]
      end
    end

    context 'with two characters that cross' do
      let(:weave) do
        weave = Lachisis::Weave.new
        weave.add(100, 10, Lachisis::Event.new('somewhere', alice: :enter))
        weave.add(100, 20, Lachisis::Event.new('nowhere', alice: :present))

        weave.add(100, 10, Lachisis::Event.new('nowhere', bob: :enter))
        weave.add(100, 20, Lachisis::Event.new('somewhere', bob: :present))
        weave
      end

      before do
        allow(layout).to receive(:layout)
          .and_return([%w[somewhere nowhere],
                       %i[alice bob]])
      end

      specify 'crosses their lines over' do
        thread_a = svg_xml.css('#thread_alice_0')
        expect(thread_a.length).to eq 1

        coords_a = thread_a[0]['d'].match(
          /M (#{num}) (#{num}) .* (#{num}) (#{num})/
        )
        expect(coords_a).not_to be_nil

        thread_b = svg_xml.css('#thread_bob_0')
        expect(thread_b.length).to eq 1

        coords_b = thread_b[0]['d'].match(
          /M (#{num}) (#{num}) .* (#{num}) (#{num})/
        )
        expect(coords_b).not_to be_nil

        _, x1a, y1a, x2a, y2a = *coords_a.to_a.map(&:to_f)
        _, x1b, y1b, x2b, y2b = *coords_b.to_a.map(&:to_f)

        # Starting and ending columns are the same for both lines
        expect(x1a).to eq x1b
        expect(x2a).to eq x2b

        # Threads swap horizontal position
        expect(y1a).to eq y2b
        expect(y1b).to eq y2a
      end
    end

    context 'with a character who disappears and then reappears' do
      let(:weave) do
        weave = Lachisis::Weave.new
        weave.add(100, 10, Lachisis::Event.new('somewhere', prodigal: :present))
        weave.add(100, 20, Lachisis::Event.new('somewhere', prodigal: :exit))
        weave.add(100, 30, Lachisis::Event.new('somewhere', faithful: :present))
        weave.add(100, 40, Lachisis::Event.new('somewhere', prodigal: :enter))
        weave
      end

      before do
        allow(layout).to receive(:layout)
          .and_return([['somewhere'], %i[faithful prodigal]])
      end

      specify 'exports SVG to a text file for comparison' do
        File.open(
          File.join(
            File.dirname(File.dirname(__FILE__)),
            'output',
            'prodigal.svg'
          ),
          'w'
        ) do |f|
          f.puts svg_xml
        end
      end

      specify 'does not overlap characters and symbols' do
        thread1 = svg_xml.css('#thread_faithful_0')
        expect(thread1.length).to eq 1
        coords1 = thread1[0]['d']
                  .match(/M (#{num}) (#{num}) (#{num}) (#{num})/)[1..]
                  .map(&:to_f)
        expect(coords1).not_to be_nil

        # TODO: really should test for all possible overlaps - maybe in a bigger
        #   test though?
        # thread2 = svg_xml.css('#thread_prodigal_0')
        # expect(thread2.length).to eq 1
        # coords2 =
        #   thread2[0]['d'].match(/(#{num}) (#{num}) M (#{num}) (#{num})/)[1..]
        #   .map(&:to_f)
        # expect(coords2).not_to be_nil

        svg_xml.css('.symbol_prodigal').each do |symbol|
          x_range, y_range = bounding_box(symbol)

          # TODO: probably need a custom matcher, SVG lib, or similar
          id = symbol['id']
          coords1.each_slice(2) do |p|
            expect(p).to satisfy("not to overlap with #{id}, #{x_range.inspect}, #{y_range.inspect} (for #{thread1[0]['id']})") do |p|
              !x_range.include?(p.first) || !y_range.include?(p.last)
            end
          end
        end
      end

      specify 'generates a solid line for a consistently-present character' do
        thread = svg_xml.css('#thread_faithful_0')
        expect(thread.length).to eq 1

        coords = thread[0]['d'].match(/M (#{num}) (#{num}) (#{num}) (#{num})/)
        expect(coords).not_to be_nil

        _, x1, y1, x2, y2 = *coords.to_a.map(&:to_f)

        # Horizontal distance between frames
        expect(x2 - x1).to be >= 10

        # Line is horizontal (no vertical component)
        expect([y1, y2].uniq).to eq [y1]
      end

      specify 'generates two separate lines for a wandering character' do
        thread = svg_xml.css('#thread_prodigal_0')
        expect(thread.length).to eq 1

        # TODO: probably want a helper for this?
        coords = thread[0]['d']
                 .scan(/M ((#{num} #{num}\s*)+)/)
                 .map { |path| path[0].scan(num).map(&:to_f) }
        expect(coords.length).to eq 2
        expect(coords[0]).not_to be_nil
        expect(coords[1]).not_to be_nil

        x1, y1, x2, y2 = *coords[0].to_a.map(&:to_f)
        x3, y3, x4, y4 = *coords[1].to_a.map(&:to_f)

        # Horizontal distance between frames
        expect(x2 - x1).to be >= 10
        expect(x3 - x2).to be >= 10
        expect(x4 - x3).to be >= 10

        # Line is horizontal (no vertical component)
        expect([y1, y2, y3, y4].uniq).to eq [y1]
      end
    end
  end
end
