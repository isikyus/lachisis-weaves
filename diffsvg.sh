#!/usr/bin/env bash
#
# "Diffs" two SVG images by rendering them
# on top of each other in different colours.
# Very simplistic; only works with black lines & text
# as that's all I need to look at Lachisis output at present

# TODO: args check doesn't actually work
if [ "x$ARGC" = x2 ]
then
  echo "Usage: diffsvg.sh <file1.svg> <file2.svg>"
  exit 1
fi

group_wrapper='<g opacity="0.5">'
(
  # HACK: merging XML files with regexp
  sed "s/<svg.*/\\0$group_wrapper/ ; s/black/red/g ; s/<\/svg>//" "$1"
  echo "</group>$group_wrapper"
  sed 's/<?xml.*//; s/<svg.*// ; s/black/green/g ; s/<\/svg>/<\/group>\0/' "$2"
)
