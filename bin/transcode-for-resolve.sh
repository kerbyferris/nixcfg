#!/usr/bin/env bash
# Transcodes video to ProRes HQ and audio to PCM for DaVinci Resolve import.

if [ -z "$1" ]; then
    echo "Usage: $0 <input_file>"
    echo "Output will be named <input_file_basename>_prores.mov"
    exit 1
fi

INPUT_FILE="$1"
FILENAME=$(basename -- "$INPUT_FILE")
FILENAME_NO_EXT="${FILENAME%.*}"
OUTPUT_FILE="${FILENAME_NO_EXT}_prores.mov"

echo "Transcoding '$INPUT_FILE' to '$OUTPUT_FILE' for DaVinci Resolve..."
echo "Video: ProRes 422 HQ"
echo "Audio: PCM 16-bit Little-Endian"

ffmpeg -i "$INPUT_FILE" \
       -c:v prores_ks -profile:v 3 \
       -c:a pcm_s16le \
       -map 0:v:0 -map 0:a:0? \
       "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo "Transcoding successful! Output: $OUTPUT_FILE"
else
    echo "Transcoding failed!"
    exit 1
fi
