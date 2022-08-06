require 'lachisis/event'
require 'lachisis/weave'

RSpec.describe Lachisis::Weave do
  subject(:weave) { Lachisis::Weave.new }

  let(:event) { Lachisis::Event.new('somewhere', %w[ alice bob ]) }
  let(:major_time) { 100 }
  let(:minor_time) { 10 }

  specify 'initially has no frames' do
    expect(weave.frames).to be_empty
  end

  specify 'adding an event creates a frame' do
    weave.add(major_time, minor_time, event)

    expect(weave.frames.length).to eq 1

    frame = weave.frames.first
    expect(frame.major).to eq 100
    expect(frame.minor).to eq 10
    expect(frame.events).to eq Set[event]
  end


  context 'with an event already' do
    let(:existing_event) { Lachisis::Event.new('elsewhere', %w[ iolillia sophie ]) }


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
        expect(merged_event.characters).to match_array ['sophie', 'iolillia', 'alice', 'bob']
      end
    end

    context 'at a different time' do
      before { weave.add(major_time, minor_time - 10, existing_event) }

      specify 'separates events in different frames' do
        expect do
          weave.add(major_time, minor_time, event)
        end.to change { weave.frames.length }.from(1).to(2)

        frames = weave.frames
        expect(frames.first.major).to eq major_time
        expect(frames.first.minor).to eq minor_time - 10
        expect(frames.first.events).to eq Set[existing_event]

        expect(frames.last.major).to eq major_time
        expect(frames.last.minor).to eq minor_time
        expect(frames.last.events).to eq Set[event]
      end

      specify 'keeps events in order regardless of time added' do
        weave.add(major_time - 10, minor_time + 10, event)

        expect(weave.frames.map(&:events)).to eq [Set[event], Set[existing_event]]
      end
    end
  end
end
