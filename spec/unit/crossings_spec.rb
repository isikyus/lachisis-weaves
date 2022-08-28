require 'lachisis/event'
require 'lachisis/svg'
require 'lachisis/weave'

RSpec.describe Lachisis::SVG::Crossings do
  let(:weave) { Lachisis::Weave.new }
  subject(:crossings) { Lachisis::SVG::Crossings.count(weave, location_order, character_order) }

  before do
    weave.add(0, 0, Lachisis::Event.new('A', %w[ one two ]))
    weave.add(0, 0, Lachisis::Event.new('B', %w[ three ]))
    weave.add(0, 0, Lachisis::Event.new('D', %w[ four ]))

    weave.add(0, 1, Lachisis::Event.new('A', %w[ one ]))
    weave.add(0, 1, Lachisis::Event.new('C', %w[ two ]))
    weave.add(0, 1, Lachisis::Event.new('B', %w[ three ]))
    weave.add(0, 1, Lachisis::Event.new('D', %w[ four ]))
  end

  describe '#count' do
    context 'with a layout that does not cross over' do
      let(:location_order) { %w[ A C B D ] }
      let(:character_order) { %w[ one two three four] }

      specify 'counts 0 crossings' do
        expect(crossings.total).to eq 0
      end

      specify 'reports none per character' do
        expect(crossings.by_character).to eq({})
      end

      specify 'reports none per location' do
        expect(crossings.by_location).to eq({})
      end
    end

    context 'with a layout that crosses over characters within a location' do
      let(:location_order) { %w[ A C B D ] }
      let(:character_order) { %w[ two one three four ] }

      specify 'counts 1 crossing' do
        expect(crossings.total).to eq 1
      end

      specify 'reports which characters are involved' do
        expect(crossings.by_character).to eq(Set[:one, :two] => 2)
      end

      specify 'reports which locations are involved' do
        expect(crossings.by_location).to eq(Set[:A, :C] => 2)
      end
    end

    context 'with a layout that crosses over locations and characters' do
      let(:location_order) { %w[ A B C D ] }
      let(:character_order) { %w[ two one three four ] }

      specify 'counts 2 crossings' do
        expect(crossings.total).to eq 2
      end

      specify 'reports which characters are involved' do
        expect(crossings.by_character).to eq(
          Set[:one, :two] => 2,
          Set[:two, :three] => 2
        )
      end

      specify 'reports which locations are involved' do
        expect(crossings.by_location).to eq(
          Set[:A, :C] => 2,
          Set[:A, :B, :C] => 2
        )
      end
    end
  end

  describe '#swap' do
    let(:location_order) { %w[ A B C D ] }
    let(:character_order) { %w[ two one three four ] }

    context 'swapping characters' do
      let(:after_swap) { crossings.swap(nil, %w[ two one ]) }

      specify 'updates crossing counts' do
        expect(after_swap.total).to eq 1
      end

      specify 'updates which characters are involved' do
        expect(after_swap.by_character).to eq(
          Set[:two, :three] => 2
        )
      end

      specify 'updates which locations are involved' do
        expect(after_swap.by_location).to eq(
          Set[:A, :B, :C] => 2
        )
      end
    end

    context 'swapping locations' do
      let(:after_swap) { crossings.swap(%w[ A B ], nil) }

      specify 'updates crossing counts' do
        expect(after_swap.total).to eq 1
      end

      specify 'updates which characters are involved' do
        expect(after_swap.by_character).to eq(
          Set[:one, :two] => 2
        )
      end

      specify 'updates which locations are involved' do
        expect(after_swap.by_location).to eq(
          Set[:A, :C] => 2
        )
      end
    end

    context 'swapping both and creating new crossings' do
      let(:after_swap) { crossings.swap(%w[ D C ], %w[ two one ]) }

      specify 'updates crossing counts' do
        expect(after_swap.total).to eq 2
      end

      specify 'updates which characters are involved' do
        expect(after_swap.by_character).to eq(
          Set[:two, :three] => 2,
          Set[:two, :four] => 2
        )
      end

      specify 'updates which locations are involved' do
        expect(after_swap.by_location).to eq(
          Set[:A, :B, :C] => 2,
          Set[:A, :C, :D] => 2
        )
      end
    end
  end
end
