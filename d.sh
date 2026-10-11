#!/bin/bash
# Read-only diagnostics for the M3 login/restart loop, run from Recovery Terminal:
#   curl -fsSL https://raw.githubusercontent.com/pcvaders/mac-m3/backup/d.sh -o /tmp/d.sh && bash /tmp/d.sh
# Changes nothing on the Mac. Prints a short summary and saves a full report to
# the Lexar as "M3 Backup Oct26/diagnostics-<time>.txt".

DATA="${DATA:-/Volumes/Macintosh HD - Data}"
SYS="${SYS:-/Volumes/Macintosh HD}"
VOL="${VOL:-/Volumes/Lex4TB}"
USERNAME="${USERNAME_OVERRIDE:-Voyager1}"
S="$DATA/Users/$USERNAME"

if [ ! -d "$DATA/Users" ]; then
  echo "Unlocking Macintosh HD - Data (enter your Voyager1 password)"
  diskutil apfs unlockVolume "Macintosh HD - Data"
fi
[ -d "$DATA/Users" ] || { echo "ERROR: Data volume not available"; exit 1; }

OUT="/tmp/diagnostics.txt"
[ -d "$VOL/M3 Backup Oct26" ] && OUT="$VOL/M3 Backup Oct26/diagnostics-$(date +%Y%m%d-%H%M).txt"

SYSREP="$DATA/Library/Logs/DiagnosticReports"
USRREP="$S/Library/Logs/DiagnosticReports"

# Newest-first list of report files matching a pattern, across both report dirs.
reports() { ls -t "$SYSREP"/$1 "$USRREP"/$1 2>/dev/null; }

# Pull the panic message out of a .panic file (JSON body), unescaping newlines.
panic_string() {
  grep -o '"panicString" *: *"[^"]*' "$1" 2>/dev/null | head -1 \
    | sed -e 's/^"panicString" *: *"//' -e 's/\\n/\n/g' -e 's/\\t/  /g'
}

{
echo "######## M3 DIAGNOSTICS  $(date)"

echo; echo "======== macOS version"
defaults read "$SYS/System/Library/CoreServices/SystemVersion" ProductVersion 2>/dev/null
defaults read "$SYS/System/Library/CoreServices/SystemVersion" ProductBuildVersion 2>/dev/null

echo; echo "======== Disk space"
df -h "$DATA" 2>/dev/null

echo; echo "======== Kernel panics (newest first)"
panics=$(reports '*.panic')
if [ -z "$panics" ]; then
  echo "No .panic files found"
else
  echo "$panics" | head -10
  echo "$panics" | head -3 | while read -r p; do
    echo; echo "---- ${p##*/}"
    panic_string "$p" | head -40
  done
fi

echo; echo "======== Crash reports, newest 40 (names show which app crashed)"
reports '*.ips' | head -40 | sed 's#.*/##'

echo; echo "======== Login-related crashes (loginwindow / WindowServer / launchd / SecurityAgent)"
reports '*.ips' | grep -i -e loginwindow -e WindowServer -e launchd -e SecurityAgent -e authorizationhost | head -4 \
| while read -r p; do
  echo; echo "---- ${p##*/}"
  grep -o -e '"exception" *: *{[^}]*}' -e '"termination" *: *{[^}]*}' -e '"crashed" *: *true' -e '"name" *: *"[^"]*"' "$p" 2>/dev/null | head -12
  grep -o '"asi" *: *{[^}]*}' "$p" 2>/dev/null | head -3
done

echo; echo "======== Watchdog / reset reports"
reports '*watchdog*' | head -5
reports '*Reset*' | head -5
reports '*.shutdownStall' | head -5

echo; echo "======== Install log: last update activity and errors"
IL="$DATA/private/var/log/install.log"
if [ -f "$IL" ]; then
  grep -i -e 'error' -e 'fail' -e 'abort' "$IL" | tail -25
  echo "-- last lines:"; tail -15 "$IL"
else
  echo "No install.log"
fi

echo; echo "======== Startup items (third-party software that runs at boot/login)"
for d in "$S/Library/LaunchAgents" "$DATA/Library/LaunchAgents" "$DATA/Library/LaunchDaemons" \
         "$DATA/Library/StartupItems" "$DATA/Library/Extensions" \
         "$DATA/Library/Security/SecurityAgentPlugins" "$DATA/Library/SystemExtensions"; do
  echo "-- ${d#$DATA}"
  ls "$d" 2>/dev/null
done
echo "-- Disabled earlier (Users/Shared/disabled-launch-items)"
ls "$DATA/Users/Shared/disabled-launch-items" 2>/dev/null

echo; echo "======== Login window settings"
defaults read "$DATA/Library/Preferences/com.apple.loginwindow" 2>/dev/null

echo; echo "======== Device management / profiles"
ls "$DATA/private/var/db/ConfigurationProfiles/Store" 2>/dev/null
[ -e "$DATA/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound" ] && echo "MDM enrollment record present"

echo; echo "======== Accounts"
ls "$DATA/Users"
ls "$DATA/private/var/db/dslocal/nodes/Default/users" 2>/dev/null | grep -v '^_'
echo "######## END"
} > "$OUT" 2>&1

# --- On-screen summary --------------------------------------------------------
clear 2>/dev/null
echo "######## SUMMARY  (full report: $OUT)"
sed -n '/======== macOS version/,/======== Disk space/p' "$OUT" | sed '$d'
df -h "$DATA" 2>/dev/null | tail -1
echo
echo "Kernel panics found: $(reports '*.panic' | wc -l | tr -d ' ')"
latest=$(reports '*.panic' | head -1)
if [ -n "$latest" ]; then
  echo "Newest: ${latest##*/}"
  panic_string "$latest" | head -12
fi
echo
echo "Newest crash reports:"
reports '*.ips' | head -10 | sed 's#.*/#  #'
echo
echo "Startup items in /Library/LaunchDaemons:"
ls "$DATA/Library/LaunchDaemons" 2>/dev/null | sed 's/^/  /'
echo
echo "Take a photo of this screen and send it to Claude."
echo "Full report saved to: $OUT"
