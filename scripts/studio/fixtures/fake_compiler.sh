#!/bin/sh
# Stands in for a map compiler in the steps session: reads the map it is
# given and says of it what such a program would, by entity and brush
# number and by line, then stops with a code of its own.
map="$1"
echo "--- fakebsp ---"
echo "reading $map"
echo "brushes: $(grep -c '^// brush' "$map")"
echo "Entity 0, Brush 3: mirrored plane"
echo "WARNING: Entity 1 (info_player_start) stands close to a wall"
line=$(grep -n '^// brush 5' "$map" | head -1 | cut -d: -f1)
echo "$map:$((line + 2)): brush has a thin side"
exit 3
