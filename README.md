[![Maintainability](https://api.codeclimate.com/v1/badges/b0fca587162288adcf1c/maintainability)](https://codeclimate.com/github/isikyus/lachisis-weaves/maintainability)

# Lachisis Weaves

An attempt at generating [xkcd-657-style](https://xkcd.com/657/) narrative
charts from marked-up text.

## Usage

For a text summary of who was where when:

```shell
bundle exec ruby read_events.rb <filename>
```

For SVG output:

```shell
bundle exec ruby read_events.rb -s <filename>
```

`<filename>` should be a valid XML file. Lachisis (so far) ignores the XML
except for `<?lachisis ... ?>` processing instructions, and generates a
sequence of "events" (in the relativity sense: a point in space-time) for
graphing.

Valid processing instructions consist of a sequence of pairs `name:value`,
separated by whitespace. Values must not contain whitespace or
equals signs (not even in quotes).

Example valid instructions:

* `<?lachisis location:somewhere enter:someone ?>` Record an event that `someone`
  arrived at `somewhere`, using the current major timestamp (default 0.0),
  and the next minor timestamp (whatever the last event's minor timestamp
  was, plus one; starts at 0).

* `<?lachisis location:somewhere present:someone ?>` As above, except records
    that `someone` was here already at the current time (i.e. earlier than anyone
    arriving in this same event.

  * [ ] Currently equivalent to `enter:` but should really cause propogation
    to behave somewhat differently (i.e. it will affect where the character
    is shown as being before they appear in this event).

* `<?lachisis enter:another_person ?>` Record a new event at the current location
  (wherever the last event was), with all the current characters plus
  `another_person`. Again, uses the current major timestamp and next minor
  timestamp.

* `<?lachisis enter:stranger location:elsewhere time:2 ?>` Record that `stranger`
  was at `elsewhere` at time 2.0 (time values are floating-point numbers). This
  sets the "major timestamp" to 2.0, and resets the minor timestamp to 0.

  If there is another processing instruction with the same _explicit_ `location`
  and `time` values as this one, they will be combined (with that major
  timestamp and minor timestamp 0), recording that all characters in both
  instructions were together in one place at that time.

* `<?lachisis enter:statue location:gallery time:2 time:0 ?>` Records that
  `statue` was at `gallery` at both times 0 and 2 (and implicitly all times
   in beteween), and sets the major timestamp to 2 (as it's assumed the story
   continues from the last point in that range).

* `<?lachisis enter:statue enter:someone location:atrium ?>` Records that
  `statue` and `someone` were together in `atrium`, at the current
  major/next minor timestamp
