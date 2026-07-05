# frozen_string_literal: true

require_relative '../../support/svg_helpers'
require 'lachisis/svg'

require 'nokogiri'

RSpec.describe Lachisis::SVG::Symbols do
  include SvgHelpers
  subject(:symbols) { described_class.new }

  let(:symbol_xml) do
    Nokogiri::XML.parse(symbol)
  end

  let(:symbol_tag) do
    symbol_xml.css('*').first
  end

  let(:character) { 'nobody' }
  let(:x) { 0 }
  let(:y) { 0 }

  describe '#death' do
    let(:symbol) { symbols.death(x, y, character) }

    specify 'draws a symbol that fits within its metrics' do
      bounds_x, _bounds_y = bounding_box(symbol_tag)
      expect(bounds_x.max - bounds_x.min)
        .to be <= symbols.spacing(:death)
    end

    specify 'centers symbol on given point' do
      bounds_x, bounds_y = bounding_box(symbol_tag)

      centre_x = bounds_x.minmax.sum / 2
      centre_y = bounds_y.minmax.sum / 2

      delta = (bounds_x.max - bounds_x.min) / 10
      expect(centre_x).to be_within(delta).of(x)
      expect(centre_y).to be_within(delta).of(y)
    end

    specify 'draws symbol with aspect ratio close to 1:1' do
      bounds_x, bounds_y = bounding_box(symbol_tag)

      range_x = bounds_x.max - bounds_x.min
      range_y = bounds_y.max - bounds_y.min
      delta = range_x / 10
      expect(range_x).to be_within(delta).of(range_y)
    end
  end

  describe '#disappear' do
    let(:symbol) { symbols.disappear(x, y, character) }

    specify 'draws a symbol that fits within its metrics' do
      bounds_x, _bounds_y = bounding_box(symbol_tag)
      expect(bounds_x.max - bounds_x.min)
        .to be <= symbols.spacing(:disappear)
    end

    specify 'starts symbol at given point' do
      bounds_x, bounds_y = bounding_box(symbol_tag)

      start_x = bounds_x.min
      centre_y = bounds_y.minmax.sum / 2

      delta = Lachisis::SVG::Constants::THREAD_WIDTH
      expect(start_x).to be_within(delta).of(x)
      expect(centre_y).to be_within(delta).of(y)
    end
  end

  describe '#arrive' do
    let(:symbol) { symbols.arrive(x, y, character) }

    specify 'draws a symbol that fits within its metrics' do
      bounds_x, _bounds_y = bounding_box(symbol_tag)
      expect(bounds_x.max - bounds_x.min)
        .to be <= symbols.spacing(:arrive)
    end

    specify 'ends symbol at given point' do
      bounds_x, bounds_y = bounding_box(symbol_tag)

      end_x = bounds_x.max
      centre_y = bounds_y.minmax.sum / 2

      delta = Lachisis::SVG::Constants::THREAD_WIDTH
      expect(end_x).to be_within(delta).of(x)
      expect(centre_y).to be_within(delta).of(y)
    end
  end
end
