#!/bin/bash
set -euo pipefail
SOURCE="${1:-/Users/derekbridge/reveal.js/Gif_process/Gif_photo}"
OUTPUT="${2:-/Users/derekbridge/reveal.js/Gif_process/output/Gif-collage-output-1920x1080.gif}"
TMP=$(mktemp -d)
# All supported images, in filename order; use the first frame of existing GIFs.
files=()
while IFS= read -r -d '' file; do
  files+=("$file")
done < <(find "$SOURCE" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.svg' -o -iname '*.avif' -o -iname '*.tif' -o -iname '*.tiff' \) -print0 | sort -z)
count=${#files[@]}
if (( count == 0 )); then echo 'No images found.' >&2; exit 1; fi
for ((i=0; i<count; i++)); do
  # Resize directly from the source: preserve aspect ratio and never upscale.
  magick "${files[i]}[0]" -auto-orient -filter Lanczos -resize '1200x740>' \
    -colorspace sRGB -strip +repage "$TMP/resized.png"
  read -r width height < <(magick identify -format '%w %h\n' "$TMP/resized.png")
  # A 24-pixel corner radius; intersect with any existing transparency.
  magick -size "${width}x${height}" xc:none -fill white \
    -draw "roundrectangle 0,0,$((width-1)),$((height-1)),24,24" "$TMP/mask.png"
  magick "$TMP/resized.png" -alpha set "$TMP/mask.png" \
    -compose DstIn -composite \
    \( +clone -background black -shadow 22x8+0+6 \) \
    +swap -background none -compose Over -layers merge +repage "$TMP/card-$i.png"
done
# Cycle through three offset positions, preserving the previous two cards.
x=(110 600 350)
y=(45 160 290)
for ((i=0; i<count; i++)); do
  args=(-size 1920x1080 xc:'#eeeae5')
  for ((back=2; back>=0; back--)); do
    index=$(( (i-back+count)%count ))
    slot=$((index%3))
    args+=( "$TMP/card-$index.png" -gravity northwest -geometry "+${x[slot]}+${y[slot]}" -compose over -composite )
  done
  printf -v frame '%s/frame-%03d.png' "$TMP" "$i"
  magick "${args[@]}" "$frame"
done
magick -delay 55 -dispose none "$TMP"/frame-*.png \
  -loop 0 -layers Optimize "$OUTPUT"
echo "Created $OUTPUT using $count images."
echo "Temporary frames: $TMP"
