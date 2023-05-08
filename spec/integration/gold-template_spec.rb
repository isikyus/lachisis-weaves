require 'open3'


RSpec.describe 'read_events.rb' do
  LACHISIS_PATH = File.dirname(File.dirname(__dir__))

  def generate_with_args(*args, ruby_args: [])
    output, error, status = Open3.capture3(
      'bundle',
      'exec',
      'ruby',
      *ruby_args,
      File.join(LACHISIS_PATH, 'read_events.rb'),
      *args
    )

    # TODO: can't test this yet without a -q option or similar
    #expect(error).to be_empty
    expect(status).to eq 0

    output
  rescue RSpec::Expectations::ExpectationNotMetError => e
    raise e.exception("#{e.message}\nError output was:\n\n#{error}")
  end

  context 'with known input and output' do
    xdescribe 'so-called "annealed" layout' do
      let(:annealed_svg) do
        File.open('spec/fixtures/kathrakopolis-annealed.svg', &:read)
      end

      specify 'generates a known-good layout' do
        svg = generate_with_args(
          '-s', 'spec/fixtures/kathrakopolis.xml',
          # This layout is only used in this one test since it's not currently useful.
          ruby_args: ['-I.', '-r', 'lachisis/layout/simulated_annealing.rb']
        )
        expect(svg).to eq(annealed_svg)
      end
    end

    describe 'manual layout' do
      let(:manual_svg) do
        File.open('spec/fixtures/kathrakopolis-manual.svg', &:read)
      end

      specify 'generates a known-good layout' do
        svg = generate_with_args('-s', 'spec/fixtures/kathrakopolis.xml')
        expect(svg).to eq(manual_svg)
      end
    end
  end
end
