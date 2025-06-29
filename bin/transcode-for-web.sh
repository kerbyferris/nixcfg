#!/usr/bin/env bash
# Transcodes video to H.264 (CRF 23) and audio to AAC (192k) for web distribution.

if [ -z "$1" ]; then
    echo "Usage: $0 <input_file>"
    echo "Output will be named <input_file_basename>_h264.mp4"
    exit 1
fi

INPUT_FILE="$1"
FILENAME=$(basename -- "$INPUT_FILE")
FILENAME_NO_EXT="${FILENAME%.*}"
OUTPUT_FILE="${FILENAME_NO_EXT}_h264.mp4"

echo "Transcoding '$INPUT_FILE' to '$OUTPUT_FILE' for web distribution..."
echo "Video: H.264 (libx264, preset medium, CRF 23)"
echo "Audio: AAC (192kbps)"

ffmpeg -i "$INPUT_FILE" \
       -c:v libx264 -preset medium -crf 23 \
       -c:a aac -b:a 192k \
       -map 0:v:0 -map 0:a:0? \
       "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo "Transcoding successful! Output: $OUTPUT_FILE"
else
    echo "Transcoding failed!"
    exit 1
fi
