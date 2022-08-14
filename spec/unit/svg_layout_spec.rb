require 'lachisis/event'
require 'lachisis/svg'
require 'lachisis/weave'

RSpec.describe Lachisis::SVG::Layout do
  let(:weave) { Lachisis::Weave.new }
  subject(:layout) { Lachisis::SVG::Layout.new }

  describe '#count_crossings' do
    before do
      weave.add(0, 0, Lachisis::Event.new('A', %w[ one two ]))
      weave.add(0, 0, Lachisis::Event.new('B', %w[ three ]))

      weave.add(0, 1, Lachisis::Event.new('A', %w[ one ]))
      weave.add(0, 1, Lachisis::Event.new('C', %w[ two ]))
      weave.add(0, 1, Lachisis::Event.new('B', %w[ three ]))
    end

    context 'with a layout that does not cross over' do
      let(:location_order) { %w[ A C B ] }
      let(:character_order) { %w[ one two three ] }

      specify 'counts 0 crossings' do
        expect(layout.count_crossings(weave, location_order, character_order)).to eq 0
      end
    end

    context 'with a layout that crosses over characters within a location' do
      let(:location_order) { %w[ A C B ] }
      let(:character_order) { %w[ two one three ] }

      specify 'counts 1 crossing' do
        expect(layout.count_crossings(weave, location_order, character_order)).to eq 1
      end
    end

    context 'with a layout that crosses over locations and characters' do
      let(:location_order) { %w[ A B C ] }
      let(:character_order) { %w[ two one three ] }

      specify 'counts 2 crossings' do
        expect(layout.count_crossings(weave, location_order, character_order)).to eq 2
      end
    end
  end
end
