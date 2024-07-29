# frozen_string_literal: true

require 'lachisis/event'
require 'lachisis/weave'
require 'lachisis/svg'

require 'nokogiri'

# TODO: move to spec helper
require 'byebug'

RSpec.describe Lachisis::SVG do
  subject(:svg) { Lachisis::SVG.new(layout) }

  let(:layout) do
    spy(:layout)
  end

  let(:svg_xml) do
    Nokogiri::XML.parse(svg.call(weave))
  end

  describe '#call' do
    context 'with a basic weave without crossings' do
      let(:weave) do
        weave = Lachisis::Weave.new
        weave.add(100, 10, Lachisis::Event.new('somewhere', alice: :present))
        weave.add(100, 20, Lachisis::Event.new('somewhere', alice: :present))
        weave
      end

      before do
        allow(layout).to receive(:layout)
          .and_return([['somewhere'], [:alice]])
      end

      specify 'generates a horizontal line' do
        thread = svg_xml.css('#thread_alice_0')
        expect(thread.length).to eq 1

        coords = thread[0]['d'].match(/M (\d+) (\d+) (\d+) (\d+)/)
        expect(coords).not_to be_nil

        _, x1, y1, x2, y2 = *coords.to_a.map(&:to_i)

        # Horizontal distance between frames
        expect(x2 - x1).to be > 10

        # Line is horizontal (no vertical component)
        expect(y1).to eq y2
      end

      specify 'labels it with the character name' do
        thread = svg_xml.css('#thread_alice_0')
        coords = thread[0]['d'].match(/M (\d+) (\d+) (\d+) (\d+)/)
        _, x1, y1, x2, y2 = *coords

        labels = svg_xml.xpath("//xmlns:text[text()='alice']")
        expect(labels.length).to eq 2

        left_label = svg_xml.xpath("//xmlns:text[text()='alice'][@text-anchor='end']")
        expect(left_label.length).to eq 1

        right_label = svg_xml.xpath("//xmlns:text[text()='alice'][@text-anchor='start']")
        expect(right_label.length).to eq 1

        expect(left_label[0]['x']).to be < x1
        expect(left_label[0]['y']).to eq y1

        expect(right_label[0]['x']).to be > x2
        expect(right_label[0]['y']).to eq y2
      end

      specify 'labels the location' do
        thread = svg_xml.css('#thread_alice_0')
        coords = thread[0]['d'].match(/M (\d+) (\d+) (\d+) (\d+)/)
        _, x1, y1, _x2, _y2 = *coords

        location_label = svg_xml.xpath('//xmlns:text[text()="somewhere"]')
        expect(location_label.length).to eq 1

        expect(location_label[0]['x']).to be < x1
        expect(location_label[0]['y']).to be > y1
      end
    end
  end
end
