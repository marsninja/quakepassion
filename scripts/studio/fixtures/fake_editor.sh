#!/bin/sh
# Stands in for an image editor in the outside session: "edits" the file it
# is given by putting another picture, kept beside its folder, in its place.
file="$1"
cp "$(dirname "$file")/../spare/$(basename "$file")" "$file"
