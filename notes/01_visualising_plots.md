# Lachisis: Visualising plots

The narrative charts from [xkcd 657](https://xkcd.com/657/) have impressed me for a while.
They seem like a really good way to summarise complex plots.

But they are a lot of work to draw, so the other week I had a go at making a program to do them.
I put together a script called [Lachisis Weaves](https://github.com/isikyus/lachisis-weaves), ran it on my [first Defenders of Kathrakopolis post](https://www.isikyus.com/wordpress/2018/07/session-1-rocks-fall-defenders-of-kathrakopolis/).
So far, it looks pretty good:

[### TODO first image]

My next test was the first 101 comics of [DMFA](http://missmab.com/index.php).
That data entry took a while, to start with — automating that would be nice, but recognising who is where, and _when_, in a comic is a whole separate project.
Also it feels a bit Electronic Monk-ish to build a bot to read tedious comments for me.
So I read it myself, and logged the characters in each page by hand, then had my script draw out all the connecting lines.

The resulting diagram is of course a spoiler for DMFA comics 1 to 101, so it's below the fold.

<!-- more -->

images/dmfa_fa70ca9b72561ae66ae396f38be88648cdc9aae9.svg

That's a mess. For starters, it's way too big to take in.
I may have entered the data in a _touch_ more detail than necessary, but that's only part of the problem.
Each physical location in the story should be a horizontal band in the diagram, but characters jump back and forth between bands with no rhyme or reason.
Halfway down (highlighted in fuchsia) are a band of characters who only appear in the "Amber's Studio" asides, not even in the same universe as the rest of the comic — but the layout here puts them somewhere in the middle of Twink Territories!

Surely I can do better than this.
But how, exactly?

The first thimg I tried was sorting by the name of the location.
Combined with some a folder-like naming convention, to put `lost-lake/basement` and `lost-lake/bar` next to each other, but far away from `beach/seafood-restaurant`, this actually works pretty well.
The early Lost Lake scenes (center left), beach arc (top middle) and Twink Territories (bottom right) now stand out as separate scenes.

But it's still not ideal.
There are a lot of extra crossing lines, and Amber and co are still neighbours of the Amazon tribe and Gavy the surfing instructor. (Mab and Pip being near them actually isn't a mistake, though fully justifying it would spoil things past the 101st comic).
I could fix this with careful naming, and some hacks like sticking numbers on the front to control sorting, but there should be a better way.
I'd like to try and find it.

I may not succeed.
What I'd like to do here is sort the locations in the story so the lines can cross as little as possible.
I'm not sure exactly how hard it is, but it sounds suspiciously similar to the Travelling Salesman Problem and an equivalent one called Crossing Numbers, which are both famously NP-hard.
(This, by the way, is why the auto-layout feature of every diagramming program is so terrible.)
But I have a few tricks up my sleeve.

The first is simplificiation.
A lot of those lines are bit characters who only appear in a few comics.
Some of these one-offs get more important later on (more spoilers!), so I can't just cut them all out, but I could break the lines like xkcd does with the Eagles in the Lord of the Rings chart.
That chart also has a few other handy ideas, like actually _labelling_ things.
I'll keep this one in my back pocket for now, as it's a bit cheat-ish and I'd like to see how far I can get without it first.

The second trick is approximation.
Solving NP-complete problems like crossing numbers perfectly is hard, but I don't need perfect.
I can probably improve things at least a bit by making the code make some smart guesses, like putting Amber and co somewhere outside the main locations.
To the editor!

...

OK, after a bit of fiddling around and procrastination, I have the ability to swap in different sorting rules.
The picture looks just about the same :-(

I need a better sorting rule to actually try..
I _could_ try to do something top-down and logical like detecting and moving out un-connected sets of charactes.
But since I suspect this is an NP-complete problem that path seems like it'll end with me bashing my head against the tombstones of greater minds.

So insted I'd like to try a bottom-up approximate algorithm.
Specifically (what I think) Simulated Annealing.
Basically, a more sophisiticated [TODO link]bogosort: throw everything up in the air, and hope it comes down in a better order.
Do this a few times.
Pick the best result.
Then repeat the process, but don't throw it up as far.

First step: measure what is a better or worse order.

---------------------------

OK, I've done that.
Measurement is pretty easy - go through the diagram and count the number of lines that cross.
The fewer, the better.

<aside>
  So how do you actually count crossing lines?
  It's obvious to a human, but I can't just tell the program to look at the diagram.
  
  What I can do, though, is look at pairs of "frames" (vertical events that happen at the same time), and the characters in each one.
  From the perspective of one character, say Mab, I can find all the characters who are above and below me in the first frame (this is easy with a sorted list).
  Do the same for the second frame, and note characters who moved from above to below me or vice versa.
  Each of them has a line that crosses mine.
  
  If I do that for every character I end up counting all the crossings twice (once from the perspective of each character involved).
  But since it's _exactly_ twice this isn't a problem; I can just halve the final number.
</aside>

With the aid of that, and some extra code to do things randomly, I can get an annealing-ish algorithm to run.
It doesn't do anything.

OK, that was a bug — in fact several bugs.
With those fixed, I've got an improved layout but it's not that impressive.

blog/images/dmfa_71f93598e7b2ae13271f4b30ddcb5f44e678882c.svg

Honestly, the biggest problem with this is that most things haven't even moved;
The diagonal line of locations along the bottom of the screen is what happens when they're added to the diagram in order of appearence in the story, without regard to where they actually are.

Fortunately, I've realised there's a more sensible way to do the annealing
(still not reading the instructions though so I could still be wrong).
See, _real_ annealing is a physical process, where a substance settles into shape as it cools.

When it does that, the atoms don't jump around randomly — at least, not completely.
Instead, it's the locations under the most stress — with the most potential energy — that tend to move, since they're under the most pressure.

In my situation, I think that means I should be moving around the locations that cause the most problems — in this case hopefully that's the lines in the middle that have lots of vertical lines cutting across them.

Let's have a go at that.

-----------------------------------

Work continues.
Moving lines that have the most crossings helps a little, but not enough.
Really it would make more sense to specifically swap pairs of lines that cross; that will be the next step.

If that doesn't work I need to either look up simulated annealing and do it properly, or change tack and try one of my other back-pocket options.

----------------------------------------

I've got swapping lines working now, but it has two problems.

1. It's slow. Really slow. And with the typical parameters I was using (temperature 200, reducing by \*= 0.7, 100 samples per iteration) it's not good enough to make much difference
2. I've broken something else and the layout isn't getting applied.
    After running the swapping-lines code for over 24 hours it did manage to find a layout with only 500-odd crossings:

    ```
    - best this round: <#Crossings 545 across 176 characters and 271 locations >
    - improvement this round: 0 (current favoured option is 545)
    Crossing number: 545
    Location order: earth/studio, earth/studio/emulator, pasture/elsewhere, human-dimension, pasture, coast, elf-lands, twink-territories/rock, lorendas-place, beach/ice-cream, beach/volleyball-field, beach/surf, lost-lake/war-zone/recruiting-office, beach/surf-school, beach, beach/singles-bar, beach/high-point, twink-territories/headquarters/outskirts, dungeon, twink-territories/headquarters/information-booth, twink-territories/headquarters/gate, therapy, twink-territories/headquarters/biggss-tent, twink-territories/road, elsewhere, lost-lake/bar, twink-territories/lorendas-house/bedroom, lost-lake/throne, twink-territories/separated, lost-lake/pokeholics-anonymous, lost-lake/dining, pizza-shop, adventuring/escaped, start, lorendas-place/lounge, beach/hotel, lost-lake/kitchen, twink-territories/headquarters/biggss-tent/other-side-of-wall, lost-lake/inn/outside, lost-lake/bath, twink-territories/headquarters/inside, lost-lake/inn, lost-lake/war-zone, twink-territories/lorendas-house/lounge, jyrras-mansion, lost-lake/basement, twink-territories, twink-territories/headquarters/restroom, twink-territories/headquarters/aside, lost-lake/den, earth/scotland, beach/seafood-restaurant, lost-lake/mabs-grove, lost-lake, lost-lake/outside, twink-territories/headquarters, lost-lake/dans-room, twink-territories/headquarters/biggss-tent/outside, adventuring/drake-nest, adventuring/apart, adventuring, san-residence, water-cities
    ```

Specifically, it ran for this long (31 hours 47 minutes and 31.596 seconds):

```
real	1907m31.596s
user	1906m54.276s
sys	0m12.712s

```

But when I look at the actual image it's not using that layout --- note that Amber's studio is clearly not at the top, for instance.

[image blog/images/dmfa_329a88e12824f8e58ee56f9fb61c0ea801289c10.svg]

I need to fix this before I can properly evaluate the approach.

I'm not running the job for 31 hours again, but luckily I saved the sort order as output.
With a bit of hackery I can get it back into the program without re-running the layout (mostly; this skips the sorting of characters but that's not quite as important), and generate this diagram:

[image blog/images/dmfa_329a88e12824f8e58ee56f9fb61c0ea801289c10_actually_using_sort_order.svg]

That's much better. 
It's not perfect: there's still a lot of extraneous crossings and "stretched" lines for no apparent reason, and somehow the event of Lorenda being born has gone missing (though that may be a data-entry issue).
But it's pretty clear this layout algorithm is, in fact, doing layout.

This is real, meaningful progress.
I wasn't sure I could even get to this point.
True, it's insanely slow— but I haven't even _tried_ to optimise it, or to simplify the job by cutting out dead or location-unknown characters.
Give it some time and polish and I believe this can actually be a viable layout algorithm.

Although that said, I've just actually gone and read the Wikipedia page on Simulated Annealing while all this was running, and it does sound like the real algorithm won't be too hard to add and may even be faster.
And before I do anything else I do need some reasonbly solid tests.

There's a long way to go yet, but I'm definitely on a viable track.

P.S.
One thing I just noticed looking at the diagram is the way it's sorted Lorenda's landlord all the way off to the top, very far from where Lorenda is in the one scene her landlord appears in.
This looks like a mistake, but it's actually correct for the rules as they stand — Lorenda's scenes with Jyrras have a bunch of Lost Lake stuff below and above them, so if the "landlord" threads was near there it would cross a bunch of main-cast characters' threads going back and forth between busy locations.
Moving the line up causes _Lorenda_ to cross a bunch of other threads on the way up and back, but she only dioes that once, and at the time it happens there aren't even too many characters between her and where the landlord went.

There are two sorts of things I can do to fix this:

* Tell the algorithm more clearly what I want.
   Currently I'm prioritising clean lines (minimal crossings) over everything else, but for readabilty it's a lot clear to keep nearby locations together, even at a cost of a few more crossings.
   The algorithm doesn't measure that, so I get what I measure.
* Truncate irrelevant threads.
   The landlord appears in one scene and then immediately dies; there's no need to have the thread extend back to the beginning of time, and it certainly shouldn't continue past that scene.

-----------------------------

OK, next step, try to speed it up.

To start with let's try using https://github.com/ruby/profile to find out what's so slow:

Done that, and it's given me results starting with this (plus more lower-priority things further down):

```
  %   cumulative   self              self     total
 time   seconds   seconds    calls  ms/call  ms/call  name
 10.92    60.52     60.52  5109468     0.01     0.02  Hash#hash
  8.88   109.73     49.21  7471368     0.01     0.03  Set#&
  8.73   158.13     48.40  4131609     0.01     0.08  Lachisis::SVG::SimulatedAnnealing#sample_by_weights
  7.08   197.40     39.27  3689922     0.01     0.16  Array#each
  4.91   224.64     27.24  7320911     0.00     0.06  Class#new
  4.63   250.32     25.68  3559055     0.01     0.03  Set#initialize
  4.24   273.79     23.48  9033040     0.00     0.01  Hash#[]
  4.21   297.11     23.32  3559072     0.01     0.04  Set#do_with_enum
  3.98   319.16     22.05  2710614     0.01     0.38  Lachisis::SVG::Crossings#initialize
  3.49   338.51     19.35  3343924     0.01     0.02  Set#merge
  3.28   356.67     18.16 21347735     0.00     0.00  Kernel#hash
  3.24   374.64     17.97  5109468     0.00     0.02  Set#hash
  3.17   392.22     17.58  4981121     0.00     0.00  Set#include?
  2.97   408.71     16.49  1780422     0.01     0.01  Set#eql?
  2.41   422.07     13.36  3559072     0.00     0.03  Enumerable#each_entry
  2.09   433.68     11.60  3040749     0.00     0.07  Set#each
  2.08   445.18     11.51  3040749     0.00     0.07  Hash#each_key
  1.92   455.81     10.63  2872794     0.00     0.00  Set#add
  1.77   465.60      9.78  2490456     0.00     0.01  Enumerable#any?
  1.72   475.11      9.51   492020     0.02     0.06  Lachisis::SVG::Crossings#crossing_characters
  1.41   482.94      7.83  8725895     0.00     0.00  Integer#+
  1.21   489.62      6.68  1422180     0.00     0.19  Array#map
  0.72   493.60      3.98  1068578     0.00     0.07  Enumerable#to_set
  0.70   497.49      3.89  4271407     0.00     0.00  Kernel#is_a?
  0.64   501.07      3.57  4046825     0.00     0.00  Integer#>=
  0.57   504.23      3.16  3560493     0.00     0.00  Kernel#respond_to?
  0.57   507.38      3.16  3759103     0.00     0.00  Kernel#class
  0.53   510.34      2.96   199130     0.01     0.22  Lachisis::SVG::Crossings::Crossing#initialize
  0.52   513.23      2.89  3559079     0.00     0.00  Hash#initialize
  0.49   515.97      2.74   257400     0.01     1.63  Lachisis::SVG::SimulatedAnnealing#shuffle_array
  0.46   518.52      2.54     3009     0.85     5.37  Array#|
  0.45   521.03      2.51  2875726     0.00     0.00  Hash#[]=
  0.41   523.29      2.26  2490766     0.00     0.00  NilClass#nil?
  0.40   525.51      2.23   576768     0.00     0.02  Lachisis::SVG::Crossings#char_order
  0.37   527.58      2.06  2178987     0.00     0.00  Kernel#instance_variable_get

...

  0.00   554.28      0.00        1     0.00     0.00  Nokogiri::XML::SAX::Document#start_document
  0.00   554.28      0.00        1     0.00     0.00  Nokogiri::XML::SAX::Document#start_element
  0.00   554.28      0.00        1     0.00     0.00  Nokogiri::XML::SAX::Document#start_element_namespace
  0.00   554.29      0.00        1     0.00 554285.04  #toplevel
```

Another profiling trick [TODO add StackOverflow link] is to run the program
and stop it with Ctrl+C. Assuming there's one bit of code slowing the program
down, it should spend most of its time running the slow bit, so if you Ctrl+C
it at random there's pretty good odds the stack trace will include the slow bit.

Trying this gives me a few candidates that make sense to optimise (and that
also show up in the other code). These two are a couple of the clearest:

* `	from /home/edward/Documents/projects/lachisis-weaves/lachisis/svg.rb:55:in `block (3 levels) in initialize'`
  which is in `Lachisis::SVG::Crossings#initialize`, and
* `/home/edward/Documents/projects/lachisis-weaves/lachisis/svg.rb:269:in `block in sample_by_weights'`,
  in `Lachisis::SVG::SimulatedAnnealing#sample_by_weights`

Combined with the other lines I see in the stack traces, this makes `sample_by_weights`
and `SVG::Crossings::Crossing#initialize` pretty obvious choices to speed up.
`sample_by_weights` seems to be using a bit more time, but it's also likely
to be a bit of a pain to optimise as it's hard to test due to being non-deterministic.

The other thing I do notice is lots of Set and Hash-related operations, especially
things like mering and &'ing, that are not necessarily efficient. Notice I'm nearly
doing more set unions than I am adding up integers, which should be _way_ faster.

OK, I could try micro-optimising how I do set calculations and figure out a way to do
this with arithmetic instead of sets. But that seems a bit silly when I know the real
Simulated Annealing algorithm skips a lot of this. I'm doing a lot of array shuffling
for candidates I then don't even use, and I doubt the details of a properly even
random-number calculation help much anyway.

So let's start by just cutting down on wasted randomness.
Switching to just one shuffle rather than several per iteration actually makes a big
positive difference.

The bottom line:

```
  0.00   296.37      0.00        1     0.00     0.06  Bundler::Definition#current_ruby_platform_locked?
  0.00   296.37      0.00        2     0.00     0.00  Lachisis::Weave#events
  0.00   296.37      0.00        1     0.00     0.00  Lachisis::Weave#locations
  0.00   296.37      0.00        1     0.00 296372.31  #toplevel
```

Stats show a much better result on the same test case, the Kathrakopolis threads.

```
- best this round: <#Crossings 17 across 16 characters and 10 locations >
- improvement this round: 0 (current favoured option is 17)
Crossing number: 17
Location order: ["labyrinth", "pans-house", "docks", "wildflowers_house", "moon_pool", "travel-quarter", "great_pillar", "jethans_place", "noble_quarter", "thanes_house", "peak", "mile"]
```

For comparison, this is the result I got last time:

```
- best this round: <#Crossings 25 across 21 characters and 14 locations >
- improvement this round: 0 (current favoured option is 25)
Crossing number: 25
Location order: ["mile", "peak", "noble_quarter", "docks", "thanes_house", "great_pillar", "moon_pool", "wildflowers_house", "jethans_place", "travel-quarter", "pans-house", "labyrinth"]
```

-------------------

That's a pretty good speedup, but we're still talking close to 5 minutes to layout this graph --- and 
DMFA in full is well over two _thousand_ pages (including side stories), which (assuming layout is NP-hard) will be more than
20x as slow.

What else can I speed up?

Well, Ctrl+C'ing the code a few times now suggests Crossings#initialize is taking much of the time -- which makes sense since it was about half the time before.
I could run a profile to confirm that, but that's slow and the previous profile showed it was a likely target anyway, so I may skip that (fingers crossed) and go straight to speeding it up.

How?

Again, I don't want to get too deep into micro-optimisations at this early stage, but I can see a couple of macro things that would help:

* Update the existing crossings count rather than recalculating it from scratch.
  All my updates at the moment involve swapping two locations (or characters).
  For locations I'm pretty sure this can only affect crossings with other locations that were originally between them --- so in what Wikipedia suggests is the optimal case where I only swap adjacent lines, the update will be pretty quick. Even with random swaps it should help.
  For characters it's less clear-cut but I think similar logic should work.
  
* Change the scoring function. Currently I'm counting crossings but this is (a) lots of set operations, which seem like they may be slow, and (b) isn't actually the best metric of the layout.
    Notice in the image [kathrakopolis_2de4d52f8a3c07f30eba334cc0fbc7a48ad7844d] that Vinnie's final location (after leaving the minotaur) is several rows away from where the minotaur was in the labyrinth. 
    But in the story he's only gone around a corner, and there's no layout reason to move him that far away (0 crossings regardless).
    However, the crossing-counting layout isn't going to improve on this.
    
    Another option I considered (initially when thinking about using Linear Programming) is to minimise the total length of vertical (well, slanted) lines.
    This is easy to calculate -- if a character moves from location A to B, the vertical distance is `abs((index of A in the sort order) - (index of B))`,
    plus maybe a small correction to account for characters (slightly trickier since it depends on the characters in the intervening locations).
    That's a linear, integer calculation, which is essential for linear programming but may also be faster in this context.
    
    However, doing this right now would mess up the fake-annealing logic as that sample-by-weights method relies on detailed crossings information
    that this objective function calculation wouldn't generate. As such I may hold off on this, or at least wait until I'm using a simpler shuffling algorithm (e.g. adjacent swaps only).
    

---------------

OK, after much fiddling around I've got code that updates the existing crossings count.

I've run some profiling on it, and first of all, it took ages.
Over 23 hours, in fact:

[blog/dmfa_log_9930f37a32f50c28f07bb5c7a0bda428776577ed.txt]

I've also realised I didn't properly file the benchmark I ran previously, so now I need to
run another one to compare with :-(
Into the Git logs!

OK, I've done that now:

[blog/dmfa_log_062f7927047f7579f819aa0f58b940804806692f.txt]

The comparison doesn't look good:

```
edward@tandoltar:~/Documents/projects/lachisis-weaves$ tail blog/dmfa_log_*
==> blog/dmfa_log_062f7927047f7579f819aa0f58b940804806692f.txt <==
  0.00 21240.31      0.00        1     0.00     0.00  Gem::BasicSpecification#extension_dir
  0.00 21240.31      0.00        1     0.00     0.00  Array#insert
  0.00 21240.31      0.00        1     0.00     0.00  Gem.add_to_load_path
  0.00 21240.31      0.00        1     0.00     0.00  Bundler::RubygemsIntegration#add_to_load_path
  0.00 21240.31      0.00       19     0.00     0.00  Dir.[]
  0.00 21240.31      0.00       20     0.00     0.00  Bundler::Runtime#setup_manpath
  0.00 21240.31      0.00        1     0.00     0.00  Bundler::Runtime#lock
  0.00 21240.31      0.00        1     0.00     0.00  Regexp.last_match
  0.00 21240.31      0.00        1     0.00     0.00  BasicObject#singleton_method_undefined
  0.00 21240.31      0.00        1     0.00 21240312.15  #toplevel

==> blog/dmfa_log_9930f37a32f50c28f07bb5c7a0bda428776577ed.txt <==
  0.00 85111.75      0.00        3     0.00     0.00  String#shellescape
  0.00 85111.75      0.00        1     0.00     0.00  Nokogiri::VersionInfo#windows?
  0.00 85111.75      0.00        6     0.00     0.00  Nokogiri::VersionInfo#to_hash
  0.00 85111.75      0.00        1     0.00     0.00  Nokogiri::VersionInfo#engine
  0.00 85111.75      0.00        2     0.00     0.00  Nokogiri::VersionInfo#libxml2_precompiled?
  0.00 85111.75      0.00        1     0.00     0.00  Nokogiri::VersionInfo#libxml2_has_iconv?
  0.00 85111.75      0.00        1     0.00     0.00  Nokogiri::VersionInfo#libxslt_has_datetime?
  0.00 85111.75      0.00        1     0.00     0.00  Hash.[]
  0.00 85111.75      0.00        1     0.00     0.00  Nokogiri.uses_gumbo?
  0.00 85111.75      0.00        1     0.00 85111753.40  #toplevel
```

This may indeed be a dead end.
If it is, I'll need another path --- possibly something like the linear-programming approach I wrote about further up.
Or possibly a better data structure --- I've had an idea about storing the layout as a matrix
(rows are characters, columns frames, cells event/location IDs) plus some sort orders, which might allow more efficient layout.

Before I do that, though, let's see how far I can get with low-hanging micro-optimisations on this new algorithm.

--------------------------------

OK, I'm not getting very far.
From commit fea6dd01333aaab7da59cad086d308675b95add4 it's apparent that the algorithms I'm using really aren't working.
I can't even solve a simple, 4-character 2-event model reliably.
I need a better algorithm.

How can I do that?
Well, I've randomly browsed Wikipedia on knot theory, but it all seems to descend very quickly into group theory and topology that I don't understand.
I have been thinking about permutations, since the layout could be seen a something like a sequence of permutations, and obviously the location order I need for minimum crossings is also a permutation.
(I've kind of given up on global character order; that was an optimisation to make the code I started wtih easier, but the code still doesn't work, and if I remove the requirement of a global order I can always just use the minimum-crossings character order in every location locally. A few crossings locally to one location aren't too bad anyway.

One idea I did have was viewing the weave end-on, looking down the location lines.
This creates something I'm calling the "travel graph": nodes are locations, and edges indicate characters moving between them (one edge per movement, for now -- so parallel edges are allowed, although not self-loops).

I conjecture that the minimal-crossings drawing of a weave has at most one crossing per cycle in the travel graph (a bit ambitious, but I think it turns out false anyway so I might as well shoot for the moon).
The first few forced-crossing layouts I've thought of do indeed have cycles.

A 2-cycle:

C1 at L1, C2 at L2, C1 -> L2, C1 -> L1

A 3-cycle ("borromean" in the sense that no two of these edges force a crossing but all three together do):

C1 at L1    C1 -> L2
C2 at L2    C2 -> L3
C3 at L3    C3 -> L1

Both of those are "directed" cycles in the sense that the cycle follows the movement direction of the characters along the edges.
But we can also have an undirected cycle force a crossing:

C1 at L2    C1 -> L1
C2 at L2    C2 -> L3
C3 at L4    C3 -> L3
C4 at L4    C4 -> L1
 
Assume WLOG that L2 is drawn above L4.
If L1 is above L3, the lines L2-L3 and L1-L4 cross.
If L1 is below L3, then L2-L1 and L3-L4 cross,


So far, so good.
How would I go about proving this conjecture?
Well, if it's true that crossings require cycles, then there should (hopefully :fingers_crossed:) be an algorithm to lay out a weave whose travel graph is acyclic with 0 crossings.
An acyclic travel graph must be a forest — a set of disjoint trees,
so it suffices to lay out a single tree; if we can do that we can then repeat the process on the remaining trees.

To lay out a tree-travel-graph'ed weave, let's start by picking an arbitrary location as the root, then lay out the other locations above and below it.
Can we do this in such a way that no two characters cross?

Well, by tree-ness each character can only visit this root location at most once, meaning they have at most one arrival and at most one leave event.
Assume for the moment that characters arrive and leave exactly once.
Every character arrives from a unique locations (otherwise we have parallel edges, which count as cycles), so we can choose independently for each one whether they arrive from above or below this location.
Likewise for how they leave.
But we still only have two directions to choose from.

Can we always lay this out without crossings?
Possibly not.

Consider the sequence +A (A arrives), +B, +C, +D, -B (B leaves), -C, -D, -A.

* After everyone has arrived, A and B must be adjacent (otherwise someone would have to have crossed one of their lines to end up between them).
* B leaves first, therefore C must have arrived on the other side of A.
* D arrives after C, so it has to be either adjacent to B or to C.
* But both B and C leave before D, so one of them must cross its line in leaving.

Thus the conjecture is disproven; even with an acyclic travel graph, the weave can still have crossings.
No wonder it's so hard to lay one out neatly!

But do these crossings matter?
This example produces a crossing that has to happen within a single location, which I'm saying is the least concerning kind.
My concern is that there might be a layout that causes a crossing like this within a cluster of locations, at which point I'm not sure it would still look neat.

2023-04-10

OK, let's see if ignoring those crossings will help.
Suppose we only care about crossings induced by cycles.
How can we tell which cycles require a crossing.

I conjecture that a cycle induces a crossing if and only if the cycle is "un-orderable", as follows:

* Label all edges in the travel graph with the index of the frame they happen in (the time at which the character moved).
  * If there are multiple character movements between two locations, use multiple edges, each one labelled accordingly.
* Note that frames are totally ordered (at least in stories without time travel)
* A cycle is "orderable" if we can traverse the cycle in a sequence respecting the ordering of edge labels (in some direction, from some point on it).
  All other cycles are un-orderable.

Can I prove this?

No. Consider the following:

```
Frame:        1         2          3         4
C1 at L1 ; C1 -> L0          ; C1 -> L1
C2 at L1 ;          C2 -> L2 ;            C2 -> L1 
```

This is an unorderable cycle but it can be drawn without crossings (the resulting layout is a diamond shape).
Maybe we can recover the unorderable cycle -> crossing edge of the iff by allowing ordering to include a single reversal?
No; it would be trivial to have a similar diamond layout with an arbitrarary amount of zig-zagging along one edge.

(There might perhaps be a loophole here, though: this isn't a simple cycle.
 We could construct a travel-graph cycle with only the C2 edges 2 and 4, or only the C1 edges 1 and 3, and both of those are ordered.
 So maybe we can ignore this particular cycle as being a composite one.
 Further thought needed on this.)

But maybe we don't need to.
If we can prove that all crossings of interest (i.e. between multiple locations) necessarily result from un-ordered cycles that would at least narrow down the class of weaves that can be drawn without crossings, and maybe help layout a bit.

However that seems hard, so for now I'll try assuming the conjecture works in that direction, and sketch an algorithm that would work if that were the case.

* Find all orderable cycles, and their associated orders.
* Each such "sorted cycle" defines a partial order on locations (read them off in the order the cycle passes through them).
  If all these partial orders are consistent, we could sort the locations using them.

Will that work, though?

Well, for the example above we get the partial orders L1 <= L0 (from the first edge only; we ignore the second as L1 is already placed; effectively it's at both ends of the cycle but we pick the start arbitrarily to get a partial order), and L1 <= L2.
That reasonably results in a layout order L1, L0, L2 (or equivalently, L1, L2, L0).
So far, so good.

--------------

Nope, the conjecture doesn't work.

Suppose we have a sorted cycle A -> B -> C -> D ( -> A), all triggered by movements of one character ("Oberon"), who starts and ends the weave at A.
Now add characters Alice, Bob, Charlie, and Deborah who start at new locations A0, B0, C0, and D0 respectively.
In frames 1-4, Oberon moves A -> B -> C -> D and remains at D for now.
Alice, Bob, Charlie, and Deborah then each in separate frames leave their starting locations to move to A, B, C, and D respectively.
Then they each leave those locations to travel to final destinations A', B', C', and D' and remain there for the remainder of the weave.
Finally, Oberon moves from D back to A.

There are no cycles except for Oberon's, which doesn't induce a crossing on its own.
Alice et al.'s movements are all acyclic.

However the layout must contain a least one crossing.
Locations A0-D0 must all be outside the ABCD group Oberon moves in, otherwise the characters starting there would be crossed by Oberon's Frame 1-4 movements.
Likewise A'-D' must be outside the group or the characters ending up there would be crossed by Oberon's return.
    Wait, no, this doesn't hold as we could rearrange ABCD so A and D are adjacent without creating a crossing.
    We can mitigate it by having Oberon move A->B->C->D->C->B->A, but that actually violates our conjecture as it creates pairs of "up" and "down" edges in the travel graph between the same pairs of nodes, and we can construct a cycle going A->B (up), B->C (down), and so on that cannot be ordered.
