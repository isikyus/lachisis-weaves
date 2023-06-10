# frozen_string_literal: true

require 'lachisis/layout'
require 'lachisis/layout/crossings'

module Lachisis
  module Layout
    # Try to lay out a weave using simulated annealing.
    # Basically doesn't work at the moment.
    # This is on ice until I get a clearer idea of how to approach it.
    class SimulatedAnnealing < AbstractLayout
      SAMPLES_PER_ITERATION = 100
      STARTING_TEMPERATURE = 200.0
      COOLING_RATE = 0.7

      def initialize
        super

        # Chosen by fair dice roll ...
        # Actually just constant for now so results are deterministic
        @random = Random.new(4)
      end

      def layout(weave)
        temperature = STARTING_TEMPERATURE
        best_locations = weave.locations
        best_characters = weave.characters
        best_score = Crossings.count(weave, best_locations, best_characters)

        log("Initial best score: #{best_score}")

        while temperature > 1
          improvement = 0

          log("Temperature #{temperature}")
          samples = Array.new(SAMPLES_PER_ITERATION) do |i|
            swaps = find_swaps(best_locations, best_characters, best_score)
                    .map { |pair| pair.map(&:to_s) }
            locs = best_score.apply_swap(best_locations, swaps[0])
            chars = best_score.apply_swap(best_characters, swaps[1])
            score = best_score.swap(*swaps)

            log("#{i} - #{score}")

            {
              locs: locs,
              chars: chars,
              score: score
            }
          end

          candidate = samples.min_by { |s| s[:score].total }
          log("- best this round: #{candidate[:score]}")

          if candidate[:score].total < best_score.total
            improvement = best_score.total - candidate[:score].total
            best_score = candidate[:score]
            best_locations = candidate[:locs]
            best_characters = candidate[:chars]
          end

          log("- improvement this round: #{improvement}" \
              "(current favoured option is #{best_score.total})\n")

          # Decreasing exponentially is good for this, right?
          temperature *= COOLING_RATE
        end

        [best_locations, best_characters]
      end

      private

      def find_swaps(locations, characters, crossings)
        [
          find_swap(locations, crossings.by_location),
          find_swap(characters, crossings.by_character)
        ]
      end

      # @param temperature [Float]
      # @param array [Array<Symbol,String>]
      # @param weighted_sets [Array<Set<Symbol>>] Sets of 2+ elements
      #       with weights indicating how good of a swap a pair from
      #       that set would be.
      #
      # @return [Array<Symbol,String>] Two elements to be swapped
      def find_swap(array, weighted_sets)
        symbolised_array = array.map(&:to_sym)
        all_pairs = symbolised_array
                    .permutation(2)
                    .map(&:to_set)
                    .to_a
        all_sets = all_pairs | weighted_sets.keys

        set = sample_by_weights(all_sets, weighted_sets)
        set.to_a.sample(2, random: @random)
      end

      # Take a weighted sample from the entries in an array.
      #
      # @param array [Array<Object>]
      # @param weights [Hash<Object,Integer>] Weights for each
      #         array element. Weights will all be incremented
      #         by 1 so we can treat elements not in the array
      #         as weight 1.
      # @return [Object] An element sampled from the array
      def sample_by_weights(array, weights)
        total_weight = array.length + weights.values.sum
        weighted_index = @random.rand(total_weight)

        weight_so_far = 0
        sample = array.detect do |elem|
          weight_so_far += 1 + (weights[elem] || 0)
          weight_so_far >= weighted_index
        end

        unless sample
          raise 'No element found for weight ' \
                "#{weighted_index} / #{total_weight}" \
                " (max weight reached was #{weight_so_far})"
        end

        sample
      end

      def log(msg)
        warn(msg)
      end
    end
  end
end
