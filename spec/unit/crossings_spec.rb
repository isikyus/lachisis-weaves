require 'lachisis/event'
require 'lachisis/layout'
require 'lachisis/weave'

RSpec.describe Lachisis::Layout::Crossings do
  let(:weave) { Lachisis::Weave.new }
  subject(:crossings) { Lachisis::Layout::Crossings.count(weave, location_order, character_order) }

  before do
    # Initial layout (assuming lexicographic ordering)
    #
    # A 1 --------- 1 A
    #   2 --\
    #        \
    # B 3 ----\---- 3 B
    #          \
    # C         \-- 2 C
    #
    # D 4 --------- 4 D
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
    # Initial layout (with this order)
    #
    # A 2 -\          A
    #   1 --\------ 1
    #        \
    # B 3 ----\---- 3 B
    #          \
    # C         \-- 2 C
    #
    # D 4 --------- 4 D
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
      # Layout after swap
      #
      # A 1 --------- 1 A
      #   2 ----\
      #         |
      # B 3 ----|---- 3 B
      #         |
      # D 4 ----|---- 4 D
      #         |
      # C       \---- 2 C
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

    context 'swapping locations over a longer distance' do
      # Post-swap layout
      #
      # A 2 -\          A
      #   1 --\------ 1
      #        \
      # D 4 ----\---- 4 D
      #          \
      # C         \-- 2 C
      #
      # B 3 --------- 3 B
      let(:after_swap) { crossings.swap(%w[ D B ], nil) }

      specify 'updates crossing counts' do
        expect(after_swap.total).to eq 2
      end

      specify 'updates which characters are involved' do
        expect(after_swap.by_character).to eq(
          Set[:two, :one] => 2,
          Set[:two, :four] => 2
        )
      end

      specify 'updates which locations are involved' do
        expect(after_swap.by_location).to eq(
          Set[:A, :C] => 2,
          Set[:A, :C, :D] => 2
        )
      end
    end

    context 'swapping characters over longer distance' do
      before do
        # Layout with extra characters (relying on the weave
        # to merge them)
        #
        # A 2 -\            A
        #   1 --\-------- 1
        #   5 ---\--\
        #         \  \
        # B 3 -----\--\-- 3 B
        #           \  \- 5
        #            \
        # C           \-- 2 C
        #
        # D 4 ----------- 4 D
        weave.add(0, 0, Lachisis::Event.new('A', %w[ five ]))
        weave.add(0, 1, Lachisis::Event.new('B', %w[ five ]))
      end
      let(:location_order) { %w[ A B C D ] }
      let(:character_order) { %w[ two one three four five ] }

      # Layout after swap
      #
      # A 5 ----\         A
      #   1 -----\---- 1
      #   2 ---\  \
      #         \  \
      # B        \  \-- 5 B
      #   3 ------\---- 3
      #            \
      # C           \-- 2 C
      #
      # D 4 ----------- 4 D
      let(:after_swap) { crossings.swap(nil, %w[ two five ]) }

      specify 'updates crossing counts' do
        expect(after_swap.total).to eq 2
      end

      specify 'updates which characters are involved' do
        expect(after_swap.by_character).to eq(
          Set[:five, :one] => 2,
          Set[:two, :three] => 2
        )
      end

      specify 'updates which locations are involved' do
        expect(after_swap.by_location).to eq(
          Set[:A, :B] => 2,
          Set[:A, :B, :C] => 2
        )
      end
    end
    
    pending 'need to test more cases to get full test coverage'
  end
end
