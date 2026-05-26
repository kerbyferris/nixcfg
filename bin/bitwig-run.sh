#!/usr/bin/env bash

export VIDPLAY_LIBS_DIR="$HOME/.config/vidplayvst-libs"

exec steam-run -- \
  bwrap --ro-bind "$VIDPLAY_LIBS_DIR" /usr/share/vidplayvst -- \
  bitwig-studio
