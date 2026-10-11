#!/bin/bash
# Read-only: dig into the WindowServer / loginwindow crash reports from the
# login loop and show why they crashed and what third-party code was loaded.
# Run from Recovery Terminal:
#   curl -fsSL https://raw.githubusercontent.com/pcvaders/mac-m3/backup/s.sh -o /Volumes/Lex4TB/s.sh && bash /Volumes/Lex4TB/s.sh

DATA="${DATA:-/Volumes/Macintosh HD - Data}"
VOL="${VOL:-/Volumes/Lex4TB}"
USERNAME="${USERNAME_OVERRIDE:-Voyager1}"
OUT="$VOL/M3 Backup Oct26/windowserver-crashes.txt"

if [ ! -d "$DATA/Users" ]; then
  echo "Unlocking Macintosh HD - Data (enter your Voyager1 password)"
  diskutil apfs unlockVolume "Macintosh HD - Data"
fi
cd / || exit 1

R1="$DATA/Library/Logs/DiagnosticReports"
R2="$DATA/Users/$USERNAME/Library/Logs/DiagnosticReports"

# Print one JSON object field (single-line or pretty-printed) from a report.
field() { # field <file> <key>
  awk -v k="\"$2\"" '
    index($0, k) && !on { on = 1; depth = 0 }
    on { print; depth += gsub(/{/, "{") - gsub(/}/, "}"); if (depth <= 0) exit }
  ' "$1" | head -20 | cut -c1-200
}

report() {
  f="$1"
  echo "################ ${f##*/}"
  echo "-- exception:";   field "$f" exception
  echo "-- termination:"; field "$f" termination
  echo "-- asi (app-specific info):"; field "$f" asi
  echo "-- first code symbols in the report:"
  grep -o '"symbol" *: *"[^"]*"' "$f" | head -15 | sed 's/"symbol" *: *//'
  echo "-- NON-APPLE code loaded in this process:"
  grep -o '"path" *: *"[^"]*"' "$f" | sed 's/"path" *: *//; s/"//g' \
    | grep -v -e '^/System/' -e '^/usr/lib/' -e '^/usr/libexec/' -e '^/Library/Apple/' -e '^\*' | sort -u
  echo
}

{
  echo "Crash reports, newest first:"
  ls -t "$R1"/*.ips "$R2"/*.ips 2>/dev/null | grep -i -e WindowServer -e loginwindow | head -6 | sed 's#.*/#  #'
  echo
  ls -t "$R1"/*.ips "$R2"/*.ips 2>/dev/null | grep -i -e WindowServer -e loginwindow | head -3 \
  | while read -r f; do report "$f"; done
} > "$OUT" 2>&1

cat "$OUT"
echo "Saved to: $OUT"
echo "Take photos of this (scroll up if needed) and send them to Claude."
