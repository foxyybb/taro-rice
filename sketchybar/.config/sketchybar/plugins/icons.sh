#!/usr/bin/env bash

# Nerd Font icon glyphs for the stats items.
# NOTE: these use Nerd Fonts v3 Material Design codepoints (U+F0000+ plane).
# The previous values were v2 codepoints (U+F85A/FB19/F7C9) that were RELOCATED
# in Nerd Fonts v3 and now render as blank boxes. They are written as UTF-8 byte
# escapes so the 4-byte glyphs survive file edits (editors strip raw PUA bytes).
export BATTERY=$'\xef\x89\x80'        # U+F240  fa-battery
export CPU=$'\xf3\xb0\xb1\x8f'        # U+F0C4F mdi-cpu-64-bit
export DISK=$'\xf3\xb0\x8b\x8a'       # U+F02CA mdi-harddisk
export MEMORY=$'\xf3\xb0\x8d\x9b'     # U+F035B mdi-memory
export NETWORK=$'\xf3\xb0\x96\x9f'    # U+F059F mdi-wan
export NETWORK_DOWN=$'\xf3\xb0\x87\x9a' # U+F01DA mdi-download
export NETWORK_UP=$'\xf3\xb0\x95\x92'   # U+F0552 mdi-upload
