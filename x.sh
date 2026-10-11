#!/bin/bash
# Stage 1 restore: copy YOUR FILES ONLY back from the Lexar into this account.
# Run in Terminal on the working Mac (NOT Recovery), logged in as voyager1, Lexar plugged in:
#   curl -fsSL https://raw.githubusercontent.com/pcvaders/mac-m3/backup/x.sh -o ~/x.sh && bash ~/x.sh
#
# Never copies software or regenerable clutter. All apps are reinstalled fresh
# from official sources instead:
#   - app bundles (*.app) anywhere, ~/Applications, Library (all app data/caches)
#   - caches and build/dependency folders: .cache, node_modules, venv/.venv,
#     __pycache__, .pytest_cache, DerivedData, .gradle, .next, .turbo, .parcel-cache
#   - top-level tmp/ and venv/, the Trash, .DS_Store
# Copies a short list of settings files (.ssh, .gitconfig, shell profiles).
# Existing files with the same name are overwritten; nothing is deleted.

VOL="${VOL:-/Volumes/Lex4TB}"
SRC="${SRC:-$VOL/M3 Backup Oct26/Voyager1}"
DEST="${DEST:-$HOME}"
LOG="$DEST/restore-log.txt"

DOTFILES=".ssh .gitconfig .gitignore_global .zshrc .zprofile .zshenv .bash_profile .bashrc .profile"
SKIP_TOP="Library Applications tmp venv .Trash .cache .DS_Store .CFUserTextEncoding"
EXCLUDES="*.app node_modules .venv venv __pycache__ .pytest_cache .cache DerivedData .gradle .next .turbo .parcel-cache .DS_Store"

[ -d "$SRC" ] || { echo "Backup not found at: $SRC"; echo "Is the Lexar plugged in? Check with: ls /Volumes"; exit 1; }
command -v rsync >/dev/null || { echo "rsync not found - stopping (it is needed to skip apps and caches)."; exit 1; }

set --
for e in $EXCLUDES; do set -- "$@" --exclude="$e"; done

items=()
for f in "$SRC"/*; do
  n="${f##*/}"
  case " $SKIP_TOP " in *" $n "*) continue;; esac
  case "$n" in *.app) continue;; esac
  items+=("$n")
done

echo "Restoring from: $SRC"
echo "Into:           $DEST"
echo
echo "Will copy (minus apps, caches and dependency folders inside them):"
for n in "${items[@]}"; do echo "  $n"; done
for d in $DOTFILES; do [ -e "$SRC/$d" ] && echo "  $d"; done
echo
echo "Will NOT copy: $SKIP_TOP"
echo "Skipped inside folders: $EXCLUDES"
echo "Apps are reinstalled fresh from official sources (see HANDOFF.md stage 2)."
echo
if [ -t 0 ]; then
  read -r -p "Type yes to start: " ok
  [ "$ok" = "yes" ] || { echo "Cancelled - nothing copied."; exit 0; }
fi

echo "--- restore started $(date) ---" >> "$LOG"
for n in "${items[@]}"; do
  echo "== $n"
  if [ -d "$SRC/$n" ]; then
    rsync -a "$@" "$SRC/$n/" "$DEST/$n/" 2>>"$LOG"
  else
    rsync -a "$@" "$SRC/$n" "$DEST/$n" 2>>"$LOG"
  fi
done
for d in $DOTFILES; do
  [ -e "$SRC/$d" ] || continue
  echo "== $d"
  if [ -d "$SRC/$d" ]; then rsync -a "$SRC/$d/" "$DEST/$d/" 2>>"$LOG"; else rsync -a "$SRC/$d" "$DEST/$d" 2>>"$LOG"; fi
done
[ -d "$DEST/.ssh" ] && chmod 700 "$DEST/.ssh" && chmod 600 "$DEST/.ssh"/id_* 2>/dev/null

echo
echo "DONE. Errors (if any) are in: $LOG"
echo "Copy errors logged: $(grep -vc '^--- ' "$LOG")"
echo "Projects: dependency folders were skipped - run npm/pnpm/bun install or recreate venvs per project."
echo "Next: restart the Mac and check you can still log in."
