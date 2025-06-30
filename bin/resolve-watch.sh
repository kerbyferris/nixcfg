#!/usr/bin/env bash
# Watches a directory for new files and transcodes them for Resolve.

WATCH_DIR="/home/kerby/Dropbox/Family Room/footage_raw"
OUTPUT_DIR="/home/kerby/Dropbox/Family Room/footage_transcoded"

mkdir -p "$WATCH_DIR" "$OUTPUT_DIR"

echo "Watching $WATCH_DIR for new files..."

inotifywait -m -e create --format '%w%f' "$WATCH_DIR" | while read FILE
do
    echo "New file detected: $FILE"
    if [[ -f "$FILE" ]]; then
        # Ensure it's not a temporary file being written
        sleep 1 # Give it a moment to finish writing
        if [[ $(lsof -t "$FILE" 2>/dev/null) ]]; then
            echo "File still in use, skipping for now: $FILE"
            continue
        fi

        FILENAME=$(basename -- "$FILE")
        FILENAME_NO_EXT="${FILENAME%.*}"
        OUTPUT_FILE="${OUTPUT_DIR}/${FILENAME_NO_EXT}_prores.mov"

        echo "Transcoding '$FILE' to '$OUTPUT_FILE'..."
        ffmpeg -i "$FILE" \
               -c:v prores_ks -profile:v 3 \
               -c:a pcm_s16le \
               -map 0:v:0 -map 0:a:0? \
               "$OUTPUT_FILE"

        if [ $? -eq 0 ]; then
            echo "Transcoding successful! Output: $OUTPUT_FILE"
            # Optional: remove original file
            # rm "$FILE"
        else
            echo "Transcoding of '$FILE' failed!"
        fi
    fi
done

