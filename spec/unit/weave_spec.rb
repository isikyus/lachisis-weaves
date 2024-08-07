require 'lachisis/event'
require 'lachisis/weave'

RSpec.describe Lachisis::Weave do
  subject(:weave) { Lachisis::Weave.new }

  let(:event) { Lachisis::Event.new('somewhere', { alice: :present, bob: :present }) }
  let(:major_time) { 100 }
  let(:minor_time) { 10 }

  specify 'initially has no frames' do
    expect(weave.frames).to be_empty
  end

  describe '#add' do
    specify 'adding an event creates a frame' do
      weave.add(major_time, minor_time, event)

      expect(weave.frames.length).to eq 1

      frame = weave.frames.first
      expect(frame.timestamp.major).to eq 100
      expect(frame.timestamp.minor).to eq 10
      expect(frame.events).to eq Set[event]
    end


    context 'with an event already' do
      let(:existing_event) { Lachisis::Event.new('elsewhere', { iolillia: :present, sophie: :present }) }

      context 'at the same time' do
        before { weave.add(major_time, minor_time, existing_event) }

        specify 'groups events with common time in one frame' do
          expect do
            weave.add(major_time, minor_time, event)
          end.not_to change { weave.frames.length }.from(1)

          frame = weave.frames.first
          expect(frame.events).to eq Set[event, existing_event]
        end

        specify 'merges events with the same time and location' do
          event.location = existing_event.location
          weave.add(major_time, minor_time, event)

          frame = weave.frames.first
          expect(frame.events.length).to eq 1

          merged_event = frame.events.first
          expect(merged_event.location).to eq existing_event.location
          expect(merged_event.actions).to eq(sophie: :present, iolillia: :present, alice: :present, bob: :present)
        end
      end

      context 'at a different time' do
        before { weave.add(major_time, minor_time - 10, existing_event) }

        specify 'separates events in different frames' do
          expect do
            weave.add(major_time, minor_time, event)
          end.to change { weave.frames.length }.from(1).to(2)

          frames = weave.frames
          expect(frames.first.timestamp.major).to eq major_time
          expect(frames.first.timestamp.minor).to eq minor_time - 10
          expect(frames.first.events).to eq Set[existing_event]

          expect(frames.last.timestamp.major).to eq major_time
          expect(frames.last.timestamp.minor).to eq minor_time
          expect(frames.last.events).to eq Set[event]
        end

        specify 'keeps events in order regardless of time added' do
          weave.add(major_time - 10, minor_time + 10, event)

          expect(weave.frames.map(&:events)).to eq [Set[event], Set[existing_event]]
        end
      end
    end
  end

  describe '#propagate!' do
    context 'with multiple events and time between them' do
      before do
        weave.add(10, 0, Lachisis::Event.new('home', { alice: :present, bob: :present }))
        weave.add(10, 0, Lachisis::Event.new('delphi', { sue: :present }))
        weave.add(20, 0, Lachisis::Event.new('delphi', { alice: :arrive, oracle: :present }))
        weave.add(20, 5, Lachisis::Event.new('home', { alice: :arrive, cathy: :present, sue: :arrive }))
      end

      specify 'assumes people stay in place after their last event' do
        weave.propagate!

        end_at_delphi, end_at_home, *rest = *weave.frames.last.events.sort_by(&:location)

        expect(rest).to be_empty

        expect(end_at_delphi.location).to eq 'delphi'
        expect(end_at_delphi.characters).to eq Set[:oracle]

        expect(end_at_home.location).to eq 'home'
        expect(end_at_home.characters).to eq Set[:alice, :bob, :cathy, :sue]
      end

      specify 'assumes people were there before their first "present" event' do
        weave.propagate!

        start_at_delphi, start_at_home, *rest = *weave.frames.first.events.sort_by(&:location)

        expect(rest).to be_empty

        expect(start_at_delphi.location).to eq 'delphi'
        expect(start_at_delphi.characters).to eq Set[:oracle, :sue]

        expect(start_at_home.location).to eq 'home'
        expect(start_at_home.characters).to eq Set[:alice, :bob, :cathy]
      end

      specify 'between events at different locations, assumes people travel to their next "present" location' do
        weave.frames.last.events.first.actions[:sue] = :present
        weave.propagate!

        middle_frame = weave.frames[1]
        expect(middle_frame.timestamp.major).to eq 20
        expect(middle_frame.timestamp.minor).to eq 0

        middle_at_delphi, middle_at_home, *rest = *middle_frame.events.sort_by(&:location)

        expect(rest).to be_empty

        expect(middle_at_delphi.location).to eq 'delphi'
        expect(middle_at_delphi.characters).to eq Set[:oracle, :alice]

        expect(middle_at_home.location).to eq 'home'
        expect(middle_at_home.characters).to eq Set[:bob, :cathy, :sue]
      end

      specify 'between events at different locations, assumes people do not yet travel to an "arrive" location' do
        weave.frames.last.events.first.actions[:sue] = :arrive
        weave.propagate!

        middle_frame = weave.frames[1]
        expect(middle_frame.timestamp.major).to eq 20
        expect(middle_frame.timestamp.minor).to eq 0

        middle_at_delphi, middle_at_home, *rest = *middle_frame.events.sort_by(&:location)

        expect(rest).to be_empty

        expect(middle_at_delphi.location).to eq 'delphi'
        expect(middle_at_delphi.characters).to eq Set[:oracle, :sue, :alice]

        expect(middle_at_home.location).to eq 'home'
        expect(middle_at_home.characters).to eq Set[:bob, :cathy]
      end
    end

    context 'with "arrive" events rather than "present"' do
      specify 'does not assume they were there before their first event' do
        weave.add(20, 0, Lachisis::Event.new('delphi', { alice: :arrive }))
        weave.add(20, 5, Lachisis::Event.new('home', { alice: :arrive, sue: :arrive }))

        weave.propagate!

        start_at_delphi, *rest = *weave.frames.first.events.sort_by(&:location)

        expect(rest).to be_empty

        expect(start_at_delphi.location).to eq 'delphi'
        expect(start_at_delphi.characters).to eq Set[:alice]
      end
    end

    context 'with explicit "depart" or "die" events' do
      before do
        weave.add(20, 0, Lachisis::Event.new('delphi', { pythia: :die, hercules: :depart, apollo: :present }))
        weave.add(20, 5, Lachisis::Event.new('olympus', { apollo: :arrive }))

        # Not propogating here as one test needs extra following events
      end

      specify 'does not assume characters remain at their last known location' do
        weave.propagate!

        at_olympus, *rest = *weave.frames[1].events.sort_by(&:location)

        expect(rest).to be_empty

        expect(at_olympus.location).to eq 'olympus'
        expect(at_olympus.characters).to eq Set[:apollo]
      end

      specify 'does not infer location between a departure and subsequent arrival' do
        weave.add(30, 0, Lachisis::Event.new('hades', { pythia: :arrive, hercules: :arrive, apollo: :arrive }))

        weave.propagate!

        at_olympus, *rest = *weave.frames[1].events.sort_by(&:location)

        expect(rest).to be_empty

        expect(at_olympus.location).to eq 'olympus'
        expect(at_olympus.characters).to eq Set[:apollo]
      end
    end

    context 'with someone whose last location had a higher minor timestamp' do

      context 'using :arrive' do
        before do
          weave.add(1.6, 1, Lachisis::Event.new('pans-house', { pan: :present }))
          weave.add(1.6, 2, Lachisis::Event.new('great-pillar', { pan: :present, sync: :present }))
          weave.add(1.7, 0, Lachisis::Event.new('elsewhere', { random: :depart }))
          weave.add(1.9, 0, Lachisis::Event.new('kitchen', { sync: :arrive }))

          weave.propagate!
        end

        specify 'puts them in the frame they were in most recently' do
          epilogues = weave.frames.last.events.sort_by(&:location)

          expect(epilogues.map(&:location)).to eq(%w[ great-pillar kitchen ])
          pillar, kitchen = *epilogues

          expect(pillar.characters).to eq(Set[:pan])
          expect(kitchen.characters).to eq(Set[:sync])
        end
      end

      context 'using :present' do
        before do
          weave.add(0, 0, Lachisis::Event.new('A', { alice: :enter }))
          weave.add(0, 1, Lachisis::Event.new('A', { bob: :present }))
          weave.add(0, 2, Lachisis::Event.new('B', { bob: :present }))

          weave.propagate!
        end

        specify 'puts them in the frame they were in most recently' do
          middle_events = weave.frames[1].events.sort_by(&:location)

          expect(middle_events.map(&:location)).to eq(['A'])
          at_a = middle_events.first

          expect(at_a.characters).to eq(Set[:alice, :bob])
        end
      end
    end
  end

  describe '#threads' do
    let(:together_at_home) { Lachisis::Event.new('home', { hestia: :present, mercury: :present }) }
    let(:mercury_alone) { Lachisis::Event.new('home', { mercury: :present }) }
    let(:hestia_alone) { Lachisis::Event.new('afar', { hestia: :arrive }) }

    context 'with a simple weave' do
      before do
        weave.add(1, 0, together_at_home)
        weave.add(1, 1, hestia_alone)
        weave.add(1, 2, mercury_alone)
      end

      specify 'returns characters\' individual event sequences' do
        threads = weave.threads

        expect(weave.threads[:hestia].map(&:event)).to eq [together_at_home, hestia_alone]
        expect(weave.threads[:mercury].map(&:event)).to eq [together_at_home, mercury_alone]
      end

      specify 'returns adds correct timestamps to events' do
        threads = weave.threads
        timestamps = weave.frames.map(&:timestamp)

        expect(weave.threads[:hestia].map(&:timestamp)).to eq timestamps.values_at(0, 1)
        expect(weave.threads[:mercury].map(&:timestamp)).to eq timestamps.values_at(0, 2)
      end
    end

    specify 'sorts events in each thread' do
      weave.add(+100, 0, mercury_alone)
      weave.add(-100, 0, together_at_home)

      expect(weave.threads[:mercury].map(&:event)).to eq [together_at_home, mercury_alone]
    end
  end
end
