#!/usr/bin/env bash
#
# Download the latest Unicode data files and regenerate src/umwi-generated.ads.
#
# Run from anywhere — the script cd's into its own directory (generator/) so
# the generator binary finds share/generator/ and ../src/ correctly.
#
# Usage:
#   generator/refresh.sh             # download + regenerate
#   generator/refresh.sh --check     # download into a temp dir, only print
#                                    # whether any file would change; exit 0
#                                    # if up to date, 1 if changes are needed.

set -euo pipefail

cd "$(dirname "$0")"

SHARE=share/generator
declare -A URLS=(
  [UnicodeData.txt]="https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt"
  [EastAsianWidth.txt]="https://www.unicode.org/Public/UCD/latest/ucd/EastAsianWidth.txt"
  [emoji-data.txt]="https://www.unicode.org/Public/UCD/latest/ucd/emoji/emoji-data.txt"
  [emoji-sequences.txt]="https://www.unicode.org/Public/emoji/latest/emoji-sequences.txt"
)

mode="${1:-update}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

for f in "${!URLS[@]}"; do
  echo "→ fetching $f"
  curl -sSL --fail --max-time 120 -o "$tmp/$f" "${URLS[$f]}"
done

changes=0
for f in "${!URLS[@]}"; do
  if [[ ! -f "$SHARE/$f" ]] || ! cmp -s "$SHARE/$f" "$tmp/$f"; then
    changes=1
    echo "   $f differs"
  fi
done

if [[ "$mode" == "--check" ]]; then
  if [[ $changes -eq 0 ]]; then
    echo "Unicode data is up to date."
    exit 0
  else
    echo "Unicode data has changed upstream."
    exit 1
  fi
fi

if [[ $changes -eq 0 ]]; then
  echo "Unicode data already up to date; nothing to regenerate."
  exit 0
fi

for f in "${!URLS[@]}"; do
  cp "$tmp/$f" "$SHARE/$f"
done

echo "→ building generator"
alr -n build

echo "→ running generator"
./bin/generator

echo "→ Unicode data refreshed; src/umwi-generated.ads regenerated."
