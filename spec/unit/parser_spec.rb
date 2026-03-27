# frozen_string_literal: true

require 'rspec'
require 'tempfile'

require 'lachisis/parser'
require 'lachisis/cli'

RSpec.describe Lachisis::Parser do
  context 'with valid xml input' do
    let(:weave) do
      Tempfile.create('test') do |f|
        f.write(xml)
        f.flush

        cli.weave_from_xml(f.path)
      end
    end

    context 'that has valid Lachisis PIs' do
      let(:xml) do
        <<~XML
          <?xml version="1.0" ?>
          <tag>
            <?lachisis present:juliet location:balcony ?>
            <?lachisis enter:romeo ?>
          </tag>
        XML
      end

      # TODO: code under test should probably live in Parser
      let(:cli) { Lachisis::CLI.new }

      specify 'parses it' do
        first, second, *rest = weave.frames
        expect(rest).to be_empty

        expect(first.timestamp).to eq Lachisis::TimedEvent::Timestamp.new(0, 1)
        e1, *e1_rest = first.events.to_a
        expect(e1_rest).to be_empty

        expect(e1.location).to eq 'balcony'
        expect(e1.actions).to eq(juliet: :present)

        expect(second.timestamp).to eq Lachisis::TimedEvent::Timestamp.new(0, 2)
        e2, *e2_rest = second.events.to_a
        expect(e2_rest).to be_empty

        expect(e2.location).to eq 'balcony'
        expect(e2.actions).to eq(juliet: :present,
                                 romeo: :enter)
      end
    end

    context 'that starts without a location' do
      let(:xml) do
        <<~XML
          <?xml version="1.0" ?>
          <tag>
            <?lachisis present:juliet ?>
            <?lachisis enter:romeo ?>
          </tag>
        XML
      end

      # TODO: code under test should probably live in Parser
      let(:cli) { Lachisis::CLI.new }

      specify 'fails fast' do
        expect do
          weave
        end.to raise_error(/Need location/)
      end
    end
  end
end
