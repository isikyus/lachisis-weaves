# Lachisis Weaves

An attempt at generating [xkcd-657-style](https://xkcd.com/657/) narrative
charts from marked-up text.

## Usage

```shell
bundle exec ruby read_events.rb <filename>
```

Where `<filename>` is a valid XML file. Lachisis (so far) ignores the XML and
reads its specific `<?lachisis ?>` processing instructions, and generates a
sequence of "events" (in the relativity sense: a point in space-time) for
graphing.

Valid processing instructions consist of a sequence of pairs `name=value`,
separated by whitespace. Values must not contain whitespace or
equals signs (not even in quotes).

Names must be `char`, `location`, or `time`, like so:

* `<?lachisis location=somewhere char=someone ?>` Record an event that `someone`
  was at `somewhere`, using the current major timestamp (default 0.0),
  and the next minor timestamp (whatever the last event's minor timestamp
  was, plus one; starts at 0).

* `<?lachisis char=another_person ?>` Record a new event at the current location
  (wherever the last event was), with all the current characters plus
  `another_person`. Again, uses the current major timestamp and next minor
  timestamp.

* `<?lachisis char=stranger location=elsewhere time=2 ?>` Record that `stranger`
  was at `elsewhere` at time 2.0 (time values are floating-point numbers). This
  sets the "major timestamp" to 2.0, and resets the minor timestamp to 0.

  If there is another processing instruction with the same _explicit_ `location`
  and `time` values as this one, they will be combined (with that major
  timestamp and minor timestamp 0), recording that all characters in both
  instructions were together in one place at that time.

* `<?lachisis char=statue location=gallery time=2 time=0 ?>` Records that
  `statue` was at `gallery` at both times 0 and 2 (and implicitly all times
   in beteween), and sets the major timestamp to 2 (as it's assumed the story
   continues from the last point in that range).

* `<?lachisis char=statue char=someone location=atrium ?>` Records that
  `statue` and `someone` were together in `atrium`, at the current
  major/next minor timestamp
