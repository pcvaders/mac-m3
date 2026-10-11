# Apple Diagnostics: MacBook M3

Case notes for the login/restart loop on the M3 MacBook Pro after a macOS 27 developer beta update, October 2026.

## Summary

| | |
|---|---|
| Machine | MacBook Pro, M3 (Apple silicon, T6030) |
| OS when it broke | macOS 27.2 **developer beta** (build 26B5101f), Darwin 27.2.0 |
| Symptom | Log in → progress bar → black screen → Apple logo (full restart) → login screen again |
| Cause (from logs) | Kernel panic: *userspace watchdog timeout: no successful checkins from WindowServer … WindowServer initialization not complete (post IOKitWaitQuiet)*. 7 panics recorded. |
| Interpretation | WindowServer hangs while starting the display stack (Display Coprocessor / DCP threads in the reports) and macOS force-restarts. Most likely a beta / display-firmware problem rather than user data. |
| Data | Fully backed up to an external Lexar 4 TB drive (`Lex4TB/M3 Backup Oct26`) before any erase. |
| Resolution path | Erase and install **macOS Tahoe (public)** from Recovery, then update to public macOS 27 (beta updates off), then restore files selectively. Fallback: Apple Store DFU restore (AppleCare). |

## What was tried, and the result

| Step | Result |
|---|---|
| Safe Mode | Same loop |
| Reinstall macOS from Recovery (twice) + Disk Utility First Aid | Same loop (reinstalls the same beta) |
| Created a second admin account (`helper`) from Recovery via `dscl` | Never reached; loop happens for the session |
| Revive via DFU from a 2015 MacBook Pro (macOS 12) | Not possible: Finder DFU needs macOS 14+, current Apple Configurator needs 15.7+ |
| Share Disk to the 2015 Mac | Network kept dropping, abandoned |
| Display settings reset (`w.sh`) + unplug all peripherals | Same loop |
| Kernel extensions check | Full Security, 3rd-party kexts disabled. Not the cause (`SATSMARTDriver.kext` present but cannot load) |
| Apple `container` tool (550 GB sparse VM disk in `~/Library/Application Support/com.apple.container`) | Initially suspected. Ruled out by the panic logs. Disk was 90% full (94 GB free), so not a full-disk issue either |

## Evidence

**Panic (newest, `panic-full-2026-10-10-000847.0002.panic`)**

```
userspace watchdog timeout: no successful checkins from WindowServer (2 induced crashes) in 120 seconds
service returned not alive with context : is_alive_func returned unhealthy : WindowServer initialization not complete (post IOKitWaitQuiet)
```

**WindowServer crash reports** (`WindowServer-2026-10-10-001047.ips`, `-001007.ips`, `-2026-10-09-235930.ips`)

- termination namespace `WATCHDOG`, "monitoring timed out for service"
- "unresponsive work processor(s): WindowServer main thread"
- threads referenced: `DCPEndpoint18`, `AppleDCPLinkServiceSoC`, `DCPEXT1Endpoint6`, `AFKDCPEXT1Endpoint2`, `RTBuddy(SIO)`. These belong to the Display Coprocessor, including the external-display controller.

**Other crashes around each login:** `bluetoothd`, `configd`, `containermanagerd_system` (Apple's app-sandbox manager, unrelated to the `container` tool). These are likely knock-on effects.

**Third-party startup items present** (`/Library/LaunchDaemons`): Little Snitch, Adobe, Arturia, Background Music (BGM), CleverFiles/Disk Drill, Docker, EaseUS NTFS, Google Updater/Keystone, Microsoft AutoUpdate/Office/OneDrive, NewTek NDI virtual camera, XLN Audio.

**Web search (Oct 2026):** no confirmed 27.2-beta regression found. Similar WindowServer watchdog session kills have been reported on macOS 27.0 (Blizzard forums), and one third-party cause has been documented (screenpipe #7181).

## Backup

Location: `Lex4TB/M3 Backup Oct26/`

- `Voyager1/`: the home folder, including Library, hidden dotfiles and projects
- `Shared/`: `/Users/Shared`
- `installed-apps.txt`: 393 apps with versions, App Store apps marked, plus Homebrew packages
- `diagnostics-*.txt`, `windowserver-crashes.txt`: logs collected from Recovery
- `source-list.txt`, `backup-list.txt`, `missing-files.txt`, `missing-summary.txt`, `backup-errors.log`: verification

Verification: 6,059,288 files on the Mac and 5,685,953 in the backup. Everything that is missing falls into one of these groups:

- caches, temporary files and logs (~321k)
- cloud-only placeholders (~319k "Resource deadlock avoided" errors): Google Drive, OneDrive, Proton Drive (`Library/CloudStorage`, 43k) and iCloud Drive (`Library/Mobile Documents`, 1.6k). These live in the cloud.
- Home Assistant pipe files (skipped deliberately, because they hang `ditto`)
- Digiarty and Blender app-support files (re-copy attempted, still missing, low importance)

The 550 GB `com.apple.container` snapshot is sparse, so it uses far less space on the Lexar.

## Lessons learned from Recovery mode

- Recovery has `ditto`, `find`, `awk`, `sort`, `curl` and `defaults`, but **no `diff`** (and `du` may be missing). Compare file lists with `awk`.
- `/tmp` in Recovery is tiny and can be full (`curl: (23)`). Download scripts to the external drive instead.
- `ditto` can hang forever on named pipes (FIFOs). Find them with `find … -type p` and run `killall ditto` from a second Terminal window. Ctrl+C would kill the whole script.
- Always unlock the Data volume first (`diskutil apfs unlockVolume "Macintosh HD - Data"`), otherwise copies silently do nothing.
- Cloud-synced placeholders can't be copied from Recovery ("Resource deadlock avoided").
- `dscl` attribute names are case-sensitive (`UserShell`, `RealName`). `-create` on a group *replaces* its members, so use `-append`.

## Scripts (this repo, branch `backup`)

Run from Recovery Terminal with:

```
curl -fsSL https://raw.githubusercontent.com/pcvaders/mac-m3/backup/<name>.sh -o /Volumes/Lex4TB/<name>.sh && bash /Volumes/Lex4TB/<name>.sh
```

| Script | Purpose |
|---|---|
| `b.sh` | Finish the backup: dotfiles, Library, Shared, app list, file-list verification |
| `r.sh` | Re-copy Group Containers (skipping Home Assistant) plus Digiarty and Blender, then re-verify |
| `v.sh` | Verify the backup with `awk` and summarise what is missing by folder |
| `d.sh` | Read-only diagnostics: panics, crash reports, install log, startup items, profiles |
| `s.sh` | Read-only: WindowServer/loginwindow crash details and any non-Apple code loaded |
| `w.sh` | Reversibly move WindowServer display prefs aside (`undo` supported) |
| `c.sh` | Reversibly disable the Apple `container` data and launch items (not needed in the end) |

## Outcome (11 Oct 2026)

Erasing the disk and reinstalling **macOS Tahoe 26.7.1** (public) from Recovery fixed it: login and the desktop work.

**What this proves:** the hardware (M3, display, SSD) is fine.

**What it doesn't prove:** the erase removed the 27.2 beta *and* everything on the old disk at the same time, so we can't say which one caused the loop. Ruled out along the way:

- kernel extensions (Full Security)
- display prefs (`w.sh`)
- peripherals
- a single user account (Safe Mode and a second admin account looped too)

Remaining suspects:

1. a 27.2-beta WindowServer/display-firmware bug
2. third-party system software restored onto the disk (BGM audio driver, NDI virtual camera, Little Snitch, EaseUS NTFS, Docker, …)

**How to narrow it down from here:** upgrade to public 27.0.1 on the clean system, then restore files and reinstall apps in stages, restarting after each piece of system-level software. If the loop comes back, the last thing added is the cause. If it never does, the beta was the cause.

## Next steps

1. Unplug the Lexar. Erase **Macintosh HD** (APFS, Erase Volume Group). Choose **Reinstall macOS Tahoe** (public).
2. Make a fresh account with no migration, and confirm that login works.
3. Turn **Beta Updates off**, then update to the latest **public** macOS 27 before restoring app data. The data was last used on 27, so Tahoe may not open some libraries.
4. Restore Documents, Desktop, Pictures and the rest first. Restore app data selectively. **Do not** restore old Library wholesale, launch daemons or drivers.
5. If Tahoe also loops: take it to the Apple Store (AppleCare) for a DFU restore to public macOS and possible hardware/firmware diagnosis.
6. Report to Apple via Feedback Assistant with the diagnostics file.
7. Housekeeping: delete the `helper` admin account once restored, and set the GitHub repo back to private.
